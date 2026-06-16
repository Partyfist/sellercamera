//
//  CaptureScreen.swift
//  SellerCamera
//
//  Created by Codex on 2026/3/30.
//

import AVFoundation
import Combine
import PhotosUI
import SwiftUI
import UIKit

struct CaptureScreen: View {
    @StateObject private var cameraRuntime = CaptureCameraRuntime()
    @State private var isLatestReviewPresented = false
    @State private var isImportPickerPresented = false
    @State private var selectedImportPhotoItem: PhotosPickerItem?
    @State private var isImportingPhoto = false
    @State private var selectedCaptureIntent: CaptureIntentKind = .standard
    @State private var activeControlTarget: CaptureActiveControlTarget = .none
    @State private var activeBottomParameterKind: CaptureProfessionalParameterKind?
    @State private var isBottomParameterPanelExpanded = false
    @State private var isManualFocusModeEnabled = false
    @State private var isManualFocusRulerPresented = false
    @State private var isMoreOptionsPanelPresented = false
    @State private var isCaptureOptionPanelPresented = false
    @State private var pendingExposureBiasWheelValue: Double?
    @State private var pendingExposureBiasUpdatedAt: Date?
    @State private var lastDispatchedExposureBiasValue: Double?
    @State private var pendingWhiteBalanceWheelValue: Double?
    @State private var pendingWhiteBalanceUpdatedAt: Date?
    @State private var lastDispatchedWhiteBalanceValue: Double?
    @State private var pendingTintWheelValue: Double?
    @State private var pendingTintUpdatedAt: Date?
    @State private var lastDispatchedTintValue: Double?
    @State private var pendingISOWheelValue: Double?
    @State private var pendingISOUpdatedAt: Date?
    @State private var lastDispatchedISOValue: Double?
    @State private var pendingShutterWheelDurationSeconds: Double?
    @State private var pendingShutterUpdatedAt: Date?
    @State private var lastDispatchedShutterDurationSeconds: Double?
    @State private var lastDispatchedShutterTickIndex: Int?
    @State private var committedShutterDurationSeconds: Double?
    @State private var committedShutterTickIndex: Int?
    @State private var isShutterRulerInteracting = false
    @State private var pendingManualFocusPosition: Float?
    @State private var pendingManualFocusUpdatedAt: Date?
    @State private var lastDispatchedManualFocusPosition: Float?
    @State private var lastManualFocusRuntimeWriteAt: Date = .distantPast
    private let exposureBiasPendingTimeout: TimeInterval = 1.2
    private let whiteBalancePendingTimeout: TimeInterval = 1.5
    private let tintPendingTimeout: TimeInterval = 1.5
    private let isoPendingTimeout: TimeInterval = 1.5
    private let shutterPendingTimeout: TimeInterval = 1.5
    private let manualFocusPendingTimeout: TimeInterval = 1.4
    private let exposureBiasPendingTicker = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    private var isLensZoomControlPresented: Bool {
        if case .lensZoom = activeControlTarget {
            return true
        }
        return false
    }

    private var isAnyFloatingControlPresented: Bool {
        isLensZoomControlPresented || isManualFocusRulerPresented || isCaptureOptionPanelPresented
    }

    private var primaryParameterKinds: [CaptureProfessionalParameterKind] {
        [.exposureCompensation, .whiteBalance, .tint, .iso, .shutter]
    }

    private var primaryParameterStates: [CaptureProfessionalParameterState] {
        primaryParameterKinds.map(parameterState(for:))
    }

    private var bottomParameterItems: [CaptureBottomParameterItem] {
        primaryParameterStates.map(bottomParameterItem(for:))
    }

    private var horizontalRulerItems: [CaptureHorizontalParameterRulerItem] {
        primaryParameterStates.map(horizontalRulerItem(for:))
    }

    private var isBottomOverlayControlPresented: Bool {
        isBottomParameterPanelExpanded || isLensZoomControlPresented
    }

    private var isManualFocusModeActive: Bool {
        !cameraRuntime.isFocusExposureLocked && (isManualFocusModeEnabled || cameraRuntime.focusControlMode == .manual)
    }

    private var isExposureCompensationLimitedByManualExposure: Bool {
        pendingISOWheelValue != nil
            || pendingShutterWheelDurationSeconds != nil
            || cameraRuntime.selectedISOPreset != .auto
            || cameraRuntime.selectedShutterPreset != .auto
    }

    private var exposureCompensationLimitedReasonText: String {
        if pendingISOWheelValue != nil || cameraRuntime.selectedISOPreset != .auto {
            return "手动 ISO 生效中，先恢复 ISO Auto 后再调 EV"
        }
        if pendingShutterWheelDurationSeconds != nil || cameraRuntime.selectedShutterPreset != .auto {
            return "手动快门生效中，先恢复快门 Auto 后再调 EV"
        }
        return "手动曝光生效中，先恢复 ISO / 快门 Auto 后再调 EV"
    }

    private var manualFocusDisplayPosition: Double {
        if let pendingManualFocusPosition {
            return Double(pendingManualFocusPosition)
        }
        guard cameraRuntime.focusControlMode == .manual else {
            return 0.5
        }
        return Double(cameraRuntime.currentManualFocusPosition)
    }

    private var manualFocusRulerValues: [Double] {
        stride(from: 0.0, through: 1.0001, by: ManualFocusRulerTuning.lensPositionStep)
            .map { min(1.0, max(0.0, ($0 * 1000).rounded() / 1000)) }
    }

    private var shutterPrimaryAnchorDenominators: [Double] {
        [30, 50, 60, 96, 100, 120, 125, 200, 240, 250, 500, 1000, 2000, 4000, 8000]
    }

    private var shutterPrimaryAnchorDurations: [Double] {
        shutterPrimaryAnchorDenominators.map { 1.0 / $0 }
    }

    private var selectedManualFocusRulerIndex: Int {
        nearestManualFocusRulerIndex(to: manualFocusDisplayPosition, in: manualFocusRulerValues)
    }

    private var bottomControlDeckHeight: CGFloat {
        150
    }

    @ViewBuilder
    private var bottomControlDeck: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 2) {
                CaptureBottomParameterBar(
                    items: bottomParameterItems,
                    activeKind: activeBottomParameterKind,
                    onSelect: handleBottomParameterSelection
                )
                .padding(.horizontal, 14)

                CaptureBottomActionBar(
                    latestResult: cameraRuntime.latestStillPhotoResult,
                    onTapLatestResult: {
                        guard cameraRuntime.latestStillPhotoResult != nil else {
                            cameraRuntime.captureHintText = "暂无最近结果，可先拍摄一张"
                            return
                        }
                        cameraRuntime.prepareForReviewPresentation()
                        isLatestReviewPresented = true
                    },
                    onShutterTap: cameraRuntime.triggerPhotoCapture,
                    onTapGalleryPlaceholder: {
                        cameraRuntime.captureHintText = "图册与管理入口已预留，后续任务包接入完整能力。"
                    }
                )
                .padding(.horizontal, 18)
            }
            .opacity(isBottomParameterPanelExpanded ? 0 : 1)
            .allowsHitTesting(!isBottomParameterPanelExpanded)

            if isBottomParameterPanelExpanded {
                CaptureHorizontalParameterRulerPanel(
                    items: horizontalRulerItems,
                    activeKind: activeBottomParameterKind,
                    onSelect: handleBottomParameterSelection,
                    onControlTap: { kind in
                        withAnimation(.easeOut(duration: 0.14)) {
                            activeBottomParameterKind = kind
                        }
                        if kind == .exposureCompensation {
                            resetExposureCompensationWheel()
                        } else if kind == .whiteBalance {
                            applyWhiteBalanceAutoFromWheel()
                        } else if kind == .tint {
                            applyTintResetFromWheel()
                        } else if kind == .iso {
                            applyISOAutoFromWheel()
                        } else if kind == .shutter {
                            applyShutterAutoFromWheel()
                        }
                    },
                    onWheelStep: { kind, direction in
                        let didApply: Bool
                        switch kind {
                        case .exposureCompensation:
                            didApply = stepExposureCompensationWheel(by: direction)
                        case .whiteBalance:
                            didApply = stepWhiteBalanceWheel(by: direction)
                        case .tint:
                            didApply = stepTintWheel(by: direction)
                        case .iso:
                            didApply = stepISOWheel(by: direction)
                        case .shutter:
                            didApply = stepShutterWheel(by: direction)
                        default:
                            didApply = false
                        }
                        logParameterRuler(
                            kind: kind,
                            inputValue: Double(direction),
                            formattedValue: bottomParameterValueText(for: parameterState(for: kind)),
                            applied: didApply
                        )
                        return didApply
                    },
                    onRulerDragStateChange: { kind, isDragging in
                        guard kind == .shutter else { return }
                        isShutterRulerInteracting = isDragging
                        logShutterWheel(
                            "gesture state isDragging=\(isDragging) " +
                            "pendingTickIndex=\((pendingShutterWheelDurationSeconds == nil ? nil : lastDispatchedShutterTickIndex).map(String.init) ?? "nil") " +
                            "committedTickIndex=\(committedShutterTickIndex.map(String.init) ?? "nil") " +
                            "committedDuration=\(committedShutterDurationSeconds.map { String(format: "%.8f", $0) } ?? "nil")"
                        )
                    },
                    onDismiss: dismissInlineControls
                )
                .padding(.horizontal, 14)
                .transition(.asymmetric(
                    insertion: .opacity,
                    removal: .opacity
                ))
            } else if isLensZoomControlPresented {
                CaptureLensZoomControlPanel(
                    cameraRuntime: cameraRuntime,
                    onFocusDial: {}
                )
                .padding(.horizontal, 14)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
            }
        }
        .frame(height: bottomControlDeckHeight)
        .padding(.bottom, 4)
        .animation(.easeOut(duration: 0.18), value: isBottomOverlayControlPresented)
    }

    private func handleBottomParameterSelection(_ kind: CaptureProfessionalParameterKind) {
        let state = parameterState(for: kind)
        let isAvailable = state.mode != .disabled
        logParameterTap(
            parameter: kind,
            allowed: isAvailable,
            activePanel: activeBottomParameterKind,
            blockedReason: isAvailable ? nil : state.hintText
        )
        cameraRuntime.logManualParameterCompatibilityForPanel(reason: "panelOpen:\(kind.rawValue)")
        guard isAvailable else {
            cameraRuntime.captureHintText = state.hintText
            logParameterGuard(parameter: kind, reason: "disabled")
            return
        }

        if kind == .exposureCompensation, !state.isAdjustable {
            pendingExposureBiasWheelValue = nil
            pendingExposureBiasUpdatedAt = nil
            lastDispatchedExposureBiasValue = nil
            cameraRuntime.captureHintText = state.hintText
            logExposureTriangle("EV selection blocked reason=\(state.hintText)")
            logParameterGuard(parameter: kind, reason: "notAdjustable \(state.hintText)")
            return
        }

        if !state.isAdjustable {
            clearPendingValue(for: kind)
            logParameterGuard(parameter: kind, reason: "notAdjustable panelOnly \(state.hintText)")
        }

        withAnimation(.easeOut(duration: 0.18)) {
            isMoreOptionsPanelPresented = false
            isManualFocusRulerPresented = false
            if isBottomParameterPanelExpanded, activeBottomParameterKind == kind {
                isBottomParameterPanelExpanded = false
            } else {
                activeBottomParameterKind = kind
                activeControlTarget = .none
                isBottomParameterPanelExpanded = true
            }
        }

        cameraRuntime.captureHintText = state.isAdjustable
            ? "\(bottomParameterTitle(for: kind))：横拖下方刻度可手动调整"
            : state.hintText
    }

    private func dismissInlineControls() {
        guard isBottomParameterPanelExpanded || activeControlTarget != .none || isManualFocusRulerPresented || isCaptureOptionPanelPresented else { return }
        withAnimation(.easeOut(duration: 0.18)) {
            isBottomParameterPanelExpanded = false
            activeControlTarget = .none
            isManualFocusRulerPresented = false
            isCaptureOptionPanelPresented = false
        }
    }

    private func dismissMoreOptionsPanel() {
        guard isMoreOptionsPanelPresented else { return }
        withAnimation(.easeOut(duration: 0.16)) {
            isMoreOptionsPanelPresented = false
        }
    }

    private func handleMoreOptionsTap() {
        withAnimation(.easeOut(duration: 0.16)) {
            if isMoreOptionsPanelPresented {
                isMoreOptionsPanelPresented = false
            } else {
                isCaptureOptionPanelPresented = false
                isBottomParameterPanelExpanded = false
                activeControlTarget = .none
                isManualFocusRulerPresented = false
                isMoreOptionsPanelPresented = true
            }
        }
    }

    private func handleCaptureOptionTap() {
        withAnimation(.easeOut(duration: 0.16)) {
            if isCaptureOptionPanelPresented {
                isCaptureOptionPanelPresented = false
            } else {
                isMoreOptionsPanelPresented = false
                isBottomParameterPanelExpanded = false
                activeControlTarget = .none
                isManualFocusRulerPresented = false
                isCaptureOptionPanelPresented = true
            }
        }
    }

    private func dismissInlineControlsForPreviewTapIfNeeded() -> Bool {
        if isCaptureOptionPanelPresented {
            dismissInlineControls()
            return true
        }
        if isMoreOptionsPanelPresented {
            dismissMoreOptionsPanel()
            return true
        }
        if isBottomParameterPanelExpanded || activeControlTarget != .none {
            dismissInlineControls()
            return true
        }
        if isManualFocusRulerPresented {
            withAnimation(.easeOut(duration: 0.18)) {
                isManualFocusRulerPresented = false
            }
            return true
        }
        if isManualFocusModeActive {
            cameraRuntime.captureHintText = "MF 模式中，点击 MF 退出后可点按对焦"
            return true
        }
        return false
    }

    private func toggleManualFocusMode() {
        guard !cameraRuntime.isFocusExposureLocked else {
            cameraRuntime.captureHintText = "AE/AF 锁定中，长按画面解除后可进入 MF"
            return
        }
        guard cameraRuntime.isManualFocusSupported else {
            cameraRuntime.captureHintText = "当前镜头不支持手动对焦"
            return
        }
        withAnimation(.easeOut(duration: 0.18)) {
            isBottomParameterPanelExpanded = false
            activeControlTarget = .none
            isMoreOptionsPanelPresented = false
        }

        if isManualFocusModeActive {
            isManualFocusModeEnabled = false
            isManualFocusRulerPresented = false
            clearManualFocusPending()
            cameraRuntime.setProductFocusAssistManualSuppression(false)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            cameraRuntime.restoreAutofocusMode()
            cameraRuntime.captureHintText = "已恢复 AF"
        } else {
            isManualFocusModeEnabled = true
            isManualFocusRulerPresented = true
            cameraRuntime.setProductFocusAssistManualSuppression(true)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            cameraRuntime.captureHintText = "MF 模式已开启，左近右远，拖动刻度微调对焦"
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.06, blue: 0.08),
                    Color(red: 0.02, green: 0.03, blue: 0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                CaptureTopStatusBar(
                    memoryStatusText: cameraRuntime.latestCaptureStatusText,
                    flashMode: cameraRuntime.selectedFlashMode,
                    isFlashModeSupported: cameraRuntime.isFlashModeSupported,
                    onTapFlash: cameraRuntime.cycleFlashMode,
                    isExposureLockSupported: cameraRuntime.isExposureLockSupported,
                    isExposureLocked: cameraRuntime.isExposureLocked || cameraRuntime.isFocusExposureLocked,
                    onToggleExposureLock: cameraRuntime.toggleExposureLock,
                    cameraPosition: cameraRuntime.activeCameraPosition,
                    canSwitchCamera: cameraRuntime.canSwitchCamera,
                    onTapSwitchCamera: cameraRuntime.toggleCameraPosition,
                    selectedAspectRatioPreset: cameraRuntime.selectedAspectRatioPreset,
                    selectedPixelPreset: cameraRuntime.selectedPixelPreset,
                    isRawCaptureSupported: cameraRuntime.isRAWCaptureSupported,
                    isCaptureOptionsPresented: isCaptureOptionPanelPresented,
                    onTapCaptureOptions: handleCaptureOptionTap,
                    isGridEnabled: cameraRuntime.isGridEnabled,
                    onToggleGrid: cameraRuntime.toggleGrid,
                    isLevelIndicatorEnabled: cameraRuntime.isLevelIndicatorEnabled,
                    onToggleLevelIndicator: cameraRuntime.toggleLevelIndicator,
                    selectedTimerOption: cameraRuntime.selectedTimerOption,
                    onCycleTimerOption: cameraRuntime.cycleTimerOption,
                    selectedBurstOption: cameraRuntime.selectedBurstOption,
                    onCycleBurstOption: cameraRuntime.cycleBurstOption,
                    isImportingPhoto: isImportingPhoto,
                    onTapImport: {
                        guard !isImportingPhoto else { return }
                        isImportPickerPresented = true
                    },
                    isMoreOptionsPresented: isMoreOptionsPanelPresented,
                    onTapMoreOptions: handleMoreOptionsTap
                )
                .padding(.horizontal, 14)
                .padding(.top, 6)
                .padding(.bottom, 6)
                .opacity(isAnyFloatingControlPresented ? 0.86 : 1)
                .animation(.easeInOut(duration: 0.18), value: isAnyFloatingControlPresented)

                ZStack(alignment: .top) {
                    CapturePreviewContainer(
                        cameraRuntime: cameraRuntime,
                        selectedAspectRatioPreset: cameraRuntime.selectedAspectRatioPreset,
                        captureHintText: cameraRuntime.captureHintText,
                        isAnyFloatingControlPresented: isAnyFloatingControlPresented,
                        activeControlTarget: $activeControlTarget,
                        isManualFocusModeActive: isManualFocusModeActive,
                        isManualFocusRulerPresented: isManualFocusRulerPresented && isManualFocusModeActive,
                        manualFocusRulerValues: manualFocusRulerValues,
                        selectedManualFocusRulerIndex: selectedManualFocusRulerIndex,
                        manualFocusValueText: formattedManualFocusRulerValue(manualFocusDisplayPosition),
                        isManualFocusRulerEnabled: isManualFocusModeActive && cameraRuntime.isManualFocusSupported && !cameraRuntime.isFocusExposureLocked,
                        onToggleExposureLock: cameraRuntime.toggleExposureLock,
                        onToggleManualFocusMode: toggleManualFocusMode,
                        onManualFocusStep: stepManualFocusRuler,
                        onTapPreviewBeforeFocus: dismissInlineControlsForPreviewTapIfNeeded
                    )

                    if isCaptureOptionPanelPresented {
                        CaptureOptionControlPanel(
                            selectedAspectRatioPreset: cameraRuntime.selectedAspectRatioPreset,
                            selectedPixelPreset: cameraRuntime.selectedPixelPreset,
                            isRawCaptureSupported: cameraRuntime.isRAWCaptureSupported,
                            onSelectAspectRatioIndex: { index, source, context in
                                selectAspectRatioOption(index: index, source: source, context: context)
                            },
                            onSelectPixelIndex: { index, source, context in
                                selectPixelOption(index: index, source: source, context: context)
                            }
                        )
                        .padding(.horizontal, 14)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(5)
                    }
                }
                .frame(maxHeight: .infinity)
                .padding(.top, 0)

                CaptureIntentSwitcherView(selectedIntent: $selectedCaptureIntent)
                    .padding(.horizontal, 14)
                    .padding(.top, 1)
                    .padding(.bottom, 3)
                    .opacity(isAnyFloatingControlPresented ? 0.6 : 1)
                    .animation(.easeInOut(duration: 0.18), value: isAnyFloatingControlPresented)
                .simultaneousGesture(
                    TapGesture().onEnded {
                        dismissInlineControls()
                        dismissMoreOptionsPanel()
                        isCaptureOptionPanelPresented = false
                    }
                )

                bottomControlDeck
                .padding(.top, 1)
            }

            if isMoreOptionsPanelPresented {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissMoreOptionsPanel()
                    }
                    .transition(.opacity)
                    .zIndex(20)

                CaptureMoreOptionsPanel(
                    isGridEnabled: cameraRuntime.isGridEnabled,
                    onToggleGrid: cameraRuntime.toggleGrid,
                    isLevelIndicatorEnabled: cameraRuntime.isLevelIndicatorEnabled,
                    onToggleLevelIndicator: cameraRuntime.toggleLevelIndicator,
                    selectedTimerOption: cameraRuntime.selectedTimerOption,
                    onCycleTimerOption: cameraRuntime.cycleTimerOption,
                    selectedBurstOption: cameraRuntime.selectedBurstOption,
                    onCycleBurstOption: cameraRuntime.cycleBurstOption,
                    selectedStabilizerMode: cameraRuntime.selectedStabilizerMode,
                    onCycleStabilizerMode: cameraRuntime.cycleStabilizerMode,
                    isImportingPhoto: isImportingPhoto,
                    onTapImport: {
                        guard !isImportingPhoto else { return }
                        isImportPickerPresented = true
                    }
                )
                .padding(.top, 45)
                .padding(.trailing, 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity
                ))
                .zIndex(21)
            }

            if isLatestReviewPresented, let latest = cameraRuntime.latestStillPhotoResult {
                CaptureLatestReviewContainerOverlay(
                    latestResult: latest,
                    processedResult: cameraRuntime.latestProcessedResult,
                    isProcessing: cameraRuntime.isProcessingLatestResult,
                    processingErrorMessage: cameraRuntime.latestProcessingErrorText,
                    isSavingOriginal: cameraRuntime.isSavingLatestOriginal,
                    isOriginalSaved: cameraRuntime.isLatestOriginalSaveCompleted,
                    originalSaveFailureMessage: cameraRuntime.latestOriginalSaveFailureText,
                    isSavingProcessed: cameraRuntime.isSavingLatestProcessed,
                    isProcessedSaved: cameraRuntime.isLatestProcessedSaveCompleted,
                    processedSaveFailureMessage: cameraRuntime.latestProcessedSaveFailureText,
                    onSaveOriginal: {
                        _ = cameraRuntime.triggerSaveForLatestOriginal()
                    },
                    onGenerateWhiteBackground: {
                        _ = cameraRuntime.triggerProcessingForConfirmedLatest()
                    },
                    onSaveWhiteBackground: {
                        _ = cameraRuntime.triggerSaveForLatestProcessed()
                    },
                    onClose: {
                        cameraRuntime.restoreAfterReviewDismissed()
                        isLatestReviewPresented = false
                    }
                )
            }
        }
        .onReceive(cameraRuntime.$latestStillPhotoResult) { latestResult in
            if latestResult == nil {
                isLatestReviewPresented = false
                cameraRuntime.restoreAfterReviewDismissed()
            }
        }
        .photosPicker(
            isPresented: $isImportPickerPresented,
            selection: $selectedImportPhotoItem,
            matching: .images,
            preferredItemEncoding: .automatic
        )
        .onChange(of: selectedImportPhotoItem) { item in
            guard let item else { return }
            Task {
                await handleImportedPhotoSelection(item)
            }
        }
        .onChange(of: selectedCaptureIntent) { intent in
            cameraRuntime.captureHintText = intent.hintText
        }
        .onChange(of: activeControlTarget) { target in
            if target == .lensZoom, isBottomParameterPanelExpanded {
                isBottomParameterPanelExpanded = false
            }
            if target == .lensZoom {
                isManualFocusRulerPresented = false
            }
            if target != .none {
                dismissMoreOptionsPanel()
                isCaptureOptionPanelPresented = false
            }
        }
        .onChange(of: cameraRuntime.currentExposureBias) { value in
            guard let pendingExposureBiasWheelValue else { return }
            if abs(Double(value) - pendingExposureBiasWheelValue) < 0.06 {
                logExposureBiasWheel("runtime confirmed EV \(formattedEVTick(Double(value))), pending cleared")
                self.pendingExposureBiasWheelValue = nil
                self.pendingExposureBiasUpdatedAt = nil
                self.lastDispatchedExposureBiasValue = nil
            }
        }
        .onChange(of: cameraRuntime.currentWhiteBalanceTemperature) { value in
            guard let pendingWhiteBalanceWheelValue else { return }
            let confirmationTolerance = max(cameraRuntime.whiteBalanceDialStepValue * 0.5, 30)
            if abs(Double(value) - pendingWhiteBalanceWheelValue) <= confirmationTolerance {
                logWhiteBalanceWheel("runtime confirmed WB \(formattedWhiteBalanceTick(Double(value))), pending cleared")
                self.pendingWhiteBalanceWheelValue = nil
                self.pendingWhiteBalanceUpdatedAt = nil
                self.lastDispatchedWhiteBalanceValue = nil
            }
        }
        .onChange(of: cameraRuntime.selectedWhiteBalancePreset) { preset in
            guard preset == .auto else { return }
            if let pendingWhiteBalanceWheelValue {
                // Manual takeover wins over a stale runtime AUTO echo while the device write is still pending.
                logWhiteBalanceWheel("runtime AUTO ignored while pending manual WB \(formattedWhiteBalanceTick(pendingWhiteBalanceWheelValue))")
                return
            }
            pendingWhiteBalanceWheelValue = nil
            pendingWhiteBalanceUpdatedAt = nil
            lastDispatchedWhiteBalanceValue = nil
            logWhiteBalanceWheel("WB switched to AUTO, cleared pending")
            pendingTintWheelValue = nil
            pendingTintUpdatedAt = nil
            lastDispatchedTintValue = nil
            logTintWheel("WB switched to AUTO, Tint pending cleared")
        }
        .onChange(of: cameraRuntime.currentWhiteBalanceTint) { value in
            guard let pendingTintWheelValue else { return }
            let confirmationTolerance = max(cameraRuntime.whiteBalanceTintDialStepValue * 0.5, 2)
            if abs(Double(value) - pendingTintWheelValue) <= confirmationTolerance {
                logTintWheel("runtime confirmed Tint \(formattedTintTick(Double(value))), pending cleared")
                self.pendingTintWheelValue = nil
                self.pendingTintUpdatedAt = nil
                self.lastDispatchedTintValue = nil
            }
        }
        .onChange(of: cameraRuntime.currentManualISOValue) { value in
            guard let pendingISOWheelValue else { return }
            let confirmationTolerance: Double = 1.0
            if abs(Double(value) - pendingISOWheelValue) <= confirmationTolerance {
                logISOWheel("runtime confirmed ISO \(formattedISOTick(Double(value))), pending cleared")
                self.pendingISOWheelValue = nil
                self.pendingISOUpdatedAt = nil
                self.lastDispatchedISOValue = nil
            }
        }
        .onChange(of: cameraRuntime.selectedISOPreset) { preset in
            if preset != .auto {
                clearExposureBiasPendingForManualExposure(reason: "manual ISO")
                logExposureTriangle("isoMode=manual shutterMode=\(cameraRuntime.selectedShutterPreset == .auto ? "auto" : "manual") evState=locked reason=manualISO")
                return
            }
            if let pendingISOWheelValue {
                // Keep the first manual drag visible until the runtime confirms or the pending timeout expires.
                logISOWheel("runtime AUTO ignored while pending manual ISO \(formattedISOTick(pendingISOWheelValue))")
                return
            }
            pendingISOWheelValue = nil
            pendingISOUpdatedAt = nil
            lastDispatchedISOValue = nil
            logExposureTriangle("isoMode=auto shutterMode=\(cameraRuntime.selectedShutterPreset == .auto ? "auto" : "manual") evState=\(cameraRuntime.selectedShutterPreset == .auto ? "enabled" : "locked") reason=isoAuto")
            logISOWheel("ISO switched to AUTO, cleared pending")
        }
        .onChange(of: cameraRuntime.currentManualShutterDurationSeconds) { value in
            guard let pendingShutterWheelDurationSeconds else { return }
            let delta = abs(value - pendingShutterWheelDurationSeconds)
            let confirmationTolerance = max(0.000001, pendingShutterWheelDurationSeconds * 0.01)
            let runtimeConfirmedTickIndex = shutterWheelDurationValues().enumerated().min { lhs, rhs in
                abs(lhs.element - value) < abs(rhs.element - value)
            }?.offset
            logExposureReadback(
                "targetDuration=\(String(format: "%.8f", pendingShutterWheelDurationSeconds)) " +
                "deviceReadbackDuration=\(String(format: "%.8f", value)) " +
                "deltaTargetToReadback=\(String(format: "%.8f", delta)) " +
                "runtimeConfirmedTickIndex=\(runtimeConfirmedTickIndex.map(String.init) ?? "nil") " +
                "pendingTickIndex=\(lastDispatchedShutterTickIndex.map(String.init) ?? "nil") " +
                "committedTickIndex=\(committedShutterTickIndex.map(String.init) ?? "nil") " +
                "display=\(formattedShutterDisplayText(seconds: value) ?? "--") " +
                "reason=\(isShutterRulerInteracting ? "deferredDuringDrag" : (delta <= confirmationTolerance ? "runtimeConfirmed" : "waiting"))"
            )
            guard !isShutterRulerInteracting else { return }
            if delta <= confirmationTolerance {
                logShutterWheel("runtime confirmed shutter \(formattedShutterDisplayText(seconds: value) ?? "--"), pending cleared")
                self.committedShutterDurationSeconds = pendingShutterWheelDurationSeconds
                self.committedShutterTickIndex = lastDispatchedShutterTickIndex ?? runtimeConfirmedTickIndex
                self.pendingShutterWheelDurationSeconds = nil
                self.pendingShutterUpdatedAt = nil
            }
        }
        .onChange(of: cameraRuntime.selectedShutterPreset) { preset in
            if preset != .auto {
                clearExposureBiasPendingForManualExposure(reason: "manual shutter")
                logExposureTriangle("isoMode=\(cameraRuntime.selectedISOPreset == .auto ? "auto" : "manual") shutterMode=manual evState=locked reason=manualShutter")
                return
            }
            if let pendingShutterWheelDurationSeconds {
                // Shutter writes are asynchronous; do not let an AUTO echo erase an in-flight manual drag.
                logShutterWheel("runtime AUTO ignored while pending manual shutter \(formattedShutterDisplayText(seconds: pendingShutterWheelDurationSeconds) ?? "--")")
                return
            }
            pendingShutterWheelDurationSeconds = nil
            pendingShutterUpdatedAt = nil
            lastDispatchedShutterDurationSeconds = nil
            lastDispatchedShutterTickIndex = nil
            committedShutterDurationSeconds = nil
            committedShutterTickIndex = nil
            logExposureTriangle("isoMode=\(cameraRuntime.selectedISOPreset == .auto ? "auto" : "manual") shutterMode=auto evState=\(cameraRuntime.selectedISOPreset == .auto ? "enabled" : "locked") reason=shutterAuto")
            logShutterWheel("Shutter switched to AUTO, cleared pending")
        }
        .onChange(of: cameraRuntime.currentManualFocusPosition) { value in
            guard let pendingManualFocusPosition else { return }
            if abs(value - pendingManualFocusPosition) <= 0.02 {
                clearManualFocusPending()
            }
        }
        .onChange(of: cameraRuntime.focusControlMode) { mode in
            if mode == .auto {
                isManualFocusModeEnabled = false
                isManualFocusRulerPresented = false
                clearManualFocusPending()
                cameraRuntime.setProductFocusAssistManualSuppression(false)
            }
        }
        .onChange(of: cameraRuntime.isFocusExposureLocked) { isLocked in
            guard isLocked else { return }
            isManualFocusModeEnabled = false
            isManualFocusRulerPresented = false
            clearManualFocusPending()
            cameraRuntime.setProductFocusAssistManualSuppression(false)
        }
        .onReceive(exposureBiasPendingTicker) { _ in
            if let pendingExposureBiasWheelValue, let pendingExposureBiasUpdatedAt,
               Date().timeIntervalSince(pendingExposureBiasUpdatedAt) > exposureBiasPendingTimeout {
                logExposureBiasWheel("pending timeout for EV \(formattedEVTick(pendingExposureBiasWheelValue)), fallback to runtime \(formattedEVTick(Double(cameraRuntime.currentExposureBias)))")
                self.pendingExposureBiasWheelValue = nil
                self.pendingExposureBiasUpdatedAt = nil
                self.lastDispatchedExposureBiasValue = nil
            }

            if let pendingWhiteBalanceWheelValue, let pendingWhiteBalanceUpdatedAt,
               Date().timeIntervalSince(pendingWhiteBalanceUpdatedAt) > whiteBalancePendingTimeout {
                logWhiteBalanceWheel("pending timeout for WB \(formattedWhiteBalanceTick(pendingWhiteBalanceWheelValue)), fallback to runtime \(formattedWhiteBalanceTick(Double(cameraRuntime.currentWhiteBalanceTemperature)))")
                self.pendingWhiteBalanceWheelValue = nil
                self.pendingWhiteBalanceUpdatedAt = nil
                self.lastDispatchedWhiteBalanceValue = nil
            }

            if let pendingTintWheelValue, let pendingTintUpdatedAt,
               Date().timeIntervalSince(pendingTintUpdatedAt) > tintPendingTimeout {
                logTintWheel("pending timeout for Tint \(formattedTintTick(pendingTintWheelValue)), fallback to runtime \(formattedTintTick(Double(cameraRuntime.currentWhiteBalanceTint)))")
                self.pendingTintWheelValue = nil
                self.pendingTintUpdatedAt = nil
                self.lastDispatchedTintValue = nil
            }

            if let pendingISOWheelValue, let pendingISOUpdatedAt,
               Date().timeIntervalSince(pendingISOUpdatedAt) > isoPendingTimeout {
                logISOWheel("pending timeout for ISO \(formattedISOTick(pendingISOWheelValue)), fallback to runtime \(formattedISOTick(Double(cameraRuntime.currentManualISOValue)))")
                self.pendingISOWheelValue = nil
                self.pendingISOUpdatedAt = nil
                self.lastDispatchedISOValue = nil
            }

            if let pendingShutterWheelDurationSeconds, let pendingShutterUpdatedAt,
               Date().timeIntervalSince(pendingShutterUpdatedAt) > shutterPendingTimeout {
                logShutterWheel("pending timeout for shutter \(formattedShutterDisplayText(seconds: pendingShutterWheelDurationSeconds) ?? "--"), fallback to runtime \(formattedShutterDisplayText(seconds: cameraRuntime.currentManualShutterDurationSeconds) ?? "--")")
                self.pendingShutterWheelDurationSeconds = nil
                self.pendingShutterUpdatedAt = nil
                self.lastDispatchedShutterDurationSeconds = nil
                self.lastDispatchedShutterTickIndex = nil
            }

            if let pendingManualFocusPosition, let pendingManualFocusUpdatedAt,
               Date().timeIntervalSince(pendingManualFocusUpdatedAt) > manualFocusPendingTimeout {
                logManualFocusRuler("pending timeout for MF \(formattedManualFocusRulerValue(Double(pendingManualFocusPosition))), fallback to runtime \(formattedManualFocusRulerValue(Double(cameraRuntime.currentManualFocusPosition)))")
                clearManualFocusPending()
            }

        }
        .animation(.easeInOut(duration: 0.18), value: activeBottomParameterKind)
        .animation(.easeInOut(duration: 0.18), value: isBottomParameterPanelExpanded)
    }

    @MainActor
    private func handleImportedPhotoSelection(_ item: PhotosPickerItem) async {
        isImportingPhoto = true
        defer {
            isImportingPhoto = false
            selectedImportPhotoItem = nil
        }

        do {
            guard let imageData = try await item.loadTransferable(type: Data.self), !imageData.isEmpty else {
                cameraRuntime.notifyImportFailure("未读取到可用图片，请重试")
                return
            }
            _ = await cameraRuntime.importSinglePhotoFromLibraryData(imageData)
        } catch {
            cameraRuntime.notifyImportFailure("读取相册图片失败，请重试")
        }
    }

    private func selectAspectRatioPreset(_ preset: CapturePhotoAspectRatioPreset) {
        let allPresets = CapturePhotoAspectRatioPreset.allCases
        guard let index = allPresets.firstIndex(of: preset) else { return }
        selectAspectRatioOption(index: index, source: .tap)
    }

    private func selectPixelPreset(_ preset: CapturePhotoPixelPreset) {
        let allPresets = CapturePhotoPixelPreset.allCases
        guard let index = allPresets.firstIndex(of: preset) else { return }
        selectPixelOption(index: index, source: .tap)
    }

    private func selectAspectRatioOption(
        index: Int,
        source: CaptureOptionSelectionSource,
        context: CaptureOptionSelectionContext = .empty
    ) {
        let result = cameraRuntime.selectAspectRatioPreset(index: index, source: source.rawValue)
        logCaptureOptionControl(
            scope: .aspectRatio,
            source: source,
            context: context,
            targetIndex: index,
            selectedValue: result.selectedValue,
            runtimeAppliedValue: result.runtimeAppliedValue,
            fallbackReason: result.fallbackReason,
            generation: result.generation
        )
    }

    private func selectPixelOption(
        index: Int,
        source: CaptureOptionSelectionSource,
        context: CaptureOptionSelectionContext = .empty
    ) {
        let result = cameraRuntime.selectPixelPreset(index: index, source: source.rawValue)
        logCaptureOptionControl(
            scope: .outputQuality,
            source: source,
            context: context,
            targetIndex: index,
            selectedValue: result.selectedValue,
            runtimeAppliedValue: result.runtimeAppliedValue,
            fallbackReason: result.fallbackReason,
            generation: result.generation
        )
    }

    private func logCaptureOptionControl(
        scope: CaptureOptionControlScope,
        source: CaptureOptionSelectionSource,
        context: CaptureOptionSelectionContext,
        targetIndex: Int,
        selectedValue: String,
        runtimeAppliedValue: String,
        fallbackReason: String?,
        generation: UInt64
    ) {
#if DEBUG
        print(
            "[CaptureOptionControl] " +
            "scope=\(scope.rawValue) " +
            "source=\(source.rawValue) " +
            "startIndex=\(context.startIndex.map(String.init) ?? "nil") " +
            "targetIndex=\(targetIndex) " +
            "translation=\(context.translation.map { String(format: "%.1f", $0) } ?? "nil") " +
            "predictedTranslation=\(context.predictedTranslation.map { String(format: "%.1f", $0) } ?? "nil") " +
            "flingSteps=\(context.flingSteps.map(String.init) ?? "nil") " +
            "selectedValue=\(selectedValue) " +
            "runtimeAppliedValue=\(runtimeAppliedValue) " +
            "fallbackReason=\(fallbackReason ?? "none") " +
            "generation=\(generation)"
        )
#endif
    }
}

private struct CaptureLensZoomControlPanel: View {
    @ObservedObject var cameraRuntime: CaptureCameraRuntime
    let onFocusDial: () -> Void
    @State private var pendingLensZoomValue: Double?
    @State private var lastDispatchedLensZoomValue: Double?
    @State private var lastLensZoomPendingAt: Date?
    private let pendingTimeout: TimeInterval = 1.0

    private var displayZoomValue: Double {
        pendingLensZoomValue ?? cameraRuntime.lensZoomDialValue
    }

    private var lensZoomValues: [Double] {
        lensZoomRulerValues(range: cameraRuntime.lensZoomDialRange, currentValue: displayZoomValue)
    }

    private var selectedLensZoomIndex: Int {
        nearestLensZoomIndex(to: displayZoomValue, in: lensZoomValues)
    }

    private var majorLensZoomIndexes: Set<Int> {
        let values = lensZoomValues
        let range = cameraRuntime.lensZoomDialRange
        let anchors = lensZoomMajorLabelValues(range: range)
        let indexes = anchors.compactMap { anchor -> Int? in
            guard let nearestIndex = values.indices.min(by: { abs(values[$0] - anchor) < abs(values[$1] - anchor) }) else {
                return nil
            }
            return abs(values[nearestIndex] - anchor) <= 0.26 ? nearestIndex : nil
        }
        return Set(indexes)
    }

    var body: some View {
        VStack(spacing: 0) {
            CaptureZoomDialView(
                values: lensZoomValues,
                valueRange: cameraRuntime.lensZoomDialRange,
                selectedIndex: selectedLensZoomIndex,
                currentValueText: formatLensZoom(displayZoomValue),
                majorTickIndexes: majorLensZoomIndexes,
                isEnabled: true,
                onEditingBegan: {
                    cameraRuntime.beginLensZoomRulerInteraction()
                },
                onValueChanged: { value in
                    dispatchLensZoomValue(value, isFinal: false)
                },
                onValueSettled: { value in
                    dispatchLensZoomValue(value, isFinal: true)
                }
            )
        }
        .frame(height: 104)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.045, green: 0.052, blue: 0.060).opacity(0.82),
                    Color(red: 0.014, green: 0.018, blue: 0.026).opacity(0.88)
                ],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: 17, style: .continuous)
        )
        .shadow(color: .black.opacity(0.22), radius: 14, x: 0, y: 8)
        .onChange(of: cameraRuntime.lensZoomDialValue) { value in
            guard let pendingLensZoomValue else { return }
            if abs(value - pendingLensZoomValue) <= 0.08 {
                self.pendingLensZoomValue = nil
                self.lastDispatchedLensZoomValue = nil
                self.lastLensZoomPendingAt = nil
            } else if let lastLensZoomPendingAt,
                      Date().timeIntervalSince(lastLensZoomPendingAt) > pendingTimeout {
                self.pendingLensZoomValue = nil
                self.lastDispatchedLensZoomValue = nil
                self.lastLensZoomPendingAt = nil
            }
        }
        .onChange(of: cameraRuntime.selectedLensProfile?.id) { _ in
            pendingLensZoomValue = nil
            lastDispatchedLensZoomValue = nil
            lastLensZoomPendingAt = nil
        }
    }

    private func dispatchLensZoomValue(_ value: Double, isFinal: Bool) {
        let range = cameraRuntime.lensZoomDialRange
        let targetValue = max(range.lowerBound, min(range.upperBound, roundedLensZoomTarget(value)))
        if !isFinal, let lastDispatchedLensZoomValue, abs(lastDispatchedLensZoomValue - targetValue) < 0.004 {
            pendingLensZoomValue = targetValue
            return
        }
        pendingLensZoomValue = targetValue
        lastDispatchedLensZoomValue = targetValue
        lastLensZoomPendingAt = Date()
        onFocusDial()
        if isFinal {
            cameraRuntime.endLensZoomRulerInteraction(finalDialValue: targetValue)
        } else {
            cameraRuntime.setLensZoomDialValueFromRuler(targetValue)
        }
    }

    private func lensZoomRulerValues(range: ClosedRange<Double>, currentValue: Double) -> [Double] {
        let lower = max(0.1, range.lowerBound)
        let upper = max(lower, range.upperBound)
        guard upper > lower + 0.001 else { return [roundedLensZoom(lower)] }

        var values: [Double] = []
        var cursor = lower
        while cursor <= upper + 0.001 {
            values.append(roundedLensZoom(cursor))
            cursor += 0.1
        }

        values.append(roundedLensZoom(lower))
        values.append(roundedLensZoom(upper))
        values.append(roundedLensZoom(currentValue))
        return Array(Set(values))
            .filter { $0 >= lower - 0.001 && $0 <= upper + 0.001 }
            .sorted()
    }

    private func lensZoomMajorLabelValues(range: ClosedRange<Double>) -> [Double] {
        let anchors: [Double] = [0.5, 1.0, 2.0, 3.0, 5.0, 10.0, 15.0]
        var values = anchors.filter { $0 >= range.lowerBound - 0.001 && $0 <= range.upperBound + 0.001 }
        values.append(roundedLensZoom(range.lowerBound))
        values.append(roundedLensZoom(range.upperBound))
        return Array(Set(values)).sorted()
    }

    private func nearestLensZoomIndex(to value: Double, in values: [Double]) -> Int {
        guard let index = values.indices.min(by: { abs(values[$0] - value) < abs(values[$1] - value) }) else {
            return 0
        }
        return index
    }

    private func roundedLensZoom(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }

    private func roundedLensZoomTarget(_ value: Double) -> Double {
        (value * 50).rounded() / 50
    }

    private func formatLensZoom(_ value: Double) -> String {
        String(format: "%.1fx", value)
    }
}

private enum ManualFocusRulerStepResult {
    case applied
    case throttled(lastWriteAge: TimeInterval)
    case rejected
}

private enum ManualFocusRulerTuning {
    static let normalSensitivity: CGFloat = 8.0
    static let fineSensitivity: CGFloat = 0.40
    static let ultraFineSensitivity: CGFloat = 0.16

    static let dragStepThreshold: CGFloat = 10
    static let tickSpacing: CGFloat = 10

    static let normalMaxStepPerUpdate: Int = 12
    static let fineMaxStepPerUpdate: Int = 2
    static let ultraFineMaxStepPerUpdate: Int = 1

    static let lensPositionStep: Double = 0.005
    static let writeMinInterval: TimeInterval = 0.04
}

private struct CaptureManualFocusRulerPanel: View {
    let values: [Double]
    let selectedIndex: Int
    let currentValueText: String
    let isEnabled: Bool
    let onStep: (Int) -> ManualFocusRulerStepResult
    @State private var dragOffset: CGFloat = 0
    @State private var lastDragStepTranslation: CGFloat = 0
    @State private var isDragInProgress = false
    @State private var lastStepAppliedAt: Date = .distantPast
    @State private var lastDragDirection: Int = 0
    @State private var lastScrubSensitivity: CGFloat = 1
    @State private var lastHapticAt: Date = .distantPast
    @State private var lastHapticSignature: String?
    private let accent = Color(red: 0.46, green: 0.78, blue: 1.0)
    private let tickSpacing: CGFloat = ManualFocusRulerTuning.tickSpacing
    private let dragStepThreshold: CGFloat = ManualFocusRulerTuning.dragStepThreshold

    var body: some View {
        GeometryReader { geometry in
            let width = max(1, geometry.size.width)
            let centerX = width / 2

            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.036, green: 0.044, blue: 0.058).opacity(0.88),
                                Color(red: 0.014, green: 0.018, blue: 0.026).opacity(0.92)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                HStack {
                    Text("近")
                    Spacer()
                    Text("远")
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(isEnabled ? 0.46 : 0.22))
                .padding(.horizontal, 13)
                .position(x: centerX, y: 58)
                .allowsHitTesting(false)

                focusRulerTicks
                    .offset(x: centerX - CGFloat(selectedIndex) * tickSpacing - tickSpacing / 2 + dragOffset)
                    .frame(width: width, height: 52, alignment: .leading)
                    .clipped()
                    .position(x: centerX, y: 42)

                centerPointer
                    .position(x: centerX, y: 39)

                valueBadge
                    .position(x: centerX, y: 12)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        guard isEnabled else { return }
                        dragOffset = value.translation.width - lastDragStepTranslation
                        handleDrag(value.translation)
                    }
                    .onEnded { value in
                        finishDrag(
                            translationWidth: value.translation.width,
                            predictedEndTranslationWidth: value.predictedEndTranslation.width,
                            animateOffset: true
                        )
                    }
            )
            .onDisappear {
                finishDrag(
                    translationWidth: nil,
                    predictedEndTranslationWidth: nil,
                    animateOffset: false
                )
            }
        }
        .frame(height: 76)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.black.opacity(isEnabled ? 0.18 : 0.12), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .shadow(color: .black.opacity(0.22), radius: 14, x: 0, y: 8)
        .opacity(isEnabled ? 1 : 0.58)
    }

    private var focusRulerTicks: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                let isSelected = index == selectedIndex
                let isMajor = isMajorTick(value)
                let shouldHideCenterTick = shouldHideFocusCenterTick(index: index, value: value)
                VStack(spacing: 3) {
                    if shouldHideCenterTick {
                        Color.clear
                            .frame(width: 1.6, height: tickHeight(isSelected: isSelected, isMajor: isMajor))
                    } else {
                        Rectangle()
                            .fill(tickColor(isSelected: isSelected, isMajor: isMajor))
                            .frame(width: isSelected ? 1.6 : 0.9, height: tickHeight(isSelected: isSelected, isMajor: isMajor))
                            .shadow(color: isSelected ? accent.opacity(0.22) : .clear, radius: 4, x: 0, y: 0)
                    }

                    Text(shouldShowFocusTickLabel(index: index, value: value) ? focusTickLabel(value) : "")
                        .font(.system(size: 7, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(tickLabelColor(isSelected: isSelected))
                        .lineLimit(1)
                        .minimumScaleFactor(0.58)
                        .frame(width: 42, height: 12)
                }
                .frame(width: tickSpacing, height: 43, alignment: .bottom)
            }
        }
        .animation(.easeOut(duration: 0.14), value: selectedIndex)
    }

    private var centerPointer: some View {
        VStack(spacing: 0) {
            LensRulerTriangle()
                .fill(accent)
                .frame(width: 8, height: 5)
                .shadow(color: accent.opacity(0.28), radius: 5, x: 0, y: 0)

            Rectangle()
                .fill(accent)
                .frame(width: 1.4, height: 28)
                .shadow(color: accent.opacity(0.28), radius: 6, x: 0, y: 0)
        }
        .allowsHitTesting(false)
    }

    private var valueBadge: some View {
        Text(currentValueText)
            .font(.system(size: 11, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(.white.opacity(isEnabled ? 0.98 : 0.48))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule(style: .continuous).fill(accent.opacity(isEnabled ? 0.20 : 0.07)))
            .overlay(Capsule(style: .continuous).stroke(accent.opacity(isEnabled ? 0.42 : 0.12), lineWidth: 1))
            .shadow(color: accent.opacity(isEnabled ? 0.18 : 0), radius: 8, x: 0, y: 0)
            .id(currentValueText)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
            .animation(.easeOut(duration: 0.13), value: currentValueText)
            .allowsHitTesting(false)
    }

    private func handleDrag(_ translation: CGSize) {
        guard isEnabled else { return }
        isDragInProgress = true

        let threshold = dragStepThreshold
        let sensitivity = scrubSensitivity(for: translation.height)
        lastScrubSensitivity = sensitivity
        let effectiveThreshold = threshold / sensitivity
        let translationWidth = translation.width
        let delta = translationWidth - lastDragStepTranslation
        let rawStepCount = Int((delta / effectiveThreshold).rounded(.towardZero))
        guard rawStepCount != 0 else { return }

        let now = Date()
        let rawDirection = rawStepCount > 0 ? 1 : -1
        if lastDragDirection != 0, rawDirection != lastDragDirection {
            lastStepAppliedAt = .distantPast
        }
        lastDragDirection = rawDirection
        let cooldownAllowed = now.timeIntervalSince(lastStepAppliedAt) >= 0.12
        guard cooldownAllowed else {
#if DEBUG
            logManualFocusDrag(
                translationWidth: translationWidth,
                delta: delta,
                effectiveThreshold: effectiveThreshold,
                rawStepCount: rawStepCount,
                appliedStepDelta: 0,
                cap: maximumManualFocusStepCount(for: sensitivity),
                lensBefore: values.indices.contains(selectedIndex) ? values[selectedIndex] : 0,
                lensAfter: values.indices.contains(selectedIndex) ? values[selectedIndex] : 0,
                mode: manualFocusScrubMode(for: sensitivity),
                writeAllowed: false,
                throttled: false,
                cooldownAllowed: false,
                consumedOffset: false,
                wasClamped: false,
                lastWriteAge: nil
            )
#endif
            return
        }

        let maximumStepCount = maximumManualFocusStepCount(for: sensitivity)
        let consumedRawStepCount = max(-maximumStepCount, min(maximumStepCount, rawStepCount))
        let clampedStepCount = -consumedRawStepCount
#if DEBUG
        let lensBefore = values.indices.contains(selectedIndex) ? values[selectedIndex] : 0
        let predictedIndex = max(0, min(values.count - 1, selectedIndex + clampedStepCount))
        let lensAfter = values.indices.contains(predictedIndex) ? values[predictedIndex] : lensBefore
        let mode = manualFocusScrubMode(for: sensitivity)
        let wasClamped = consumedRawStepCount != rawStepCount
#endif
        let stepResult = onStep(clampedStepCount)
        switch stepResult {
        case .applied:
            lastDragStepTranslation += CGFloat(consumedRawStepCount) * effectiveThreshold
        case .throttled(let lastWriteAge):
#if DEBUG
            logManualFocusDrag(
                translationWidth: translationWidth,
                delta: delta,
                effectiveThreshold: effectiveThreshold,
                rawStepCount: rawStepCount,
                appliedStepDelta: clampedStepCount,
                cap: maximumStepCount,
                lensBefore: lensBefore,
                lensAfter: lensBefore,
                mode: mode,
                writeAllowed: false,
                throttled: true,
                cooldownAllowed: true,
                consumedOffset: false,
                wasClamped: wasClamped,
                lastWriteAge: lastWriteAge
            )
#endif
            return
        case .rejected:
            // Boundary movement is still consumed so users can reverse immediately at 0/1 limits.
            lastDragStepTranslation += CGFloat(rawStepCount) * effectiveThreshold
#if DEBUG
            logManualFocusDrag(
                translationWidth: translationWidth,
                delta: delta,
                effectiveThreshold: effectiveThreshold,
                rawStepCount: rawStepCount,
                appliedStepDelta: clampedStepCount,
                cap: maximumStepCount,
                lensBefore: lensBefore,
                lensAfter: lensBefore,
                mode: mode,
                writeAllowed: false,
                throttled: false,
                cooldownAllowed: true,
                consumedOffset: true,
                wasClamped: wasClamped,
                lastWriteAge: nil
            )
#endif
            return
        }

        lastStepAppliedAt = now
        triggerGearHapticIfNeeded(step: clampedStepCount, at: now)
#if DEBUG
        logManualFocusDrag(
            translationWidth: translationWidth,
            delta: delta,
            effectiveThreshold: effectiveThreshold,
            rawStepCount: rawStepCount,
            appliedStepDelta: clampedStepCount,
            cap: maximumStepCount,
            lensBefore: lensBefore,
            lensAfter: lensAfter,
            mode: mode,
            writeAllowed: true,
            throttled: false,
            cooldownAllowed: true,
            consumedOffset: true,
            wasClamped: wasClamped,
            lastWriteAge: nil
        )
#endif
    }

    private func finishDrag(
        translationWidth: CGFloat?,
        predictedEndTranslationWidth: CGFloat?,
        animateOffset: Bool
    ) {
        if isEnabled, let translationWidth, let predictedEndTranslationWidth {
            applyInertiaStep(
                translationWidth: translationWidth,
                predictedEndTranslationWidth: predictedEndTranslationWidth
            )
        }
        isDragInProgress = false
        lastDragStepTranslation = 0
        lastDragDirection = 0
        lastScrubSensitivity = 1
        if animateOffset {
            withAnimation(.easeOut(duration: 0.12)) {
                dragOffset = 0
            }
        } else {
            dragOffset = 0
        }
    }

    private func applyInertiaStep(translationWidth: CGFloat, predictedEndTranslationWidth: CGFloat) {
        guard lastScrubSensitivity >= 1 else { return }
        let predictedDelta = predictedEndTranslationWidth - translationWidth
        let rawStepCount = Int(((predictedDelta * 0.24) / dragStepThreshold).rounded(.towardZero))
        let inertiaStepCount = max(-2, min(2, -rawStepCount))
        guard inertiaStepCount != 0 else { return }
        let stepResult = onStep(inertiaStepCount)
        if case .applied = stepResult {
            triggerGearHapticIfNeeded(step: inertiaStepCount, at: Date())
        }
    }

    private func scrubSensitivity(for verticalTranslation: CGFloat) -> CGFloat {
        let lift = max(0, -verticalTranslation)
        // Normal drag is faster for range coverage; lifted drags remain precise for focus tweaks.
        if lift > 90 { return ManualFocusRulerTuning.ultraFineSensitivity }
        if lift > 40 { return ManualFocusRulerTuning.fineSensitivity }
        return ManualFocusRulerTuning.normalSensitivity
    }

    private func maximumManualFocusStepCount(for sensitivity: CGFloat) -> Int {
        if sensitivity >= 1 { return ManualFocusRulerTuning.normalMaxStepPerUpdate }
        if sensitivity >= 0.30 { return ManualFocusRulerTuning.fineMaxStepPerUpdate }
        return ManualFocusRulerTuning.ultraFineMaxStepPerUpdate
    }

    private func manualFocusScrubMode(for sensitivity: CGFloat) -> String {
        if sensitivity >= 1 { return "normal" }
        if sensitivity >= 0.30 { return "fine" }
        return "ultraFine"
    }

#if DEBUG
    private func logManualFocusDrag(
        translationWidth: CGFloat,
        delta: CGFloat,
        effectiveThreshold: CGFloat,
        rawStepCount: Int,
        appliedStepDelta: Int,
        cap: Int,
        lensBefore: Double,
        lensAfter: Double,
        mode: String,
        writeAllowed: Bool,
        throttled: Bool,
        cooldownAllowed: Bool,
        consumedOffset: Bool,
        wasClamped: Bool,
        lastWriteAge: TimeInterval?
    ) {
        let lastWriteAgeText = lastWriteAge.map { String(format: "%.3f", $0) } ?? "n/a"
        print(
            "[ManualFocusRuler] mode=\(mode) " +
            "translation=\(String(format: "%.1f", translationWidth)) " +
            "delta=\(String(format: "%.1f", delta)) " +
            "effectiveThreshold=\(String(format: "%.2f", effectiveThreshold)) " +
            "rawStepCount=\(rawStepCount) appliedStepDelta=\(appliedStepDelta) " +
            "cap=\(cap) lensBefore=\(String(format: "%.3f", lensBefore)) " +
            "lensAfter=\(String(format: "%.3f", lensAfter)) " +
            "lensDelta=\(String(format: "%.3f", lensAfter - lensBefore)) " +
            "writeAllowed=\(writeAllowed) throttled=\(throttled) " +
            "cooldownAllowed=\(cooldownAllowed) consumedOffset=\(consumedOffset) " +
            "clamped=\(wasClamped) lastWriteAge=\(lastWriteAgeText)"
        )
    }
#endif

    private func triggerGearHapticIfNeeded(step: Int, at now: Date) {
        let signature = "mf-\(selectedIndex)-\(step)"
        guard signature != lastHapticSignature else { return }
        guard now.timeIntervalSince(lastHapticAt) >= 0.09 else { return }
        lastHapticSignature = signature
        lastHapticAt = now
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func isMajorTick(_ value: Double) -> Bool {
        let percent = Int((value * 100).rounded())
        return percent == 0 || percent == 25 || percent == 50 || percent == 75 || percent == 100
    }

    private func focusTickLabel(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))"
    }

    private func shouldShowFocusTickLabel(index: Int, value: Double) -> Bool {
        guard isMajorTick(value) else { return false }
        guard values.indices.contains(selectedIndex) else { return true }
        let selectedValue = values[selectedIndex]
        let isNearSelectedIndex = abs(index - selectedIndex) <= 10
        let isNearSelectedValue = abs(value - selectedValue) <= 0.0501
        return !(isNearSelectedIndex || isNearSelectedValue)
    }

    private func shouldHideFocusCenterTick(index: Int, value: Double) -> Bool {
        guard values.indices.contains(selectedIndex) else { return false }
        let selectedValue = values[selectedIndex]
        return index == selectedIndex || abs(value - selectedValue) <= 0.0051
    }

    private func tickHeight(isSelected: Bool, isMajor: Bool) -> CGFloat {
        if isSelected { return 20 }
        return isMajor ? 15 : 8
    }

    private func tickColor(isSelected: Bool, isMajor: Bool) -> Color {
        guard isEnabled else { return .white.opacity(0.20) }
        if isSelected { return accent }
        return .white.opacity(isMajor ? 0.34 : 0.16)
    }

    private func tickLabelColor(isSelected: Bool) -> Color {
        guard isEnabled else { return .white.opacity(0.22) }
        if isSelected { return .white.opacity(0.94) }
        return .white.opacity(0.42)
    }
}

private enum CaptureActiveControlTarget: Equatable {
    case none
    case lensZoom
}

private enum CaptureOptionControlScope: String {
    case aspectRatio
    case outputQuality
}

private enum CaptureOptionSelectionSource: String {
    case tap
    case drag
    case fling
    case programmaticRestore
    case capabilityFallback
}

private struct CaptureOptionSelectionContext {
    var startIndex: Int?
    var translation: CGFloat?
    var predictedTranslation: CGFloat?
    var flingSteps: Int?

    static let empty = CaptureOptionSelectionContext()
}

private enum CaptureIntentKind: String, CaseIterable, Identifiable {
    case standard
    case detail
    case whiteBackground

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard:
            return "标准"
        case .detail:
            return "细节"
        case .whiteBackground:
            return "白底"
        }
    }

    var hintText: String {
        switch self {
        case .standard:
            return "标准图 · 平衡构图"
        case .detail:
            return "细节图 · 清晰优先"
        case .whiteBackground:
            return "白底导向 · 保边界"
        }
    }
}

private struct CaptureIntentSwitcherView: View {
    @Binding var selectedIntent: CaptureIntentKind

    var body: some View {
        HStack(spacing: 8) {
            ForEach(CaptureIntentKind.allCases) { intent in
                let isActive = selectedIntent == intent
                Button {
                    selectedIntent = intent
                } label: {
                    Text(intent.title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(isActive ? 0.96 : 0.72))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(
                            Capsule(style: .continuous)
                                .fill(isActive ? Color.teal.opacity(0.2) : Color.white.opacity(0.06))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(isActive ? Color.teal.opacity(0.48) : Color.white.opacity(0.1), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct CaptureTopStatusBar: View {
    let memoryStatusText: String
    let flashMode: CaptureFlashMode
    let isFlashModeSupported: Bool
    let onTapFlash: () -> Void
    let isExposureLockSupported: Bool
    let isExposureLocked: Bool
    let onToggleExposureLock: () -> Void
    let cameraPosition: AVCaptureDevice.Position
    let canSwitchCamera: Bool
    let onTapSwitchCamera: () -> Void
    let selectedAspectRatioPreset: CapturePhotoAspectRatioPreset
    let selectedPixelPreset: CapturePhotoPixelPreset
    let isRawCaptureSupported: Bool
    let isCaptureOptionsPresented: Bool
    let onTapCaptureOptions: () -> Void
    let isGridEnabled: Bool
    let onToggleGrid: () -> Void
    let isLevelIndicatorEnabled: Bool
    let onToggleLevelIndicator: () -> Void
    let selectedTimerOption: CaptureTimerOption
    let onCycleTimerOption: () -> Void
    let selectedBurstOption: CaptureBurstOption
    let onCycleBurstOption: () -> Void
    let isImportingPhoto: Bool
    let onTapImport: () -> Void
    let isMoreOptionsPresented: Bool
    let onTapMoreOptions: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 7) {
                Button(action: onTapFlash) {
                    topToolButtonContent(
                        symbol: flashMode.symbolName,
                        text: flashMode.shortText,
                        enabled: isFlashModeSupported
                    )
                }
                .buttonStyle(.plain)
                .disabled(!isFlashModeSupported)

                Button(action: onTapCaptureOptions) {
                    topToolButtonContent(
                        symbol: "rectangle.on.rectangle.angled",
                        text: "\(selectedAspectRatioPreset.displayText)·\(pixelCompactText(for: selectedPixelPreset))",
                        enabled: true,
                        showsSymbol: false,
                        isActive: isCaptureOptionsPresented
                    )
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                Button(action: onTapSwitchCamera) {
                    topToolButtonContent(
                        symbol: "camera.rotate",
                        text: cameraPosition == .back ? "后摄" : "前摄",
                        enabled: canSwitchCamera
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canSwitchCamera)

                Button(action: onTapMoreOptions) {
                    topToolButtonContent(
                        symbol: "ellipsis.circle",
                        text: "更多",
                        enabled: true,
                        isActive: isMoreOptionsPresented
                    )
                }
                .buttonStyle(.plain)
            }

            Text(memoryStatusText)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.56))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func topToolButtonContent(
        symbol: String,
        text: String,
        enabled: Bool,
        showsSymbol: Bool = true,
        isActive: Bool = false
    ) -> some View {
        HStack(spacing: 6) {
            if showsSymbol {
                Image(systemName: symbol)
                    .font(.caption2.weight(.semibold))
            }
            Text(text)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(0.82)
                .monospacedDigit()
        }
        .foregroundStyle(isActive ? Color(red: 0.20, green: 0.88, blue: 0.76) : .white.opacity(enabled ? 0.94 : 0.54))
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(
            (isActive ? Color(red: 0.20, green: 0.88, blue: 0.76).opacity(0.16) : .white.opacity(enabled ? 0.1 : 0.07)),
            in: Capsule()
        )
        .overlay(
            Capsule()
                .stroke(isActive ? Color(red: 0.20, green: 0.88, blue: 0.76).opacity(0.34) : .white.opacity(enabled ? 0.12 : 0.08), lineWidth: 1)
        )
    }

    private func pixelCompactText(for preset: CapturePhotoPixelPreset) -> String {
        switch preset {
        case .best:
            return "Best"
        case .p800:
            return "0.8K"
        case .p1200:
            return "1.2K"
        case .p1600:
            return "1.6K"
        case .p2400:
            return "2.4K"
        case .raw:
            return "RAW"
        }
    }

    private func pixelMenuText(for preset: CapturePhotoPixelPreset) -> String {
        if preset == .raw, !isRawCaptureSupported {
            return "RAW（不可用）"
        }
        return preset.displayText(for: selectedAspectRatioPreset.ratioValue)
    }
}

private struct CaptureOptionControlPanel: View {
    let selectedAspectRatioPreset: CapturePhotoAspectRatioPreset
    let selectedPixelPreset: CapturePhotoPixelPreset
    let isRawCaptureSupported: Bool
    let onSelectAspectRatioIndex: (Int, CaptureOptionSelectionSource, CaptureOptionSelectionContext) -> Void
    let onSelectPixelIndex: (Int, CaptureOptionSelectionSource, CaptureOptionSelectionContext) -> Void

    private var aspectRatioItems: [CaptureOptionRulerItem] {
        CapturePhotoAspectRatioPreset.allCases.map {
            CaptureOptionRulerItem(
                id: $0.displayText,
                title: $0.displayText,
                subtitle: "比例",
                isSelectable: true
            )
        }
    }

    private var pixelItems: [CaptureOptionRulerItem] {
        CapturePhotoPixelPreset.allCases.map { preset in
            let isRawUnavailable = preset == .raw && !isRawCaptureSupported
            return CaptureOptionRulerItem(
                id: preset.shortLabel,
                title: pixelTitle(for: preset),
                subtitle: isRawUnavailable
                    ? "不可用"
                    : preset.displayText(for: selectedAspectRatioPreset.ratioValue),
                isSelectable: true,
                warnsOnSelect: isRawUnavailable
            )
        }
    }

    private var selectedAspectRatioIndex: Int {
        CapturePhotoAspectRatioPreset.allCases.firstIndex(of: selectedAspectRatioPreset) ?? 0
    }

    private var selectedPixelIndex: Int {
        CapturePhotoPixelPreset.allCases.firstIndex(of: selectedPixelPreset) ?? 0
    }

    var body: some View {
        VStack(spacing: 9) {
            CaptureDiscreteOptionRuler(
                scope: .aspectRatio,
                title: "拍摄比例",
                items: aspectRatioItems,
                selectedIndex: selectedAspectRatioIndex,
                optionSpacing: 66,
                maximumFlingSteps: 2,
                onSelectIndex: onSelectAspectRatioIndex
            )

            CaptureDiscreteOptionRuler(
                scope: .outputQuality,
                title: "输出像素",
                items: pixelItems,
                selectedIndex: selectedPixelIndex,
                optionSpacing: 62,
                maximumFlingSteps: 2,
                onSelectIndex: onSelectPixelIndex
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.58))
        )
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.34), radius: 18, x: 0, y: 12)
    }

    private func pixelTitle(for preset: CapturePhotoPixelPreset) -> String {
        switch preset {
        case .p800:
            return "800"
        case .p1200:
            return "1200"
        case .p1600:
            return "1600"
        case .p2400:
            return "2400"
        case .best:
            return "Best"
        case .raw:
            return "RAW"
        }
    }
}

private struct CaptureOptionRulerItem: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let isSelectable: Bool
    var warnsOnSelect: Bool = false
}

private struct CaptureDiscreteOptionRuler: View {
    private enum Tuning {
        static let snapDuration: TimeInterval = 0.15
        static let dragActivationDistance: CGFloat = 3
        static let inertiaScale: CGFloat = 0.55
        static let edgeResistance: CGFloat = 0.34
    }

    let scope: CaptureOptionControlScope
    let title: String
    let items: [CaptureOptionRulerItem]
    let selectedIndex: Int
    let optionSpacing: CGFloat
    let maximumFlingSteps: Int
    let onSelectIndex: (Int, CaptureOptionSelectionSource, CaptureOptionSelectionContext) -> Void

    @State private var dragStartIndex: Int?
    @State private var visualOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var lastCandidateIndex: Int?
    @State private var lastHapticIndex: Int?
    @State private var snapGeneration: UInt64 = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(.white.opacity(0.58))
                    .textCase(.uppercase)

                Spacer(minLength: 0)

                Text(selectedItemTitle)
                    .font(.system(size: 11, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(Color(red: 0.20, green: 0.88, blue: 0.76))
            }
            .padding(.horizontal, 4)

            GeometryReader { proxy in
                let centerX = proxy.size.width / 2
                ZStack {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        optionChip(for: item, index: index)
                            .position(
                                x: centerX + CGFloat(index - displayBaseIndex) * optionSpacing + visualOffset,
                                y: 30
                            )
                    }

                    Capsule(style: .continuous)
                        .fill(Color(red: 0.20, green: 0.88, blue: 0.76).opacity(0.92))
                        .frame(width: 20, height: 2)
                        .position(x: centerX, y: 58)
                        .allowsHitTesting(false)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
                .contentShape(Rectangle())
                .highPriorityGesture(dragGesture)
            }
            .frame(height: 62)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.065))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .onChange(of: selectedIndex) { _ in
            guard !isDragging else { return }
            withAnimation(.easeOut(duration: Tuning.snapDuration)) {
                visualOffset = 0
            }
        }
    }

    private var selectedItemTitle: String {
        guard items.indices.contains(selectedIndex) else { return "--" }
        return items[selectedIndex].title
    }

    private var displayBaseIndex: Int {
        dragStartIndex ?? selectedIndex
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: Tuning.dragActivationDistance)
            .onChanged { value in
                beginDragIfNeeded()
                guard let startIndex = dragStartIndex else { return }
                let boundedTranslation = resistedTranslation(value.translation.width, startIndex: startIndex)
                visualOffset = boundedTranslation

                let candidateIndex = clampedIndex(startIndex + Int((-boundedTranslation / optionSpacing).rounded()))
                guard candidateIndex != lastCandidateIndex else { return }
                lastCandidateIndex = candidateIndex
                guard items.indices.contains(candidateIndex), items[candidateIndex].isSelectable else { return }
                triggerSelectionHapticIfNeeded(for: candidateIndex)
                onSelectIndex(
                    candidateIndex,
                    .drag,
                    CaptureOptionSelectionContext(
                        startIndex: startIndex,
                        translation: value.translation.width,
                        predictedTranslation: nil,
                        flingSteps: nil
                    )
                )
            }
            .onEnded { value in
                finishDrag(
                    translation: value.translation.width,
                    predictedTranslation: value.predictedEndTranslation.width
                )
            }
    }

    private func optionChip(for item: CaptureOptionRulerItem, index: Int) -> some View {
        let isSelected = index == selectedIndex
        let isCandidate = index == lastCandidateIndex && isDragging
        return VStack(spacing: 2) {
            Text(item.title)
                .font(.system(size: isSelected ? 13 : 12, weight: isSelected ? .bold : .semibold))
                .monospacedDigit()
                .foregroundStyle(chipTitleColor(isSelected: isSelected, item: item))
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(item.subtitle)
                .font(.system(size: 8.5, weight: .medium))
                .foregroundStyle(item.warnsOnSelect ? Color.orange.opacity(0.80) : .white.opacity(isSelected ? 0.70 : 0.38))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .frame(width: optionSpacing - 6, height: 46)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(chipFill(isSelected: isSelected, isCandidate: isCandidate, item: item))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(chipStroke(isSelected: isSelected, isCandidate: isCandidate, item: item), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isDragging, item.isSelectable else { return }
            if index != selectedIndex || item.warnsOnSelect {
                triggerSelectionHapticIfNeeded(for: index)
            }
            onSelectIndex(
                index,
                .tap,
                CaptureOptionSelectionContext(startIndex: selectedIndex)
            )
            withAnimation(.easeOut(duration: Tuning.snapDuration)) {
                visualOffset = 0
            }
        }
        .animation(.easeOut(duration: 0.12), value: isSelected)
        .animation(.easeOut(duration: 0.12), value: isCandidate)
    }

    private func beginDragIfNeeded() {
        guard dragStartIndex == nil else { return }
        snapGeneration &+= 1
        dragStartIndex = selectedIndex
        lastCandidateIndex = selectedIndex
        lastHapticIndex = selectedIndex
        isDragging = true
    }

    private func finishDrag(translation: CGFloat, predictedTranslation: CGFloat) {
        guard let startIndex = dragStartIndex else {
            resetDragState(animated: true)
            return
        }

        let boundedTranslation = resistedTranslation(translation, startIndex: startIndex)
        let baseTargetIndex = clampedIndex(startIndex + Int((-boundedTranslation / optionSpacing).rounded()))
        let predictedDelta = predictedTranslation - translation
        let rawFlingSteps = Int(((-predictedDelta / optionSpacing) * Tuning.inertiaScale).rounded())
        let flingSteps = max(-maximumFlingSteps, min(maximumFlingSteps, rawFlingSteps))
        let targetIndex = nearestSelectableIndex(to: clampedIndex(baseTargetIndex + flingSteps))
        let source: CaptureOptionSelectionSource = flingSteps == 0 ? .drag : .fling

        triggerSelectionHapticIfNeeded(for: targetIndex)
        onSelectIndex(
            targetIndex,
            source,
            CaptureOptionSelectionContext(
                startIndex: startIndex,
                translation: translation,
                predictedTranslation: predictedTranslation,
                flingSteps: flingSteps
            )
        )
        resetDragState(animated: true)
    }

    private func resetDragState(animated: Bool) {
        let generation = snapGeneration &+ 1
        snapGeneration = generation
        let updates = {
            visualOffset = 0
            dragStartIndex = nil
            isDragging = false
            lastCandidateIndex = nil
        }
        if animated {
            withAnimation(.easeOut(duration: Tuning.snapDuration), updates)
        } else {
            updates()
        }
    }

    private func resistedTranslation(_ translation: CGFloat, startIndex: Int) -> CGFloat {
        let minimum = -CGFloat(max(0, items.count - 1 - startIndex)) * optionSpacing
        let maximum = CGFloat(max(0, startIndex)) * optionSpacing
        if translation < minimum {
            return minimum + (translation - minimum) * Tuning.edgeResistance
        }
        if translation > maximum {
            return maximum + (translation - maximum) * Tuning.edgeResistance
        }
        return translation
    }

    private func clampedIndex(_ index: Int) -> Int {
        max(0, min(max(0, items.count - 1), index))
    }

    private func nearestSelectableIndex(to index: Int) -> Int {
        guard items.indices.contains(index), !items.isEmpty else { return 0 }
        if items[index].isSelectable { return index }
        return items.indices
            .filter { items[$0].isSelectable }
            .min { abs($0 - index) < abs($1 - index) } ?? selectedIndex
    }

    private func triggerSelectionHapticIfNeeded(for index: Int) {
        guard index != lastHapticIndex else { return }
        lastHapticIndex = index
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func chipTitleColor(isSelected: Bool, item: CaptureOptionRulerItem) -> Color {
        guard item.isSelectable else { return .white.opacity(0.28) }
        if item.warnsOnSelect { return isSelected ? .orange.opacity(0.92) : .white.opacity(0.72) }
        return isSelected ? Color(red: 0.20, green: 0.88, blue: 0.76) : .white.opacity(0.86)
    }

    private func chipFill(isSelected: Bool, isCandidate: Bool, item: CaptureOptionRulerItem) -> Color {
        guard item.isSelectable else { return .white.opacity(0.035) }
        if item.warnsOnSelect { return Color.orange.opacity(isSelected ? 0.15 : 0.06) }
        if isSelected { return Color(red: 0.20, green: 0.88, blue: 0.76).opacity(0.14) }
        if isCandidate { return Color.white.opacity(0.11) }
        return Color.white.opacity(0.055)
    }

    private func chipStroke(isSelected: Bool, isCandidate: Bool, item: CaptureOptionRulerItem) -> Color {
        guard item.isSelectable else { return .white.opacity(0.05) }
        if item.warnsOnSelect { return Color.orange.opacity(isSelected ? 0.34 : 0.18) }
        if isSelected { return Color(red: 0.20, green: 0.88, blue: 0.76).opacity(0.42) }
        if isCandidate { return .white.opacity(0.20) }
        return .white.opacity(0.08)
    }
}

private struct CaptureMoreOptionsPanel: View {
    let isGridEnabled: Bool
    let onToggleGrid: () -> Void
    let isLevelIndicatorEnabled: Bool
    let onToggleLevelIndicator: () -> Void
    let selectedTimerOption: CaptureTimerOption
    let onCycleTimerOption: () -> Void
    let selectedBurstOption: CaptureBurstOption
    let onCycleBurstOption: () -> Void
    let selectedStabilizerMode: CaptureStabilizerMode
    let onCycleStabilizerMode: () -> Void
    let isImportingPhoto: Bool
    let onTapImport: () -> Void

    private let accent = Color(red: 0.20, green: 0.88, blue: 0.76)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("拍摄辅助")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.52))
                .padding(.horizontal, 4)

            moreOptionButton(
                title: isGridEnabled ? "网格已开启" : "网格已关闭",
                subtitle: "构图辅助",
                systemImage: "square.grid.3x3",
                isActive: isGridEnabled,
                action: onToggleGrid
            )

            moreOptionButton(
                title: isLevelIndicatorEnabled ? "水平仪已开启" : "水平仪已关闭",
                subtitle: "拍摄稳定辅助",
                systemImage: "level",
                isActive: isLevelIndicatorEnabled,
                action: onToggleLevelIndicator
            )

            moreOptionButton(
                title: "稳定器 \(selectedStabilizerMode.displayText)",
                subtitle: "减少手持抖动导致的模糊",
                systemImage: "hand.raised.fill",
                isActive: selectedStabilizerMode != .off,
                action: onCycleStabilizerMode
            )

            moreOptionButton(
                title: "定时 \(selectedTimerOption.displayText)",
                subtitle: "点击切换下一档",
                systemImage: "timer",
                isActive: selectedTimerOption != .off,
                action: onCycleTimerOption
            )

            moreOptionButton(
                title: "连拍 \(selectedBurstOption.displayText)",
                subtitle: "点击切换下一档",
                systemImage: "square.stack.3d.up.fill",
                isActive: selectedBurstOption != .single,
                action: onCycleBurstOption
            )

            Divider()
                .overlay(.white.opacity(0.12))

            moreOptionButton(
                title: isImportingPhoto ? "导入中…" : "导入单张图片",
                subtitle: "从相册导入素材",
                systemImage: "photo.on.rectangle.angled",
                isActive: false,
                isEnabled: !isImportingPhoto,
                action: onTapImport
            )
        }
        .frame(width: 238)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.035, green: 0.043, blue: 0.055).opacity(0.98))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.36), radius: 18, x: 0, y: 12)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture {
            // Keep taps inside the panel from reaching the outside dismiss layer.
        }
    }

    private func moreOptionButton(
        title: String,
        subtitle: String,
        systemImage: String,
        isActive: Bool,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isActive ? accent : .white.opacity(isEnabled ? 0.76 : 0.34))
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(isEnabled ? 0.94 : 0.40))
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(isEnabled ? 0.44 : 0.26))
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                Circle()
                    .fill(isActive ? accent : .white.opacity(isEnabled ? 0.22 : 0.08))
                    .frame(width: 7, height: 7)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isActive ? accent.opacity(0.12) : .white.opacity(isEnabled ? 0.055 : 0.025))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isActive ? accent.opacity(0.25) : .white.opacity(0.07), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

private struct CapturePreviewContainer: View {
    @ObservedObject var cameraRuntime: CaptureCameraRuntime
    let selectedAspectRatioPreset: CapturePhotoAspectRatioPreset
    let captureHintText: String
    let isAnyFloatingControlPresented: Bool
    @Binding var activeControlTarget: CaptureActiveControlTarget
    let isManualFocusModeActive: Bool
    let isManualFocusRulerPresented: Bool
    let manualFocusRulerValues: [Double]
    let selectedManualFocusRulerIndex: Int
    let manualFocusValueText: String
    let isManualFocusRulerEnabled: Bool
    let onToggleExposureLock: () -> Void
    let onToggleManualFocusMode: () -> Void
    let onManualFocusStep: (Int) -> ManualFocusRulerStepResult
    let onTapPreviewBeforeFocus: () -> Bool
    @State private var transientLensFeedback: String?
    @State private var lensFeedbackToken = UUID()

    var body: some View {
        GeometryReader { geometry in
            let containerSize = geometry.size
            let safeWidth = max(1, containerSize.width)
            let safeHeight = max(1, containerSize.height - 8)
            let workspaceRect = workspaceRectFor(
                preset: selectedAspectRatioPreset,
                in: CGSize(width: safeWidth, height: safeHeight)
            )
            let lensInset = max(18, min(30, workspaceRect.height * 0.08))
            let lensY = max(workspaceRect.minY + 24, workspaceRect.maxY - lensInset)
            let hintPreferredY = lensY - 36
            let hintY = max(
                workspaceRect.midY + 62,
                min(hintPreferredY, workspaceRect.maxY - 52)
            )
            let nonPersistentHint = (isLensSwitchHint(captureHintText) || isManualFocusHint(captureHintText))
                ? ""
                : captureHintText
            let displayHintText = transientLensFeedback ?? nonPersistentHint

            ZStack {
                CaptureLivePreviewView(
                    cameraRuntime: cameraRuntime,
                    onTapPreviewBeforeFocus: onTapPreviewBeforeFocus
                )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                CaptureWorkspaceMaskOverlay(
                    workspaceRect: workspaceRect,
                    outsideFillColor: Color(red: 0.03, green: 0.04, blue: 0.06)
                )
                    .allowsHitTesting(false)

                CaptureLensControlStrip(
                    cameraRuntime: cameraRuntime,
                    activeControlTarget: $activeControlTarget,
                    isManualFocusModeActive: isManualFocusModeActive,
                    onToggleExposureLock: onToggleExposureLock,
                    onToggleManualFocusMode: onToggleManualFocusMode
                )
                .frame(width: max(164, min(workspaceRect.width - 20, safeWidth - 14)))
                .position(
                    x: workspaceRect.midX,
                    y: lensY
                )

                if isManualFocusRulerPresented {
                    CaptureManualFocusRulerPanel(
                        values: manualFocusRulerValues,
                        selectedIndex: selectedManualFocusRulerIndex,
                        currentValueText: manualFocusValueText,
                        isEnabled: isManualFocusRulerEnabled,
                        onStep: onManualFocusStep
                    )
                    .frame(width: max(220, min(workspaceRect.width - 24, safeWidth - 20)))
                    .position(
                        x: workspaceRect.midX,
                        y: min(containerSize.height - 56, lensY + 56)
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
                    .zIndex(4)
                }

                if !displayHintText.isEmpty {
                    CaptureAssistHintSlot(text: displayHintText)
                        .frame(width: max(160, min(workspaceRect.width - 30, safeWidth - 20)))
                        .position(x: workspaceRect.midX, y: hintY)
                        .opacity(
                            transientLensFeedback == nil
                                ? (isAnyFloatingControlPresented ? 0.42 : 0.74)
                                : 0.9
                        )
                        .animation(.easeInOut(duration: 0.18), value: isAnyFloatingControlPresented)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: containerSize.width, height: containerSize.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            handleHintUpdate(captureHintText)
        }
        .onChange(of: captureHintText) { text in
            handleHintUpdate(text)
        }
        .padding(.horizontal, 0)
        .padding(.bottom, 0)
    }

    private func workspaceRectFor(preset: CapturePhotoAspectRatioPreset, in size: CGSize) -> CGRect {
        let safeRatio = max(0.01, preset.ratioValue)
        let availableWidth = max(1, size.width)
        let availableHeight = max(1, size.height)

        if preset == .ratio9x16 {
            let verticalGuard = max(14, min(28, availableHeight * 0.05))
            let boundedHeight = max(1, availableHeight - verticalGuard * 2)
            let widthFromHeight = boundedHeight * safeRatio
            let fittedWidth = min(availableWidth, widthFromHeight)
            let fittedHeight = fittedWidth / safeRatio
            return CGRect(
                x: (availableWidth - fittedWidth) / 2,
                y: (availableHeight - fittedHeight) / 2,
                width: fittedWidth,
                height: fittedHeight
            )
        }

        let fullWidthHeight = availableWidth / safeRatio
        if fullWidthHeight <= availableHeight {
            return CGRect(
                x: 0,
                y: (availableHeight - fullWidthHeight) / 2,
                width: availableWidth,
                height: fullWidthHeight
            )
        }

        let fittedWidth = availableHeight * safeRatio
        return CGRect(
            x: (availableWidth - fittedWidth) / 2,
            y: 0,
            width: fittedWidth,
            height: availableHeight
        )
    }

    private func isLensSwitchHint(_ text: String) -> Bool {
        text.hasPrefix("已切换")
    }

    private func isManualFocusHint(_ text: String) -> Bool {
        guard isManualFocusRulerPresented else { return false }
        return text.hasPrefix("MF")
            || text.contains("手动对焦")
            || text.contains("MF 模式")
            || text.contains("MF 生效")
    }

    private func handleHintUpdate(_ text: String) {
        guard isLensSwitchHint(text) else { return }
        transientLensFeedback = text
        let token = UUID()
        lensFeedbackToken = token
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.05) {
            guard lensFeedbackToken == token else { return }
            transientLensFeedback = nil
        }
    }
}

private struct CaptureWorkspaceMaskOverlay: View {
    let workspaceRect: CGRect
    let outsideFillColor: Color

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let x = max(0, workspaceRect.minX)
            let y = max(0, workspaceRect.minY)
            let w = max(0, min(workspaceRect.width, width))
            let h = max(0, min(workspaceRect.height, height))

            Path { path in
                path.addRect(CGRect(x: 0, y: 0, width: width, height: y))
                path.addRect(CGRect(x: 0, y: y + h, width: width, height: max(0, height - (y + h))))
                path.addRect(CGRect(x: 0, y: y, width: x, height: h))
                path.addRect(CGRect(x: x + w, y: y, width: max(0, width - (x + w)), height: h))
            }
            .fill(outsideFillColor)
        }
    }
}

private struct CaptureLensControlStrip: View {
    @ObservedObject var cameraRuntime: CaptureCameraRuntime
    @Binding var activeControlTarget: CaptureActiveControlTarget
    let isManualFocusModeActive: Bool
    let onToggleExposureLock: () -> Void
    let onToggleManualFocusMode: () -> Void
    private let accent = Color(red: 0.20, green: 0.88, blue: 0.76)
    private let lockAccent = Color(red: 1.0, green: 0.70, blue: 0.28)
    private let manualAccent = Color(red: 0.46, green: 0.78, blue: 1.0)

    private var availableCapabilities: [CaptureSemanticFocalCapability] {
        cameraRuntime.availableSemanticFocalCapabilities
    }

    private var isExposureLocked: Bool {
        cameraRuntime.isExposureLocked || cameraRuntime.isFocusExposureLocked
    }

    private var isManualFocusDisabled: Bool {
        cameraRuntime.isFocusExposureLocked || !cameraRuntime.isManualFocusSupported
    }

    var body: some View {
        HStack(spacing: accessorySpacing) {
            Button(action: onToggleExposureLock) {
                controlCapsule(
                    text: "AE-L",
                    isActive: isExposureLocked,
                    isEnabled: cameraRuntime.isExposureLockSupported,
                    accentColor: lockAccent
                )
            }
            .buttonStyle(.plain)
            .disabled(!cameraRuntime.isExposureLockSupported)

            if availableCapabilities.isEmpty {
                Text(cameraRuntime.activeCameraPosition == .front ? "前置镜头" : "当前机型无可用镜头焦段")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.66))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.white.opacity(0.06), in: Capsule())
            } else {
                HStack(spacing: focalSpacing) {
                    ForEach(availableCapabilities) { capability in
                        let focal = capability.focal
                        let isSelected = cameraRuntime.selectedSemanticFocal == focal

                        Button {
                            if isSelected {
                                activeControlTarget = activeControlTarget == .lensZoom ? .none : .lensZoom
                            } else {
                                cameraRuntime.selectSemanticFocal(focal)
                                activeControlTarget = .lensZoom
                            }
                        } label: {
                            Text(focal.displayText)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(isSelected ? accent : .white.opacity(0.76))
                                .padding(.horizontal, focalHorizontalPadding)
                                .padding(.vertical, 6)
                                .frame(minWidth: focalButtonMinWidth)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(
                                            isSelected
                                                ? accent.opacity(0.14)
                                                : Color.white.opacity(0.045)
                                        )
                                )
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(
                                            isSelected
                                                ? accent.opacity(0.34)
                                                : Color.white.opacity(0.055),
                                            lineWidth: 1
                                        )
                                )
                                .shadow(color: isSelected ? accent.opacity(0.18) : .clear, radius: 9, x: 0, y: 0)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button(action: onToggleManualFocusMode) {
                controlCapsule(
                    text: "MF",
                    isActive: isManualFocusModeActive,
                    isEnabled: !isManualFocusDisabled,
                    accentColor: manualAccent
                )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    private var hasDenseLensControls: Bool {
        availableCapabilities.count >= 4
    }

    private var accessorySpacing: CGFloat {
        hasDenseLensControls ? 10 : 14
    }

    private var focalSpacing: CGFloat {
        hasDenseLensControls ? 5 : 7
    }

    private var focalButtonMinWidth: CGFloat {
        hasDenseLensControls ? 50 : 58
    }

    private var focalHorizontalPadding: CGFloat {
        hasDenseLensControls ? 8 : 10
    }

    private var auxiliaryControlMinWidth: CGFloat {
        hasDenseLensControls ? 42 : 48
    }

    private var auxiliaryHorizontalPadding: CGFloat {
        hasDenseLensControls ? 8 : 10
    }

    private func controlCapsule(
        text: String,
        isActive: Bool,
        isEnabled: Bool,
        accentColor: Color
    ) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(isActive ? accentColor : .white.opacity(isEnabled ? 0.76 : 0.32))
            .padding(.horizontal, auxiliaryHorizontalPadding)
            .padding(.vertical, 6)
            .frame(minWidth: auxiliaryControlMinWidth)
            .background(
                Capsule(style: .continuous)
                    .fill(isActive ? accentColor.opacity(0.14) : Color.white.opacity(isEnabled ? 0.045 : 0.025))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(isActive ? accentColor.opacity(0.34) : Color.white.opacity(isEnabled ? 0.055 : 0.035), lineWidth: 1)
            )
            .shadow(color: isActive ? accentColor.opacity(0.18) : .clear, radius: 9, x: 0, y: 0)
    }
}

private struct CaptureZoomDialView: View {
    private enum Tuning {
        static let tickSpacing: CGFloat = 34
        static let normalSensitivity: CGFloat = 3.0
        static let fineSensitivity: CGFloat = 0.90
        static let ultraFineSensitivity: CGFloat = 0.38
        static let pointsPerZoomCommon: CGFloat = 96
        static let pointsPerZoomHigh: CGFloat = 172
        static let smoothingPreviousWeight: Double = 0.34
        static let dragSnapThreshold: Double = 0.016
        static let dragSnapWeight: Double = 0.25
        static let settleSnapThreshold: Double = 0.075
        static let settleSnapWeight: Double = 1.0
        static let emitDelta: Double = 0.005
        static let maxInertiaDelta: CGFloat = 38
        static let inertiaScale: CGFloat = 0.22
        static let anchorHapticThreshold: Double = 0.032
        static let hapticMinInterval: TimeInterval = 0.12
    }

    let values: [Double]
    let valueRange: ClosedRange<Double>
    let selectedIndex: Int
    let currentValueText: String
    let majorTickIndexes: Set<Int>
    let isEnabled: Bool
    let onEditingBegan: () -> Void
    let onValueChanged: (Double) -> Void
    let onValueSettled: (Double) -> Void
    @State private var dragOffset: CGFloat = 0
    @State private var isDragInProgress = false
    @State private var lastScrubSensitivity: CGFloat = 1
    @State private var lastHapticAt: Date = .distantPast
    @State private var lastHapticSignature: String?
    @State private var dragBaselineValue: Double?
    @State private var lastEmittedZoomValue: Double?
    private let accent = Color(red: 0.20, green: 0.88, blue: 0.76)
    private let tickSpacing: CGFloat = Tuning.tickSpacing

    var body: some View {
        GeometryReader { geometry in
            let width = max(1, geometry.size.width)
            let centerX = width / 2

            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(isEnabled ? 0.36 : 0.26))

                lensRulerTicks
                    .offset(x: centerX - CGFloat(selectedIndex) * tickSpacing - tickSpacing / 2 + dragOffset)
                    .frame(width: width, height: 52, alignment: .leading)
                    .clipped()
                    .position(x: centerX, y: 42)

                centerPointer
                    .position(x: centerX, y: 41)

                valueBadge
                    .position(x: centerX, y: 12)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        guard isEnabled else { return }
                        handleDrag(value.translation)
                    }
                    .onEnded { value in
                        finishDrag(
                            translationWidth: value.translation.width,
                            predictedEndTranslationWidth: value.predictedEndTranslation.width,
                            animateOffset: true
                        )
                    }
            )
            .onDisappear {
                finishDrag(
                    translationWidth: nil,
                    predictedEndTranslationWidth: nil,
                    animateOffset: false
                )
            }
        }
        .frame(height: 70)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.black.opacity(isEnabled ? 0.18 : 0.12))
        )
    }

    private var lensRulerTicks: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                let isSelected = index == selectedIndex
                let isMajor = majorTickIndexes.contains(index)
                VStack(spacing: 3) {
                    Rectangle()
                        .fill(tickColor(isSelected: isSelected, isMajor: isMajor))
                        .frame(width: isSelected ? 1.6 : 0.9, height: tickHeight(isSelected: isSelected, isMajor: isMajor))
                        .shadow(color: isSelected ? accent.opacity(0.22) : .clear, radius: 4, x: 0, y: 0)
                    Text(isMajor ? formatMultiplier(value) : "")
                        .font(.system(size: isSelected ? 8.5 : 7, weight: isSelected ? .semibold : .medium))
                        .monospacedDigit()
                        .foregroundStyle(tickLabelColor(isSelected: isSelected))
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                        .frame(width: 50, height: 12)
                }
                .frame(width: tickSpacing, height: 43, alignment: .bottom)
            }
        }
        .animation(.easeOut(duration: 0.14), value: selectedIndex)
    }

    private var centerPointer: some View {
        VStack(spacing: 0) {
            LensRulerTriangle()
                .fill(accent)
                .frame(width: 8, height: 5)
                .shadow(color: accent.opacity(0.28), radius: 5, x: 0, y: 0)

            Rectangle()
                .fill(accent)
                .frame(width: 1.4, height: 30)
                .shadow(color: accent.opacity(0.28), radius: 6, x: 0, y: 0)
        }
        .allowsHitTesting(false)
    }

    private var valueBadge: some View {
        Text(currentValueText)
            .font(.system(size: 11, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(.white.opacity(isEnabled ? 0.98 : 0.48))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(accent.opacity(isEnabled ? 0.20 : 0.07))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(accent.opacity(isEnabled ? 0.42 : 0.12), lineWidth: 1)
            )
            .shadow(color: accent.opacity(isEnabled ? 0.18 : 0), radius: 8, x: 0, y: 0)
            .id(currentValueText)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
            .animation(.easeOut(duration: 0.13), value: currentValueText)
            .allowsHitTesting(false)
    }

    private func tickHeight(isSelected: Bool, isMajor: Bool) -> CGFloat {
        if isSelected { return 21 }
        return isMajor ? 16 : 9
    }

    private func tickColor(isSelected: Bool, isMajor: Bool) -> Color {
        guard isEnabled else { return .white.opacity(0.20) }
        if isSelected { return accent }
        return .white.opacity(isMajor ? 0.34 : 0.16)
    }

    private func tickLabelColor(isSelected: Bool) -> Color {
        guard isEnabled else { return .white.opacity(0.22) }
        if isSelected { return .white.opacity(0.94) }
        return .white.opacity(0.42)
    }

    private func handleDrag(_ translation: CGSize) {
        guard isEnabled else { return }
        if !isDragInProgress {
            isDragInProgress = true
            dragBaselineValue = selectedZoomValue
            lastEmittedZoomValue = nil
            onEditingBegan()
        }
        let sensitivity = scrubSensitivity(for: translation.height)
        lastScrubSensitivity = sensitivity
        dragOffset = translation.width.truncatingRemainder(dividingBy: tickSpacing)

        let rawZoom = mappedZoomValue(for: translation.width, sensitivity: sensitivity)
        let smoothedZoom = smoothedZoomValue(rawZoom)
        let emittedZoom = softSnappedZoomValue(smoothedZoom, final: false)
        guard shouldEmitZoomValue(emittedZoom) else { return }

#if DEBUG
        print(
            "[CaptureLensZoomRuler] " +
            "dragDelta=\(String(format: "%.1f", translation.width)) " +
            "sensitivity=\(String(format: "%.2f", sensitivity)) " +
            "rawZoom=\(String(format: "%.3f", rawZoom)) " +
            "smoothedZoom=\(String(format: "%.3f", smoothedZoom)) " +
            "emittedZoom=\(String(format: "%.3f", emittedZoom))"
        )
#endif
        lastEmittedZoomValue = emittedZoom
        onValueChanged(emittedZoom)
        triggerAnchorHapticIfNeeded(for: emittedZoom, at: Date())
    }

    private func finishDrag(
        translationWidth: CGFloat?,
        predictedEndTranslationWidth: CGFloat?,
        animateOffset: Bool
    ) {
        if isEnabled, let translationWidth, let predictedEndTranslationWidth {
            applyInertiaSettle(
                translationWidth: translationWidth,
                predictedEndTranslationWidth: predictedEndTranslationWidth
            )
        }
        isDragInProgress = false
        lastScrubSensitivity = 1
        dragBaselineValue = nil
        lastEmittedZoomValue = nil
        if animateOffset {
            withAnimation(.easeOut(duration: 0.12)) {
                dragOffset = 0
            }
        } else {
            dragOffset = 0
        }
    }

    private func applyInertiaSettle(translationWidth: CGFloat, predictedEndTranslationWidth: CGFloat) {
        let baseline = dragBaselineValue ?? selectedZoomValue
        let sensitivity = max(0.1, lastScrubSensitivity)
        let predictedDelta = predictedEndTranslationWidth - translationWidth
        let cappedInertiaDelta = max(
            -Tuning.maxInertiaDelta,
            min(Tuning.maxInertiaDelta, predictedDelta * Tuning.inertiaScale)
        )
        let inertiaEnabled = sensitivity >= 1
        let finalTranslation = translationWidth + (inertiaEnabled ? cappedInertiaDelta : 0)
        let target = finalSnappedZoomValue(mappedZoomValue(
            for: finalTranslation,
            sensitivity: sensitivity,
            baseline: baseline
        ))
        onValueSettled(target)
        triggerAnchorHapticIfNeeded(for: target, at: Date(), force: true)
    }

    private var selectedZoomValue: Double {
        guard values.indices.contains(selectedIndex) else {
            return max(valueRange.lowerBound, min(valueRange.upperBound, 1.0))
        }
        return values[selectedIndex]
    }

    private func mappedZoomValue(
        for translationWidth: CGFloat,
        sensitivity: CGFloat,
        baseline explicitBaseline: Double? = nil
    ) -> Double {
        let baseline = explicitBaseline ?? dragBaselineValue ?? selectedZoomValue
        let effectiveSensitivity = max(0.12, sensitivity)
        let pointsPerZoom: CGFloat = baseline > 3.0 ? Tuning.pointsPerZoomHigh : Tuning.pointsPerZoomCommon
        let rawDelta = Double((-translationWidth / pointsPerZoom) * effectiveSensitivity)
        var candidate = baseline + rawDelta
        if candidate > 3.0 {
            candidate = 3.0 + (candidate - 3.0) * 0.58
        }
        return clampedZoom(candidate)
    }

    private func smoothedZoomValue(_ rawZoom: Double) -> Double {
        guard let lastEmittedZoomValue else { return rawZoom }
        return clampedZoom(
            lastEmittedZoomValue * Tuning.smoothingPreviousWeight
                + rawZoom * (1.0 - Tuning.smoothingPreviousWeight)
        )
    }

    private func softSnappedZoomValue(_ zoom: Double, final: Bool) -> Double {
        let threshold = final ? Tuning.settleSnapThreshold : Tuning.dragSnapThreshold
        guard let anchor = zoomAnchors.min(by: { abs($0 - zoom) < abs($1 - zoom) }),
              abs(anchor - zoom) <= threshold else {
            return clampedZoom(zoom)
        }
        let weight = final ? Tuning.settleSnapWeight : Tuning.dragSnapWeight
        return clampedZoom(zoom + (anchor - zoom) * weight)
    }

    private func finalSnappedZoomValue(_ zoom: Double) -> Double {
        softSnappedZoomValue(zoom, final: true)
    }

    private var zoomAnchors: [Double] {
        [0.5, 1.0, 2.0, 3.0].filter { $0 >= valueRange.lowerBound - 0.001 && $0 <= valueRange.upperBound + 0.001 }
    }

    private func clampedZoom(_ zoom: Double) -> Double {
        max(valueRange.lowerBound, min(valueRange.upperBound, zoom))
    }

    private func shouldEmitZoomValue(_ value: Double) -> Bool {
        guard let lastEmittedZoomValue else { return true }
        return abs(lastEmittedZoomValue - value) >= Tuning.emitDelta
    }

    private func scrubSensitivity(for verticalTranslation: CGFloat) -> CGFloat {
        let lift = max(0, -verticalTranslation)
        // Normal drag covers more zoom range; lifted drags keep the R73 fine-control path.
        if lift > 90 { return Tuning.ultraFineSensitivity }
        if lift > 40 { return Tuning.fineSensitivity }
        return Tuning.normalSensitivity
    }

    private func triggerAnchorHapticIfNeeded(for zoom: Double, at now: Date, force: Bool = false) {
        guard let anchor = zoomAnchors.min(by: { abs($0 - zoom) < abs($1 - zoom) }) else { return }
        guard force || abs(anchor - zoom) <= Tuning.anchorHapticThreshold else { return }
        let signature = "lens-anchor-\(String(format: "%.1f", anchor))"
        guard signature != lastHapticSignature else { return }
        guard now.timeIntervalSince(lastHapticAt) >= Tuning.hapticMinInterval else { return }
        lastHapticSignature = signature
        lastHapticAt = now
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func formatMultiplier(_ multiplier: Double) -> String {
        String(format: "%.1fx", multiplier)
    }
}

private struct LensRulerTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

private struct CaptureAssistHintSlot: View {
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
            Text(text)
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.86)
        }
        .foregroundStyle(.white.opacity(0.82))
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(.black.opacity(0.36), in: Capsule())
        .overlay(
            Capsule()
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
}

private extension CaptureScreen {
    func bottomParameterItem(for state: CaptureProfessionalParameterState) -> CaptureBottomParameterItem {
        CaptureBottomParameterItem(
            kind: state.kind,
            title: bottomParameterTitle(for: state.kind),
            valueText: bottomParameterValueText(for: state),
            isManualOrLocked: state.mode == .manual || state.mode == .locked,
            isAvailable: state.mode != .disabled
        )
    }

    func horizontalRulerItem(for state: CaptureProfessionalParameterState) -> CaptureHorizontalParameterRulerItem {
        let ticks = horizontalRulerTicks(for: state)
        let selectedIndex = horizontalRulerSelectedIndex(for: state, ticks: ticks)
        return CaptureHorizontalParameterRulerItem(
            parameter: bottomParameterItem(for: state),
            tickLabels: ticks.map(\.label),
            selectedIndex: selectedIndex,
            majorTickIndexes: horizontalRulerMajorTickIndexes(for: state.kind, ticks: ticks, selectedIndex: selectedIndex),
            controlKind: horizontalRulerControlKind(for: state),
            isRulerInteractive: (
                (state.kind == .exposureCompensation && state.isAdjustable) ||
                    (state.kind == .whiteBalance && state.isAdjustable) ||
                    (state.kind == .tint && state.isAdjustable) ||
                    (state.kind == .iso && state.isAdjustable) ||
                    (state.kind == .shutter && state.isAdjustable)
            ),
            dragThreshold: rulerDragThreshold(for: state.kind),
            maximumStepCount: rulerMaximumStepCount(for: state.kind),
            tickSpacing: rulerTickSpacing(for: state.kind),
            supportsInertia: state.isAdjustable
        )
    }

    private struct HorizontalRulerTick: Equatable {
        let value: Double
        let label: String
    }

    private func horizontalRulerTicks(for state: CaptureProfessionalParameterState) -> [HorizontalRulerTick] {
        switch state.kind {
        case .exposureCompensation:
            return exposureCompensationWheelValues().map { HorizontalRulerTick(value: $0, label: formattedEVTick($0)) }
        case .whiteBalance:
            return whiteBalanceWheelValues().map { HorizontalRulerTick(value: $0, label: formattedWhiteBalanceTick($0)) }
        case .tint:
            return tintWheelValues().map { HorizontalRulerTick(value: $0, label: formattedTintTick($0)) }
        case .iso:
            return isoWheelValues().map { HorizontalRulerTick(value: $0, label: formattedISOTick($0)) }
        case .shutter:
            return shutterWheelDurationValues().map { HorizontalRulerTick(value: $0, label: formattedShutterTick($0)) }
        default:
            return [HorizontalRulerTick(value: state.dialValue, label: bottomParameterValueText(for: state))]
        }
    }

    private func horizontalRulerSelectedIndex(for state: CaptureProfessionalParameterState, ticks: [HorizontalRulerTick]) -> Int {
        guard !ticks.isEmpty else { return 0 }

        let targetValue: Double
        switch state.kind {
        case .exposureCompensation:
            targetValue = pendingExposureBiasWheelValue ?? Double(cameraRuntime.currentExposureBias)
        case .whiteBalance:
            targetValue = pendingWhiteBalanceWheelValue ?? Double(cameraRuntime.currentWhiteBalanceTemperature)
        case .tint:
            targetValue = pendingTintWheelValue ?? Double(cameraRuntime.currentWhiteBalanceTint)
        case .iso:
            if let pendingISOWheelValue {
                targetValue = pendingISOWheelValue
            } else if state.mode == .manual {
                targetValue = Double(cameraRuntime.currentManualISOValue)
            } else {
                targetValue = Double(cameraRuntime.currentISOValue)
            }
        case .shutter:
            if let pendingShutterWheelDurationSeconds {
                targetValue = pendingShutterWheelDurationSeconds
            } else if state.mode == .manual {
                targetValue = cameraRuntime.currentManualShutterDurationSeconds
            } else {
                targetValue = cameraRuntime.currentShutterDurationSeconds
            }
        default:
            targetValue = state.dialValue
        }

        return ticks.enumerated().min { lhs, rhs in
            abs(lhs.element.value - targetValue) < abs(rhs.element.value - targetValue)
        }?.offset ?? 0
    }

    private func horizontalRulerMajorTickIndexes(
        for kind: CaptureProfessionalParameterKind,
        ticks: [HorizontalRulerTick],
        selectedIndex: Int
    ) -> Set<Int> {
        guard !ticks.isEmpty else { return [] }
        var indexes: Set<Int> = [0, max(0, ticks.count - 1), min(max(0, selectedIndex), ticks.count - 1)]

        switch kind {
        case .exposureCompensation:
            addMajorIndexes(for: [-2.0, -1.0, 0.0, 1.0, 2.0], ticks: ticks, into: &indexes)
        case .whiteBalance:
            addMajorIndexes(for: stride(from: 2500.0, through: 9000.0, by: 500.0).map { $0 }, ticks: ticks, into: &indexes)
        case .tint:
            addMajorIndexes(for: stride(from: -50.0, through: 50.0, by: 5.0).map { $0 }, ticks: ticks, into: &indexes)
        case .iso:
            addMajorIndexes(for: [50, 100, 200, 400, 800, 1600, 3200], ticks: ticks, into: &indexes)
        case .shutter:
            addMajorIndexes(for: shutterPrimaryAnchorDurations, ticks: ticks, into: &indexes)
        default:
            break
        }

        if indexes.count < 5, ticks.count > 4 {
            let labelInterval = max(1, ticks.count / 5)
            for index in stride(from: 0, to: ticks.count, by: labelInterval) {
                indexes.insert(index)
            }
        }
        return indexes
    }

    private func addMajorIndexes(for values: [Double], ticks: [HorizontalRulerTick], into indexes: inout Set<Int>) {
        for value in values {
            guard let nearest = ticks.enumerated().min(by: { lhs, rhs in
                abs(lhs.element.value - value) < abs(rhs.element.value - value)
            }) else { continue }
            indexes.insert(nearest.offset)
        }
    }

    private func horizontalRulerControlKind(for state: CaptureProfessionalParameterState) -> CaptureRulerControlKind {
        switch state.kind {
        case .exposureCompensation where state.mode == .locked:
            return .lock
        case .exposureCompensation, .tint:
            return .reset
        case .shutter where state.mode == .locked:
            return .lock
        case .whiteBalance, .iso, .shutter:
            return .auto(isOn: state.mode == .auto)
        default:
            return .reset
        }
    }

    private func rulerDragThreshold(for kind: CaptureProfessionalParameterKind) -> CGFloat {
        switch kind {
        case .exposureCompensation:
            return 42
        case .whiteBalance:
            return 28
        case .tint:
            return 26
        case .iso:
            return 40
        case .shutter:
            return 44
        default:
            return 42
        }
    }

    private func rulerMaximumStepCount(for kind: CaptureProfessionalParameterKind) -> Int {
        switch kind {
        case .whiteBalance, .iso:
            return 2
        case .exposureCompensation, .tint:
            return 1
        case .shutter:
            return 2
        default:
            return 1
        }
    }

    private func rulerTickSpacing(for kind: CaptureProfessionalParameterKind) -> CGFloat {
        switch kind {
        case .shutter:
            return 18
        case .whiteBalance:
            return 14
        case .tint:
            return 16
        default:
            return 24
        }
    }

    private func bottomParameterTitle(for kind: CaptureProfessionalParameterKind) -> String {
        switch kind {
        case .focus:
            return "FOCUS"
        case .exposureCompensation:
            return "EV"
        case .whiteBalance:
            return "WB"
        case .tint:
            return "TINT"
        case .iso:
            return "ISO"
        case .shutter:
            return "S"
        case .ratio:
            return "RATIO"
        case .pixel:
            return "PX"
        case .settings:
            return "SET"
        }
    }

    private func bottomParameterValueText(for state: CaptureProfessionalParameterState) -> String {
        switch state.kind {
        case .focus:
            switch state.mode {
            case .auto:
                return "A \(formattedWhiteBalanceTick(Double(cameraRuntime.currentWhiteBalanceTemperature)))"
            case .manual:
                return "M"
            case .locked:
                return "L"
            case .pending:
                return "..."
            case .disabled:
                return "--"
            }
        case .exposureCompensation:
            guard state.mode != .disabled else { return "--" }
            guard state.mode != .locked else { return "LOCK" }
            if state.mode == .auto, cameraRuntime.productAutoExposureAppliedBias != nil {
                return "A\(formattedEVTick(Double(cameraRuntime.currentExposureBias)))"
            }
            return formattedEVTick(pendingExposureBiasWheelValue ?? Double(cameraRuntime.currentExposureBias))
        case .whiteBalance:
            guard state.mode != .disabled else { return "--" }
            if let pendingWhiteBalanceWheelValue {
                return formattedWhiteBalanceTick(pendingWhiteBalanceWheelValue)
            }
            switch state.mode {
            case .auto:
                return "A \(formattedWhiteBalanceTick(Double(cameraRuntime.currentWhiteBalanceTemperature)))"
            case .manual:
                return cameraRuntime.whiteBalanceDisplayText
            case .locked:
                return "L"
            case .pending:
                return "..."
            case .disabled:
                return "--"
            }
        case .tint:
            guard state.mode != .disabled else { return "--" }
            if let pendingTintWheelValue {
                return formattedTintDisplayText(pendingTintWheelValue)
            }
            switch state.mode {
            case .manual:
                return formattedTintDisplayText(Double(cameraRuntime.currentWhiteBalanceTint))
            case .locked:
                return "L"
            case .pending:
                return "..."
            case .disabled:
                return "--"
            case .auto:
                return formattedTintDisplayText(Double(cameraRuntime.currentWhiteBalanceTint))
            }
        case .iso:
            guard state.mode != .disabled else { return "--" }
            if let pendingISOWheelValue {
                return formattedISOTick(pendingISOWheelValue)
            }
            switch state.mode {
            case .auto:
                let roundedISO = Int(cameraRuntime.currentISOValue.rounded())
                return roundedISO > 0 ? "A \(roundedISO)" : "A"
            case .manual:
                let roundedISO = Int(cameraRuntime.currentManualISOValue.rounded())
                return roundedISO > 0 ? "\(roundedISO)" : "--"
            case .locked:
                return "L"
            case .pending:
                return "..."
            case .disabled:
                return "--"
            }
        case .shutter:
            guard state.mode != .disabled else { return "--" }
            if state.mode == .locked {
                return "LOCK"
            }
            if let pendingShutterWheelDurationSeconds {
                return formattedShutterDisplayText(seconds: pendingShutterWheelDurationSeconds) ?? "--"
            }
            let seconds = state.mode == .manual
                ? cameraRuntime.currentManualShutterDurationSeconds
                : cameraRuntime.currentShutterDurationSeconds
            if let text = formattedShutterDisplayText(seconds: seconds) {
                return state.mode == .auto ? "A \(text)" : text
            }
            return state.mode == .auto ? "A" : "--"
        case .ratio, .pixel, .settings:
            return state.valueText
        }
    }

    private func formattedEVTick(_ value: Double) -> String {
        if abs(value) < 0.05 {
            return "0.0"
        }
        return String(format: "%+.1f", value)
    }

    private func formattedWhiteBalanceTick(_ value: Double) -> String {
        "\(Int(value.rounded()))K"
    }

    private func formattedTintTick(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        if rounded == 0 { return "0" }
        if rounded > 0 { return "M\(rounded)" }
        return "G\(abs(rounded))"
    }

    private func formattedTintDisplayText(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        if rounded == 0 { return "0" }
        return rounded > 0 ? "+\(rounded)" : "\(rounded)"
    }

    private func formattedISOTick(_ value: Double) -> String {
        "\(Int(value.rounded()))"
    }

    private func formattedShutterTick(_ seconds: Double) -> String {
        formattedShutterDisplayText(seconds: seconds) ?? "--"
    }

    private func manualTakeoverTargetIndex(
        currentIndex: Int,
        direction: Int,
        valueCount: Int,
        isAutoMode: Bool
    ) -> (index: Int, forceWrite: Bool)? {
        let targetIndex = min(max(currentIndex + direction, 0), valueCount - 1)
        if targetIndex != currentIndex {
            // AUTO takeover must not be filtered by duplicate guards; the first drag establishes manual ownership.
            return (targetIndex, isAutoMode)
        }

        guard isAutoMode else { return nil }
        let takeoverBaselineIndex = min(max(currentIndex - direction, 0), valueCount - 1)
        guard takeoverBaselineIndex != currentIndex else { return nil }
        // AUTO takeover must also move to a real manual tick; writing the same boundary value feels like a swallowed first drag.
        return (takeoverBaselineIndex, true)
    }

    private var isSimulatorCameraParameterFallbackEnabled: Bool {
#if DEBUG && targetEnvironment(simulator)
        true
#else
        false
#endif
    }

    private func stepExposureCompensationWheel(by direction: Int) -> Bool {
        guard direction != 0 else { return false }
        let state = parameterState(for: .exposureCompensation)
        guard state.isAdjustable else {
            clearExposureBiasPendingForManualExposure(reason: "EV drag blocked")
            cameraRuntime.captureHintText = state.hintText
            logExposureTriangle("EV drag blocked isoMode=\(cameraRuntime.selectedISOPreset == .auto ? "auto" : "manual") shutterMode=\(cameraRuntime.selectedShutterPreset == .auto ? "auto" : "manual") evState=locked reason=\(state.hintText)")
            logExposureBiasWheel("skip EV write: exposure compensation not adjustable")
            return false
        }

        let values = exposureCompensationWheelValues()
        guard values.count > 1 else { return false }

        activeBottomParameterKind = .exposureCompensation
        isBottomParameterPanelExpanded = true

        let current = nearestExposureCompensationWheelValue(
            to: pendingExposureBiasWheelValue ?? Double(cameraRuntime.currentExposureBias),
            in: values
        )
        guard let index = values.firstIndex(of: current) else { return false }

        guard let takeoverTarget = manualTakeoverTargetIndex(
            currentIndex: index,
            direction: direction,
            valueCount: values.count,
            isAutoMode: state.mode == .auto
        ) else {
            logExposureBiasWheel("skip EV write at boundary \(formattedEVTick(current))")
            return false
        }

        let targetValue = values[takeoverTarget.index]
        if !takeoverTarget.forceWrite,
           abs(targetValue - (pendingExposureBiasWheelValue ?? Double(cameraRuntime.currentExposureBias))) < 0.05 {
            logExposureBiasWheel("skip EV write duplicated tick \(formattedEVTick(targetValue))")
            return false
        }
        if !takeoverTarget.forceWrite,
           let lastDispatchedExposureBiasValue,
           abs(targetValue - lastDispatchedExposureBiasValue) < 0.05 {
            logExposureBiasWheel("skip EV write same target \(formattedEVTick(targetValue))")
            return false
        }

        pendingExposureBiasWheelValue = targetValue
        pendingExposureBiasUpdatedAt = Date()
        lastDispatchedExposureBiasValue = targetValue
        logExposureBiasWheel("dispatch EV write target \(formattedEVTick(targetValue))")
        cameraRuntime.setExposureBiasDialValue(targetValue)
        return true
    }

    private func resetExposureCompensationWheel() {
        let state = parameterState(for: .exposureCompensation)
        guard state.canReset else {
            clearExposureBiasPendingForManualExposure(reason: "EV reset blocked")
            cameraRuntime.captureHintText = state.hintText
            logExposureTriangle("EV reset blocked isoMode=\(cameraRuntime.selectedISOPreset == .auto ? "auto" : "manual") shutterMode=\(cameraRuntime.selectedShutterPreset == .auto ? "auto" : "manual") evState=locked reason=\(state.hintText)")
            logExposureBiasWheel("skip EV reset: cannot reset in current state")
            return
        }

        pendingExposureBiasWheelValue = 0
        pendingExposureBiasUpdatedAt = Date()
        lastDispatchedExposureBiasValue = 0
        activeBottomParameterKind = .exposureCompensation
        logExposureBiasWheel("dispatch EV reset to 0.0")
        cameraRuntime.resetExposureBias()
    }

    private func stepWhiteBalanceWheel(by direction: Int) -> Bool {
        guard direction != 0 else { return false }
        let state = parameterState(for: .whiteBalance)
        guard state.isAdjustable else {
            pendingWhiteBalanceWheelValue = nil
            pendingWhiteBalanceUpdatedAt = nil
            logParameterGuard(parameter: .whiteBalance, reason: "notAdjustable mode=\(debugParameterModeText(state.mode))")
            logWhiteBalanceWheel("skip WB write: white balance not adjustable direction=\(direction) mode=\(debugParameterModeText(state.mode)) runtimePreset=\(String(describing: cameraRuntime.selectedWhiteBalancePreset))")
            return false
        }

        let values = whiteBalanceWheelValues()
        guard values.count > 1 else { return false }

        activeBottomParameterKind = .whiteBalance
        isBottomParameterPanelExpanded = true

        let current = nearestWhiteBalanceWheelValue(
            to: pendingWhiteBalanceWheelValue ?? Double(cameraRuntime.currentWhiteBalanceTemperature),
            in: values
        )
        guard let index = values.firstIndex(of: current) else { return false }
        logWhiteBalanceWheel(
            "changed direction=\(direction) mode=\(debugParameterModeText(state.mode)) pending=\(debugOptionalWhiteBalanceTick(pendingWhiteBalanceWheelValue)) runtime=\(formattedWhiteBalanceTick(Double(cameraRuntime.currentWhiteBalanceTemperature))) displayed=\(bottomParameterValueText(for: state)) currentIndex=\(index) current=\(formattedWhiteBalanceTick(current)) runtimePreset=\(String(describing: cameraRuntime.selectedWhiteBalancePreset))"
        )

        guard let takeoverTarget = manualTakeoverTargetIndex(
            currentIndex: index,
            direction: direction,
            valueCount: values.count,
            isAutoMode: state.mode == .auto
        ) else {
            logWhiteBalanceWheel("skip WB write at boundary \(formattedWhiteBalanceTick(current)) direction=\(direction) isAuto=\(state.mode == .auto)")
            return false
        }

        let targetValue = values[takeoverTarget.index]
        let valueTolerance = max(cameraRuntime.whiteBalanceDialStepValue * 0.5, 20)
        if !takeoverTarget.forceWrite,
           abs(targetValue - (pendingWhiteBalanceWheelValue ?? Double(cameraRuntime.currentWhiteBalanceTemperature))) < valueTolerance {
            logWhiteBalanceWheel("skip WB write duplicated tick \(formattedWhiteBalanceTick(targetValue)) targetIndex=\(takeoverTarget.index) didTakeover=false")
            return false
        }
        if !takeoverTarget.forceWrite,
           let lastDispatchedWhiteBalanceValue,
           abs(targetValue - lastDispatchedWhiteBalanceValue) < valueTolerance {
            logWhiteBalanceWheel("skip WB write same target \(formattedWhiteBalanceTick(targetValue)) targetIndex=\(takeoverTarget.index) didTakeover=false")
            return false
        }

        pendingWhiteBalanceWheelValue = targetValue
        pendingWhiteBalanceUpdatedAt = Date()
        lastDispatchedWhiteBalanceValue = targetValue
        logWhiteBalanceWheel(
            "dispatch WB write target=\(formattedWhiteBalanceTick(targetValue)) targetIndex=\(takeoverTarget.index) forceWrite=\(takeoverTarget.forceWrite) didTakeover=\(state.mode == .auto) pending=\(debugOptionalWhiteBalanceTick(pendingWhiteBalanceWheelValue))"
        )
        cameraRuntime.setWhiteBalanceDialValue(targetValue)
        return true
    }

    private func applyWhiteBalanceAutoFromWheel() {
        guard parameterState(for: .whiteBalance).canUseAuto || parameterState(for: .whiteBalance).canReset else {
            pendingWhiteBalanceWheelValue = nil
            pendingWhiteBalanceUpdatedAt = nil
            logWhiteBalanceWheel("skip WB auto: cannot use auto in current state")
            return
        }

        activeBottomParameterKind = .whiteBalance
        pendingWhiteBalanceWheelValue = nil
        pendingWhiteBalanceUpdatedAt = nil
        lastDispatchedWhiteBalanceValue = nil
        logWhiteBalanceWheel("dispatch WB auto")
        cameraRuntime.applyWhiteBalanceAuto()
    }

    private func stepTintWheel(by direction: Int) -> Bool {
        guard direction != 0 else { return false }
        guard parameterState(for: .tint).isAdjustable else {
            pendingTintWheelValue = nil
            pendingTintUpdatedAt = nil
            logParameterGuard(parameter: .tint, reason: "notAdjustable")
            logTintWheel("skip Tint write: Tint not adjustable")
            return false
        }

        let values = tintWheelValues()
        guard values.count > 1 else { return false }

        activeBottomParameterKind = .tint
        isBottomParameterPanelExpanded = true

        let current = nearestTintWheelValue(
            to: pendingTintWheelValue ?? Double(cameraRuntime.currentWhiteBalanceTint),
            in: values
        )
        guard let index = values.firstIndex(of: current) else { return false }

        let targetIndex = min(max(index + direction, 0), values.count - 1)
        guard targetIndex != index else {
            logTintWheel("skip Tint write at boundary \(formattedTintTick(current))")
            return false
        }

        let targetValue = values[targetIndex]
        let valueTolerance = 0.5
        guard abs(targetValue - (pendingTintWheelValue ?? Double(cameraRuntime.currentWhiteBalanceTint))) >= valueTolerance else {
            logTintWheel("skip Tint write duplicated tick \(formattedTintTick(targetValue))")
            return false
        }
        if let lastDispatchedTintValue, abs(targetValue - lastDispatchedTintValue) < valueTolerance {
            logTintWheel("skip Tint write same target \(formattedTintTick(targetValue))")
            return false
        }

        pendingTintWheelValue = targetValue
        pendingTintUpdatedAt = Date()
        lastDispatchedTintValue = targetValue
        logTintWheel("dispatch Tint write target \(formattedTintTick(targetValue))")
        cameraRuntime.setWhiteBalanceTintDialValue(targetValue)
        return true
    }

    private func applyTintResetFromWheel() {
        guard parameterState(for: .tint).canReset else {
            pendingTintWheelValue = nil
            pendingTintUpdatedAt = nil
            logTintWheel("skip Tint reset: cannot reset in current state")
            return
        }

        activeBottomParameterKind = .tint
        if cameraRuntime.selectedWhiteBalancePreset == .auto {
            pendingTintWheelValue = nil
            pendingTintUpdatedAt = nil
            lastDispatchedTintValue = nil
            logTintWheel("dispatch Tint reset to 0 (WB auto mode)")
        } else {
            pendingTintWheelValue = 0
            pendingTintUpdatedAt = Date()
            lastDispatchedTintValue = 0
            logTintWheel("dispatch Tint reset to 0 (WB manual mode)")
        }
        cameraRuntime.resetWhiteBalanceTint()
    }

    private func stepISOWheel(by direction: Int) -> Bool {
        guard direction != 0 else { return false }
        let state = parameterState(for: .iso)
        guard state.isAdjustable else {
            pendingISOWheelValue = nil
            pendingISOUpdatedAt = nil
            logParameterGuard(parameter: .iso, reason: "notAdjustable mode=\(debugParameterModeText(state.mode))")
            logISOWheel("skip ISO write: ISO not adjustable")
            return false
        }

        let values = isoWheelValues()
        guard values.count > 1 else { return false }

        activeBottomParameterKind = .iso
        isBottomParameterPanelExpanded = true

        let runtimeISO = state.mode == .manual
            ? Double(cameraRuntime.currentManualISOValue)
            : Double(cameraRuntime.currentISOValue)
        let current = nearestISOWheelValue(
            to: pendingISOWheelValue ?? runtimeISO,
            in: values
        )
        guard let index = values.firstIndex(of: current) else { return false }

        guard let takeoverTarget = manualTakeoverTargetIndex(
            currentIndex: index,
            direction: direction,
            valueCount: values.count,
            isAutoMode: state.mode == .auto
        ) else {
            logISOWheel("skip ISO write at boundary \(formattedISOTick(current))")
            return false
        }

        let targetISO = values[takeoverTarget.index]
        let valueTolerance: Double = 1.0
        if !takeoverTarget.forceWrite,
           abs(targetISO - (pendingISOWheelValue ?? runtimeISO)) < valueTolerance {
            logISOWheel("skip ISO write duplicated tick \(formattedISOTick(targetISO))")
            return false
        }
        if !takeoverTarget.forceWrite,
           let lastDispatchedISOValue,
           abs(targetISO - lastDispatchedISOValue) < valueTolerance {
            logISOWheel("skip ISO write same target \(formattedISOTick(targetISO))")
            return false
        }

        guard let normalizedTarget = isoNormalizedValue(forISO: targetISO) else {
            logISOWheel("skip ISO write: failed to normalize target \(formattedISOTick(targetISO))")
            return false
        }

        pendingISOWheelValue = targetISO
        pendingISOUpdatedAt = Date()
        lastDispatchedISOValue = targetISO
        logISOWheel("dispatch ISO write target \(formattedISOTick(targetISO))")
        logExposureTriangle("action=isoDrag isoMode=manual shutterMode=\(cameraRuntime.selectedShutterPreset == .auto ? "auto" : "manual") evState=locked reason=manualISO")
        cameraRuntime.setISODialValue(normalizedTarget)
        return true
    }

    private func applyISOAutoFromWheel() {
        guard parameterState(for: .iso).canUseAuto || parameterState(for: .iso).canReset else {
            pendingISOWheelValue = nil
            pendingISOUpdatedAt = nil
            logISOWheel("skip ISO auto: cannot use auto in current state")
            return
        }

        activeBottomParameterKind = .iso
        pendingISOWheelValue = nil
        pendingISOUpdatedAt = nil
        lastDispatchedISOValue = nil
        logISOWheel("dispatch ISO auto")
        logExposureTriangle("action=isoAuto isoMode=auto shutterMode=\(cameraRuntime.selectedShutterPreset == .auto ? "auto" : "manual") evState=\(cameraRuntime.selectedShutterPreset == .auto ? "enabled" : "locked") reason=autoRestore")
        cameraRuntime.applyISOAuto()
    }

    private func stepShutterWheel(by direction: Int) -> Bool {
        guard direction != 0 else { return false }
        let state = parameterState(for: .shutter)
        guard state.isAdjustable else {
            pendingShutterWheelDurationSeconds = nil
            pendingShutterUpdatedAt = nil
            lastDispatchedShutterTickIndex = nil
            lastDispatchedShutterDurationSeconds = nil
            logParameterGuard(parameter: .shutter, reason: "notAdjustable mode=\(debugParameterModeText(state.mode))")
            logShutterWheel("skip shutter write: shutter not adjustable")
            return false
        }

        let values = shutterWheelDurationValues()
        guard values.count > 1 else { return false }

        activeBottomParameterKind = .shutter
        isBottomParameterPanelExpanded = true

        let runtimeSeconds = state.mode == .manual
            ? cameraRuntime.currentManualShutterDurationSeconds
            : cameraRuntime.currentShutterDurationSeconds
        let current = nearestShutterWheelDuration(
            to: pendingShutterWheelDurationSeconds ?? runtimeSeconds,
            in: values
        )
        guard let index = values.firstIndex(of: current) else { return false }
        let requestedTargetIndex = index + direction
        let clampedTargetIndex = min(max(requestedTargetIndex, 0), values.count - 1)

        guard let takeoverTarget = manualTakeoverTargetIndex(
            currentIndex: index,
            direction: direction,
            valueCount: values.count,
            isAutoMode: state.mode == .auto
        ) else {
            logShutterWheel(
                "skip shutter write at boundary \(formattedShutterTick(current)) " +
                "dragDirection=\(direction) previousTickIndex=\(index) targetTickIndex=\(requestedTargetIndex) " +
                "minTickIndex=0 maxTickIndex=\(values.count - 1) clampedTickIndex=\(clampedTargetIndex)"
            )
            return false
        }

        let targetDuration = values[takeoverTarget.index]
        let epsilon = shutterDurationIdentityEpsilon(for: targetDuration)
        if !takeoverTarget.forceWrite,
           pendingShutterWheelDurationSeconds == nil,
           !isShutterRulerInteracting,
           committedShutterTickIndex == takeoverTarget.index,
           let committedShutterDurationSeconds,
           abs(targetDuration - committedShutterDurationSeconds) < epsilon {
            logShutterWheel(
                "skip shutter write duplicated tick index=\(takeoverTarget.index) duration=\(formattedShutterTick(targetDuration)) " +
                "delta=\(String(format: "%.8f", abs(targetDuration - committedShutterDurationSeconds))) " +
                "previousTickIndex=\(index) pendingTickIndex=nil committedTickIndex=\(committedShutterTickIndex.map(String.init) ?? "nil") " +
                "skipReason=skipDuplicate"
            )
            return false
        }

        guard let normalizedTarget = shutterNormalizedValue(forDurationSeconds: targetDuration) else {
            logShutterWheel("skip shutter write: failed to normalize target \(formattedShutterTick(targetDuration))")
            return false
        }

        pendingShutterWheelDurationSeconds = targetDuration
        pendingShutterUpdatedAt = Date()
        lastDispatchedShutterDurationSeconds = targetDuration
        lastDispatchedShutterTickIndex = takeoverTarget.index
        let writeReason = isShutterRulerInteracting ? "draggingUpdate" : "finalCommit"
        logShutterWheel(
            "dispatch shutter write target \(formattedShutterTick(targetDuration)) " +
            "dragDirection=\(direction) previousTickIndex=\(index) targetTickIndex=\(takeoverTarget.index) " +
            "pendingTickIndex=\(takeoverTarget.index) committedTickIndex=\(committedShutterTickIndex.map(String.init) ?? "nil") " +
            "isDragging=\(isShutterRulerInteracting) isInertia=false writeReason=\(writeReason)"
        )
        logShutterRange(
            "min=\(formattedShutterTick(cameraRuntime.minimumShutterDurationSeconds)) " +
            "max=\(formattedShutterTick(cameraRuntime.maximumShutterDurationSeconds)) " +
            "tickCount=\(values.count) " +
            "mappedTick=\(takeoverTarget.index)/\(values.count - 1) " +
            "previousTickIndex=\(index) " +
            "targetTickIndex=\(takeoverTarget.index) " +
            "pendingTickIndex=\(lastDispatchedShutterTickIndex.map(String.init) ?? "nil") " +
            "committedTickIndex=\(committedShutterTickIndex.map(String.init) ?? "nil") " +
            "targetDuration=\(String(format: "%.8f", targetDuration)) " +
            "display=\(formattedShutterDisplayText(seconds: targetDuration) ?? "--") " +
            "writeReason=\(writeReason)"
        )
        logExposureTriangle("action=shutterDrag isoMode=\(cameraRuntime.selectedISOPreset == .auto ? "auto" : "manual") shutterMode=manual evState=locked reason=manualShutter")
        cameraRuntime.setShutterDialValue(normalizedTarget)
        return true
    }

    private func applyShutterAutoFromWheel() {
        guard parameterState(for: .shutter).canUseAuto || parameterState(for: .shutter).canReset else {
            pendingShutterWheelDurationSeconds = nil
            pendingShutterUpdatedAt = nil
            lastDispatchedShutterTickIndex = nil
            lastDispatchedShutterDurationSeconds = nil
            logShutterWheel("skip shutter auto: cannot use auto in current state")
            return
        }

        activeBottomParameterKind = .shutter
        pendingShutterWheelDurationSeconds = nil
        pendingShutterUpdatedAt = nil
        lastDispatchedShutterDurationSeconds = nil
        lastDispatchedShutterTickIndex = nil
        committedShutterDurationSeconds = nil
        committedShutterTickIndex = nil
        logShutterWheel("dispatch shutter auto")
        logExposureTriangle("action=shutterAuto isoMode=\(cameraRuntime.selectedISOPreset == .auto ? "auto" : "manual") shutterMode=auto evState=\(cameraRuntime.selectedISOPreset == .auto ? "enabled" : "locked") reason=autoRestore")
        cameraRuntime.applyShutterAuto()
    }

    private func clearPendingValue(for kind: CaptureProfessionalParameterKind) {
        switch kind {
        case .exposureCompensation:
            pendingExposureBiasWheelValue = nil
            pendingExposureBiasUpdatedAt = nil
            lastDispatchedExposureBiasValue = nil
        case .whiteBalance:
            pendingWhiteBalanceWheelValue = nil
            pendingWhiteBalanceUpdatedAt = nil
            lastDispatchedWhiteBalanceValue = nil
        case .tint:
            pendingTintWheelValue = nil
            pendingTintUpdatedAt = nil
            lastDispatchedTintValue = nil
        case .iso:
            pendingISOWheelValue = nil
            pendingISOUpdatedAt = nil
            lastDispatchedISOValue = nil
        case .shutter:
            pendingShutterWheelDurationSeconds = nil
            pendingShutterUpdatedAt = nil
            lastDispatchedShutterDurationSeconds = nil
            lastDispatchedShutterTickIndex = nil
        case .focus:
            clearManualFocusPending()
        default:
            break
        }
    }

    private func exposureCompensationWheelValues() -> [Double] {
        let deviceMinimum = Double(cameraRuntime.minimumExposureBias)
        let deviceMaximum = Double(cameraRuntime.maximumExposureBias)
        let boundedMinimum = max(-2.0, deviceMinimum)
        let boundedMaximum = min(2.0, deviceMaximum)

        guard boundedMinimum <= boundedMaximum else {
            return [0]
        }

        return (-6...6)
            .map { Double($0) / 3.0 }
            .filter { $0 >= boundedMinimum - 0.01 && $0 <= boundedMaximum + 0.01 }
    }

    private func whiteBalanceWheelValues() -> [Double] {
        let range = cameraRuntime.whiteBalanceDialRange
        let lowerBound = Int(range.lowerBound.rounded())
        let upperBound = Int(range.upperBound.rounded())
        guard lowerBound <= upperBound else { return [Double(lowerBound)] }

        // WB keeps sparse labels but uses 50K snap ticks for a denser gear feel.
        let snapStep = 50
        let firstTick = Int((Double(lowerBound) / Double(snapStep)).rounded(.up)) * snapStep
        let lastTick = Int((Double(upperBound) / Double(snapStep)).rounded(.down)) * snapStep
        var values: [Double] = firstTick <= lastTick
            ? stride(from: firstTick, through: lastTick, by: snapStep).map(Double.init)
            : []

        values.append(Double(lowerBound))
        values.append(Double(upperBound))
        values.append(Double(cameraRuntime.currentWhiteBalanceTemperature.rounded()))
        return Array(Set(values)).sorted()
    }

    private func tintWheelValues() -> [Double] {
        let range = cameraRuntime.whiteBalanceTintDialRange
        let lowerBound = max(-50, Int(range.lowerBound.rounded()))
        let upperBound = min(50, Int(range.upperBound.rounded()))
        guard lowerBound <= upperBound else { return [Double(lowerBound)] }

        // Tint labels remain on 5-step anchors while the ruler moves in 1-unit ticks.
        var values = stride(from: lowerBound, through: upperBound, by: 1).map(Double.init)

        values.append(0)
        values.append(Double(lowerBound))
        values.append(Double(upperBound))
        values.append(Double(cameraRuntime.currentWhiteBalanceTint.rounded()))
        return Array(Set(values)).sorted()
    }

    private func isoWheelValues() -> [Double] {
        let minISO = Double(cameraRuntime.minimumISOValue)
        let maxISO = Double(cameraRuntime.maximumISOValue)
        guard minISO.isFinite, maxISO.isFinite, minISO > 0, maxISO > minISO else {
            let fallbackISO = max(1, Double(cameraRuntime.currentManualISOValue))
            return [fallbackISO]
        }

        let preferredISOValues: [Double] = [
            25, 32, 40, 50, 64, 80, 100, 125, 160, 200, 250, 320,
            400, 500, 640, 800, 1000, 1250, 1600, 2000, 2500, 3200,
            4000, 5000, 6400
        ]
        var values = preferredISOValues
            .filter { $0 >= minISO - 0.01 && $0 <= maxISO + 0.01 }
            .map { $0.rounded() }
        values.append(minISO.rounded())
        values.append(maxISO.rounded())
        values.append(Double(cameraRuntime.currentISOValue.rounded()))
        values.append(Double(cameraRuntime.currentManualISOValue.rounded()))

        let uniqueSorted = Array(Set(values)).sorted()
        return uniqueSorted
    }

    private func shutterWheelDurationValues() -> [Double] {
        let minSeconds = cameraRuntime.minimumShutterDurationSeconds
        let maxSeconds = cameraRuntime.maximumShutterDurationSeconds
        guard minSeconds.isFinite, maxSeconds.isFinite, minSeconds > 0, maxSeconds > minSeconds else {
            let fallback = max(0.00025, cameraRuntime.currentManualShutterDurationSeconds)
            return [fallback]
        }

        // Keep the ruler on product-photo shutter anchors while preserving activeFormat endpoints.
        var values: [Double] = [maxSeconds]
        values.append(contentsOf: shutterPrimaryAnchorDurations.filter { anchor in
            anchor >= minSeconds && anchor <= maxSeconds
        })
        values.append(minSeconds)
        values.append(maxSeconds)
        if let pendingShutterWheelDurationSeconds, pendingShutterWheelDurationSeconds.isFinite, pendingShutterWheelDurationSeconds > 0 {
            values.append(pendingShutterWheelDurationSeconds)
        }
        if cameraRuntime.currentManualShutterDurationSeconds.isFinite, cameraRuntime.currentManualShutterDurationSeconds > 0 {
            values.append(cameraRuntime.currentManualShutterDurationSeconds)
        }
        if cameraRuntime.currentShutterDurationSeconds.isFinite, cameraRuntime.currentShutterDurationSeconds > 0 {
            values.append(cameraRuntime.currentShutterDurationSeconds)
        }
        let clampedValues = values.compactMap { value -> Double? in
            guard value.isFinite, value > 0 else { return nil }
            return max(minSeconds, min(maxSeconds, value))
        }
        return deduplicatedShutterDurations(clampedValues).sorted(by: >)
    }

    private func deduplicatedShutterDurations(_ values: [Double]) -> [Double] {
        var seenKeys: Set<Int64> = []
        var result: [Double] = []
        for value in values {
            let key = shutterDurationIdentityKey(value)
            guard !seenKeys.contains(key) else { continue }
            seenKeys.insert(key)
            result.append(value)
        }
        return result
    }

    private func shutterDurationIdentityKey(_ seconds: Double) -> Int64 {
        Int64((seconds * 1_000_000_000).rounded())
    }

    private func shutterDurationIdentityEpsilon(for seconds: Double) -> Double {
        max(0.0000005, seconds * 0.0005)
    }

    private func isoNormalizedValue(forISO iso: Double) -> Double? {
        let minISO = Double(cameraRuntime.minimumISOValue)
        let maxISO = Double(cameraRuntime.maximumISOValue)
        guard minISO.isFinite, maxISO.isFinite, minISO > 0, maxISO > minISO else { return nil }
        let clampedISO = max(minISO, min(maxISO, iso))
        let minLog = log2(minISO)
        let maxLog = log2(maxISO)
        let valueLog = log2(clampedISO)
        let denominator = maxLog - minLog
        guard denominator > .ulpOfOne else { return 0 }
        return max(0.0, min(1.0, (valueLog - minLog) / denominator))
    }

    private func shutterNormalizedValue(forDurationSeconds seconds: Double) -> Double? {
        let minSeconds = cameraRuntime.minimumShutterDurationSeconds
        let maxSeconds = cameraRuntime.maximumShutterDurationSeconds
        guard minSeconds.isFinite, maxSeconds.isFinite, minSeconds > 0, maxSeconds > minSeconds, seconds > 0 else {
            return nil
        }
        let clamped = max(minSeconds, min(maxSeconds, seconds))
        let minLog = log2(minSeconds)
        let maxLog = log2(maxSeconds)
        let denominator = minLog - maxLog
        guard abs(denominator) > .ulpOfOne else { return 0 }
        let valueLog = log2(clamped)
        return max(0.0, min(1.0, (valueLog - maxLog) / denominator))
    }

    private func nearestExposureCompensationWheelValue(to value: Double, in values: [Double]) -> Double {
        values.min { lhs, rhs in
            abs(lhs - value) < abs(rhs - value)
        } ?? 0
    }

    private func nearestWhiteBalanceWheelValue(to value: Double, in values: [Double]) -> Double {
        values.min { lhs, rhs in
            abs(lhs - value) < abs(rhs - value)
        } ?? value
    }

    private func nearestTintWheelValue(to value: Double, in values: [Double]) -> Double {
        values.min { lhs, rhs in
            abs(lhs - value) < abs(rhs - value)
        } ?? value
    }

    private func nearestISOWheelValue(to value: Double, in values: [Double]) -> Double {
        values.min { lhs, rhs in
            abs(lhs - value) < abs(rhs - value)
        } ?? value
    }

    private func nearestShutterWheelDuration(to value: Double, in values: [Double]) -> Double {
        values.min { lhs, rhs in
            abs(lhs - value) < abs(rhs - value)
        } ?? value
    }

    private func logExposureBiasWheel(_ message: String) {
#if DEBUG
        print("[CaptureEVWheel] \(message)")
#endif
    }

    private func logExposureTriangle(_ message: String) {
#if DEBUG
        print("[CaptureExposureTriangle] \(message)")
#endif
    }

    private func logParameterTap(
        parameter: CaptureProfessionalParameterKind,
        allowed: Bool,
        activePanel: CaptureProfessionalParameterKind?,
        blockedReason: String?
    ) {
#if DEBUG
        print(
            "[CaptureParameterTap] " +
            "parameter=\(parameter.rawValue) " +
            "allowed=\(allowed) " +
            "activePanel=\(activePanel?.rawValue ?? "nil") " +
            "lensZoomActive=\(isLensZoomControlPresented) " +
            "blockedReason=\(blockedReason ?? "none")"
        )
#endif
    }

    private func logParameterRuler(
        kind: CaptureProfessionalParameterKind,
        inputValue: Double,
        formattedValue: String,
        applied: Bool
    ) {
#if DEBUG
        print(
            "[CaptureParameterRuler] " +
            "kind=\(kind.rawValue) " +
            "input=\(String(format: "%.3f", inputValue)) " +
            "formatted=\(formattedValue) " +
            "applied=\(applied)"
        )
#endif
    }

    private func logParameterGuard(parameter: CaptureProfessionalParameterKind, reason: String) {
#if DEBUG
        print("[CaptureParameterGuard] parameter=\(parameter.rawValue) reason=\(reason)")
#endif
    }

    private func clearExposureBiasPendingForManualExposure(reason: String) {
        guard pendingExposureBiasWheelValue != nil
            || pendingExposureBiasUpdatedAt != nil
            || lastDispatchedExposureBiasValue != nil else { return }
        pendingExposureBiasWheelValue = nil
        pendingExposureBiasUpdatedAt = nil
        lastDispatchedExposureBiasValue = nil
        logExposureTriangle("cleared EV pending reason=\(reason)")
    }

    private func logWhiteBalanceWheel(_ message: String) {
#if DEBUG
        print("[CaptureWBWheel] \(message)")
#endif
    }

    private func debugOptionalWhiteBalanceTick(_ value: Double?) -> String {
#if DEBUG
        guard let value else { return "nil" }
        return formattedWhiteBalanceTick(value)
#else
        return ""
#endif
    }

    private func debugParameterModeText(_ mode: CaptureProfessionalParameterMode) -> String {
#if DEBUG
        switch mode {
        case .auto:
            return "auto"
        case .manual:
            return "manual"
        case .locked:
            return "locked"
        case .disabled:
            return "disabled"
        case .pending:
            return "pending"
        }
#else
        return ""
#endif
    }

    private func logTintWheel(_ message: String) {
#if DEBUG
        print("[CaptureTintWheel] \(message)")
#endif
    }

    private func logISOWheel(_ message: String) {
#if DEBUG
        print("[CaptureISOWheel] \(message)")
#endif
    }

    private func logShutterWheel(_ message: String) {
#if DEBUG
        print("[CaptureShutterWheel] \(message)")
#endif
    }

    private func logShutterRange(_ message: String) {
#if DEBUG
        print("[CaptureShutterRange] \(message)")
#endif
    }

    private func logExposureReadback(_ message: String) {
#if DEBUG
        print("[CaptureExposureReadback] \(message)")
#endif
    }

    private func logManualFocusRuler(_ message: String) {
#if DEBUG
        print("[CaptureManualFocusRuler] \(message)")
#endif
    }

    private func clearManualFocusPending() {
        pendingManualFocusPosition = nil
        pendingManualFocusUpdatedAt = nil
        lastDispatchedManualFocusPosition = nil
        lastManualFocusRuntimeWriteAt = .distantPast
    }

    private func stepManualFocusRuler(by direction: Int) -> ManualFocusRulerStepResult {
        guard isManualFocusModeActive, isManualFocusRulerPresented else { return .rejected }
        guard cameraRuntime.isManualFocusSupported else {
            cameraRuntime.captureHintText = "当前镜头不支持手动对焦"
            return .rejected
        }
        guard !cameraRuntime.isFocusExposureLocked else {
            cameraRuntime.captureHintText = "AE/AF 锁定中，长按画面解除后可调焦"
            return .rejected
        }

        let values = manualFocusRulerValues
        guard !values.isEmpty else { return .rejected }

        let currentIndex = nearestManualFocusRulerIndex(to: manualFocusDisplayPosition, in: values)
        let targetIndex = max(0, min(values.count - 1, currentIndex + direction))
        guard targetIndex != currentIndex else { return .rejected }

        let targetPosition = Float(max(0, min(1, values[targetIndex])))
        if let lastDispatchedManualFocusPosition,
           abs(lastDispatchedManualFocusPosition - targetPosition) < 0.001 {
            return .rejected
        }

        let now = Date()
        let writeAge = now.timeIntervalSince(lastManualFocusRuntimeWriteAt)
        guard writeAge >= ManualFocusRulerTuning.writeMinInterval else {
            logManualFocusRuler(
                "throttled target \(formattedManualFocusRulerValue(Double(targetPosition))) " +
                "lastWriteAge=\(String(format: "%.3f", writeAge)) minInterval=\(String(format: "%.3f", ManualFocusRulerTuning.writeMinInterval))"
            )
            return .throttled(lastWriteAge: writeAge)
        }

        pendingManualFocusPosition = targetPosition
        pendingManualFocusUpdatedAt = Date()
        lastDispatchedManualFocusPosition = targetPosition
        lastManualFocusRuntimeWriteAt = now
        logManualFocusRuler("target \(formattedManualFocusRulerValue(Double(targetPosition)))")
        cameraRuntime.setManualFocusLensPosition(targetPosition)
        return .applied
    }

    private func nearestManualFocusRulerIndex(to value: Double, in values: [Double]) -> Int {
        guard let index = values.indices.min(by: { abs(values[$0] - value) < abs(values[$1] - value) }) else {
            return 0
        }
        return index
    }

    private func formattedManualFocusRulerValue(_ value: Double) -> String {
        "MF \(Int((max(0, min(1, value)) * 100).rounded()))"
    }

    func parameterState(for kind: CaptureProfessionalParameterKind) -> CaptureProfessionalParameterState {
        switch kind {
        case .focus:
            let mode: CaptureProfessionalParameterMode
            if cameraRuntime.isFocusExposureLocked {
                mode = .locked
            } else if cameraRuntime.focusControlMode == .manual {
                mode = .manual
            } else if cameraRuntime.isManualFocusSupported {
                mode = .auto
            } else {
                mode = .disabled
            }
            return CaptureProfessionalParameterState(
                kind: .focus,
                valueText: focusEntryValueText(mode: mode),
                mode: mode,
                isAdjustable: cameraRuntime.isManualFocusSupported && !cameraRuntime.isFocusExposureLocked,
                canUseAuto: cameraRuntime.focusControlMode == .manual && !cameraRuntime.isFocusExposureLocked,
                canReset: cameraRuntime.focusControlMode == .manual && !cameraRuntime.isFocusExposureLocked,
                hintText: focusHintText(for: mode),
                dialRange: 0...1,
                dialValue: Double(cameraRuntime.currentManualFocusPosition),
                dialStep: 0.01,
                leftLabel: "远",
                centerLabel: "中",
                rightLabel: "近"
            )
        case .whiteBalance:
            let wbMode: CaptureProfessionalParameterMode
            let supportsWhiteBalanceControl = cameraRuntime.isWhiteBalancePresetSupported || isSimulatorCameraParameterFallbackEnabled
            let supportsWhiteBalanceAuto = cameraRuntime.isWhiteBalanceAutoSupported || isSimulatorCameraParameterFallbackEnabled
            if !supportsWhiteBalanceAuto && !supportsWhiteBalanceControl {
                wbMode = .disabled
            } else if pendingWhiteBalanceWheelValue != nil {
                wbMode = .manual
            } else if cameraRuntime.selectedWhiteBalancePreset == .auto {
                wbMode = .auto
            } else {
                wbMode = .manual
            }
            return CaptureProfessionalParameterState(
                kind: .whiteBalance,
                valueText: whiteBalanceEntryValueText(mode: wbMode),
                mode: wbMode,
                isAdjustable: supportsWhiteBalanceControl,
                canUseAuto: supportsWhiteBalanceAuto
                    && (cameraRuntime.selectedWhiteBalancePreset != .auto || pendingWhiteBalanceWheelValue != nil),
                canReset: supportsWhiteBalanceAuto
                    && (cameraRuntime.selectedWhiteBalancePreset != .auto || pendingWhiteBalanceWheelValue != nil),
                hintText: whiteBalanceHintText(
                    for: wbMode,
                    isPresetAdjustable: supportsWhiteBalanceControl
                ),
                dialRange: cameraRuntime.whiteBalanceDialRange,
                dialValue: cameraRuntime.whiteBalanceDialValue,
                dialStep: cameraRuntime.whiteBalanceDialStepValue,
                leftLabel: "2800K",
                centerLabel: "5000K",
                rightLabel: "7500K"
            )
        case .tint:
            let tintMode: CaptureProfessionalParameterMode
            if !cameraRuntime.isWhiteBalanceAutoSupported && !cameraRuntime.isWhiteBalancePresetSupported {
                tintMode = .disabled
            } else if cameraRuntime.isFocusExposureLocked || cameraRuntime.isExposureLocked {
                tintMode = .locked
            } else {
                tintMode = .manual
            }
            return CaptureProfessionalParameterState(
                kind: .tint,
                valueText: tintEntryValueText(mode: tintMode),
                mode: tintMode,
                isAdjustable: cameraRuntime.isWhiteBalancePresetSupported
                    && !cameraRuntime.isFocusExposureLocked
                    && !cameraRuntime.isExposureLocked,
                canUseAuto: false,
                canReset: cameraRuntime.isWhiteBalancePresetSupported
                    && !cameraRuntime.isFocusExposureLocked
                    && !cameraRuntime.isExposureLocked,
                hintText: tintHintText(for: tintMode),
                dialRange: cameraRuntime.whiteBalanceTintDialRange,
                dialValue: cameraRuntime.whiteBalanceTintDialValue,
                dialStep: cameraRuntime.whiteBalanceTintDialStepValue,
                leftLabel: "G",
                centerLabel: "A",
                rightLabel: "M"
            )
        case .iso:
            let isoMode: CaptureProfessionalParameterMode
            if cameraRuntime.isFocusExposureLocked || cameraRuntime.isExposureLocked {
                isoMode = .locked
            } else if !cameraRuntime.isISOAutoSupported && !cameraRuntime.isISOPresetSupported {
                isoMode = .disabled
            } else if pendingISOWheelValue != nil {
                isoMode = .manual
            } else if cameraRuntime.selectedISOPreset == .auto {
                isoMode = .auto
            } else {
                isoMode = .manual
            }
            return CaptureProfessionalParameterState(
                kind: .iso,
                valueText: isoEntryValueText(mode: isoMode),
                mode: isoMode,
                isAdjustable: cameraRuntime.isISOPresetSupported
                    && !cameraRuntime.isFocusExposureLocked
                    && !cameraRuntime.isExposureLocked,
                canUseAuto: cameraRuntime.isISOAutoSupported
                    && (cameraRuntime.selectedISOPreset != .auto || pendingISOWheelValue != nil)
                    && !cameraRuntime.isFocusExposureLocked
                    && !cameraRuntime.isExposureLocked,
                canReset: cameraRuntime.isISOAutoSupported
                    && (cameraRuntime.selectedISOPreset != .auto || pendingISOWheelValue != nil)
                    && !cameraRuntime.isFocusExposureLocked
                    && !cameraRuntime.isExposureLocked,
                hintText: isoHintText(
                    for: isoMode,
                    isPresetAdjustable: cameraRuntime.isISOPresetSupported,
                    blockedByExposureLock: cameraRuntime.isFocusExposureLocked || cameraRuntime.isExposureLocked
                ),
                dialRange: cameraRuntime.isoDialRange,
                dialValue: cameraRuntime.isoDialValue,
                dialStep: cameraRuntime.isoDialStepValue,
                leftLabel: cameraRuntime.isoLeftLabel,
                centerLabel: cameraRuntime.isoCenterLabel,
                rightLabel: cameraRuntime.isoRightLabel
            )
        case .shutter:
            let shutterMode: CaptureProfessionalParameterMode
            if cameraRuntime.isFocusExposureLocked || cameraRuntime.isExposureLocked {
                shutterMode = .locked
            } else if !cameraRuntime.isShutterAutoSupported && !cameraRuntime.isShutterPresetSupported {
                shutterMode = .disabled
            } else if pendingShutterWheelDurationSeconds != nil {
                shutterMode = .manual
            } else if cameraRuntime.selectedShutterPreset == .auto {
                shutterMode = .auto
            } else {
                shutterMode = .manual
            }
            return CaptureProfessionalParameterState(
                kind: .shutter,
                valueText: shutterEntryValueText(mode: shutterMode),
                mode: shutterMode,
                isAdjustable: cameraRuntime.isShutterPresetSupported
                    && !cameraRuntime.isFocusExposureLocked
                    && !cameraRuntime.isExposureLocked,
                canUseAuto: cameraRuntime.isShutterAutoSupported
                    && (cameraRuntime.selectedShutterPreset != .auto || pendingShutterWheelDurationSeconds != nil)
                    && !cameraRuntime.isFocusExposureLocked
                    && !cameraRuntime.isExposureLocked,
                canReset: cameraRuntime.isShutterAutoSupported
                    && (cameraRuntime.selectedShutterPreset != .auto || pendingShutterWheelDurationSeconds != nil)
                    && !cameraRuntime.isFocusExposureLocked
                    && !cameraRuntime.isExposureLocked,
                hintText: shutterHintText(
                    for: shutterMode,
                    isPresetAdjustable: cameraRuntime.isShutterPresetSupported,
                    blockedByExposureLock: cameraRuntime.isFocusExposureLocked || cameraRuntime.isExposureLocked
                ),
                dialRange: cameraRuntime.shutterDialRange,
                dialValue: cameraRuntime.shutterDialValue,
                dialStep: cameraRuntime.shutterDialStepValue,
                leftLabel: cameraRuntime.shutterLeftLabel,
                centerLabel: cameraRuntime.shutterCenterLabel,
                rightLabel: cameraRuntime.shutterRightLabel
            )
        case .exposureCompensation:
            let isLocked = cameraRuntime.isFocusExposureLocked || cameraRuntime.isExposureLocked
            let isManualExposureLimited = isExposureCompensationLimitedByManualExposure
            let mode: CaptureProfessionalParameterMode
            if isLocked {
                mode = .locked
            } else if !cameraRuntime.isExposureBiasSupported {
                mode = .disabled
            } else if isManualExposureLimited {
                mode = .locked
            } else if pendingExposureBiasWheelValue != nil {
                mode = .manual
            } else if cameraRuntime.isExposureBiasAutoMode {
                mode = .auto
            } else {
                mode = .manual
            }
            return CaptureProfessionalParameterState(
                kind: .exposureCompensation,
                valueText: exposureEntryValueText(mode: mode),
                mode: mode,
                isAdjustable: cameraRuntime.isExposureBiasSupported && !isLocked && !isManualExposureLimited,
                canUseAuto: cameraRuntime.isExposureBiasSupported
                    && !isLocked
                    && !isManualExposureLimited
                    && !cameraRuntime.isExposureBiasAutoMode,
                canReset: cameraRuntime.isExposureBiasSupported && !isLocked && !isManualExposureLimited,
                hintText: exposureCompensationHintText(
                    for: mode,
                    isLocked: isLocked,
                    isManualExposureLimited: isManualExposureLimited
                ),
                dialRange: Double(cameraRuntime.minimumExposureBias)...Double(cameraRuntime.maximumExposureBias),
                dialValue: Double(cameraRuntime.currentExposureBias),
                dialStep: 0.05,
                leftLabel: exposureBoundLabel(cameraRuntime.minimumExposureBias),
                centerLabel: "0.00",
                rightLabel: exposureBoundLabel(cameraRuntime.maximumExposureBias)
            )
        case .ratio:
            let maxIndex = max(0, CapturePhotoAspectRatioPreset.allCases.count - 1)
            return CaptureProfessionalParameterState(
                kind: .ratio,
                valueText: cameraRuntime.aspectRatioDisplayText,
                mode: .manual,
                isAdjustable: true,
                canUseAuto: false,
                canReset: cameraRuntime.selectedAspectRatioPreset != .ratio3x4,
                hintText: "切换拍摄比例，预览与拍照结果按所选比例一致输出。",
                dialRange: 0...Double(maxIndex),
                dialValue: cameraRuntime.aspectRatioDialValue,
                dialStep: 1,
                leftLabel: "1:1",
                centerLabel: "3:4",
                rightLabel: "16:9"
            )
        case .pixel:
            let maxIndex = max(0, CapturePhotoPixelPreset.allCases.count - 1)
            return CaptureProfessionalParameterState(
                kind: .pixel,
                valueText: cameraRuntime.pixelDisplayText,
                mode: .manual,
                isAdjustable: true,
                canUseAuto: false,
                canReset: cameraRuntime.selectedPixelPreset != .p1600,
                hintText: cameraRuntime.isRAWCaptureSupported
                    ? "切换输出像素档位；最佳不做固定长边压缩，RAW 入口已按设备能力开放。"
                    : "切换输出像素档位；最佳不做固定长边压缩，当前设备不支持 RAW。",
                dialRange: 0...Double(maxIndex),
                dialValue: cameraRuntime.pixelDialValue,
                dialStep: 1,
                leftLabel: "最佳",
                centerLabel: "1600",
                rightLabel: "RAW"
            )
        case .settings:
            return CaptureProfessionalParameterState(
                kind: .settings,
                valueText: "更多控制",
                mode: .pending,
                isAdjustable: false,
                canUseAuto: false,
                canReset: false,
                hintText: "保留设置入口挂点，本轮不扩完整设置中心。",
                dialRange: 0...1,
                dialValue: 0,
                dialStep: 1,
                leftLabel: "轻量",
                centerLabel: "待接入",
                rightLabel: "更多"
            )
        }
    }

    private func exposureBoundLabel(_ value: Float) -> String {
        String(format: "%+.2f", value)
    }

    private func focusEntryValueText(mode: CaptureProfessionalParameterMode) -> String {
        switch mode {
        case .auto:
            return "Auto"
        case .manual:
            return "MF \(cameraRuntime.manualFocusDisplayText)"
        case .locked:
            return "LOCK"
        case .disabled:
            return "Unavailable"
        case .pending:
            return "Pending"
        }
    }

    private func exposureEntryValueText(mode: CaptureProfessionalParameterMode) -> String {
        switch mode {
        case .auto:
            return cameraRuntime.productAutoExposureDisplayText
        case .manual:
            return cameraRuntime.exposureBiasDisplayText
        case .locked:
            return "Locked"
        case .disabled:
            return "Unavailable"
        case .pending:
            return "Pending"
        }
    }

    private func whiteBalanceEntryValueText(mode: CaptureProfessionalParameterMode) -> String {
        switch mode {
        case .auto:
            return "A \(formattedWhiteBalanceTick(Double(cameraRuntime.currentWhiteBalanceTemperature)))"
        case .manual:
            return cameraRuntime.whiteBalanceDisplayText
        case .locked:
            return "Locked"
        case .disabled:
            return "Unavailable"
        case .pending:
            return "Pending"
        }
    }

    private func isoEntryValueText(mode: CaptureProfessionalParameterMode) -> String {
        switch mode {
        case .auto:
            let value = Int(cameraRuntime.currentISOValue.rounded())
            return value > 0 ? "A \(value)" : "A"
        case .manual:
            return "\(Int(cameraRuntime.currentManualISOValue.rounded()))"
        case .locked:
            return "Locked"
        case .disabled:
            return "Unavailable"
        case .pending:
            return "Pending"
        }
    }

    private func shutterEntryValueText(mode: CaptureProfessionalParameterMode) -> String {
        switch mode {
        case .auto:
            if let text = formattedShutterDisplayText(seconds: cameraRuntime.currentShutterDurationSeconds) {
                return "A \(text)"
            }
            return "A"
        case .manual:
            return formattedShutterDisplayText(seconds: cameraRuntime.currentManualShutterDurationSeconds) ?? "Manual"
        case .locked:
            return "Locked"
        case .disabled:
            return "Unavailable"
        case .pending:
            return "Pending"
        }
    }

    private func tintEntryValueText(mode: CaptureProfessionalParameterMode) -> String {
        switch mode {
        case .auto:
            return formattedTintDisplayText(Double(cameraRuntime.currentWhiteBalanceTint))
        case .manual:
            return formattedTintDisplayText(Double(cameraRuntime.currentWhiteBalanceTint))
        case .locked:
            return "Locked"
        case .disabled:
            return "Unavailable"
        case .pending:
            return "Pending"
        }
    }

    private func formattedShutterDisplayText(seconds: Double) -> String? {
        guard seconds.isFinite, seconds > 0 else { return nil }
        if seconds >= 1 {
            return String(format: "%.1fs", seconds)
        }
        let reciprocal = 1.0 / seconds
        guard reciprocal.isFinite, reciprocal > 0 else { return nil }
        return "1/\(Int(reciprocal.rounded()))"
    }

    private func focusHintText(for mode: CaptureProfessionalParameterMode) -> String {
        switch mode {
        case .locked:
            return "当前为 AE/AF 锁定，需先解锁后再切 MF。"
        case .manual:
            if cameraRuntime.isExposureLocked {
                return "当前为 MF + AE-L，拖动刻度轮可连续微调对焦。"
            }
            return "当前为 MF，拖动刻度轮可连续微调对焦。"
        case .disabled:
            return "当前镜头不支持 MF，保留 AF 点击对焦。"
        case .auto:
            return "当前为 AF，拖动刻度轮可进入 MF 细调。"
        case .pending:
            return "当前参数待接入。"
        }
    }

    private func tintHintText(for mode: CaptureProfessionalParameterMode) -> String {
        switch mode {
        case .auto:
            return "当前色偏值为 0，可拖动进入手动绿/品红修正。"
        case .manual:
            return "当前手动 TINT 已生效，可继续细调或点 RESET 回 0。"
        case .locked:
            return "当前色偏调节已锁定。"
        case .disabled:
            return "当前镜头不支持色偏调节。"
        case .pending:
            return "当前参数待接入。"
        }
    }

    private func whiteBalanceHintText(
        for mode: CaptureProfessionalParameterMode,
        isPresetAdjustable: Bool
    ) -> String {
        switch mode {
        case .auto:
            guard isPresetAdjustable else {
                return "当前镜头仅支持自动白平衡。"
            }
            return "当前为自动白平衡，可拖动温度刻度进入手动细调。"
        case .manual:
            return "当前手动白平衡已生效，可细调到更稳定的商品色温。"
        case .disabled:
            return "当前镜头不支持白平衡调节，已自动降级。"
        case .pending:
            return "当前参数待接入。"
        case .locked:
            return "当前状态锁定。"
        }
    }

    private func exposureCompensationHintText(
        for mode: CaptureProfessionalParameterMode,
        isLocked: Bool,
        isManualExposureLimited: Bool
    ) -> String {
        switch mode {
        case .auto:
            return "商品 Auto 会根据预览亮度轻量优化 EV，拖动后进入手动接管。"
        case .manual:
            return "当前 EV 补偿已生效，可继续细调或快速恢复 Auto(0.00)。"
        case .locked:
            if isManualExposureLimited {
                return exposureCompensationLimitedReasonText
            }
            if isLocked {
                return "当前锁定态生效，先关闭 AE-L / AEAF-L 再调 EV。"
            }
            return "当前锁定态生效。"
        case .disabled:
            return "当前镜头不支持 EV 调节，已自动降级。"
        case .pending:
            return "当前参数待接入。"
        }
    }

    private func isoHintText(
        for mode: CaptureProfessionalParameterMode,
        isPresetAdjustable: Bool,
        blockedByExposureLock: Bool
    ) -> String {
        switch mode {
        case .auto:
            guard isPresetAdjustable else {
                return "当前镜头仅支持 ISO Auto。"
            }
            return "当前为 ISO 自动，拖动刻度可进入手动细调并稳定噪点。"
        case .manual:
            return "当前手动 ISO 已生效，可连续微调同批商品亮度与噪点一致性。"
        case .locked:
            if blockedByExposureLock {
                return "当前为锁定态，先关闭 AE-L / AEAF-L 后再调 ISO。"
            }
            return "当前为锁定态，先关闭 AE-L / AEAF-L 后再调 ISO。"
        case .disabled:
            return "当前镜头不支持固定 ISO，已自动降级。"
        case .pending:
            return "当前参数待接入。"
        }
    }

    private func shutterHintText(
        for mode: CaptureProfessionalParameterMode,
        isPresetAdjustable: Bool,
        blockedByExposureLock: Bool
    ) -> String {
        switch mode {
        case .auto:
            guard isPresetAdjustable else {
                return "当前镜头仅支持快门 Auto。"
            }
            return "当前为快门自动，拖动刻度可进入手动细调控制清晰度与稳定性。"
        case .manual:
            return "当前手动快门已生效，可连续微调固定机位与布光下的输出一致性。"
        case .locked:
            if blockedByExposureLock {
                return "当前为锁定态，先关闭 AE-L / AEAF-L 后再调快门。"
            }
            return "当前为锁定态，先关闭 AE-L / AEAF-L 后再调快门。"
        case .disabled:
            return "当前镜头不支持手动快门，已自动降级。"
        case .pending:
            return "当前参数待接入。"
        }
    }

}

private struct CaptureBottomActionBar: View {
    let latestResult: CaptureStillPhotoResult?
    let onTapLatestResult: () -> Void
    let onShutterTap: () -> Void
    let onTapGalleryPlaceholder: () -> Void

    var body: some View {
        HStack {
            CaptureBottomLatestResultButton(
                latestResult: latestResult,
                onTap: onTapLatestResult
            )

            Spacer(minLength: 14)

            Button(action: onShutterTap) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.95))
                        .frame(width: 70, height: 70)
                    Circle()
                        .stroke(.black.opacity(0.25), lineWidth: 2.4)
                        .frame(width: 56, height: 56)
                    Circle()
                        .stroke(.white.opacity(0.24), lineWidth: 1)
                        .frame(width: 80, height: 80)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Shutter")
            .contentShape(Circle())
            .frame(width: 86, height: 86)

            Spacer(minLength: 14)

            Button(action: onTapGalleryPlaceholder) {
                sideControlCard(
                    symbol: "rectangle.stack",
                    title: "图册"
                )
            }
            .buttonStyle(.plain)
        }
        .frame(height: 86)
    }

    private func sideControlCard(symbol: String, title: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
            Text(title)
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .foregroundStyle(.white.opacity(0.92))
        .frame(width: 64, height: 58)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
    }
}

private struct CaptureBottomLatestResultButton: View {
    let latestResult: CaptureStillPhotoResult?
    let onTap: () -> Void

    @State private var previewImage: UIImage?

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Group {
                    if let previewImage {
                        Image(uiImage: previewImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 30, height: 30)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    } else {
                        Image(systemName: latestResult == nil ? "photo" : "photo.fill")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
                Text(latestResult == nil ? "最近" : "最新")
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(.white.opacity(latestResult == nil ? 0.72 : 0.92))
            .frame(width: 64, height: 58)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(latestResult == nil)
        .task(id: latestResult?.id) {
            await refreshPreview()
        }
    }

    @MainActor
    private func refreshPreview() async {
        guard let latestResult else {
            previewImage = nil
            return
        }
        let imageData = latestResult.imageData
        let decoded = await Task.detached(priority: .userInitiated) {
            UIImage(data: imageData)
        }.value
        guard latestResult.id == self.latestResult?.id else { return }
        previewImage = decoded
    }
}

struct CaptureScreen_Previews: PreviewProvider {
    static var previews: some View {
        CaptureScreen()
    }
}

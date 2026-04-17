//
//  CaptureScreen.swift
//  SellerCamera
//
//  Created by Codex on 2026/3/30.
//

import AVFoundation
import PhotosUI
import SwiftUI

struct CaptureScreen: View {
    @StateObject private var cameraRuntime = CaptureCameraRuntime()
    @State private var isLatestReviewPresented = false
    @State private var isImportPickerPresented = false
    @State private var selectedImportPhotoItem: PhotosPickerItem?
    @State private var isImportingPhoto = false
    @State private var selectedCaptureIntent: CaptureIntentKind = .standard
    @State private var activeControlTarget: CaptureActiveControlTarget = .none

    private var isParameterControlPresented: Bool {
        if case .parameter = activeControlTarget {
            return true
        }
        return false
    }

    private var isLensZoomControlPresented: Bool {
        if case .lensZoom = activeControlTarget {
            return true
        }
        return false
    }

    private var isAnyFloatingControlPresented: Bool {
        isParameterControlPresented || isLensZoomControlPresented
    }

    private var activeProfessionalParameter: CaptureProfessionalParameterKind? {
        if case let .parameter(kind) = activeControlTarget {
            return kind
        }
        return nil
    }

    private var primaryParameterKinds: [CaptureProfessionalParameterKind] {
        [.focus, .exposureCompensation, .whiteBalance, .iso, .shutter]
    }

    private var primaryParameterStates: [CaptureProfessionalParameterState] {
        primaryParameterKinds.map(parameterState(for:))
    }

    private var activeParameterPanelState: CaptureProfessionalParameterState? {
        guard let activeProfessionalParameter else { return nil }
        return parameterState(for: activeProfessionalParameter)
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
                    onSelectAspectRatio: selectAspectRatioPreset,
                    onSelectPixel: selectPixelPreset,
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
                    }
                )
                .padding(.horizontal, 14)
                .padding(.top, 6)
                .padding(.bottom, 6)
                .opacity(isAnyFloatingControlPresented ? 0.86 : 1)
                .animation(.easeInOut(duration: 0.18), value: isAnyFloatingControlPresented)

                CapturePreviewContainer(
                    cameraRuntime: cameraRuntime,
                    selectedAspectRatioPreset: cameraRuntime.selectedAspectRatioPreset,
                    captureHintText: cameraRuntime.captureHintText,
                    isAnyFloatingControlPresented: isAnyFloatingControlPresented,
                    activeControlTarget: $activeControlTarget
                )
                .frame(maxHeight: .infinity)
                .padding(.top, 0)

                CaptureIntentSwitcherView(selectedIntent: $selectedCaptureIntent)
                    .padding(.horizontal, 14)
                    .padding(.top, 2)
                    .padding(.bottom, 6)
                    .opacity(isAnyFloatingControlPresented ? 0.6 : 1)
                    .animation(.easeInOut(duration: 0.18), value: isAnyFloatingControlPresented)

                CaptureProfessionalParameterEntryBar(
                    states: primaryParameterStates,
                    activeKind: activeProfessionalParameter,
                    onSelect: { kind in
                        if activeProfessionalParameter == kind {
                            activeControlTarget = .none
                        } else {
                            activeControlTarget = .parameter(kind)
                        }
                    }
                )
                .padding(.horizontal, 14)
                .padding(.top, 2)
                .padding(.bottom, 0)

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
                .padding(.top, 4)
                .padding(.bottom, 14)
            }

            if let panelState = activeParameterPanelState {
                CaptureFloatingParameterOverlay(
                    state: panelState,
                    onClose: {
                        activeControlTarget = .none
                    },
                    onAuto: {
                        handlePanelAuto(parameter: panelState.kind)
                    },
                    onReset: {
                        handlePanelReset(parameter: panelState.kind)
                    },
                    onDialChange: { newValue in
                        handlePanelDialChange(parameter: panelState.kind, value: newValue)
                    },
                    onDismissByBackgroundTap: {
                        activeControlTarget = .none
                    }
                )
                .zIndex(3)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if isLensZoomControlPresented {
                CaptureFloatingLensZoomOverlay(
                    cameraRuntime: cameraRuntime,
                    onClose: {
                        activeControlTarget = .none
                    }
                )
                .zIndex(2)
                .transition(.move(edge: .bottom).combined(with: .opacity))
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
        .animation(.easeInOut(duration: 0.2), value: activeProfessionalParameter)
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
        cameraRuntime.setAspectRatioDialValue(Double(index))
    }

    private func selectPixelPreset(_ preset: CapturePhotoPixelPreset) {
        let allPresets = CapturePhotoPixelPreset.allCases
        guard let index = allPresets.firstIndex(of: preset) else { return }
        cameraRuntime.setPixelDialValue(Double(index))
    }
}

private struct CaptureLensZoomControlPanel: View {
    @ObservedObject var cameraRuntime: CaptureCameraRuntime
    let onFocusDial: () -> Void

    private var panelTitle: String {
        "\(cameraRuntime.selectedLensDisplayText) · 镜内缩放"
    }

    private var currentValueText: String {
        String(format: "%.1fx", cameraRuntime.lensZoomDialValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(panelTitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer(minLength: 8)
                Text(currentValueText)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.94))
                    .monospacedDigit()
            }

            CaptureZoomDialView(
                range: cameraRuntime.lensZoomDialRange,
                value: cameraRuntime.lensZoomDialValue,
                isEnabled: true,
                onChange: { newValue in
                    onFocusDial()
                    cameraRuntime.setLensZoomDialValue(newValue)
                }
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
    }
}

private enum CaptureActiveControlTarget: Equatable {
    case none
    case lensZoom
    case parameter(CaptureProfessionalParameterKind)
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
    let onSelectAspectRatio: (CapturePhotoAspectRatioPreset) -> Void
    let onSelectPixel: (CapturePhotoPixelPreset) -> Void
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

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 5) {
                Button(action: onTapFlash) {
                    topToolButtonContent(
                        symbol: flashMode.symbolName,
                        text: flashMode.shortText,
                        enabled: isFlashModeSupported
                    )
                }
                .buttonStyle(.plain)
                .disabled(!isFlashModeSupported)

                Button(action: onToggleExposureLock) {
                    topToolButtonContent(
                        symbol: isExposureLocked ? "lock.fill" : "lock.open",
                        text: isExposureLocked ? "AE-L 开" : "AE-L 关",
                        enabled: isExposureLockSupported
                    )
                }
                .buttonStyle(.plain)
                .disabled(!isExposureLockSupported)

                Spacer(minLength: 0)

                Menu {
                    Section("拍摄比例") {
                        ForEach(CapturePhotoAspectRatioPreset.allCases, id: \.self) { preset in
                            Button {
                                onSelectAspectRatio(preset)
                            } label: {
                                if preset == selectedAspectRatioPreset {
                                    Label(preset.displayText, systemImage: "checkmark")
                                } else {
                                    Text(preset.displayText)
                                }
                            }
                        }
                    }

                    Section("输出像素") {
                        ForEach(CapturePhotoPixelPreset.allCases, id: \.self) { preset in
                            let text = preset.displayText(for: selectedAspectRatioPreset.ratioValue)
                            Button {
                                onSelectPixel(preset)
                            } label: {
                                if preset == selectedPixelPreset {
                                    Label(text, systemImage: "checkmark")
                                } else {
                                    Text(text)
                                }
                            }
                        }
                    }
                } label: {
                    topToolButtonContent(
                        symbol: "rectangle.on.rectangle.angled",
                        text: "\(selectedAspectRatioPreset.displayText)·\(pixelCompactText(for: selectedPixelPreset))",
                        enabled: true,
                        showsSymbol: false
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

                Menu {
                    Section("拍摄辅助") {
                        Button {
                            onToggleGrid()
                        } label: {
                            Label(isGridEnabled ? "关闭网格" : "开启网格", systemImage: "square.grid.3x3")
                        }

                        Button {
                            onToggleLevelIndicator()
                        } label: {
                            Label(isLevelIndicatorEnabled ? "关闭水平仪" : "开启水平仪", systemImage: "level")
                        }

                        Button {
                            onCycleTimerOption()
                        } label: {
                            Label("定时：\(selectedTimerOption.displayText)", systemImage: "timer")
                        }

                        Button {
                            onCycleBurstOption()
                        } label: {
                            Label("连拍：\(selectedBurstOption.displayText)", systemImage: "square.stack.3d.up.fill")
                        }
                    }

                    Divider()

                    Button {
                        onTapImport()
                    } label: {
                        Label(isImportingPhoto ? "导入中…" : "导入单张图片", systemImage: "photo.on.rectangle.angled")
                    }
                    .disabled(isImportingPhoto)
                } label: {
                    topToolButtonContent(
                        symbol: "ellipsis.circle",
                        text: "更多",
                        enabled: true
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
        showsSymbol: Bool = true
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
        .foregroundStyle(.white.opacity(enabled ? 0.94 : 0.54))
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(.white.opacity(enabled ? 0.1 : 0.07), in: Capsule())
        .overlay(
            Capsule()
                .stroke(.white.opacity(enabled ? 0.12 : 0.08), lineWidth: 1)
        )
    }

    private func pixelCompactText(for preset: CapturePhotoPixelPreset) -> String {
        switch preset {
        case .p800:
            return "0.8K"
        case .p1200:
            return "1.2K"
        case .p1600:
            return "1.6K"
        case .p2400:
            return "2.4K"
        }
    }
}

private struct CapturePreviewContainer: View {
    @ObservedObject var cameraRuntime: CaptureCameraRuntime
    let selectedAspectRatioPreset: CapturePhotoAspectRatioPreset
    let captureHintText: String
    let isAnyFloatingControlPresented: Bool
    @Binding var activeControlTarget: CaptureActiveControlTarget
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
            let nonPersistentHint = isLensSwitchHint(captureHintText) ? "" : captureHintText
            let displayHintText = transientLensFeedback ?? nonPersistentHint

            ZStack {
                CaptureLivePreviewView(cameraRuntime: cameraRuntime)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        CaptureRuntimeBadge(
                            exposureText: "EV \(cameraRuntime.exposureBiasDisplayText)",
                            lockText: (cameraRuntime.isFocusExposureLocked || cameraRuntime.isExposureLocked)
                                ? cameraRuntime.lockStatusBadgeText
                                : nil
                        )
                        .padding(10)
                    }

                CaptureWorkspaceMaskOverlay(
                    workspaceRect: workspaceRect,
                    outsideFillColor: Color(red: 0.03, green: 0.04, blue: 0.06)
                )
                    .allowsHitTesting(false)

                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
                    .frame(width: workspaceRect.width, height: workspaceRect.height)
                    .position(x: workspaceRect.midX, y: workspaceRect.midY)
                    .allowsHitTesting(false)

                CaptureLensControlStrip(
                    cameraRuntime: cameraRuntime,
                    activeControlTarget: $activeControlTarget
                )
                .frame(width: max(164, min(workspaceRect.width - 20, safeWidth - 14)))
                .position(
                    x: workspaceRect.midX,
                    y: lensY
                )

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

    private var availableCapabilities: [CaptureSemanticFocalCapability] {
        cameraRuntime.availableSemanticFocalCapabilities
    }

    var body: some View {
        HStack(spacing: 8) {
            if availableCapabilities.isEmpty {
                Text(cameraRuntime.activeCameraPosition == .front ? "前置镜头" : "当前机型无可用镜头焦段")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.66))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.white.opacity(0.06), in: Capsule())
            } else {
                ForEach(availableCapabilities) { capability in
                    let focal = capability.focal
                    let isSelected = cameraRuntime.selectedSemanticFocal == focal

                    Button {
                        if isSelected {
                            activeControlTarget = activeControlTarget == .lensZoom ? .none : .lensZoom
                        } else {
                            cameraRuntime.selectSemanticFocal(focal)
                            activeControlTarget = .none
                        }
                    } label: {
                        Text(focal.displayText)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(isSelected ? 0.96 : 0.8))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .frame(minWidth: 62)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(
                                        isSelected
                                            ? Color.teal.opacity(0.2)
                                            : Color.white.opacity(0.07)
                                    )
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(
                                        isSelected
                                            ? Color.teal.opacity(0.52)
                                            : Color.white.opacity(0.12),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct CaptureFloatingLensZoomOverlay: View {
    @ObservedObject var cameraRuntime: CaptureCameraRuntime
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.16)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onClose)

            CaptureLensZoomControlPanel(
                cameraRuntime: cameraRuntime,
                onFocusDial: {}
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 18)
        }
    }
}

private struct CaptureZoomDialView: View {
    let range: ClosedRange<Double>
    let value: Double
    let isEnabled: Bool
    let onChange: (Double) -> Void

    private var clampedValue: Double {
        max(range.lowerBound, min(range.upperBound, value))
    }

    private var currentProgress: Double {
        progressForValue(clampedValue)
    }

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geometry in
                let width = max(1, geometry.size.width)
                let indicatorX = width * currentProgress
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(isEnabled ? 0.08 : 0.05))

                    HStack(spacing: 0) {
                        ForEach(0...24, id: \.self) { tick in
                            let isMajor = tick % 6 == 0
                            Rectangle()
                                .fill(.white.opacity(isEnabled ? (isMajor ? 0.38 : 0.18) : 0.12))
                                .frame(width: 1, height: isMajor ? 16 : 10)
                            if tick < 24 {
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .padding(.horizontal, 12)

                    Capsule()
                        .fill(Color.teal.opacity(isEnabled ? 0.22 : 0.12))
                        .frame(width: max(14, indicatorX))

                    Circle()
                        .fill(.white.opacity(isEnabled ? 0.96 : 0.7))
                        .overlay(
                            Circle()
                                .stroke(.black.opacity(0.2), lineWidth: 1)
                        )
                        .frame(width: 22, height: 22)
                        .offset(x: max(0, min(width - 22, indicatorX - 11)))
                }
                .frame(height: 34)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            guard isEnabled else { return }
                            let localX = max(0, min(width, gesture.location.x))
                            let progress = localX / width
                            let rawValue = valueForProgress(progress)
                            let nextValue = softlySnappedValue(rawValue)
                            onChange(nextValue)
                        }
                )
            }
            .frame(height: 34)

            HStack {
                Text("\(formatMultiplier(range.lowerBound))")
                Spacer(minLength: 8)
                Text("镜内 \(formatMultiplier(clampedValue))")
                    .foregroundStyle(.white.opacity(isEnabled ? 0.9 : 0.58))
                Spacer(minLength: 8)
                Text("\(formatMultiplier(range.upperBound))")
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white.opacity(0.68))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(isEnabled ? 0.08 : 0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(isEnabled ? 0.14 : 0.08), lineWidth: 1)
        )
    }

    private func progressForValue(_ dialValue: Double) -> Double {
        let lower = max(0.0001, range.lowerBound)
        let upper = max(lower + 0.0001, range.upperBound)
        guard upper > lower else { return 0 }
        let safeValue = max(lower, min(upper, dialValue))
        let lowerLog = log(lower)
        let upperLog = log(upper)
        guard upperLog > lowerLog else {
            return max(0, min(1, (safeValue - lower) / (upper - lower)))
        }
        return max(0, min(1, (log(safeValue) - lowerLog) / (upperLog - lowerLog)))
    }

    private func valueForProgress(_ progress: Double) -> Double {
        let clampedProgress = max(0, min(1, progress))
        let lower = max(0.0001, range.lowerBound)
        let upper = max(lower + 0.0001, range.upperBound)
        guard upper > lower else { return lower }
        let lowerLog = log(lower)
        let upperLog = log(upper)
        guard upperLog > lowerLog else {
            return lower + clampedProgress * (upper - lower)
        }
        let raw = exp(lowerLog + clampedProgress * (upperLog - lowerLog))
        return max(lower, min(upper, raw))
    }

    private var anchorValues: [Double] {
        let anchors: [Double] = [1.0, 1.2, 1.5, 2.0, 3.0, 4.0, 5.0, 6.0]
        return anchors.filter { $0 >= range.lowerBound && $0 <= range.upperBound + 0.0001 }
    }

    private func softlySnappedValue(_ raw: Double) -> Double {
        guard let nearestAnchor = anchorValues.min(by: { abs($0 - raw) < abs($1 - raw) }) else {
            return raw
        }
        let span = max(0.0001, range.upperBound - range.lowerBound)
        // 范围越大时控制吸附窗口上限，避免长尾区间出现“粘滞感”。
        let snapWindow = max(0.02, min(0.12, span * 0.01))
        let distance = abs(nearestAnchor - raw)
        guard distance <= snapWindow else { return raw }
        let weight = (1 - distance / snapWindow) * 0.7
        let blended = raw * (1 - weight) + nearestAnchor * weight
        return max(range.lowerBound, min(range.upperBound, blended))
    }

    private func formatMultiplier(_ multiplier: Double) -> String {
        String(format: "%.1fx", multiplier)
    }
}

private struct CaptureRuntimeBadge: View {
    let exposureText: String
    let lockText: String?

    var body: some View {
        HStack(spacing: 6) {
            badgeItem(symbol: "sun.max.fill", text: exposureText)
            if let lockText {
                badgeItem(symbol: "viewfinder", text: lockText)
            }
        }
    }

    private func badgeItem(symbol: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
            Text(text)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.white.opacity(0.88))
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(.black.opacity(0.4), in: Capsule())
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
                panelStyle: .dial,
                valueText: focusEntryValueText(mode: mode),
                mode: mode,
                isAdjustable: cameraRuntime.isManualFocusSupported && !cameraRuntime.isFocusExposureLocked,
                canUseAuto: cameraRuntime.focusControlMode == .manual && !cameraRuntime.isFocusExposureLocked,
                canReset: cameraRuntime.isManualFocusSupported && !cameraRuntime.isFocusExposureLocked,
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
            if !cameraRuntime.isWhiteBalanceAutoSupported && !cameraRuntime.isWhiteBalancePresetSupported {
                wbMode = .disabled
            } else if cameraRuntime.selectedWhiteBalancePreset == .auto {
                wbMode = .auto
            } else {
                wbMode = .manual
            }
            return CaptureProfessionalParameterState(
                kind: .whiteBalance,
                panelStyle: .linear,
                valueText: whiteBalanceEntryValueText(mode: wbMode),
                mode: wbMode,
                isAdjustable: cameraRuntime.isWhiteBalancePresetSupported,
                canUseAuto: cameraRuntime.isWhiteBalanceAutoSupported
                    && cameraRuntime.selectedWhiteBalancePreset != .auto,
                canReset: cameraRuntime.isWhiteBalanceAutoSupported
                    && cameraRuntime.selectedWhiteBalancePreset != .auto,
                hintText: whiteBalanceHintText(
                    for: wbMode,
                    isPresetAdjustable: cameraRuntime.isWhiteBalancePresetSupported
                ),
                dialRange: cameraRuntime.whiteBalanceDialRange,
                dialValue: cameraRuntime.whiteBalanceDialValue,
                dialStep: cameraRuntime.whiteBalanceDialStepValue,
                leftLabel: "2800K",
                centerLabel: "5000K",
                rightLabel: "7500K"
            )
        case .iso:
            let isoBlockedByShutter = cameraRuntime.selectedShutterPreset != .auto
            let isoMode: CaptureProfessionalParameterMode
            if cameraRuntime.isFocusExposureLocked || cameraRuntime.isExposureLocked {
                isoMode = .locked
            } else if isoBlockedByShutter {
                isoMode = .locked
            } else if !cameraRuntime.isISOAutoSupported && !cameraRuntime.isISOPresetSupported {
                isoMode = .disabled
            } else if cameraRuntime.selectedISOPreset == .auto {
                isoMode = .auto
            } else {
                isoMode = .manual
            }
            return CaptureProfessionalParameterState(
                kind: .iso,
                panelStyle: .linear,
                valueText: isoEntryValueText(mode: isoMode),
                mode: isoMode,
                isAdjustable: cameraRuntime.isISOPresetSupported
                    && !cameraRuntime.isFocusExposureLocked
                    && !cameraRuntime.isExposureLocked
                    && !isoBlockedByShutter,
                canUseAuto: cameraRuntime.isISOAutoSupported
                    && cameraRuntime.selectedISOPreset != .auto
                    && !cameraRuntime.isFocusExposureLocked
                    && !cameraRuntime.isExposureLocked
                    && !isoBlockedByShutter,
                canReset: cameraRuntime.isISOAutoSupported
                    && cameraRuntime.selectedISOPreset != .auto
                    && !cameraRuntime.isFocusExposureLocked
                    && !cameraRuntime.isExposureLocked
                    && !isoBlockedByShutter,
                hintText: isoHintText(
                    for: isoMode,
                    isPresetAdjustable: cameraRuntime.isISOPresetSupported,
                    blockedByShutter: isoBlockedByShutter,
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
            let shutterBlockedByISO = cameraRuntime.selectedISOPreset != .auto
            let shutterMode: CaptureProfessionalParameterMode
            if cameraRuntime.isFocusExposureLocked || cameraRuntime.isExposureLocked {
                shutterMode = .locked
            } else if shutterBlockedByISO {
                shutterMode = .locked
            } else if !cameraRuntime.isShutterAutoSupported && !cameraRuntime.isShutterPresetSupported {
                shutterMode = .disabled
            } else if cameraRuntime.selectedShutterPreset == .auto {
                shutterMode = .auto
            } else {
                shutterMode = .manual
            }
            return CaptureProfessionalParameterState(
                kind: .shutter,
                panelStyle: .linear,
                valueText: shutterEntryValueText(mode: shutterMode),
                mode: shutterMode,
                isAdjustable: cameraRuntime.isShutterPresetSupported
                    && !cameraRuntime.isFocusExposureLocked
                    && !cameraRuntime.isExposureLocked
                    && !shutterBlockedByISO,
                canUseAuto: cameraRuntime.isShutterAutoSupported
                    && cameraRuntime.selectedShutterPreset != .auto
                    && !cameraRuntime.isFocusExposureLocked
                    && !cameraRuntime.isExposureLocked
                    && !shutterBlockedByISO,
                canReset: cameraRuntime.isShutterAutoSupported
                    && cameraRuntime.selectedShutterPreset != .auto
                    && !cameraRuntime.isFocusExposureLocked
                    && !cameraRuntime.isExposureLocked
                    && !shutterBlockedByISO,
                hintText: shutterHintText(
                    for: shutterMode,
                    isPresetAdjustable: cameraRuntime.isShutterPresetSupported,
                    blockedByISO: shutterBlockedByISO,
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
            let mode: CaptureProfessionalParameterMode
            if isLocked {
                mode = .locked
            } else if !cameraRuntime.isExposureBiasSupported {
                mode = .disabled
            } else if cameraRuntime.isExposureBiasAutoMode {
                mode = .auto
            } else {
                mode = .manual
            }
            return CaptureProfessionalParameterState(
                kind: .exposureCompensation,
                panelStyle: .dial,
                valueText: exposureEntryValueText(mode: mode),
                mode: mode,
                isAdjustable: cameraRuntime.isExposureBiasSupported && !isLocked,
                canUseAuto: cameraRuntime.isExposureBiasSupported
                    && !isLocked
                    && !cameraRuntime.isExposureBiasAutoMode,
                canReset: cameraRuntime.isExposureBiasSupported && !isLocked,
                hintText: exposureCompensationHintText(
                    for: mode,
                    isLocked: isLocked
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
                panelStyle: .linear,
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
                panelStyle: .linear,
                valueText: cameraRuntime.pixelDisplayText,
                mode: .manual,
                isAdjustable: true,
                canUseAuto: false,
                canReset: cameraRuntime.selectedPixelPreset != .p1600,
                hintText: "切换输出像素档位，拍照结果按当前比例生成对应尺寸。",
                dialRange: 0...Double(maxIndex),
                dialValue: cameraRuntime.pixelDialValue,
                dialStep: 1,
                leftLabel: "800",
                centerLabel: "1600",
                rightLabel: "2400"
            )
        case .settings:
            return CaptureProfessionalParameterState(
                kind: .settings,
                panelStyle: .placeholder,
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
            return "Locked"
        case .disabled:
            return "Unavailable"
        case .pending:
            return "Pending"
        }
    }

    private func exposureEntryValueText(mode: CaptureProfessionalParameterMode) -> String {
        switch mode {
        case .auto:
            return "Auto"
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
            return "Auto"
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
            return value > 0 ? "A·\(value)" : "Auto"
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
                return "A·\(text)"
            }
            return "Auto"
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

    private func handlePanelDialChange(parameter: CaptureProfessionalParameterKind, value: Double) {
        switch parameter {
        case .focus:
            cameraRuntime.setManualFocusLensPosition(Float(value))
        case .whiteBalance:
            cameraRuntime.setWhiteBalanceDialValue(value)
        case .iso:
            cameraRuntime.setISODialValue(value)
        case .shutter:
            cameraRuntime.setShutterDialValue(value)
        case .exposureCompensation:
            cameraRuntime.setExposureBiasDialValue(value)
        case .ratio:
            cameraRuntime.setAspectRatioDialValue(value)
        case .pixel:
            cameraRuntime.setPixelDialValue(value)
        case .settings:
            break
        }
    }

    private func handlePanelAuto(parameter: CaptureProfessionalParameterKind) {
        switch parameter {
        case .focus:
            cameraRuntime.restoreAutofocusMode()
        case .whiteBalance:
            cameraRuntime.applyWhiteBalanceAuto()
        case .iso:
            cameraRuntime.applyISOAuto()
        case .shutter:
            cameraRuntime.applyShutterAuto()
        case .exposureCompensation:
            cameraRuntime.applyExposureBiasAuto()
        case .ratio:
            break
        case .pixel:
            break
        case .settings:
            break
        }
    }

    private func handlePanelReset(parameter: CaptureProfessionalParameterKind) {
        switch parameter {
        case .focus:
            cameraRuntime.setManualFocusLensPosition(0.5)
        case .whiteBalance:
            cameraRuntime.resetWhiteBalance()
        case .iso:
            cameraRuntime.resetISO()
        case .shutter:
            cameraRuntime.resetShutter()
        case .exposureCompensation:
            cameraRuntime.resetExposureBias()
        case .ratio:
            cameraRuntime.resetAspectRatio()
        case .pixel:
            cameraRuntime.resetPixelPreset()
        case .settings:
            break
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
        isLocked: Bool
    ) -> String {
        switch mode {
        case .auto:
            return "当前 EV 为 0.00，拖动圆盘可连续做亮度微调。"
        case .manual:
            return "当前 EV 补偿已生效，可继续细调或快速恢复 Auto(0.00)。"
        case .locked:
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
        blockedByShutter: Bool,
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
            if blockedByShutter {
                return "手动快门生效中，先将快门设为 Auto 后再调 ISO。"
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
        blockedByISO: Bool,
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
            if blockedByISO {
                return "固定 ISO 生效中，先将 ISO 设为 Auto 后再调快门。"
            }
            return "当前为锁定态，先关闭 AE-L / AEAF-L 后再调快门。"
        case .disabled:
            return "当前镜头不支持手动快门，已自动降级。"
        case .pending:
            return "当前参数待接入。"
        }
    }

}

private struct CaptureFloatingParameterOverlay: View {
    let state: CaptureProfessionalParameterState
    let onClose: () -> Void
    let onAuto: () -> Void
    let onReset: () -> Void
    let onDialChange: (Double) -> Void
    let onDismissByBackgroundTap: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.16)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismissByBackgroundTap)

            CaptureProfessionalParameterPanelContainer(
                state: state,
                onClose: onClose,
                onAuto: onAuto,
                onReset: onReset,
                onDialChange: onDialChange
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 18)
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
                        .frame(width: 78, height: 78)
                    Circle()
                        .stroke(.black.opacity(0.25), lineWidth: 2.4)
                        .frame(width: 62, height: 62)
                    Circle()
                        .stroke(.white.opacity(0.24), lineWidth: 1)
                        .frame(width: 88, height: 88)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Shutter")
            .contentShape(Circle())
            .frame(width: 98, height: 98)

            Spacer(minLength: 14)

            Button(action: onTapGalleryPlaceholder) {
                sideControlCard(
                    symbol: "rectangle.stack",
                    title: "图册"
                )
            }
            .buttonStyle(.plain)
        }
        .frame(height: 112)
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
        .frame(width: 92, height: 78)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
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
            VStack(spacing: 6) {
                Group {
                    if let previewImage {
                        Image(uiImage: previewImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 36, height: 36)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else {
                        Image(systemName: latestResult == nil ? "photo" : "photo.fill")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                Text(latestResult == nil ? "最近" : "最新")
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(.white.opacity(latestResult == nil ? 0.72 : 0.92))
            .frame(width: 92, height: 78)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
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

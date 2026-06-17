//
//  CaptureBottomParameterBar.swift
//  SellerCamera
//
//  Created by Codex on 2026/5/4.
//

import SwiftUI
import UIKit

private enum CaptureParameterConsoleStyle {
    static let accent = SellerCameraColor.accentPrimary
    static let warmAccent = SellerCameraColor.accentPrimary
    static let panelStroke = SellerCameraColor.divider.opacity(0.70)
    static let panelInnerStroke = SellerCameraColor.divider.opacity(0.28)
    static let panelShadow = Color.black.opacity(0.24)
    static let baseFill = SellerCameraColor.controlSurfacePrimary.opacity(0.58)
    static let activeFill = SellerCameraControlVisualStyle.style(for: .selected).fill
    static let activeStroke = SellerCameraControlVisualStyle.style(for: .selected).stroke
    static let consoleFillTop = SellerCameraColor.controlSurfaceSecondary.opacity(0.96)
    static let consoleFillBottom = SellerCameraColor.canvasBackground.opacity(0.98)
}

struct CaptureBottomParameterItem: Identifiable, Equatable {
    let kind: CaptureProfessionalParameterKind
    let title: String
    let valueText: String
    let isManualOrLocked: Bool
    let isAvailable: Bool

    var id: CaptureProfessionalParameterKind { kind }
}

enum CaptureRulerControlKind: Equatable {
    case auto(isOn: Bool)
    case reset
    case lock
}

struct CaptureHorizontalParameterRulerItem: Identifiable, Equatable {
    let parameter: CaptureBottomParameterItem
    let tickLabels: [String]
    let selectedIndex: Int
    let majorTickIndexes: Set<Int>
    let controlKind: CaptureRulerControlKind
    let isRulerInteractive: Bool
    let dragThreshold: CGFloat
    let maximumStepCount: Int
    let tickSpacing: CGFloat
    let supportsInertia: Bool

    var id: CaptureProfessionalParameterKind { parameter.kind }
}

struct CaptureBottomParameterBar: View {
    let items: [CaptureBottomParameterItem]
    let activeKind: CaptureProfessionalParameterKind?
    let onSelect: (CaptureProfessionalParameterKind) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items) { item in
                parameterButton(for: item)
            }
        }
        .frame(height: 58)
        .padding(.horizontal, SellerCameraSpacing.xs)
    }

    private func parameterButton(for item: CaptureBottomParameterItem) -> some View {
        let isActive = activeKind == item.kind
        let state = controlState(for: item, isActive: isActive)
        let style = SellerCameraControlVisualStyle.style(for: state)

        return Button {
            guard item.isAvailable else { return }
            onSelect(item.kind)
        } label: {
            VStack(spacing: 4) {
                CaptureParameterGlyph(kind: item.kind, isActive: isActive, isAvailable: item.isAvailable)
                    .frame(width: 22, height: 15)

                Text(item.title)
                    .font(style.titleFont)
                    .textCase(.uppercase)
                    .foregroundStyle(style.foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(item.valueText)
                    .font(style.valueFont)
                    .monospacedDigit()
                    .foregroundStyle(style.secondaryForeground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.64)
                    .frame(minWidth: 42, maxWidth: .infinity)
                    .id(item.valueText)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
            .frame(maxWidth: .infinity, minHeight: SellerCameraSpacing.hitTarget, maxHeight: .infinity)
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: SellerCameraRadius.control, style: .continuous)
                    .fill(style.fill)
                    .shadow(color: style.shadow, radius: 8, x: 0, y: 0)
            }
            .overlay(alignment: .bottom) {
                if state != .normal && state != .disabled {
                    Capsule(style: .continuous)
                        .fill(style.underline)
                        .frame(width: 18, height: 2)
                        .shadow(color: style.shadow.opacity(0.8), radius: 5, x: 0, y: 0)
                        .offset(y: 2)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: SellerCameraRadius.control, style: .continuous)
                    .stroke(style.stroke, lineWidth: state == .selected ? 1 : 0.8)
            )
        }
        .buttonStyle(.plain)
        .disabled(!item.isAvailable)
        .accessibilityLabel("\(item.title) \(item.valueText)")
        .accessibilityValue(state.accessibilityText)
        .accessibilityHint(item.isAvailable ? "双击打开调节刻度" : "当前参数不可调")
        .animation(SellerCameraMotionToken.resolved(SellerCameraMotionToken.selection, reduceMotion: reduceMotion), value: isActive)
        .animation(SellerCameraMotionToken.resolved(SellerCameraMotionToken.panelDismiss, reduceMotion: reduceMotion), value: item.valueText)
    }

    private func controlState(for item: CaptureBottomParameterItem, isActive: Bool) -> SellerCameraControlState {
        guard item.isAvailable else { return .disabled }
        if isActive { return .selected }
        if item.isManualOrLocked { return .locked }
        return .normal
    }

    fileprivate func titleColor(isActive: Bool, item: CaptureBottomParameterItem) -> Color {
        guard item.isAvailable else { return SellerCameraColor.textDisabled }
        if isActive { return CaptureParameterConsoleStyle.accent }
        return SellerCameraColor.textSecondary
    }

    fileprivate func valueColor(isActive: Bool, item: CaptureBottomParameterItem) -> Color {
        guard item.isAvailable else { return SellerCameraColor.textDisabled }
        if isActive { return CaptureParameterConsoleStyle.accent }
        return SellerCameraColor.textPrimary
    }
}

struct CaptureHorizontalParameterRulerPanel: View {
    let items: [CaptureHorizontalParameterRulerItem]
    let activeKind: CaptureProfessionalParameterKind?
    let onSelect: (CaptureProfessionalParameterKind) -> Void
    let onControlTap: (CaptureProfessionalParameterKind) -> Void
    let onWheelStep: (CaptureProfessionalParameterKind, Int) -> Bool
    let onRulerDragStateChange: (CaptureProfessionalParameterKind, Bool) -> Void
    let onDismiss: () -> Void
    @State private var isRulerDragging = false
    @State private var lastRulerDragEndedAt: Date = .distantPast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var activeItem: CaptureHorizontalParameterRulerItem? {
        items.first { $0.parameter.kind == activeKind } ?? items.first
    }

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 0) {
                ForEach(items) { item in
                    CaptureRulerParameterEntry(
                        item: item.parameter,
                        isActive: item.parameter.kind == activeItem?.parameter.kind,
                        onSelect: { kind in
                            resetRulerDragTracking(markEnded: true)
                            onSelect(kind)
                        }
                    )
                }
            }
            .frame(height: 42)

            activeAnchor

            if let activeItem {
                CaptureHorizontalParameterRuler(
                    item: activeItem,
                    onControlTap: onControlTap,
                    onWheelStep: onWheelStep,
                    onDragStateChange: { isDragging in
                        if isDragging {
                            isRulerDragging = true
                        } else {
                            isRulerDragging = false
                            lastRulerDragEndedAt = Date()
                        }
                        onRulerDragStateChange(activeItem.parameter.kind, isDragging)
                    }
                )
                .id(activeItem.parameter.kind)
                .transition(.asymmetric(
                    insertion: .move(edge: .top)
                        .combined(with: .opacity)
                        .combined(with: .scale(scale: 0.96, anchor: .top)),
                    removal: .opacity
                        .combined(with: .scale(scale: 0.98, anchor: .top))
                ))
            }
        }
        .frame(height: 150)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .gesture(
            DragGesture(minimumDistance: 12)
                .onEnded { value in
                    let translation = value.translation
                    let isVerticalDismissIntent = translation.height > 116 && abs(translation.height) > abs(translation.width) * 1.4
                    let justDraggedRuler = Date().timeIntervalSince(lastRulerDragEndedAt) < 0.24
                    guard !isRulerDragging, !justDraggedRuler else { return }
                    if isVerticalDismissIntent {
                        onDismiss()
                    }
                }
        )
        .animation(SellerCameraMotionToken.resolved(SellerCameraMotionToken.panelPresent, reduceMotion: reduceMotion), value: activeKind)
        .onChange(of: activeKind) { _ in
            resetRulerDragTracking(markEnded: true)
        }
        .onDisappear {
            resetRulerDragTracking(markEnded: true)
        }
        .accessibilityElement(children: .contain)
    }

    private func resetRulerDragTracking(markEnded: Bool) {
        if isRulerDragging, let activeItem {
            onRulerDragStateChange(activeItem.parameter.kind, false)
        }
        isRulerDragging = false
        if markEnded {
            lastRulerDragEndedAt = Date()
        }
    }

    private var activeAnchor: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                VStack(spacing: 0) {
                    if item.parameter.kind == activeItem?.parameter.kind {
                        Triangle()
                            .fill(CaptureParameterConsoleStyle.accent)
                            .frame(width: 9, height: 6)
                            .shadow(color: CaptureParameterConsoleStyle.accent.opacity(0.28), radius: 5, x: 0, y: 0)
                    } else {
                        Color.clear.frame(width: 9, height: 6)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 8)
        .allowsHitTesting(false)
    }
}

private struct CaptureRulerParameterEntry: View {
    let item: CaptureBottomParameterItem
    let isActive: Bool
    let onSelect: (CaptureProfessionalParameterKind) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let state = controlState
        let style = SellerCameraControlVisualStyle.style(for: state)

        Button {
            guard item.isAvailable else { return }
            onSelect(item.kind)
        } label: {
            VStack(spacing: 2) {
                CaptureParameterGlyph(kind: item.kind, isActive: isActive, isAvailable: item.isAvailable)
                    .frame(width: 20, height: 14)

                Text(item.title)
                    .font(style.titleFont)
                    .tracking(0.35)
                    .foregroundStyle(style.foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(item.valueText)
                    .font(style.valueFont)
                    .monospacedDigit()
                    .foregroundStyle(style.secondaryForeground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                    .frame(minWidth: 38)
                    .id(item.valueText)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
            .frame(maxWidth: .infinity, minHeight: SellerCameraSpacing.hitTarget, maxHeight: .infinity)
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: SellerCameraRadius.control, style: .continuous)
                    .fill(style.fill)
                    .shadow(color: style.shadow, radius: 7, x: 0, y: 0)
            }
            .overlay(alignment: .bottom) {
                if state != .normal && state != .disabled {
                    Capsule(style: .continuous)
                        .fill(style.underline)
                        .frame(width: 17, height: 2)
                        .offset(y: 2)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: SellerCameraRadius.control, style: .continuous)
                    .stroke(style.stroke, lineWidth: isActive ? 1 : 0.8)
            )
        }
        .buttonStyle(.plain)
        .disabled(!item.isAvailable)
        .accessibilityLabel("\(item.title) \(item.valueText)")
        .accessibilityValue(state.accessibilityText)
        .accessibilityHint(item.isAvailable ? "双击切换到此参数" : "当前参数不可调")
        .animation(SellerCameraMotionToken.resolved(SellerCameraMotionToken.selection, reduceMotion: reduceMotion), value: isActive)
        .animation(SellerCameraMotionToken.resolved(SellerCameraMotionToken.panelDismiss, reduceMotion: reduceMotion), value: item.valueText)
    }

    private var controlState: SellerCameraControlState {
        guard item.isAvailable else { return .disabled }
        if isActive { return .selected }
        if item.isManualOrLocked { return .locked }
        return .normal
    }

    private var titleColor: Color {
        guard item.isAvailable else { return SellerCameraColor.textDisabled }
        return isActive ? CaptureParameterConsoleStyle.accent : .white.opacity(0.54)
    }

    private var valueColor: Color {
        guard item.isAvailable else { return SellerCameraColor.textDisabled }
        return isActive ? .white.opacity(0.98) : .white.opacity(0.84)
    }
}

private struct CaptureHorizontalParameterRuler: View {
    let item: CaptureHorizontalParameterRulerItem
    let onControlTap: (CaptureProfessionalParameterKind) -> Void
    let onWheelStep: (CaptureProfessionalParameterKind, Int) -> Bool
    let onDragStateChange: (Bool) -> Void
    @State private var dragOffset: CGFloat = 0
    @State private var lastDragStepTranslation: CGFloat = 0
    @State private var isDragInProgress = false
    @State private var lastRulerStepAppliedAt: Date = .distantPast
    @State private var lastRulerDragDirection: Int = 0
    @State private var isInertiaInProgress = false
    @State private var inertiaGeneration: UInt64 = 0
    @State private var gestureStartedAt: Date?
    @State private var lastDragSampleTranslation: CGFloat = 0
    @State private var lastDragSampleAt: Date?
    @State private var filteredDragVelocity: CGFloat = 0
    @State private var lastScrubSensitivity: CGFloat = 1
    @State private var lastDiagnosticLogAt: Date = .distantPast
    @State private var lastHapticAt: Date = .distantPast
    @State private var lastHapticSignature: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var tickSpacing: CGFloat { item.tickSpacing }
    private var interactionProfile: SellerCameraRulerInteractionProfile {
        SellerCameraRulerInteractionProfile.professionalParameter(item.parameter.kind)
    }
    private let rulerStyle = SellerCameraRulerStyle.professional

    var body: some View {
        HStack(spacing: 8) {
            ZStack(alignment: .center) {
                GeometryReader { proxy in
                    let centerX = proxy.size.width / 2

                    ZStack {
                        rulerTicks
                            .offset(x: centerX - CGFloat(item.selectedIndex) * tickSpacing - tickSpacing / 2 + dragOffset)
                            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
                            .clipped()

                        centerPointer
                            .position(x: centerX, y: 41)

                        valueBadge
                            .position(x: centerX, y: 11)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 68)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard item.isRulerInteractive, item.parameter.isAvailable else { return }
                        handleRulerDrag(value)
                    }
                    .onEnded { value in
                        finishRulerDrag(
                            translationWidth: value.translation.width,
                            predictedEndTranslationWidth: value.predictedEndTranslation.width,
                            animateOffset: true
                        )
                    }
            )
            .onDisappear {
                finishRulerDrag(
                    translationWidth: nil,
                    predictedEndTranslationWidth: nil,
                    animateOffset: false
                )
            }
            .opacity(item.isRulerInteractive ? 1 : 0.54)

            CaptureRulerControlCapsule(
                controlKind: item.controlKind,
                isEnabled: item.parameter.isAvailable && item.controlKind != .lock,
                onTap: {
                    guard item.parameter.isAvailable else { return }
                    guard item.controlKind != .lock else { return }
                    SellerCameraHaptic.play(.selection, signature: "parameter-control-\(item.parameter.kind.rawValue)")
                    onControlTap(item.parameter.kind)
                }
            )
            .frame(width: 60)
        }
        .padding(.horizontal, SellerCameraSpacing.md)
        .padding(.vertical, SellerCameraSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: SellerCameraRadius.panel, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            CaptureParameterConsoleStyle.consoleFillTop,
                            CaptureParameterConsoleStyle.consoleFillBottom
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: SellerCameraRadius.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SellerCameraRadius.panel, style: .continuous)
                .stroke(CaptureParameterConsoleStyle.panelStroke, lineWidth: 1)
        )
        .shadow(color: CaptureParameterConsoleStyle.panelShadow, radius: 14, x: 0, y: 9)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(item.parameter.title) 刻度")
        .accessibilityValue(item.parameter.valueText)
        .accessibilityHint(item.isRulerInteractive ? "左右拖动调节，手指上移可精细微调" : "当前刻度不可调")
        .accessibilityAdjustableAction { direction in
            guard item.isRulerInteractive, item.parameter.isAvailable else { return }
            switch direction {
            case .increment:
                applyAccessibilityStep(1)
            case .decrement:
                applyAccessibilityStep(-1)
            default:
                break
            }
        }
    }

    private var rulerTicks: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(Array(item.tickLabels.enumerated()), id: \.offset) { index, label in
                let isSelected = index == item.selectedIndex
                let isMajor = item.majorTickIndexes.contains(index)

                VStack(spacing: 3) {
                    Rectangle()
                        .fill(tickColor(isSelected: isSelected, isMajor: isMajor))
                        .frame(width: isSelected ? rulerStyle.tickSelectedWidth : rulerStyle.tickNormalWidth, height: tickHeight(isSelected: isSelected, isMajor: isMajor))
                        .shadow(color: isSelected ? CaptureParameterConsoleStyle.accent.opacity(0.22) : .clear, radius: 4, x: 0, y: 0)

                    Text(isMajor ? label : "")
                        .font(isSelected ? SellerCameraTypographyToken.rulerMajor : SellerCameraTypographyToken.rulerMinor)
                        .monospacedDigit()
                        .foregroundStyle(tickLabelColor(isSelected: isSelected))
                        .lineLimit(1)
                        .minimumScaleFactor(0.50)
                        .frame(width: 46, height: 12)
                }
                .frame(width: tickSpacing, height: 43, alignment: .bottom)
            }
        }
        .animation(SellerCameraMotionToken.resolved(SellerCameraMotionToken.selection, reduceMotion: reduceMotion), value: item.selectedIndex)
    }

    private var centerPointer: some View {
        VStack(spacing: 0) {
            Triangle()
                .fill(CaptureParameterConsoleStyle.accent)
                .frame(width: 8, height: 5)
                .shadow(color: CaptureParameterConsoleStyle.accent.opacity(0.28), radius: 5, x: 0, y: 0)

            Rectangle()
                .fill(CaptureParameterConsoleStyle.accent)
                .frame(width: rulerStyle.indicatorWidth, height: rulerStyle.indicatorHeight)
                .shadow(color: CaptureParameterConsoleStyle.accent.opacity(0.28), radius: 6, x: 0, y: 0)
        }
        .allowsHitTesting(false)
    }

    private var valueBadge: some View {
        Text(item.parameter.valueText)
            .font(SellerCameraTypography.rulerPrimaryValue)
            .monospacedDigit()
            .foregroundStyle(SellerCameraColor.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.58)
            .padding(.horizontal, SellerCameraSpacing.md)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(CaptureParameterConsoleStyle.accent.opacity(0.20))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(CaptureParameterConsoleStyle.accent.opacity(0.44), lineWidth: 1)
            )
            .shadow(color: CaptureParameterConsoleStyle.accent.opacity(0.18), radius: 9, x: 0, y: 0)
            .id(item.parameter.valueText)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
            .animation(SellerCameraMotionToken.resolved(SellerCameraMotionToken.panelDismiss, reduceMotion: reduceMotion), value: item.parameter.valueText)
            .allowsHitTesting(false)
    }

    private func tickHeight(isSelected: Bool, isMajor: Bool) -> CGFloat {
        if isSelected { return rulerStyle.selectedTickHeight }
        return isMajor ? rulerStyle.majorTickHeight : rulerStyle.minorTickHeight
    }

    private func tickColor(isSelected: Bool, isMajor: Bool) -> Color {
        guard item.parameter.isAvailable else { return SellerCameraColor.textDisabled.opacity(0.66) }
        if isSelected { return CaptureParameterConsoleStyle.accent }
        return SellerCameraColor.textPrimary.opacity(isMajor ? 0.34 : 0.16)
    }

    private func tickLabelColor(isSelected: Bool) -> Color {
        guard item.parameter.isAvailable else { return SellerCameraColor.textDisabled.opacity(0.74) }
        if isSelected { return SellerCameraColor.textPrimary }
        return SellerCameraColor.textTertiary
    }

    private func handleRulerDrag(_ value: DragGesture.Value) {
        guard item.isRulerInteractive, item.parameter.isAvailable else { return }
        if isInertiaInProgress {
            inertiaGeneration &+= 1
            isInertiaInProgress = false
        }
        if !isDragInProgress {
            isDragInProgress = true
            gestureStartedAt = Date()
            resetVelocityTracking(translationWidth: value.translation.width, at: gestureStartedAt ?? Date())
            inertiaGeneration &+= 1
            onDragStateChange(true)
        }

        let threshold = max(18, item.dragThreshold)
        let translation = value.translation
        let translationWidth = translation.width
        let now = Date()
        let velocity = updateVelocityTracking(translationWidth: translationWidth, at: now)
        let delta = translationWidth - lastDragStepTranslation
        let stepInfo = interactionProfile.dragStepInfo(
            delta: delta,
            baseThreshold: threshold,
            verticalTranslation: translation.height,
            velocity: velocity
        )
        lastScrubSensitivity = stepInfo.sensitivity
        dragOffset = translationWidth - lastDragStepTranslation
        logRulerDiagnosticIfNeeded(
            state: "dragging",
            rawTranslation: translationWidth,
            incrementalTranslation: delta,
            velocity: velocity,
            sensitivity: stepInfo.sensitivity,
            projectedSteps: projectedSteps(forVelocity: velocity, threshold: threshold),
            snappedIndex: item.selectedIndex
        )
        let rawStepCount = stepInfo.rawStepCount
        guard rawStepCount != 0 else { return }

        let rawDirection = rawStepCount > 0 ? 1 : -1
        if lastRulerDragDirection != 0, rawDirection != lastRulerDragDirection {
            lastRulerStepAppliedAt = .distantPast
        }
        lastRulerDragDirection = rawDirection
        // Consume movement even when cooldown or boundary prevents a value change, so edge drags do not leave residual translation.
        // Fine scrubbing and velocity-aware profiles raise/lower the consumption threshold while keeping boundary movement consumed.
        lastDragStepTranslation += CGFloat(rawStepCount) * stepInfo.effectiveThreshold
        dragOffset = translationWidth - lastDragStepTranslation
        guard now.timeIntervalSince(lastRulerStepAppliedAt) >= stepCooldown else { return }

        let clampedStepCount = -interactionProfile.cappedStepCount(rawStepCount, externalMaximum: item.maximumStepCount)
#if DEBUG
        if item.parameter.kind == .whiteBalance {
            let autoState: String
            if case .auto(let isOn) = item.controlKind {
                autoState = "\(isOn)"
            } else {
                autoState = "n/a"
            }
            print("[CaptureWBRulerDrag] changed translation=\(String(format: "%.1f", translationWidth)) delta=\(String(format: "%.1f", delta)) rawStepCount=\(rawStepCount) consumedStepCount=\(clampedStepCount) rawDirection=\(rawDirection) selectedIndex=\(item.selectedIndex) sensitivity=\(String(format: "%.2f", scrubSensitivity(for: translation.height))) auto=\(autoState)")
        } else if item.parameter.kind == .shutter {
            print("[CaptureShutterGesture] dragDirection=\(rawDirection) previousTickIndex=\(item.selectedIndex) targetTickIndex=step:\(clampedStepCount) minTickIndex=0 maxTickIndex=\(max(0, item.tickLabels.count - 1)) clampedTickIndex=pending isDragging=true isInertia=false skipReason=none writeReason=draggingUpdate")
        }
#endif
        let didApply = onWheelStep(item.parameter.kind, clampedStepCount)
        guard didApply else { return }

        lastRulerStepAppliedAt = now
        triggerGearHapticIfNeeded(step: clampedStepCount, at: now)
    }

    private var stepCooldown: TimeInterval {
        interactionProfile.stepCooldown
    }

    private func finishRulerDrag(
        translationWidth: CGFloat?,
        predictedEndTranslationWidth: CGFloat?,
        animateOffset: Bool
    ) {
        let didScheduleInertia: Bool
        if item.supportsInertia,
           item.isRulerInteractive,
           item.parameter.isAvailable,
           let translationWidth,
           predictedEndTranslationWidth != nil {
            didScheduleInertia = applyInertiaStep(
                translationWidth: translationWidth,
                releaseVelocity: filteredDragVelocity
            )
        } else {
            inertiaGeneration &+= 1
            didScheduleInertia = false
        }
        if isDragInProgress {
            onDragStateChange(false)
        }
        isDragInProgress = false
        isInertiaInProgress = didScheduleInertia
        lastScrubSensitivity = 1
        lastDragStepTranslation = 0
        lastRulerDragDirection = 0
        gestureStartedAt = nil
        lastDragSampleAt = nil
        lastDragSampleTranslation = 0
        filteredDragVelocity = 0
        if animateOffset {
            withAnimation(SellerCameraMotionToken.resolved(SellerCameraMotionToken.snap, reduceMotion: reduceMotion)) {
                dragOffset = 0
            }
        } else {
            dragOffset = 0
        }
    }

    private func applyInertiaStep(translationWidth: CGFloat, releaseVelocity: CGFloat) -> Bool {
        let threshold = max(18, item.dragThreshold)
        let rawStepCount = interactionProfile.inertialRawStepCount(
            releaseVelocity: releaseVelocity,
            baseThreshold: threshold,
            currentSensitivity: lastScrubSensitivity
        )
        guard rawStepCount != 0 else { return false }

        let inertiaStepCount = -rawStepCount
        guard inertiaStepCount != 0 else { return false }

        let generation = inertiaGeneration &+ 1
        inertiaGeneration = generation
        isInertiaInProgress = true
        logRulerDiagnosticIfNeeded(
            state: "decelerating",
            rawTranslation: translationWidth,
            incrementalTranslation: 0,
            velocity: releaseVelocity,
            sensitivity: lastScrubSensitivity,
            projectedSteps: inertiaStepCount,
            snappedIndex: max(0, min(max(0, item.tickLabels.count - 1), item.selectedIndex + inertiaStepCount))
        )
#if DEBUG
        if item.parameter.kind == .shutter {
            let direction = rawStepCount > 0 ? 1 : -1
            print("[CaptureShutterInertia] dragDirection=\(direction) previousTickIndex=\(item.selectedIndex) targetTickIndex=step:\(inertiaStepCount) minTickIndex=0 maxTickIndex=\(max(0, item.tickLabels.count - 1)) clampedTickIndex=pending isDragging=false isInertia=true skipReason=none writeReason=inertiaFinalCommit")
        }
#endif
        let direction = inertiaStepCount > 0 ? 1 : -1
        let stepTotal = abs(inertiaStepCount)
        let interval = max(0.035, interactionProfile.stepCooldown * 0.82)
        for offset in 0..<stepTotal {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(offset) * interval) {
                guard inertiaGeneration == generation, isInertiaInProgress, !isDragInProgress else { return }
                let didApply = onWheelStep(item.parameter.kind, direction)
                if didApply {
                    triggerGearHapticIfNeeded(step: direction, at: Date())
                }
                if !didApply || offset == stepTotal - 1 {
                    isInertiaInProgress = false
                }
            }
        }
        return true
    }

    private func scrubSensitivity(for verticalTranslation: CGFloat) -> CGFloat {
        interactionProfile.scrubSensitivity(forVerticalTranslation: verticalTranslation)
    }

    private func resetVelocityTracking(translationWidth: CGFloat, at now: Date) {
        lastDragSampleTranslation = translationWidth
        lastDragSampleAt = now
        filteredDragVelocity = 0
    }

    private func updateVelocityTracking(translationWidth: CGFloat, at now: Date) -> CGFloat {
        guard let lastDragSampleAt else {
            resetVelocityTracking(translationWidth: translationWidth, at: now)
            return 0
        }
        let elapsed = max(0.001, now.timeIntervalSince(lastDragSampleAt))
        let instantaneousVelocity = (translationWidth - lastDragSampleTranslation) / CGFloat(elapsed)
        if filteredDragVelocity == 0 || instantaneousVelocity.sign != filteredDragVelocity.sign {
            filteredDragVelocity = instantaneousVelocity
        } else {
            filteredDragVelocity = filteredDragVelocity * 0.35 + instantaneousVelocity * 0.65
        }
        lastDragSampleTranslation = translationWidth
        self.lastDragSampleAt = now
        return filteredDragVelocity
    }

    private func projectedSteps(forVelocity velocity: CGFloat, threshold: CGFloat) -> Int {
        -interactionProfile.inertialRawStepCount(
            releaseVelocity: velocity,
            baseThreshold: threshold,
            currentSensitivity: max(1, lastScrubSensitivity)
        )
    }

#if DEBUG
    private func logRulerDiagnosticIfNeeded(
        state: String,
        rawTranslation: CGFloat,
        incrementalTranslation: CGFloat,
        velocity: CGFloat,
        sensitivity: CGFloat,
        projectedSteps: Int,
        snappedIndex: Int
    ) {
        let now = Date()
        guard now.timeIntervalSince(lastDiagnosticLogAt) >= 0.16 else { return }
        lastDiagnosticLogAt = now
        let elapsed = gestureStartedAt.map { now.timeIntervalSince($0) } ?? 0
        let continuousPosition = Double(item.selectedIndex) - Double(rawTranslation / max(tickSpacing, 1))
        print(
            "[R83A1Ruler] " +
            "parameter=\(item.parameter.kind.rawValue) " +
            "gestureState=\(state) " +
            "rawTranslation=\(String(format: "%.2f", rawTranslation)) " +
            "incrementalTranslation=\(String(format: "%.2f", incrementalTranslation)) " +
            "elapsedTime=\(String(format: "%.3f", elapsed)) " +
            "instantaneousVelocity=\(String(format: "%.1f", velocity)) " +
            "filteredVelocity=\(String(format: "%.1f", filteredDragVelocity)) " +
            "activeSensitivity=\(String(format: "%.3f", sensitivity)) " +
            "continuousPosition=\(String(format: "%.3f", continuousPosition)) " +
            "visualIndex=\(item.selectedIndex) " +
            "snappedIndex=\(snappedIndex) " +
            "projectedSteps=\(projectedSteps) " +
            "runtimePendingValue=\(item.parameter.valueText) " +
            "runtimeCommittedValue=see-parameter-write-log " +
            "gestureGeneration=\(inertiaGeneration)"
        )
    }
#else
    private func logRulerDiagnosticIfNeeded(
        state: String,
        rawTranslation: CGFloat,
        incrementalTranslation: CGFloat,
        velocity: CGFloat,
        sensitivity: CGFloat,
        projectedSteps: Int,
        snappedIndex: Int
    ) {}
#endif

    private func triggerGearHapticIfNeeded(step: Int, at now: Date) {
        let targetIndex = max(0, min(max(0, item.tickLabels.count - 1), item.selectedIndex + step))
        guard interactionProfile.shouldTriggerHaptic(
            step: step,
            selectedIndex: targetIndex,
            majorTickIndexes: item.majorTickIndexes
        ) else { return }
        let signature = "\(String(describing: item.parameter.kind))-\(targetIndex)-\(step)"
        guard signature != lastHapticSignature else { return }
        guard now.timeIntervalSince(lastHapticAt) >= interactionProfile.hapticMinimumInterval else { return }
        lastHapticSignature = signature
        lastHapticAt = now
        SellerCameraHaptic.play(
            .selection,
            signature: "\(item.parameter.kind.rawValue)-\(targetIndex)-\(step)",
            minimumInterval: interactionProfile.hapticMinimumInterval
        )
    }

    private func applyAccessibilityStep(_ step: Int) {
        let didApply = onWheelStep(item.parameter.kind, step)
        if didApply {
            triggerGearHapticIfNeeded(step: step, at: Date())
        }
    }
}

private struct CaptureRulerControlCapsule: View {
    let controlKind: CaptureRulerControlKind
    let isEnabled: Bool
    let onTap: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let state = visualState
        let style = SellerCameraControlVisualStyle.style(for: state)

        Button(action: onTap) {
            switch controlKind {
            case .auto(let isOn):
                HStack(spacing: SellerCameraSpacing.xs) {
                    Circle()
                        .fill(isOn ? style.foreground : SellerCameraColor.textTertiary)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(style.stroke, lineWidth: 1)
                        )

                    Text("AUTO")
                        .font(SellerCameraTypography.toolLabel)
                        .tracking(0.4)
                        .foregroundStyle(isOn ? style.foreground : style.secondaryForeground)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .background(
                    Capsule(style: .continuous)
                        .fill(style.fill)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(style.stroke, lineWidth: 1)
                )
            case .reset:
                Text("RESET")
                    .font(SellerCameraTypography.toolLabel)
                    .tracking(0.45)
                    .foregroundStyle(style.foreground)
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
                    .background(
                        Capsule(style: .continuous)
                            .fill(style.fill)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(style.stroke, lineWidth: 1)
                    )
            case .lock:
                Text("LOCK")
                    .font(SellerCameraTypography.toolLabel)
                    .tracking(0.45)
                    .foregroundStyle(style.foreground)
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
                    .background(
                        Capsule(style: .continuous)
                            .fill(style.fill)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(style.stroke, lineWidth: 1)
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .scaleEffect(isEnabled ? 1 : 0.98)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(isEnabled ? "双击切换参数控制模式" : "当前控制不可用")
        .animation(SellerCameraMotionToken.resolved(SellerCameraMotionToken.selection, reduceMotion: reduceMotion), value: controlKind)
        .animation(SellerCameraMotionToken.resolved(SellerCameraMotionToken.selection, reduceMotion: reduceMotion), value: isEnabled)
    }

    private var visualState: SellerCameraControlState {
        guard isEnabled else {
            if case .lock = controlKind { return .locked }
            return .disabled
        }
        switch controlKind {
        case .auto(let isOn):
            return isOn ? .selected : .normal
        case .reset:
            return .selected
        case .lock:
            return .locked
        }
    }

    private var accessibilityLabel: String {
        switch controlKind {
        case .auto(let isOn):
            return isOn ? "自动，开启" : "自动，关闭"
        case .reset:
            return "重置"
        case .lock:
            return "锁定"
        }
    }
}

private struct CaptureParameterGlyph: View {
    let kind: CaptureProfessionalParameterKind
    let isActive: Bool
    let isAvailable: Bool
    private let metrics = SellerCameraGlyphMetrics.self

    private var stroke: Color {
        guard isAvailable else { return SellerCameraColor.textDisabled.opacity(0.92) }
        return isActive ? CaptureParameterConsoleStyle.accent : SellerCameraColor.textSecondary
    }

    private var fill: Color {
        guard isAvailable else { return SellerCameraColor.controlSurfaceDisabled }
        return isActive ? CaptureParameterConsoleStyle.accent.opacity(0.20) : SellerCameraColor.controlSurfacePrimary.opacity(0.30)
    }

    var body: some View {
        ZStack {
            switch kind {
            case .exposureCompensation:
                exposureGlyph
            case .whiteBalance:
                whiteBalanceGlyph
            case .tint:
                tintGlyph
            case .iso:
                isoGlyph
            case .shutter:
                shutterGlyph
            default:
                Circle()
                    .stroke(stroke, lineWidth: metrics.standardStrokeWidth)
            }
        }
        .shadow(color: isActive ? CaptureParameterConsoleStyle.accent.opacity(0.28) : .clear, radius: 6, x: 0, y: 0)
    }

    private var exposureGlyph: some View {
        ZStack {
            Circle()
                .fill(fill)
            Circle()
                .trim(from: 0.25, to: 0.75)
                .stroke(stroke, style: StrokeStyle(lineWidth: metrics.emphasizedStrokeWidth, lineCap: .round))
                .rotationEffect(.degrees(90))
            Circle()
                .stroke(stroke.opacity(0.90), lineWidth: metrics.standardStrokeWidth)
            Rectangle()
                .fill(stroke.opacity(0.80))
                .frame(width: metrics.hairlineWidth, height: 12)
            HStack(spacing: 8) {
                Text("-")
                Text("+")
            }
            .font(SellerCameraTypography.glyphMicroLabel)
            .foregroundStyle(stroke)
        }
    }

    private var whiteBalanceGlyph: some View {
        ZStack {
            Circle()
                .stroke(stroke, lineWidth: metrics.standardStrokeWidth)
            Rectangle()
                .fill(stroke.opacity(0.78))
                .frame(width: metrics.hairlineWidth, height: 14)
            HStack(spacing: 8) {
                Circle().fill(stroke.opacity(0.42)).frame(width: metrics.standardDot, height: metrics.standardDot)
                Circle().fill(stroke).frame(width: metrics.standardDot, height: metrics.standardDot)
            }
        }
    }

    private var tintGlyph: some View {
        ZStack {
            Capsule()
                .stroke(stroke.opacity(0.82), lineWidth: metrics.standardStrokeWidth)
                .frame(width: 20, height: 7)
            Rectangle()
                .fill(stroke.opacity(0.70))
                .frame(width: metrics.hairlineWidth, height: 14)
            HStack(spacing: 10) {
                Circle().fill(stroke.opacity(0.45)).frame(width: metrics.emphasizedDot, height: metrics.emphasizedDot)
                Circle().fill(stroke).frame(width: metrics.emphasizedDot, height: metrics.emphasizedDot)
            }
        }
    }

    private var isoGlyph: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .stroke(stroke, lineWidth: metrics.standardStrokeWidth)
            VStack(spacing: 1) {
                Text("ISO")
                    .font(SellerCameraTypography.glyphNanoLabel)
                    .foregroundStyle(stroke)
                HStack(spacing: 2) {
                    Circle().fill(stroke.opacity(0.58)).frame(width: metrics.compactDot, height: metrics.compactDot)
                    Circle().fill(stroke.opacity(0.90)).frame(width: metrics.compactDot, height: metrics.compactDot)
                    Circle().fill(stroke.opacity(0.58)).frame(width: metrics.compactDot, height: metrics.compactDot)
                }
            }
        }
    }

    private var shutterGlyph: some View {
        ZStack {
            Circle()
                .stroke(stroke.opacity(0.88), lineWidth: metrics.standardStrokeWidth)
            ForEach(0..<5, id: \.self) { index in
                Capsule()
                    .fill(stroke.opacity(index == 0 ? 1 : 0.64))
                    .frame(width: metrics.compactDot, height: 8)
                    .offset(y: -3)
                    .rotationEffect(.degrees(Double(index) * 72))
            }
            Circle()
                .fill(SellerCameraPreviewStyle.contrastOutline.opacity(0.58))
                .frame(width: metrics.emphasizedDot, height: metrics.emphasizedDot)
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

//
//  CaptureProfessionalParameterPanel.swift
//  SellerCamera
//
//  Created by Codex on 2026/4/3.
//

import SwiftUI

enum CaptureProfessionalParameterKind: String, CaseIterable, Identifiable {
    case focus
    case whiteBalance
    case iso
    case shutter
    case exposureCompensation
    case ratio
    case pixel
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .focus:
            return "Focus"
        case .whiteBalance:
            return "WB"
        case .iso:
            return "ISO"
        case .shutter:
            return "Shutter"
        case .exposureCompensation:
            return "EV"
        case .ratio:
            return "Ratio"
        case .pixel:
            return "Pixel"
        case .settings:
            return "更多"
        }
    }
}

enum CaptureProfessionalParameterPanelStyle {
    case dial
    case linear
    case placeholder
}

enum CaptureProfessionalParameterMode {
    case auto
    case manual
    case locked
    case pending
    case disabled

    var text: String {
        switch self {
        case .auto:
            return "Auto"
        case .manual:
            return "Manual"
        case .locked:
            return "Locked"
        case .pending:
            return "Pending"
        case .disabled:
            return "Unavailable"
        }
    }

    // 主条使用更短状态词，降低小屏拥挤；语义与 text 保持一致。
    var compactText: String {
        switch self {
        case .auto:
            return "Auto"
        case .manual:
            return "Man"
        case .locked:
            return "Lock"
        case .pending:
            return "Pend"
        case .disabled:
            return "N/A"
        }
    }
}

struct CaptureProfessionalParameterState {
    let kind: CaptureProfessionalParameterKind
    let panelStyle: CaptureProfessionalParameterPanelStyle
    let valueText: String
    let mode: CaptureProfessionalParameterMode
    let isAdjustable: Bool
    let canUseAuto: Bool
    let canReset: Bool
    let hintText: String
    let dialRange: ClosedRange<Double>
    let dialValue: Double
    let dialStep: Double
    let leftLabel: String
    let centerLabel: String
    let rightLabel: String
}

struct CaptureProfessionalParameterEntryBar: View {
    let states: [CaptureProfessionalParameterState]
    let activeKind: CaptureProfessionalParameterKind?
    let onSelect: (CaptureProfessionalParameterKind) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(states, id: \.kind) { state in
                    let isActive = activeKind == state.kind
                    Button {
                        onSelect(state.kind)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(state.kind.title)
                                    .font(.caption2.weight(.semibold))
                                Text(state.mode.compactText)
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(modeBadgeColor(for: state.mode), in: Capsule())
                            }
                            Text(state.valueText)
                                .font(.caption2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.84)
                                .foregroundStyle(.white.opacity(state.mode == .disabled ? 0.45 : (isActive ? 0.98 : 0.82)))
                        }
                        .foregroundStyle(.white.opacity(0.95))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(minWidth: 84, alignment: .leading)
                        .background(
                            (isActive
                                ? Color(red: 0.19, green: 0.29, blue: 0.35).opacity(0.82)
                                : Color.white.opacity(0.08)),
                            in: Capsule(style: .continuous)
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(
                                    isActive ? Color.teal.opacity(0.55) : Color.white.opacity(0.12),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func modeBadgeColor(for mode: CaptureProfessionalParameterMode) -> Color {
        switch mode {
        case .auto:
            return .blue.opacity(0.32)
        case .manual:
            return .teal.opacity(0.35)
        case .locked:
            return .orange.opacity(0.35)
        case .pending:
            return .white.opacity(0.16)
        case .disabled:
            return .red.opacity(0.32)
        }
    }
}

struct CaptureProfessionalParameterPanelContainer: View {
    let state: CaptureProfessionalParameterState
    let onClose: () -> Void
    let onAuto: () -> Void
    let onReset: () -> Void
    let onDialChange: (Double) -> Void

    var body: some View {
        switch state.panelStyle {
        case .dial:
            CaptureProfessionalDialPanel(
                state: state,
                onClose: onClose,
                onAuto: onAuto,
                onReset: onReset,
                onDialChange: onDialChange
            )
        case .linear:
            CaptureProfessionalLinearPanel(
                state: state,
                onClose: onClose,
                onAuto: onAuto,
                onReset: onReset,
                onDialChange: onDialChange
            )
        case .placeholder:
            CaptureProfessionalPlaceholderPanel(
                state: state,
                onClose: onClose
            )
        }
    }
}

struct CaptureProfessionalDialPanel: View {
    let state: CaptureProfessionalParameterState
    let onClose: () -> Void
    let onAuto: () -> Void
    let onReset: () -> Void
    let onDialChange: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            CaptureProfessionalPanelHeader(
                kindTitle: state.kind.title,
                mode: state.mode,
                valueText: state.valueText,
                canUseAuto: state.canUseAuto,
                canReset: state.canReset,
                onAuto: onAuto,
                onReset: onReset,
                onClose: onClose
            )

            CaptureDialScaleControl(
                value: state.dialValue,
                range: state.dialRange,
                step: state.dialStep,
                leftLabel: state.leftLabel,
                centerLabel: state.centerLabel,
                rightLabel: state.rightLabel,
                isEnabled: state.isAdjustable,
                onChange: onDialChange
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(.black.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
    }
}

struct CaptureProfessionalLinearPanel: View {
    let state: CaptureProfessionalParameterState
    let onClose: () -> Void
    let onAuto: () -> Void
    let onReset: () -> Void
    let onDialChange: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            CaptureProfessionalPanelHeader(
                kindTitle: state.kind.title,
                mode: state.mode,
                valueText: state.valueText,
                canUseAuto: state.canUseAuto,
                canReset: state.canReset,
                onAuto: onAuto,
                onReset: onReset,
                onClose: onClose
            )

            CaptureLinearScaleControl(
                value: state.dialValue,
                range: state.dialRange,
                step: state.dialStep,
                leftLabel: state.leftLabel,
                centerLabel: state.centerLabel,
                rightLabel: state.rightLabel,
                isEnabled: state.isAdjustable,
                onChange: onDialChange
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(.black.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
    }
}

struct CaptureProfessionalPlaceholderPanel: View {
    let state: CaptureProfessionalParameterState
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            CaptureProfessionalPanelHeader(
                kindTitle: state.kind.title,
                mode: state.mode,
                valueText: state.valueText,
                canUseAuto: false,
                canReset: false,
                onAuto: nil,
                onReset: nil,
                onClose: onClose
            )

            Text(state.hintText)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(.black.opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
    }
}

private struct CaptureProfessionalPanelHeader: View {
    let kindTitle: String
    let mode: CaptureProfessionalParameterMode
    let valueText: String
    let canUseAuto: Bool
    let canReset: Bool
    let onAuto: (() -> Void)?
    let onReset: (() -> Void)?
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(kindTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.96))

                    if mode != .auto {
                        Text(mode.text)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.88))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(modeBadgeColor, in: Capsule())
                    }
                }

                Text(headerValueText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.84))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }

            Spacer()

            HStack(spacing: 6) {
                if let onAuto {
                    actionButton(
                        title: "xmark",
                        isEnabled: true,
                        action: onClose,
                        isSymbol: true
                    )

                    if let onReset {
                        actionButton(
                            title: "arrow.counterclockwise",
                            isEnabled: canReset,
                            action: onReset,
                            isSymbol: true
                        )
                    }

                    autoToggleButton(
                        isOn: mode == .auto,
                        isEnabled: canUseAuto,
                        action: onAuto
                    )
                } else {
                    actionButton(
                        title: "xmark",
                        isEnabled: true,
                        action: onClose,
                        isSymbol: true
                    )
                }
            }
        }
    }

    private var modeBadgeColor: Color {
        switch mode {
        case .auto:
            return .blue.opacity(0.28)
        case .manual:
            return .teal.opacity(0.3)
        case .locked:
            return .orange.opacity(0.3)
        case .pending:
            return .white.opacity(0.12)
        case .disabled:
            return .red.opacity(0.26)
        }
    }

    private var headerValueText: String {
        guard valueText.hasPrefix("A·") else { return valueText }
        return valueText.replacingOccurrences(of: "A·", with: "Auto · ")
    }

    private func actionButton(
        title: String,
        isEnabled: Bool,
        action: @escaping () -> Void,
        isSymbol: Bool = false
    ) -> some View {
        Button(action: action) {
            Group {
                if isSymbol {
                    Image(systemName: title)
                } else {
                    Text(title)
                        .font(.caption2.weight(.semibold))
                }
            }
                .foregroundStyle(.white.opacity(isEnabled ? 0.9 : 0.5))
                .frame(width: 28, height: 28)
                .background(.black.opacity(isEnabled ? 0.3 : 0.15), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private func autoToggleButton(isOn: Bool, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            guard !isOn, isEnabled else { return }
            action()
        } label: {
            HStack(spacing: 5) {
                Text("Auto")
                    .font(.caption2.weight(.semibold))
                Circle()
                    .fill(isOn ? Color.teal.opacity(0.95) : Color.white.opacity(0.4))
                    .frame(width: 7, height: 7)
            }
            .foregroundStyle(.white.opacity((isOn || isEnabled) ? 0.92 : 0.5))
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background((isOn ? Color.teal.opacity(0.18) : Color.black.opacity(0.3)), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(
                        isOn ? Color.teal.opacity(0.55) : Color.white.opacity(0.12),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isOn || !isEnabled)
    }
}

private struct CaptureDialScaleControl: View {
    let value: Double
    let range: ClosedRange<Double>
    let step: Double
    let leftLabel: String
    let centerLabel: String
    let rightLabel: String
    let isEnabled: Bool
    let onChange: (Double) -> Void

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.black.opacity(0.25))
                    .frame(height: 18)

                HStack(spacing: 4) {
                    ForEach(0..<21, id: \.self) { index in
                        Capsule()
                            .fill(.white.opacity(index % 5 == 0 ? 0.75 : 0.38))
                            .frame(width: 1, height: index % 5 == 0 ? 10 : 6)
                        if index < 20 {
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(.horizontal, 10)

                Capsule()
                    .fill(isEnabled ? .teal.opacity(0.9) : .white.opacity(0.55))
                    .frame(width: 2, height: 14)
            }

            Slider(
                value: Binding(
                    get: { value },
                    set: onChange
                ),
                in: range,
                step: step
            )
            .tint(.teal.opacity(isEnabled ? 0.92 : 0.45))
            .disabled(!isEnabled)

            HStack {
                Text(leftLabel)
                Spacer()
                Text(centerLabel)
                Spacer()
                Text(rightLabel)
            }
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.6))
        }
    }
}

private struct CaptureLinearScaleControl: View {
    let value: Double
    let range: ClosedRange<Double>
    let step: Double
    let leftLabel: String
    let centerLabel: String
    let rightLabel: String
    let isEnabled: Bool
    let onChange: (Double) -> Void

    var body: some View {
        VStack(spacing: 8) {
            Slider(
                value: Binding(
                    get: { value },
                    set: onChange
                ),
                in: range,
                step: step
            )
            .tint(.teal.opacity(isEnabled ? 0.92 : 0.45))
            .disabled(!isEnabled)

            HStack {
                Text(leftLabel)
                Spacer()
                Text(centerLabel)
                Spacer()
                Text(rightLabel)
            }
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.6))
        }
    }
}

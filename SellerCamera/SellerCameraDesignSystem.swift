import SwiftUI
import UIKit

enum SellerCameraColorToken {
    static let canvas = Color(red: 0.020, green: 0.024, blue: 0.032)
    static let canvasElevated = Color(red: 0.040, green: 0.047, blue: 0.058)
    static let controlSurface = Color(red: 0.055, green: 0.061, blue: 0.074)
    static let controlSurfacePressed = Color(red: 0.075, green: 0.080, blue: 0.094)
    static let glassStroke = Color.white.opacity(0.10)
    static let textPrimary = Color.white.opacity(0.94)
    static let textSecondary = Color.white.opacity(0.66)
    static let textTertiary = Color.white.opacity(0.54)
    static let accent = Color(red: 1.00, green: 0.72, blue: 0.34)
    static let accentPressed = Color(red: 1.00, green: 0.64, blue: 0.24)
    static let success = Color(red: 0.42, green: 0.92, blue: 0.66)
    static let warning = Color(red: 1.00, green: 0.58, blue: 0.24)
    static let destructive = Color(red: 1.00, green: 0.36, blue: 0.32)
    static let focus = accent
    static let disabled = Color.white.opacity(0.30)

    static func canvasElevated(reduceTransparency: Bool) -> Color {
        reduceTransparency ? Color(red: 0.030, green: 0.034, blue: 0.044) : canvasElevated
    }

    static func controlSurface(reduceTransparency: Bool) -> Color {
        reduceTransparency ? Color(red: 0.048, green: 0.052, blue: 0.064) : controlSurface.opacity(0.82)
    }

    static func glassStroke(increaseContrast: Bool) -> Color {
        increaseContrast ? Color.white.opacity(0.22) : glassStroke
    }

    static func textSecondary(increaseContrast: Bool) -> Color {
        increaseContrast ? Color.white.opacity(0.78) : textSecondary
    }

    static func textTertiary(increaseContrast: Bool) -> Color {
        increaseContrast ? Color.white.opacity(0.58) : textTertiary
    }

    static func disabled(increaseContrast: Bool) -> Color {
        increaseContrast ? Color.white.opacity(0.42) : disabled
    }
}

enum SellerCameraColor {
    static let canvasBackground = SellerCameraColorToken.canvas
    static let controlSurfacePrimary = SellerCameraColorToken.controlSurface
    static let controlSurfaceSecondary = SellerCameraColorToken.canvasElevated
    static let controlSurfacePressed = SellerCameraColorToken.controlSurfacePressed
    static let controlSurfaceDisabled = SellerCameraColorToken.controlSurface.opacity(0.30)
    static let textPrimary = SellerCameraColorToken.textPrimary
    static let textSecondary = SellerCameraColorToken.textSecondary
    static let textTertiary = SellerCameraColorToken.textTertiary
    static let textDisabled = SellerCameraColorToken.disabled
    static let accentPrimary = SellerCameraColorToken.accent
    static let accentWarning = SellerCameraColorToken.warning
    static let accentLocked = SellerCameraColorToken.accent
    static let accentSuccess = SellerCameraColorToken.success
    static let divider = SellerCameraColorToken.glassStroke
    static let viewfinderBorder = Color.white.opacity(0.10)
    static let focusNormal = SellerCameraColorToken.focus
    static let focusLocked = SellerCameraColorToken.accent
    static let focusWarning = SellerCameraColorToken.warning

    static func controlSurfacePrimary(reduceTransparency: Bool) -> Color {
        SellerCameraColorToken.controlSurface(reduceTransparency: reduceTransparency)
    }

    static func divider(increaseContrast: Bool) -> Color {
        SellerCameraColorToken.glassStroke(increaseContrast: increaseContrast)
    }
}

enum SellerCameraTypographyToken {
    static let caption = Font.system(size: 10, weight: .medium)
    static let label = Font.system(size: 11, weight: .semibold)
    static let parameter = Font.system(size: 9, weight: .semibold)
    static let parameterActive = Font.system(size: 9, weight: .bold)
    static let status = Font.system(size: 11, weight: .medium)
    static let value = Font.system(size: 15, weight: .semibold)
    static let valueLarge = Font.system(size: 17, weight: .semibold)
    static let rulerMajor = Font.system(size: 8.5, weight: .semibold)
    static let rulerMinor = Font.system(size: 7, weight: .medium)
    static let control = Font.caption2.weight(.semibold)
}

enum SellerCameraTypography {
    static let toolLabel = SellerCameraTypographyToken.control
    static let parameterName = SellerCameraTypographyToken.parameter
    static let parameterValue = SellerCameraTypographyToken.value
    static let rulerPrimaryValue = SellerCameraTypographyToken.label.weight(.bold)
    static let rulerSecondaryValue = SellerCameraTypographyToken.rulerMajor
    static let statusLabel = SellerCameraTypographyToken.status
    static let previewCountdown = Font.system(size: 40, weight: .bold, design: .rounded)
    static let glyphMicroLabel = Font.system(size: 6, weight: .bold)
    static let glyphNanoLabel = Font.system(size: 5.5, weight: .bold)
}

enum SellerCameraSpacingToken {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 6
    static let md: CGFloat = 8
    static let lg: CGFloat = 12
    static let xl: CGFloat = 16
    static let xxl: CGFloat = 20
    static let hitTarget: CGFloat = 44
}

enum SellerCameraSpacing {
    static let xxs = SellerCameraSpacingToken.xxs
    static let xs = SellerCameraSpacingToken.xs
    static let sm = SellerCameraSpacingToken.sm
    static let md = SellerCameraSpacingToken.md
    static let lg = SellerCameraSpacingToken.lg
    static let xl = SellerCameraSpacingToken.xl
    static let xxl = SellerCameraSpacingToken.xxl
    static let hitTarget = SellerCameraSpacingToken.hitTarget
}

enum SellerCameraShapeToken {
    static let smallRadius: CGFloat = 7
    static let controlRadius: CGFloat = 12
    static let panelRadius: CGFloat = 18
    static let compactPanelRadius: CGFloat = 14
    static let capsuleRadius: CGFloat = 999
    static let shutterRingWidth: CGFloat = 2.4
    static let focusCornerLength: CGFloat = 18
}

enum SellerCameraRadius {
    static let compact = SellerCameraShapeToken.smallRadius
    static let control = SellerCameraShapeToken.controlRadius
    static let capsule = SellerCameraShapeToken.capsuleRadius
    static let panel = SellerCameraShapeToken.panelRadius
    static let viewfinder: CGFloat = 16
}

enum SellerCameraControlState: Equatable {
    case normal
    case selected
    case active
    case locked
    case warning
    case disabled

    var accessibilityText: String {
        switch self {
        case .normal:
            return "可用"
        case .selected:
            return "已选中"
        case .active:
            return "正在调节"
        case .locked:
            return "已锁定"
        case .warning:
            return "需要注意"
        case .disabled:
            return "不可用"
        }
    }
}

struct SellerCameraControlVisualStyle {
    let foreground: Color
    let secondaryForeground: Color
    let fill: Color
    let stroke: Color
    let underline: Color
    let shadow: Color
    let titleFont: Font
    let valueFont: Font

    static func style(for state: SellerCameraControlState) -> SellerCameraControlVisualStyle {
        switch state {
        case .normal:
            return SellerCameraControlVisualStyle(
                foreground: SellerCameraColor.textSecondary,
                secondaryForeground: SellerCameraColor.textSecondary,
                fill: SellerCameraColor.controlSurfacePrimary.opacity(0.46),
                stroke: SellerCameraColor.divider.opacity(0.56),
                underline: .clear,
                shadow: .clear,
                titleFont: SellerCameraTypography.parameterName,
                valueFont: SellerCameraTypography.parameterValue
            )
        case .selected:
            return SellerCameraControlVisualStyle(
                foreground: SellerCameraColor.accentPrimary,
                secondaryForeground: SellerCameraColor.textPrimary,
                fill: SellerCameraColor.accentPrimary.opacity(0.12),
                stroke: SellerCameraColor.accentPrimary.opacity(0.34),
                underline: SellerCameraColor.accentPrimary,
                shadow: SellerCameraColor.accentPrimary.opacity(0.14),
                titleFont: SellerCameraTypographyToken.parameterActive,
                valueFont: SellerCameraTypography.parameterValue.weight(.bold)
            )
        case .active:
            return SellerCameraControlVisualStyle(
                foreground: SellerCameraColor.accentPrimary,
                secondaryForeground: SellerCameraColor.textPrimary,
                fill: SellerCameraColor.accentPrimary.opacity(0.16),
                stroke: SellerCameraColor.accentPrimary.opacity(0.44),
                underline: SellerCameraColor.accentPrimary,
                shadow: SellerCameraColor.accentPrimary.opacity(0.18),
                titleFont: SellerCameraTypographyToken.parameterActive,
                valueFont: SellerCameraTypography.parameterValue.weight(.bold)
            )
        case .locked:
            return SellerCameraControlVisualStyle(
                foreground: SellerCameraColor.accentLocked,
                secondaryForeground: SellerCameraColor.textPrimary,
                fill: SellerCameraColor.accentLocked.opacity(0.12),
                stroke: SellerCameraColor.accentLocked.opacity(0.32),
                underline: SellerCameraColor.accentLocked.opacity(0.82),
                shadow: SellerCameraColor.accentLocked.opacity(0.12),
                titleFont: SellerCameraTypographyToken.parameterActive,
                valueFont: SellerCameraTypography.parameterValue.weight(.semibold)
            )
        case .warning:
            return SellerCameraControlVisualStyle(
                foreground: SellerCameraColor.accentWarning,
                secondaryForeground: SellerCameraColor.textPrimary,
                fill: SellerCameraColor.accentWarning.opacity(0.13),
                stroke: SellerCameraColor.accentWarning.opacity(0.36),
                underline: SellerCameraColor.accentWarning,
                shadow: SellerCameraColor.accentWarning.opacity(0.12),
                titleFont: SellerCameraTypographyToken.parameterActive,
                valueFont: SellerCameraTypography.parameterValue.weight(.semibold)
            )
        case .disabled:
            return SellerCameraControlVisualStyle(
                foreground: SellerCameraColor.textDisabled,
                secondaryForeground: SellerCameraColor.textDisabled,
                fill: SellerCameraColor.controlSurfaceDisabled,
                stroke: SellerCameraColor.divider.opacity(0.34),
                underline: .clear,
                shadow: .clear,
                titleFont: SellerCameraTypography.parameterName,
                valueFont: SellerCameraTypography.parameterValue
            )
        }
    }
}

enum SellerCameraMotionToken {
    static let press = Animation.easeOut(duration: 0.10)
    static let selection = Animation.spring(response: 0.22, dampingFraction: 0.86)
    static let panelPresent = Animation.easeOut(duration: 0.18)
    static let panelDismiss = Animation.easeOut(duration: 0.14)
    static let snap = Animation.spring(response: 0.18, dampingFraction: 0.92)
    static let modeSwitch = Animation.easeInOut(duration: 0.18)
    static let focus = Animation.spring(response: 0.22, dampingFraction: 0.78)
    static let warning = Animation.easeOut(duration: 0.16)
    static let reducedMotion = Animation.easeOut(duration: 0.08)

    static func resolved(_ animation: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? reducedMotion : animation
    }
}

struct SellerCameraRulerStyle {
    let containerRadius: CGFloat
    let tickSelectedWidth: CGFloat
    let tickNormalWidth: CGFloat
    let majorTickHeight: CGFloat
    let mediumTickHeight: CGFloat
    let minorTickHeight: CGFloat
    let selectedTickHeight: CGFloat
    let indicatorWidth: CGFloat
    let indicatorHeight: CGFloat
    let valueBadgeHeight: CGFloat
    let activeLift: CGFloat

    static let professional = SellerCameraRulerStyle(
        containerRadius: SellerCameraRadius.control,
        tickSelectedWidth: 1.6,
        tickNormalWidth: 0.9,
        majorTickHeight: 16,
        mediumTickHeight: 12,
        minorTickHeight: 9,
        selectedTickHeight: 22,
        indicatorWidth: 1.4,
        indicatorHeight: 30,
        valueBadgeHeight: 22,
        activeLift: 2
    )

    static let compactOption = SellerCameraRulerStyle(
        containerRadius: SellerCameraRadius.control,
        tickSelectedWidth: 1.6,
        tickNormalWidth: 0.9,
        majorTickHeight: 18,
        mediumTickHeight: 13,
        minorTickHeight: 10,
        selectedTickHeight: 22,
        indicatorWidth: 1.4,
        indicatorHeight: 20,
        valueBadgeHeight: 24,
        activeLift: 1
    )
}

enum SellerCameraGlyphProminence {
    case compact
    case standard
    case emphasized
    case status
}

enum SellerCameraGlyphMetrics {
    static let compactSize: CGFloat = 10
    static let standardSize: CGFloat = 12
    static let emphasizedSize: CGFloat = 16
    static let statusSize: CGFloat = 9
    static let compactFrame: CGFloat = 14
    static let standardFrame: CGFloat = 18
    static let largeFrame: CGFloat = 30
    static let regularWeight: Font.Weight = .semibold
    static let selectedWeight: Font.Weight = .bold
    static let statusWeight: Font.Weight = .semibold
    static let hairlineWidth: CGFloat = 1
    static let standardStrokeWidth: CGFloat = 1.2
    static let emphasizedStrokeWidth: CGFloat = 1.45
    static let compactDot: CGFloat = 2
    static let standardDot: CGFloat = 3
    static let emphasizedDot: CGFloat = 4
}

struct SellerCameraGlyphStyleModifier: ViewModifier {
    let state: SellerCameraControlState
    let prominence: SellerCameraGlyphProminence

    func body(content: Content) -> some View {
        let controlStyle = SellerCameraControlVisualStyle.style(for: state)
        content
            .font(.system(size: symbolSize, weight: symbolWeight))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(state == .normal ? controlStyle.secondaryForeground : controlStyle.foreground)
            .frame(width: frameSize, height: frameSize)
    }

    private var symbolSize: CGFloat {
        switch prominence {
        case .compact:
            return SellerCameraGlyphMetrics.compactSize
        case .standard:
            return SellerCameraGlyphMetrics.standardSize
        case .emphasized:
            return SellerCameraGlyphMetrics.emphasizedSize
        case .status:
            return SellerCameraGlyphMetrics.statusSize
        }
    }

    private var symbolWeight: Font.Weight {
        switch state {
        case .selected, .active, .locked, .warning:
            return SellerCameraGlyphMetrics.selectedWeight
        case .normal, .disabled:
            return prominence == .status ? SellerCameraGlyphMetrics.statusWeight : SellerCameraGlyphMetrics.regularWeight
        }
    }

    private var frameSize: CGFloat {
        switch prominence {
        case .compact, .status:
            return SellerCameraGlyphMetrics.compactFrame
        case .standard:
            return SellerCameraGlyphMetrics.standardFrame
        case .emphasized:
            return SellerCameraGlyphMetrics.largeFrame
        }
    }
}

enum SellerCameraPreviewMetrics {
    static let hairlineWidth: CGFloat = 0.8
    static let standardLineWidth: CGFloat = 1.1
    static let emphasizedLineWidth: CGFloat = 1.6
    static let contrastOutlineWidth: CGFloat = 3.2
    static let gridOpacity: Double = 0.30
    static let guideMaskOpacity: Double = 0.28
    static let guideBorderOpacity: Double = 0.0
    static let levelInactiveOpacity: Double = 0.78
    static let levelActiveOpacity: Double = 0.92
    static let levelReferenceOpacity: Double = 0.34
    static let hudBackgroundOpacity: Double = 0.56
    static let hudActiveBackgroundOpacity: Double = 0.42
    static let focusOuterFrame: CGFloat = 84
    static let focusOuterPathSize: CGFloat = 80
    static let focusInnerFrame: CGFloat = 70
    static let focusInnerPathSize: CGFloat = 66
    static let focusCornerLength: CGFloat = 18
    static let focusInnerCornerLength: CGFloat = 13
    static let focusInset: CGFloat = 2
    static let focusBadgeOffset: CGFloat = 0
    static let focusIconOffset: CGFloat = -47
    static let focusLineWidth: CGFloat = 1.6
    static let focusWarningLineWidth: CGFloat = 1.9
    static let focusInnerLineWidth: CGFloat = 1.1
    static let levelShortTickWidth: CGFloat = 1.4
    static let levelCenterTickWidth: CGFloat = 1.6
    static let levelShortTickHeight: CGFloat = 8
    static let levelHorizontalWidth: CGFloat = 96
    static let levelHorizontalHeight: CGFloat = 2
    static let levelCrossSize: CGFloat = 24
    static let guideBorderWidth: CGFloat = 0.0
}

enum SellerCameraPreviewStyle {
    static let overlayPrimary = SellerCameraColor.textPrimary
    static let overlaySecondary = SellerCameraColor.textSecondary
    static let overlayMuted = SellerCameraColor.textTertiary
    static let contrastOutline = Color.black.opacity(0.42)
    static let maskFill = Color.black.opacity(SellerCameraPreviewMetrics.guideMaskOpacity)
    static let gridLine = SellerCameraColor.textPrimary.opacity(SellerCameraPreviewMetrics.gridOpacity)
    static let guideBorder = SellerCameraColor.textPrimary.opacity(SellerCameraPreviewMetrics.guideBorderOpacity)
    static let hudSurface = Color.black.opacity(SellerCameraPreviewMetrics.hudBackgroundOpacity)
    static let hudStroke = SellerCameraColor.divider.opacity(0.70)
    static let focusNormal = SellerCameraColor.accentPrimary
    static let focusConfirmed = SellerCameraColor.accentSuccess
    static let focusLocked = SellerCameraColor.accentSuccess
    static let focusUnlocked = Color(red: 0.48, green: 0.75, blue: 1.0)
    static let focusWarning = SellerCameraColor.accentWarning
    static let levelNeutral = SellerCameraColor.textPrimary
    static let levelAligned = SellerCameraColor.accentSuccess
    static let levelWarning = SellerCameraColor.accentWarning
}

enum SellerCameraHapticToken: Hashable {
    case selection
    case fineMode
    case boundary
    case lock
    case capture
    case warning
}

@MainActor
enum SellerCameraHaptic {
    private static var lastFireAt: [String: Date] = [:]

    static func play(
        _ token: SellerCameraHapticToken,
        signature: String? = nil,
        minimumInterval: TimeInterval = 0.06
    ) {
        let key = signature ?? String(describing: token)
        let now = Date()
        if let lastDate = lastFireAt[key], now.timeIntervalSince(lastDate) < minimumInterval {
            return
        }
        lastFireAt[key] = now

        switch token {
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        case .fineMode:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        case .boundary:
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.72)
        case .lock:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.82)
        case .capture:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }
}

enum SellerCameraRulerGesturePhase {
    case idle
    case pressing
    case dragging
    case decelerating
    case snapping
}

struct SellerCameraRulerGestureState {
    var phase: SellerCameraRulerGesturePhase = .idle
    var startValue: Double = 0
    var translation: CGFloat = 0
    var velocity: CGFloat = 0
    var predictedTranslation: CGFloat = 0
    var candidateStep: Int = 0
    var committedStep: Int = 0
    var generation: UInt64 = 0
}

struct SellerCameraRulerMetrics {
    let tickSpacing: CGFloat
    let selectedTickWidth: CGFloat
    let normalTickWidth: CGFloat
    let majorTickHeight: CGFloat
    let minorTickHeight: CGFloat
    let selectedTickHeight: CGFloat
    let valueBadgeHeight: CGFloat

    static let parameter = SellerCameraRulerMetrics(
        tickSpacing: 34,
        selectedTickWidth: 1.6,
        normalTickWidth: 0.9,
        majorTickHeight: 16,
        minorTickHeight: 9,
        selectedTickHeight: 21,
        valueBadgeHeight: 22
    )

    static let discreteOption = SellerCameraRulerMetrics(
        tickSpacing: 64,
        selectedTickWidth: 1.6,
        normalTickWidth: 0.9,
        majorTickHeight: 18,
        minorTickHeight: 10,
        selectedTickHeight: 22,
        valueBadgeHeight: 24
    )
}

enum SellerCameraRulerHapticPolicy: Equatable {
    case everyAcceptedStep
    case majorTick
    case semanticAnchor
    case discreteSelection
    case quiet
}

struct SellerCameraRulerInteractionProfile {
    let pointsPerStep: CGFloat
    let sensitivity: CGFloat
    let fineSensitivity: CGFloat
    let ultraFineSensitivity: CGFloat
    let maximumFlingSteps: Int
    let velocityThreshold: CGFloat
    let boundaryResistance: CGFloat
    let snapAnimation: Animation
    let allowsContinuousValue: Bool
    let inertiaScale: CGFloat
    let minimumDragDeadZone: CGFloat
    let maximumStepsPerUpdate: Int
    let stepCooldown: TimeInterval
    let hapticMinimumInterval: TimeInterval
    let hapticPolicy: SellerCameraRulerHapticPolicy
    let fineModeLiftThreshold: CGFloat
    let ultraFineModeLiftThreshold: CGFloat
    let maximumVelocityMultiplier: CGFloat
    let inertiaProjectionDuration: TimeInterval

    init(
        pointsPerStep: CGFloat,
        sensitivity: CGFloat,
        fineSensitivity: CGFloat,
        ultraFineSensitivity: CGFloat,
        maximumFlingSteps: Int,
        velocityThreshold: CGFloat,
        boundaryResistance: CGFloat,
        snapAnimation: Animation,
        allowsContinuousValue: Bool,
        inertiaScale: CGFloat,
        minimumDragDeadZone: CGFloat = 4,
        maximumStepsPerUpdate: Int = 1,
        stepCooldown: TimeInterval = 0.07,
        hapticMinimumInterval: TimeInterval = 0.09,
        hapticPolicy: SellerCameraRulerHapticPolicy = .majorTick,
        fineModeLiftThreshold: CGFloat = 42,
        ultraFineModeLiftThreshold: CGFloat = 92,
        maximumVelocityMultiplier: CGFloat = 1.18,
        inertiaProjectionDuration: TimeInterval = 0.12
    ) {
        self.pointsPerStep = pointsPerStep
        self.sensitivity = sensitivity
        self.fineSensitivity = fineSensitivity
        self.ultraFineSensitivity = ultraFineSensitivity
        self.maximumFlingSteps = maximumFlingSteps
        self.velocityThreshold = velocityThreshold
        self.boundaryResistance = boundaryResistance
        self.snapAnimation = snapAnimation
        self.allowsContinuousValue = allowsContinuousValue
        self.inertiaScale = inertiaScale
        self.minimumDragDeadZone = minimumDragDeadZone
        self.maximumStepsPerUpdate = maximumStepsPerUpdate
        self.stepCooldown = stepCooldown
        self.hapticMinimumInterval = hapticMinimumInterval
        self.hapticPolicy = hapticPolicy
        self.fineModeLiftThreshold = fineModeLiftThreshold
        self.ultraFineModeLiftThreshold = ultraFineModeLiftThreshold
        self.maximumVelocityMultiplier = maximumVelocityMultiplier
        self.inertiaProjectionDuration = inertiaProjectionDuration
    }

    static let continuousPrecision = SellerCameraRulerInteractionProfile(
        pointsPerStep: 34,
        sensitivity: 1.55,
        fineSensitivity: 0.68,
        ultraFineSensitivity: 0.32,
        maximumFlingSteps: 2,
        velocityThreshold: 48,
        boundaryResistance: 0.38,
        snapAnimation: SellerCameraMotionToken.snap,
        allowsContinuousValue: true,
        inertiaScale: 0.42,
        minimumDragDeadZone: 5,
        maximumStepsPerUpdate: 1,
        stepCooldown: 0.065,
        hapticMinimumInterval: 0.09,
        hapticPolicy: .majorTick,
        maximumVelocityMultiplier: 1.16
    )

    static let discreteTechnical = SellerCameraRulerInteractionProfile(
        pointsPerStep: 32,
        sensitivity: 1.72,
        fineSensitivity: 0.82,
        ultraFineSensitivity: 0.44,
        maximumFlingSteps: 2,
        velocityThreshold: 64,
        boundaryResistance: 0.34,
        snapAnimation: SellerCameraMotionToken.snap,
        allowsContinuousValue: false,
        inertiaScale: 0.38,
        minimumDragDeadZone: 5,
        maximumStepsPerUpdate: 4,
        stepCooldown: 0.05,
        hapticMinimumInterval: 0.09,
        hapticPolicy: .majorTick,
        maximumVelocityMultiplier: 1.22
    )

    static let ratioOutputQuality = SellerCameraRulerInteractionProfile(
        pointsPerStep: 64,
        sensitivity: 1.0,
        fineSensitivity: 1.0,
        ultraFineSensitivity: 1.0,
        maximumFlingSteps: 1,
        velocityThreshold: 58,
        boundaryResistance: 0.34,
        snapAnimation: SellerCameraMotionToken.snap,
        allowsContinuousValue: false,
        inertiaScale: 0.28,
        minimumDragDeadZone: 6,
        maximumStepsPerUpdate: 1,
        stepCooldown: 0.08,
        hapticMinimumInterval: 0.11,
        hapticPolicy: .discreteSelection,
        maximumVelocityMultiplier: 1.0
    )

    static let shutterTechnical = SellerCameraRulerInteractionProfile(
        pointsPerStep: 36,
        sensitivity: 1.36,
        fineSensitivity: 0.55,
        ultraFineSensitivity: 0.26,
        maximumFlingSteps: 1,
        velocityThreshold: 76,
        boundaryResistance: 0.34,
        snapAnimation: SellerCameraMotionToken.snap,
        allowsContinuousValue: false,
        inertiaScale: 0.32,
        minimumDragDeadZone: 6,
        maximumStepsPerUpdate: 1,
        stepCooldown: 0.075,
        hapticMinimumInterval: 0.11,
        hapticPolicy: .majorTick,
        maximumVelocityMultiplier: 1.08
    )

    static let exposurePrecision = SellerCameraRulerInteractionProfile(
        pointsPerStep: 34,
        sensitivity: 1.58,
        fineSensitivity: 0.62,
        ultraFineSensitivity: 0.30,
        maximumFlingSteps: 1,
        velocityThreshold: 54,
        boundaryResistance: 0.38,
        snapAnimation: SellerCameraMotionToken.snap,
        allowsContinuousValue: true,
        inertiaScale: 0.24,
        minimumDragDeadZone: 6,
        maximumStepsPerUpdate: 1,
        stepCooldown: 0.06,
        hapticMinimumInterval: 0.10,
        hapticPolicy: .semanticAnchor,
        maximumVelocityMultiplier: 1.12
    )

    static let tintPrecision = SellerCameraRulerInteractionProfile(
        pointsPerStep: 34,
        sensitivity: 1.68,
        fineSensitivity: 0.66,
        ultraFineSensitivity: 0.32,
        maximumFlingSteps: 2,
        velocityThreshold: 58,
        boundaryResistance: 0.38,
        snapAnimation: SellerCameraMotionToken.snap,
        allowsContinuousValue: true,
        inertiaScale: 0.34,
        minimumDragDeadZone: 5,
        maximumStepsPerUpdate: 2,
        stepCooldown: 0.055,
        hapticMinimumInterval: 0.095,
        hapticPolicy: .majorTick,
        maximumVelocityMultiplier: 1.18
    )

    static let manualFocusPrecision = SellerCameraRulerInteractionProfile(
        pointsPerStep: 20,
        sensitivity: 2.05,
        fineSensitivity: 0.50,
        ultraFineSensitivity: 0.20,
        maximumFlingSteps: 2,
        velocityThreshold: 64,
        boundaryResistance: 0.38,
        snapAnimation: SellerCameraMotionToken.snap,
        allowsContinuousValue: true,
        inertiaScale: 0.16,
        minimumDragDeadZone: 5,
        maximumStepsPerUpdate: 6,
        stepCooldown: 0.045,
        hapticMinimumInterval: 0.11,
        hapticPolicy: .quiet,
        maximumVelocityMultiplier: 1.20
    )

    static let zoomPrecision = SellerCameraRulerInteractionProfile(
        pointsPerStep: 96,
        sensitivity: 2.75,
        fineSensitivity: 0.82,
        ultraFineSensitivity: 0.34,
        maximumFlingSteps: 2,
        velocityThreshold: 62,
        boundaryResistance: 0.38,
        snapAnimation: SellerCameraMotionToken.snap,
        allowsContinuousValue: true,
        inertiaScale: 0.18,
        minimumDragDeadZone: 5,
        maximumStepsPerUpdate: 1,
        stepCooldown: 0.05,
        hapticMinimumInterval: 0.13,
        hapticPolicy: .semanticAnchor,
        maximumVelocityMultiplier: 1.10
    )
}

extension SellerCameraRulerInteractionProfile {
    static func professionalParameter(_ kind: CaptureProfessionalParameterKind) -> SellerCameraRulerInteractionProfile {
        switch kind {
        case .shutter:
            return .shutterTechnical
        case .iso, .whiteBalance:
            return .discreteTechnical
        case .tint:
            return .tintPrecision
        case .exposureCompensation:
            return .exposurePrecision
        case .focus:
            return .manualFocusPrecision
        default:
            return .continuousPrecision
        }
    }

    func scrubSensitivity(forVerticalTranslation verticalTranslation: CGFloat, predictedDelta: CGFloat = 0) -> CGFloat {
        let lift = max(0, -verticalTranslation)
        if lift > ultraFineModeLiftThreshold { return ultraFineSensitivity }
        if lift > fineModeLiftThreshold { return fineSensitivity }
        return sensitivity * velocityMultiplier(for: predictedDelta)
    }

    func scrubSensitivity(forVerticalTranslation verticalTranslation: CGFloat, velocity: CGFloat) -> CGFloat {
        scrubSensitivity(
            forVerticalTranslation: verticalTranslation,
            predictedDelta: projectedDelta(forVelocity: velocity)
        )
    }

    func effectivePointsPerStep(
        baseThreshold: CGFloat,
        verticalTranslation: CGFloat,
        predictedDelta: CGFloat = 0
    ) -> (threshold: CGFloat, sensitivity: CGFloat) {
        let resolvedSensitivity = max(0.05, scrubSensitivity(forVerticalTranslation: verticalTranslation, predictedDelta: predictedDelta))
        let threshold = max(minimumDragDeadZone, max(1, baseThreshold) / resolvedSensitivity)
        return (threshold, resolvedSensitivity)
    }

    func effectivePointsPerStep(
        baseThreshold: CGFloat,
        verticalTranslation: CGFloat,
        velocity: CGFloat
    ) -> (threshold: CGFloat, sensitivity: CGFloat) {
        effectivePointsPerStep(
            baseThreshold: baseThreshold,
            verticalTranslation: verticalTranslation,
            predictedDelta: projectedDelta(forVelocity: velocity)
        )
    }

    func dragStepInfo(
        delta: CGFloat,
        baseThreshold: CGFloat,
        verticalTranslation: CGFloat,
        predictedDelta: CGFloat = 0
    ) -> (rawStepCount: Int, effectiveThreshold: CGFloat, sensitivity: CGFloat) {
        let resolved = effectivePointsPerStep(
            baseThreshold: baseThreshold,
            verticalTranslation: verticalTranslation,
            predictedDelta: predictedDelta
        )
        guard abs(delta) >= resolved.threshold else {
            return (0, resolved.threshold, resolved.sensitivity)
        }
        let rawStepCount = Int((delta / resolved.threshold).rounded(.towardZero))
        return (rawStepCount, resolved.threshold, resolved.sensitivity)
    }

    func dragStepInfo(
        delta: CGFloat,
        baseThreshold: CGFloat,
        verticalTranslation: CGFloat,
        velocity: CGFloat
    ) -> (rawStepCount: Int, effectiveThreshold: CGFloat, sensitivity: CGFloat) {
        dragStepInfo(
            delta: delta,
            baseThreshold: baseThreshold,
            verticalTranslation: verticalTranslation,
            predictedDelta: projectedDelta(forVelocity: velocity)
        )
    }

    func cappedStepCount(_ stepCount: Int, externalMaximum: Int? = nil) -> Int {
        let maximum = max(1, min(maximumStepsPerUpdate, externalMaximum ?? maximumStepsPerUpdate))
        return max(-maximum, min(maximum, stepCount))
    }

    func inertialRawStepCount(
        translationWidth: CGFloat,
        predictedEndTranslationWidth: CGFloat,
        baseThreshold: CGFloat,
        currentSensitivity: CGFloat
    ) -> Int {
        guard currentSensitivity >= 1 else { return 0 }
        let predictedDelta = predictedEndTranslationWidth - translationWidth
        guard abs(predictedDelta) >= velocityThreshold else { return 0 }
        let rawStepCount = Int(((predictedDelta * inertiaScale) / max(1, baseThreshold)).rounded(.towardZero))
        return max(-maximumFlingSteps, min(maximumFlingSteps, rawStepCount))
    }

    func inertialRawStepCount(
        releaseVelocity: CGFloat,
        baseThreshold: CGFloat,
        currentSensitivity: CGFloat
    ) -> Int {
        guard currentSensitivity >= 1 else { return 0 }
        let projectedDelta = projectedDelta(forVelocity: releaseVelocity)
        guard abs(projectedDelta) >= velocityThreshold else { return 0 }
        let rawStepCount = Int(((projectedDelta * inertiaScale) / max(1, baseThreshold)).rounded(.towardZero))
        return max(-maximumFlingSteps, min(maximumFlingSteps, rawStepCount))
    }

    func shouldTriggerHaptic(step: Int, selectedIndex: Int, majorTickIndexes: Set<Int>) -> Bool {
        guard step != 0 else { return false }
        switch hapticPolicy {
        case .everyAcceptedStep, .discreteSelection:
            return true
        case .majorTick:
            return abs(step) > 1 || majorTickIndexes.contains(selectedIndex)
        case .semanticAnchor:
            return majorTickIndexes.contains(selectedIndex)
        case .quiet:
            return false
        }
    }

    private func velocityMultiplier(for predictedDelta: CGFloat) -> CGFloat {
        guard maximumVelocityMultiplier > 1 else { return 1 }
        let speed = abs(predictedDelta)
        guard speed > velocityThreshold else { return 1 }
        let progress = min(1, (speed - velocityThreshold) / max(velocityThreshold, 1))
        let easedProgress = progress * progress * (3 - 2 * progress)
        return 1 + (maximumVelocityMultiplier - 1) * easedProgress
    }

    private func projectedDelta(forVelocity velocity: CGFloat) -> CGFloat {
        velocity * CGFloat(inertiaProjectionDuration)
    }
}

struct SellerCameraGlassPanelModifier: ViewModifier {
    let radius: CGFloat
    let baseOpacity: Double
    let strokeOpacity: Double
    let shadowOpacity: Double

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let increaseContrast = UIAccessibility.isDarkerSystemColorsEnabled

        content
            .background(
                shape.fill(
                    SellerCameraColorToken.controlSurface(reduceTransparency: reduceTransparency)
                        .opacity(reduceTransparency ? 1 : baseOpacity)
                )
            )
            .background {
                if !reduceTransparency {
                    shape.fill(.thinMaterial)
                }
            }
            .overlay(
                shape.stroke(
                    SellerCameraColorToken.glassStroke(increaseContrast: increaseContrast)
                        .opacity(increaseContrast ? 1 : strokeOpacity),
                    lineWidth: increaseContrast ? 1.2 : 1
                )
            )
            .shadow(
                color: Color.black.opacity(reduceTransparency ? 0.20 : shadowOpacity),
                radius: reduceTransparency ? 8 : 16,
                x: 0,
                y: reduceTransparency ? 6 : 10
            )
    }
}

extension View {
    func sellerCameraGlyphStyle(
        state: SellerCameraControlState = .normal,
        prominence: SellerCameraGlyphProminence = .standard
    ) -> some View {
        modifier(SellerCameraGlyphStyleModifier(state: state, prominence: prominence))
    }

    func sellerCameraGlassPanel(
        radius: CGFloat = SellerCameraShapeToken.panelRadius,
        baseOpacity: Double = 0.74,
        strokeOpacity: Double = 1,
        shadowOpacity: Double = 0.30
    ) -> some View {
        modifier(
            SellerCameraGlassPanelModifier(
                radius: radius,
                baseOpacity: baseOpacity,
                strokeOpacity: strokeOpacity,
                shadowOpacity: shadowOpacity
            )
        )
    }
}

struct SellerCameraPressButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.94
    var disabledScale: CGFloat = 0.98

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : (isEnabled ? 1 : disabledScale))
            .opacity(isEnabled ? 1 : 0.58)
            .animation(SellerCameraMotionToken.resolved(SellerCameraMotionToken.press, reduceMotion: reduceMotion), value: configuration.isPressed)
            .animation(SellerCameraMotionToken.resolved(SellerCameraMotionToken.selection, reduceMotion: reduceMotion), value: isEnabled)
    }
}

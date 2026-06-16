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
    static let textTertiary = Color.white.opacity(0.42)
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

enum SellerCameraShapeToken {
    static let smallRadius: CGFloat = 7
    static let controlRadius: CGFloat = 12
    static let panelRadius: CGFloat = 18
    static let compactPanelRadius: CGFloat = 14
    static let capsuleRadius: CGFloat = 999
    static let shutterRingWidth: CGFloat = 2.4
    static let focusCornerLength: CGFloat = 18
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

    static let continuousPrecision = SellerCameraRulerInteractionProfile(
        pointsPerStep: 34,
        sensitivity: 1.8,
        fineSensitivity: 0.75,
        ultraFineSensitivity: 0.35,
        maximumFlingSteps: 2,
        velocityThreshold: 48,
        boundaryResistance: 0.38,
        snapAnimation: SellerCameraMotionToken.snap,
        allowsContinuousValue: true,
        inertiaScale: 0.50
    )

    static let discreteTechnical = SellerCameraRulerInteractionProfile(
        pointsPerStep: 34,
        sensitivity: 1.4,
        fineSensitivity: 0.82,
        ultraFineSensitivity: 0.50,
        maximumFlingSteps: 4,
        velocityThreshold: 56,
        boundaryResistance: 0.34,
        snapAnimation: SellerCameraMotionToken.snap,
        allowsContinuousValue: false,
        inertiaScale: 0.75
    )

    static let ratioOutputQuality = SellerCameraRulerInteractionProfile(
        pointsPerStep: 64,
        sensitivity: 1.0,
        fineSensitivity: 1.0,
        ultraFineSensitivity: 1.0,
        maximumFlingSteps: 2,
        velocityThreshold: 52,
        boundaryResistance: 0.34,
        snapAnimation: SellerCameraMotionToken.snap,
        allowsContinuousValue: false,
        inertiaScale: 0.55
    )

    static let shutterTechnical = SellerCameraRulerInteractionProfile(
        pointsPerStep: 34,
        sensitivity: 1.8,
        fineSensitivity: 0.75,
        ultraFineSensitivity: 0.35,
        maximumFlingSteps: 5,
        velocityThreshold: 60,
        boundaryResistance: 0.34,
        snapAnimation: SellerCameraMotionToken.snap,
        allowsContinuousValue: false,
        inertiaScale: 1.0
    )

    static let exposurePrecision = SellerCameraRulerInteractionProfile(
        pointsPerStep: 34,
        sensitivity: 1.8,
        fineSensitivity: 0.75,
        ultraFineSensitivity: 0.35,
        maximumFlingSteps: 1,
        velocityThreshold: 42,
        boundaryResistance: 0.38,
        snapAnimation: SellerCameraMotionToken.snap,
        allowsContinuousValue: true,
        inertiaScale: 0.42
    )

    static let tintPrecision = SellerCameraRulerInteractionProfile(
        pointsPerStep: 34,
        sensitivity: 1.8,
        fineSensitivity: 0.75,
        ultraFineSensitivity: 0.35,
        maximumFlingSteps: 2,
        velocityThreshold: 44,
        boundaryResistance: 0.38,
        snapAnimation: SellerCameraMotionToken.snap,
        allowsContinuousValue: true,
        inertiaScale: 0.55
    )

    static let manualFocusPrecision = SellerCameraRulerInteractionProfile(
        pointsPerStep: 18,
        sensitivity: 2.4,
        fineSensitivity: 0.65,
        ultraFineSensitivity: 0.22,
        maximumFlingSteps: 2,
        velocityThreshold: 42,
        boundaryResistance: 0.38,
        snapAnimation: SellerCameraMotionToken.snap,
        allowsContinuousValue: true,
        inertiaScale: 0.24
    )

    static let zoomPrecision = SellerCameraRulerInteractionProfile(
        pointsPerStep: 96,
        sensitivity: 3.0,
        fineSensitivity: 0.90,
        ultraFineSensitivity: 0.38,
        maximumFlingSteps: 2,
        velocityThreshold: 44,
        boundaryResistance: 0.38,
        snapAnimation: SellerCameraMotionToken.snap,
        allowsContinuousValue: true,
        inertiaScale: 0.22
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
            .animation(reduceMotion ? SellerCameraMotionToken.reducedMotion : SellerCameraMotionToken.press, value: configuration.isPressed)
            .animation(SellerCameraMotionToken.selection, value: isEnabled)
    }
}

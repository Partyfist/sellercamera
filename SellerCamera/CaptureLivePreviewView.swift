//
//  CaptureLivePreviewView.swift
//  SellerCamera
//
//  Created by Codex on 2026/4/1.
//

import AVFoundation
import Combine
import CoreMotion
import ImageIO
import SwiftUI
import UIKit

enum CaptureFlashMode: CaseIterable {
    case off
    case auto
    case on

    var displayText: String {
        switch self {
        case .off:
            return "闪光关"
        case .auto:
            return "闪光自动"
        case .on:
            return "闪光开"
        }
    }

    var shortText: String {
        switch self {
        case .off:
            return "关"
        case .auto:
            return "自动"
        case .on:
            return "开"
        }
    }

    var symbolName: String {
        switch self {
        case .off:
            return "bolt.slash.fill"
        case .auto:
            return "bolt.badge.a.fill"
        case .on:
            return "bolt.fill"
        }
    }

    var avFlashMode: AVCaptureDevice.FlashMode {
        switch self {
        case .off:
            return .off
        case .auto:
            return .auto
        case .on:
            return .on
        }
    }
}

enum CaptureTimerOption: Int, CaseIterable {
    case off = 0
    case three = 3
    case five = 5
    case ten = 10

    var displayText: String {
        switch self {
        case .off:
            return "定时关"
        case .three:
            return "3 秒"
        case .five:
            return "5 秒"
        case .ten:
            return "10 秒"
        }
    }

    var shortText: String {
        switch self {
        case .off:
            return "关"
        case .three:
            return "3s"
        case .five:
            return "5s"
        case .ten:
            return "10s"
        }
    }
}

enum CaptureStabilizerMode: String, CaseIterable {
    case off
    case standard
    case enhanced

    var displayText: String {
        switch self {
        case .off:
            return "关闭"
        case .standard:
            return "标准"
        case .enhanced:
            return "增强"
        }
    }

    var captureSettleWaitNanoseconds: UInt64 {
        switch self {
        case .off:
            return 0
        case .standard:
            return 200_000_000
        case .enhanced:
            return 450_000_000
        }
    }

    var requestedVideoStabilizationMode: AVCaptureVideoStabilizationMode {
        switch self {
        case .off:
            return .off
        case .standard:
            return .auto
        case .enhanced:
            return .cinematic
        }
    }
}

enum CaptureWhiteBalancePreset: CaseIterable {
    case auto
    case warm
    case neutral
    case cool
    case custom

    var displayText: String {
        switch self {
        case .auto:
            return "Auto"
        case .warm:
            return "暖光"
        case .neutral:
            return "中性"
        case .cool:
            return "冷光"
        case .custom:
            return "手动"
        }
    }

    var temperature: Float {
        switch self {
        case .auto:
            return 5200
        case .warm:
            return 3200
        case .neutral:
            return 5000
        case .cool:
            return 6500
        case .custom:
            return 5000
        }
    }
}

enum CaptureISOPreset: CaseIterable {
    case auto
    case low
    case medium
    case high
    case custom

    var displayText: String {
        switch self {
        case .auto:
            return "Auto"
        case .low:
            return "低"
        case .medium:
            return "中"
        case .high:
            return "高"
        case .custom:
            return "手动"
        }
    }

    fileprivate var normalizedPosition: Float? {
        switch self {
        case .auto:
            return nil
        case .low:
            return 0.2
        case .medium:
            return 0.5
        case .high:
            return 0.8
        case .custom:
            return nil
        }
    }
}

enum CaptureShutterPreset: CaseIterable {
    case auto
    case s1_30
    case s1_60
    case s1_120
    case s1_250
    case s1_500
    case custom

    var displayText: String {
        switch self {
        case .auto:
            return "Auto"
        case .s1_30:
            return "1/30"
        case .s1_60:
            return "1/60"
        case .s1_120:
            return "1/120"
        case .s1_250:
            return "1/250"
        case .s1_500:
            return "1/500"
        case .custom:
            return "手动"
        }
    }

    fileprivate var durationSeconds: Double? {
        switch self {
        case .auto:
            return nil
        case .s1_30:
            return 1.0 / 30.0
        case .s1_60:
            return 1.0 / 60.0
        case .s1_120:
            return 1.0 / 120.0
        case .s1_250:
            return 1.0 / 250.0
        case .s1_500:
            return 1.0 / 500.0
        case .custom:
            return nil
        }
    }
}

enum CapturePhotoAspectRatioPreset: CaseIterable {
    case ratio1x1
    case ratio4x5
    case ratio3x4
    case ratio16x9
    case ratio9x16

    var displayText: String {
        switch self {
        case .ratio1x1:
            return "1:1"
        case .ratio4x5:
            return "4:5"
        case .ratio3x4:
            return "3:4"
        case .ratio9x16:
            return "9:16"
        case .ratio16x9:
            return "16:9"
        }
    }

    var ratioValue: CGFloat {
        switch self {
        case .ratio1x1:
            return 1.0
        case .ratio4x5:
            return 4.0 / 5.0
        case .ratio3x4:
            return 3.0 / 4.0
        case .ratio9x16:
            return 9.0 / 16.0
        case .ratio16x9:
            return 16.0 / 9.0
        }
    }
}

enum CapturePhotoPixelPreset: CaseIterable {
    case p800
    case p1200
    case p1600
    case p2400
    case best
    case raw

    var fixedLongEdgePixels: Int? {
        switch self {
        case .best, .raw:
            return nil
        case .p800:
            return 800
        case .p1200:
            return 1200
        case .p1600:
            return 1600
        case .p2400:
            return 2400
        }
    }

    var shortLabel: String {
        switch self {
        case .best:
            return "best"
        case .raw:
            return "raw"
        case .p800, .p1200, .p1600, .p2400:
            return "\(fixedLongEdgePixels ?? 0)"
        }
    }

    var requiresRawSupport: Bool {
        self == .raw
    }

    var usesFixedOutputSize: Bool {
        fixedLongEdgePixels != nil
    }

    func fixedOutputPixelSize(for ratio: CGFloat) -> CGSize? {
        guard let fixedLongEdgePixels else { return nil }
        let safeRatio = max(0.01, ratio)
        let longEdge = CGFloat(fixedLongEdgePixels)
        let width: CGFloat
        let height: CGFloat
        if safeRatio >= 1 {
            width = longEdge
            height = longEdge / safeRatio
        } else {
            height = longEdge
            width = longEdge * safeRatio
        }
        return CGSize(
            width: max(2, (width.rounded() / 2).rounded() * 2),
            height: max(2, (height.rounded() / 2).rounded() * 2)
        )
    }

    func displayText(for ratio: CGFloat) -> String {
        guard let size = fixedOutputPixelSize(for: ratio) else {
            switch self {
            case .best:
                return "最佳质量"
            case .raw:
                return "RAW"
            case .p800, .p1200, .p1600, .p2400:
                return "最佳质量"
            }
        }
        return "\(Int(size.width))×\(Int(size.height))"
    }
}

struct CaptureOptionSelectionResult {
    let selectedIndex: Int
    let selectedValue: String
    let runtimeAppliedValue: String
    let fallbackReason: String?
    let generation: UInt64
}

enum CaptureBurstOption: Int, CaseIterable {
    case single = 1
    case triple = 3
    case quintuple = 5

    var displayText: String {
        switch self {
        case .single:
            return "单拍"
        case .triple:
            return "连拍 3"
        case .quintuple:
            return "连拍 5"
        }
    }

    var shortText: String {
        switch self {
        case .single:
            return "1 张"
        case .triple:
            return "3 张"
        case .quintuple:
            return "5 张"
        }
    }
}

struct CaptureLensProfile: Identifiable, Equatable {
    enum Kind: String {
        case front
        case ultraWide
        case wide
        case tele
    }

    enum Source: String {
        case virtual
        case physical
        case derived
    }

    let id: String
    let kind: Kind
    let source: Source
    let position: AVCaptureDevice.Position
    let semanticFocal: CaptureSemanticFocal?
    let displayText: String
    let menuText: String
    let preferredDeviceType: AVCaptureDevice.DeviceType?
    let baseZoomFactor: CGFloat
    let lensMaxZoomFactor: CGFloat

    func updating(lensMaxZoomFactor: CGFloat) -> CaptureLensProfile {
        CaptureLensProfile(
            id: id,
            kind: kind,
            source: source,
            position: position,
            semanticFocal: semanticFocal,
            displayText: displayText,
            menuText: menuText,
            preferredDeviceType: preferredDeviceType,
            baseZoomFactor: baseZoomFactor,
            lensMaxZoomFactor: lensMaxZoomFactor
        )
    }
}

enum ManualParameterAvailability: Equatable {
    case pending(reason: String)
    case available
    case temporarilyUnavailable(reason: String)
    case unsupported(reason: String)
    case failed(reason: String)

    var isWritable: Bool {
        if case .available = self { return true }
        return false
    }

    var reasonText: String {
        switch self {
        case .pending(let reason),
             .temporarilyUnavailable(let reason),
             .unsupported(let reason),
             .failed(let reason):
            return reason
        case .available:
            return "available"
        }
    }
}

enum ManualFocusCapability: Equatable {
    case full
    case lockCurrentOnly(reason: String)
    case unsupported(reason: String)

    var isFull: Bool {
        if case .full = self { return true }
        return false
    }

    var canEnterManualFocusMode: Bool {
        switch self {
        case .full, .lockCurrentOnly:
            return true
        case .unsupported:
            return false
        }
    }

    var reasonText: String {
        switch self {
        case .full:
            return "full"
        case .lockCurrentOnly(let reason),
             .unsupported(let reason):
            return reason
        }
    }

    var userFacingHint: String {
        switch self {
        case .full:
            return "MF 可用"
        case .lockCurrentOnly:
            return "当前镜头仅支持锁定焦点，暂不支持手动拖动"
        case .unsupported(let reason):
            switch reason {
            case "noActiveSessionDevice":
                return "相机尚未就绪"
            case "lensSwitching":
                return "镜头切换完成后再试"
            case "previewRestricted":
                return "当前拍摄处理中，稍后再调焦"
            case "focusExposureLocked":
                return "AE/AF 锁定中，长按画面解除后可进入 MF"
            case "lockedFocusUnsupported":
                return "当前镜头不支持手动对焦"
            default:
                return "当前摄像头不支持手动对焦"
            }
        }
    }
}

enum PhysicalCameraProfile: Equatable {
    case ultraWide
    case wide
    case telephoto

    var preferredDeviceType: AVCaptureDevice.DeviceType {
        switch self {
        case .ultraWide:
            return .builtInUltraWideCamera
        case .wide:
            return .builtInWideAngleCamera
        case .telephoto:
            return .builtInTelephotoCamera
        }
    }

    var displayText: String {
        switch self {
        case .ultraWide:
            return "Ultra Wide"
        case .wide:
            return "Wide"
        case .telephoto:
            return "Telephoto"
        }
    }
}

struct CaptureDeviceIdentity: Equatable {
    let uniqueID: String
    let localizedName: String
    let deviceType: AVCaptureDevice.DeviceType

    init(device: AVCaptureDevice) {
        uniqueID = device.uniqueID
        localizedName = device.localizedName
        deviceType = device.deviceType
    }

    var isPhysicalManualBackCamera: Bool {
        deviceType == .builtInUltraWideCamera
            || deviceType == .builtInWideAngleCamera
            || deviceType == .builtInTelephotoCamera
    }
}

enum CaptureDeviceOperatingMode: Equatable {
    case automaticVirtual
    case manualPhysical(profile: PhysicalCameraProfile)
    case switching(from: CaptureDeviceIdentity?, to: CaptureDeviceIdentity, reason: String)
    case unavailable(reason: String)

    var shouldUsePhysicalLensProfiles: Bool {
        switch self {
        case .manualPhysical:
            return true
        case .switching(_, let target, _):
            return target.isPhysicalManualBackCamera
        case .automaticVirtual, .unavailable:
            return false
        }
    }
}

enum ManualParameterWriteScope: Equatable {
    case exposure
    case whiteBalance
}

struct ManualParameterWriteToken: Equatable {
    let scope: ManualParameterWriteScope
    let deviceGeneration: UInt64
    let parameterGeneration: UInt64
    let deviceID: String
}

enum CaptureSemanticFocal: Int, CaseIterable, Identifiable {
    case mm13
    case mm24
    case mm48
    case mm77

    var id: Int { rawValue }

    var millimeters: Int {
        switch self {
        case .mm13:
            return 13
        case .mm24:
            return 24
        case .mm48:
            return 48
        case .mm77:
            return 77
        }
    }

    var displayText: String {
        switch self {
        case .mm13:
            return "13mm"
        case .mm24:
            return "24mm"
        case .mm48:
            return "48mm"
        case .mm77:
            return "77mm"
        }
    }
}

enum CaptureSemanticFocalAvailability {
    case unavailable
    case physical
    case derived
}

struct CaptureSemanticFocalCapability: Identifiable {
    let focal: CaptureSemanticFocal
    let availability: CaptureSemanticFocalAvailability
    let lensID: String?
    let lensZoomMultiplierRange: ClosedRange<Double>?

    var id: CaptureSemanticFocal { focal }

    var isAvailable: Bool {
        availability != .unavailable
    }
}

struct SellerCameraLensTarget: Equatable {
    let displayMillimeters: Int
    let requestedZoomFactor: CGFloat
    let clampedZoomFactor: CGFloat
    let preferredDeviceType: AVCaptureDevice.DeviceType?
}

enum CaptureFocusControlMode {
    case auto
    case manual

    var shortText: String {
        switch self {
        case .auto:
            return "AF"
        case .manual:
            return "MF"
        }
    }
}

struct CaptureFocusMarker: Identifiable {
    enum Mode: Equatable {
        case focusing
        case focused
        case warning
        case locked
        case unlocked
    }

    let id = UUID()
    let normalizedPoint: CGPoint
    let mode: Mode
}

final class CaptureCameraRuntime: NSObject, ObservableObject {
    private static let whiteBalanceMinimumTemperature: Float = 2800
    private static let whiteBalanceMaximumTemperature: Float = 7500
    private static let whiteBalanceDialStep: Float = 50
    private static let whiteBalanceMinimumTint: Float = -50
    private static let whiteBalanceMaximumTint: Float = 50
    private static let whiteBalanceTintDialStep: Float = 5
    private static let isoDialNormalizedStep: Double = 0.01
    private static let shutterDialNormalizedStep: Double = 0.01
    private static let derived48PreferredLongEdge = 7600
    private static let derived48StrongConfidenceLongEdge = 8000
    private static let derived48SwitchOverTolerance: CGFloat = 0.32
    // 阶段性收口：13mm / 77mm 优先保证手感与稳定性，不追求超长尾倍率。
    private static let stageLensLocalMaxMultiplierCap: CGFloat = 15.0
    // 77mm 切镜后极短稳定窗口：仅用于收口瞬态卡顿，不改变常态手感。
    private static let tele77PostSwitchStabilizationWindow: TimeInterval = 0.22
    private static let tele77PostSwitchWriteInterval: TimeInterval = 0.05
    private static let tele77PostSwitchHysteresis: CGFloat = 0.02
    private static let productAutoSceneSessionWarmupInterval: TimeInterval = 1.2
    private static let productAutoSceneNearBlackProbeLimit = 2
    private static let wideLensBoundaryHeadroom: CGFloat = 1.06
    private static let teleLensBoundaryHeadroom: CGFloat = 1.06
    private static let lensZoomSnapThresholdBase: CGFloat = 0.03
    private static let lensZoomRampRate: Float = 7.0
    private static let closeFocusFallbackCooldown: TimeInterval = 5.0
    private static let closeFocusFallbackDelay: TimeInterval = 0.22
    private static let lensRulerDirectWriteInterval: TimeInterval = 1.0 / 30.0
    private static let lensRulerSwitchOverHysteresis: CGFloat = 0.022
    private static let stabilizerUserDefaultsKey = "seller.camera.capture.stabilizer.mode"

    @Published var latestStillPhotoResult: CaptureStillPhotoResult?
    @Published var latestCaptureStatusText = "未拍摄"
    @Published var captureHintText = "轻触画面可对焦与测光"

    @Published var confirmedStillPhotoResult: CaptureStillPhotoResult?
    @Published var latestProcessedResult: CaptureProcessedPhotoResult?
    @Published var latestProcessingErrorText: String?
    @Published var isProcessingLatestResult = false
    @Published var isSavingLatestProcessed = false
    @Published var isLatestProcessedSaveCompleted = false
    @Published var latestProcessedSaveFailureText: String?

    @Published var latestAcceptedProcessedResult: CaptureProcessedPhotoResult?
    @Published var latestReadyForOutputProcessedResult: CaptureProcessedPhotoResult?
    @Published var latestPreservedSourceResult: CaptureStillPhotoResult?
    @Published var isSavingLatestOriginal = false
    @Published var isLatestOriginalSaveCompleted = false
    @Published var latestOriginalSaveFailureText: String?
    @Published var isOutputtingLatestReadyResult = false
    @Published var isLatestReadyResultOutputCompleted = false
    @Published var latestReadyOutputFailureText: String?

    @Published var selectedFlashMode: CaptureFlashMode = .auto
    @Published var selectedTimerOption: CaptureTimerOption = .off
    @Published var selectedBurstOption: CaptureBurstOption = .single
    @Published var selectedStabilizerMode: CaptureStabilizerMode = {
        let rawValue = UserDefaults.standard.string(forKey: CaptureCameraRuntime.stabilizerUserDefaultsKey)
        return rawValue.flatMap(CaptureStabilizerMode.init(rawValue:)) ?? .standard
    }()
    @Published var isGridEnabled = false
    @Published var isLevelIndicatorEnabled = false
    @Published var isFlashModeSupported = false
    @Published var isExposureLockSupported = false
    @Published var isExposureBiasSupported = false
    @Published var isWhiteBalanceAutoSupported = false
    @Published var isWhiteBalancePresetSupported = false
    @Published var whiteBalanceManualAvailability: ManualParameterAvailability = .pending(reason: "sessionPreparing")
    @Published var selectedWhiteBalancePreset: CaptureWhiteBalancePreset = .auto
    @Published var currentWhiteBalanceTemperature: Float = 5000
    @Published var currentWhiteBalanceTint: Float = 0
    @Published var isISOAutoSupported = false
    @Published var isISOPresetSupported = false
    @Published var isoManualAvailability: ManualParameterAvailability = .pending(reason: "sessionPreparing")
    @Published var selectedISOPreset: CaptureISOPreset = .auto
    @Published var minimumISOValue: Float = 0
    @Published var maximumISOValue: Float = 0
    @Published var currentManualISOValue: Float = 0
    @Published var isShutterAutoSupported = false
    @Published var isShutterPresetSupported = false
    @Published var shutterManualAvailability: ManualParameterAvailability = .pending(reason: "sessionPreparing")
    @Published var selectedShutterPreset: CaptureShutterPreset = .auto
    @Published var minimumShutterDurationSeconds: Double = 0
    @Published var maximumShutterDurationSeconds: Double = 0
    @Published var currentManualShutterDurationSeconds: Double = 1.0 / 120.0
    @Published var selectedAspectRatioPreset: CapturePhotoAspectRatioPreset = .ratio3x4
    @Published var selectedPixelPreset: CapturePhotoPixelPreset = .p1600
    @Published var isRAWCaptureSupported = false
    @Published var isManualFocusEntrySupported = false
    @Published var isManualFocusSupported = false
    @Published var canSwitchCamera = false
    @Published var activeCameraPosition: AVCaptureDevice.Position = .back
    @Published var activeCameraDeviceType: AVCaptureDevice.DeviceType?
    @Published var availableLensProfiles: [CaptureLensProfile] = []
    @Published var selectedLensProfileID: String = ""

    @Published var currentZoomFactor: CGFloat = 1.0
    @Published var minimumZoomFactor: CGFloat = 1.0
    @Published var activeDeviceMaximumZoomFactor: CGFloat = 1.0
    @Published var maximumZoomFactor: CGFloat = 1.0
    @Published var currentExposureBias: Float = 0
    @Published var isExposureBiasAutoMode = true
    @Published var minimumExposureBias: Float = 0
    @Published var maximumExposureBias: Float = 0
    @Published var productAutoExposureStatusText = "商品 Auto 待机"
    @Published var productAutoExposureAppliedBias: Float?
    @Published var productAutoWhiteBalanceStatusText = "商品 WB 待机"
    @Published var productAutoWhiteBalanceAppliedTemperature: Float?
    @Published var productSharpnessStatusText = "清晰度待机"
    @Published var currentISOValue: Float = 0
    @Published var currentShutterDurationSeconds: Double = 0
    @Published var focusControlMode: CaptureFocusControlMode = .auto
    @Published var currentManualFocusPosition: Float = 1.0

    @Published var countdownSecondsRemaining: Int?
    @Published var isBurstCapturing = false
    @Published var burstProgressText: String?
    @Published var focusMarker: CaptureFocusMarker?
    @Published var levelRollDegrees: Double?
    @Published var levelGravityX: Double?
    @Published var levelGravityY: Double?
    @Published var levelGravityZ: Double?
    @Published var quickPreviewImage: UIImage?
    @Published var isFocusExposureLocked = false
    @Published var isExposureLocked = false
    @Published var isSwitchingCamera = false
    @Published var captureDeviceOperatingMode: CaptureDeviceOperatingMode = .automaticVirtual

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "seller.camera.session.queue")
    private var currentVideoInput: AVCaptureDeviceInput?
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let videoAnalysisQueue = DispatchQueue(label: "seller.camera.video.analysis.queue")
    private var isSessionConfigured = false
    private var pendingCaptureDelegates: [UUID: CapturePhotoDelegateProxy] = [:]
    private var countdownTask: Task<Void, Never>?
    private var burstTask: Task<Void, Never>?
    private var quickPreviewHideTask: Task<Void, Never>?
    private var focusFeedbackTask: Task<Void, Never>?
    private var lastAppliedManualFocusPosition: Float?
    private var tele77StabilizationUntil: TimeInterval = 0
    private var tele77LastWriteTimestamp: TimeInterval = 0
    private var tele77PendingMultiplier: CGFloat?
    private var tele77StabilizationToken = UUID()
    private let productAutoExposureOptimizer = ProductAutoExposureOptimizer()
    private let productAutoWhiteBalanceOptimizer = ProductAutoWhiteBalanceOptimizer()
    private var lastProductAutoExposureAnalysisAt: CFTimeInterval = 0
    private var lastProductAutoExposureWriteAt = Date.distantPast
    private var lastProductAutoExposureDebugLogAt = Date.distantPast
    private var lastProductAutoWhiteBalanceWriteAt = Date.distantPast
    private var lastProductAutoWhiteBalanceDebugLogAt = Date.distantPast
    private var lastProductAutoSceneDebugLogAt = Date.distantPast
    private var lastProductAutoSceneFrameGuardLogAt = Date.distantPast
    private var lastProductSharpnessDebugLogAt = Date.distantPast
    private var lastProductSharpnessHintAt = Date.distantPast
    private var lastProductFocusAssistAt = Date.distantPast
    private var lastUserFocusInteractionAt = Date.distantPast
    private var lastManualFocusInteractionAt = Date.distantPast
    private var lastCloseFocusFallbackAt = Date.distantPast
    private var lastLensRulerZoomWriteAt = Date.distantPast
    private var pendingLensRulerZoomTarget: CGFloat?
    private var lastLensRulerInteractionAt = Date.distantPast
    private var lensZoomReadbackGeneration: UInt64 = 0
    private var deviceSwitchGeneration: UInt64 = 0
    private var exposureParameterWriteGeneration: UInt64 = 0
    private var whiteBalanceParameterWriteGeneration: UInt64 = 0
    private var aspectRatioSelectionGeneration: UInt64 = 0
    private var pixelSelectionGeneration: UInt64 = 0
    private var pendingDeviceSwitchCompletion: (() -> Void)?
    private var productSharpnessBlurryHitCount = 0
    private var productSharpnessSharpHitCount = 0
    private var isProductFocusAssistSuppressedByManualFocusUI = false
    private var hasProductFocusAssistTriggeredForCurrentBlurEpisode = false
    private var lastSessionStartAt = Date.distantPast
    private var isCaptureStabilizerSettling = false
    private var productAutoSceneNearBlackFrameStreak = 0
    private let productAutoExposureAnalysisInterval: CFTimeInterval = 0.35
    private let productAutoExposureWriteInterval: TimeInterval = 0.35
    private let productAutoExposureDebugLogInterval: TimeInterval = 1.0
    private let productAutoWhiteBalanceWriteInterval: TimeInterval = 1.0
    private let productAutoWhiteBalanceDebugLogInterval: TimeInterval = 1.0
    private let productAutoSceneDebugLogInterval: TimeInterval = 1.0
    private let productSharpnessDebugLogInterval: TimeInterval = 1.0
    private let productFocusAssistCooldown: TimeInterval = 7.0
    private let productFocusAssistManualCooldown: TimeInterval = 6.0
    private let tapFocusThrottleInterval: TimeInterval = 0.28
    private let tapFocusSettleDelay: TimeInterval = 0.32
    private let tapFocusTimeout: TimeInterval = 1.15

    private let motionManager = CMMotionManager()
    private var levelMotionStarted = false

    deinit {
        countdownTask?.cancel()
        burstTask?.cancel()
        quickPreviewHideTask?.cancel()
        focusFeedbackTask?.cancel()
        videoOutput.setSampleBufferDelegate(nil, queue: nil)
        motionManager.stopDeviceMotionUpdates()
    }

    func startRunningSessionIfNeeded() {
        Task { [weak self] in
            guard let self else { return }
            let granted = await self.ensureVideoPermission()
            guard granted else {
                DispatchQueue.main.async {
                    self.captureHintText = "请先在系统设置中开启相机权限"
                }
                return
            }

            await self.configureSessionIfNeeded()
            self.startSession()
            DispatchQueue.main.async {
                self.captureHintText = "轻触画面可对焦与测光"
                self.refreshStatusSummary()
            }
        }
    }

    func stopRunningSessionIfPossible() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func triggerPhotoCapture() {
        if isOutputtingLatestReadyResult {
            captureHintText = "输出中，仍可返回拍摄"
            return
        }
        if isBurstCapturing {
            captureHintText = "连拍进行中，请稍候"
            return
        }
        if countdownSecondsRemaining != nil {
            captureHintText = "倒计时中，可点击取消"
            return
        }

        let delay = selectedTimerOption.rawValue
        if delay > 0 {
            startCountdown(seconds: delay)
        } else {
            startBurstSequence()
        }
    }

    @MainActor
    func importSinglePhotoFromLibraryData(_ imageData: Data) async -> Bool {
        captureHintText = "正在导入图片..."
        refreshStatusSummary()

        do {
            guard let decodedImage = UIImage(data: imageData) else {
                throw NSError(domain: "CaptureCameraRuntime.Import", code: -1)
            }

            let normalizedImage = decodedImage.normalizedForCapturePipeline()
            guard let normalizedData = normalizedImage.jpegData(compressionQuality: 0.98) else {
                throw NSError(domain: "CaptureCameraRuntime.Import", code: -2)
            }

            let pixelSize: CGSize?
            if let cgImage = normalizedImage.cgImage {
                pixelSize = CGSize(width: cgImage.width, height: cgImage.height)
            } else {
                pixelSize = nil
            }

            var metadata: [String: String] = [
                "capture_source": CaptureStillPhotoSource.photoLibrary.rawValue
            ]
            metadata["importedByteCount"] = "\(imageData.count)"

            let importedResult = CaptureStillPhotoResult(
                source: .photoLibrary,
                imageData: normalizedData,
                pixelSize: pixelSize,
                metadata: metadata
            )

            handleCaptureSuccess(importedResult, shotIndex: 1, totalCount: 1)
            captureHintText = "导入成功，可直接保存原图或生成白底图"
            refreshStatusSummary()
            return true
        } catch {
            notifyImportFailure("导入图片失败，请重试")
            return false
        }
    }

    @MainActor
    func notifyImportFailure(_ message: String) {
        captureHintText = message
        refreshStatusSummary()
    }

    func cancelCountdownIfNeeded() {
        guard countdownSecondsRemaining != nil else { return }
        countdownTask?.cancel()
        countdownTask = nil
        countdownSecondsRemaining = nil
        captureHintText = "已取消定时拍摄"
        refreshStatusSummary()
    }

    func cycleFlashMode() {
        guard isFlashModeSupported else {
            captureHintText = "当前摄像头不支持闪光灯"
            return
        }
        guard let index = CaptureFlashMode.allCases.firstIndex(of: selectedFlashMode) else { return }
        let next = CaptureFlashMode.allCases[(index + 1) % CaptureFlashMode.allCases.count]
        selectedFlashMode = next
        captureHintText = "闪光灯：\(next.shortText)"
    }

    func cycleTimerOption() {
        guard let index = CaptureTimerOption.allCases.firstIndex(of: selectedTimerOption) else { return }
        selectedTimerOption = CaptureTimerOption.allCases[(index + 1) % CaptureTimerOption.allCases.count]
        captureHintText = "定时拍摄：\(selectedTimerOption.displayText)"
    }

    func cycleBurstOption() {
        guard let index = CaptureBurstOption.allCases.firstIndex(of: selectedBurstOption) else { return }
        selectedBurstOption = CaptureBurstOption.allCases[(index + 1) % CaptureBurstOption.allCases.count]
        captureHintText = selectedBurstOption == .single
            ? "拍摄模式：单拍"
            : "拍摄模式：\(selectedBurstOption.displayText)"
    }

    func cycleExposureBias() {
        guard isExposureBiasSupported else {
            captureHintText = "当前摄像头不支持 EV 调节"
            return
        }
        guard !isManualExposurePresetActive else {
            captureHintText = manualExposureEVLockHintText
            logExposureTriangle("EV cycle blocked isoMode=\(selectedISOPreset == .auto ? "auto" : "manual") shutterMode=\(selectedShutterPreset == .auto ? "auto" : "manual") evState=locked")
            return
        }
        guard !isFocusExposureLocked else {
            captureHintText = "AE/AF 锁定中，先解锁后再调 EV"
            return
        }
        guard !isExposureLocked else {
            captureHintText = "AE 已锁定，先关闭 AE-L 后再调 EV"
            return
        }
        guard !isPreviewInteractionTemporarilyRestricted else {
            captureHintText = previewInteractionRestrictedHintText
            return
        }

        let presets: [Float] = [-2.0, -1.0, -0.5, 0, 0.5, 1.0, 2.0]
        let available = presets
            .filter { $0 >= minimumExposureBias - 0.01 && $0 <= maximumExposureBias + 0.01 }
            .sorted()
        guard !available.isEmpty else {
            captureHintText = "当前摄像头不支持 EV 调节"
            return
        }

        let current = currentExposureBias
        let next = available.first(where: { $0 > current + 0.05 }) ?? available[0]
        setExposureBias(next, switchesToManual: true)
    }

    func setExposureBiasDialValue(_ requestedValue: Double) {
        guard isExposureBiasSupported else {
            captureHintText = "当前摄像头不支持 EV 调节"
            return
        }
        guard !isManualExposurePresetActive else {
            captureHintText = manualExposureEVLockHintText
            logExposureTriangle("EV dial blocked isoMode=\(selectedISOPreset == .auto ? "auto" : "manual") shutterMode=\(selectedShutterPreset == .auto ? "auto" : "manual") evState=locked")
            return
        }
        guard !isFocusExposureLocked else {
            captureHintText = "AE/AF 锁定中，先解锁后再调 EV"
            return
        }
        guard !isExposureLocked else {
            captureHintText = "AE 已锁定，先关闭 AE-L 后再调 EV"
            return
        }
        guard !isPreviewInteractionTemporarilyRestricted else {
            captureHintText = previewInteractionRestrictedHintText
            return
        }

        let clamped = max(Double(minimumExposureBias), min(Double(maximumExposureBias), requestedValue))
        setExposureBias(Float(clamped), switchesToManual: true)
    }

    func applyExposureBiasAuto() {
        guard !isManualExposurePresetActive else {
            captureHintText = manualExposureEVLockHintText
            logExposureTriangle("EV auto reset blocked isoMode=\(selectedISOPreset == .auto ? "auto" : "manual") shutterMode=\(selectedShutterPreset == .auto ? "auto" : "manual") evState=locked")
            return
        }
        productAutoExposureOptimizer.reset()
        productAutoExposureAppliedBias = nil
        productAutoExposureStatusText = "商品 Auto 恢复"
        setExposureBias(0, switchesToManual: false)
    }

    func resetExposureBias() {
        applyExposureBiasAuto()
    }

    func toggleExposureLock() {
        guard isExposureLockSupported else {
            captureHintText = "当前摄像头不支持 AE 锁定"
            return
        }
        guard !isFocusExposureLocked else {
            captureHintText = "AE/AF 锁定中，长按画面可解锁"
            return
        }
        guard !isPreviewInteractionTemporarilyRestricted else {
            captureHintText = previewInteractionRestrictedHintText
            return
        }

        let shouldLock = !isExposureLocked
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard let device = self.currentVideoInput?.device else { return }
            do {
                try device.lockForConfiguration()
                if shouldLock {
                    guard device.isExposureModeSupported(.locked) else {
                        device.unlockForConfiguration()
                        DispatchQueue.main.async {
                            self.captureHintText = "当前摄像头不支持 AE 锁定"
                        }
                        return
                    }
                    device.exposureMode = .locked
                } else {
                    guard device.isExposureModeSupported(.continuousAutoExposure) else {
                        device.unlockForConfiguration()
                        DispatchQueue.main.async {
                            self.captureHintText = "当前摄像头不支持自动曝光恢复"
                        }
                        return
                    }
                    device.exposureMode = .continuousAutoExposure
                }
                let updatedBias = device.exposureTargetBias
                let updatedISO = device.iso
                let updatedShutterSeconds = CMTimeGetSeconds(device.exposureDuration)
                device.unlockForConfiguration()
                DispatchQueue.main.async {
                    let switchedFromManualExposurePreset = self.selectedISOPreset != .auto
                        || self.selectedShutterPreset != .auto
                    self.isExposureLocked = shouldLock
                    self.currentExposureBias = updatedBias
                    self.currentISOValue = updatedISO
                    self.currentShutterDurationSeconds = updatedShutterSeconds.isFinite ? updatedShutterSeconds : 0
                    self.selectedISOPreset = .auto
                    self.selectedShutterPreset = .auto
                    if shouldLock {
                        self.captureHintText = switchedFromManualExposurePreset
                            ? "AE 已锁定，ISO/快门已回 Auto"
                            : "AE 已锁定"
                    } else {
                        self.captureHintText = "AE-L 已关闭，恢复自动曝光"
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.captureHintText = shouldLock ? "AE 锁定失败" : "AE-L 关闭失败"
                }
            }
        }
    }

    func setWhiteBalanceDialValue(_ requestedValue: Double) {
        applyWhiteBalanceManualValues(
            requestedTemperature: Float(requestedValue),
            requestedTint: currentWhiteBalanceTint,
            semanticPreset: .custom,
            shouldShowHint: true
        )
    }

    func setWhiteBalanceTintDialValue(_ requestedValue: Double) {
        applyWhiteBalanceManualValues(
            requestedTemperature: currentWhiteBalanceTemperature,
            requestedTint: Float(requestedValue),
            semanticPreset: .custom,
            shouldShowHint: true
        )
    }

    func applyWhiteBalanceAuto() {
        applyWhiteBalancePreset(.auto, shouldShowHint: true)
    }

    func resetWhiteBalance() {
        applyWhiteBalancePreset(.auto, shouldShowHint: true)
    }

    func resetWhiteBalanceTint() {
        guard !isPreviewInteractionTemporarilyRestricted else {
            captureHintText = previewInteractionRestrictedHintText
            return
        }
        guard isWhiteBalancePresetSupported || isWhiteBalanceAutoSupported else {
            captureHintText = "当前摄像头不支持色偏调节"
            return
        }

        if selectedWhiteBalancePreset == .auto {
            currentWhiteBalanceTint = 0
            captureHintText = "色偏：0"
            return
        }

        applyWhiteBalanceManualValues(
            requestedTemperature: currentWhiteBalanceTemperature,
            requestedTint: 0,
            semanticPreset: .custom,
            shouldShowHint: true
        )
    }

    var whiteBalanceDialValue: Double {
        Double(currentWhiteBalanceTemperature)
    }

    var whiteBalanceDialRange: ClosedRange<Double> {
        Double(Self.whiteBalanceMinimumTemperature)...Double(Self.whiteBalanceMaximumTemperature)
    }

    var whiteBalanceDialStepValue: Double {
        Double(Self.whiteBalanceDialStep)
    }

    var whiteBalanceTintDialValue: Double {
        Double(currentWhiteBalanceTint)
    }

    var whiteBalanceTintDialRange: ClosedRange<Double> {
        Double(Self.whiteBalanceMinimumTint)...Double(Self.whiteBalanceMaximumTint)
    }

    var whiteBalanceTintDialStepValue: Double {
        Double(Self.whiteBalanceTintDialStep)
    }

    var whiteBalanceDisplayText: String {
        if selectedWhiteBalancePreset == .auto {
            if let productAutoWhiteBalanceAppliedTemperature {
                return "Auto \(Int(productAutoWhiteBalanceAppliedTemperature.rounded()))K"
            }
            return "Auto"
        }
        return "\(Int(currentWhiteBalanceTemperature.rounded()))K"
    }

    private func applyWhiteBalancePreset(
        _ preset: CaptureWhiteBalancePreset,
        shouldShowHint: Bool
    ) {
        guard !isPreviewInteractionTemporarilyRestricted else {
            captureHintText = previewInteractionRestrictedHintText
            return
        }
        guard isWhiteBalanceAutoSupported || isWhiteBalancePresetSupported else {
            captureHintText = "当前摄像头不支持白平衡调节"
            return
        }

        if preset != .auto {
            let targetTemperature: Float = preset == .custom
                ? currentWhiteBalanceTemperature
                : preset.temperature
            let targetTint: Float = preset == .custom ? currentWhiteBalanceTint : 0
            applyWhiteBalanceManualValues(
                requestedTemperature: targetTemperature,
                requestedTint: targetTint,
                semanticPreset: preset,
                shouldShowHint: shouldShowHint
            )
            return
        }

        invalidateManualParameterWrites(scope: .whiteBalance)
        selectedWhiteBalancePreset = .auto
        currentWhiteBalanceTint = 0
        productAutoWhiteBalanceOptimizer.reset()
        productAutoWhiteBalanceAppliedTemperature = nil
        productAutoWhiteBalanceStatusText = "商品 WB 恢复"
        if shouldShowHint {
            captureHintText = "白平衡：Auto"
        }
        restoreAutomaticVirtualModeIfReady(reason: "whiteBalanceAutoIntent")

        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard let device = self.currentVideoInput?.device else { return }
            do {
                try device.lockForConfiguration()
                guard device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) else {
                    device.unlockForConfiguration()
                    DispatchQueue.main.async {
                        self.captureHintText = "当前摄像头不支持自动白平衡"
                    }
                    return
                }
                let operationToken = self.nextManualParameterWriteToken(for: device, scope: .whiteBalance)
                device.whiteBalanceMode = .continuousAutoWhiteBalance
                let autoTempTint = device.temperatureAndTintValues(for: device.deviceWhiteBalanceGains)
                device.unlockForConfiguration()
                DispatchQueue.main.async {
                    guard self.isCurrentManualParameterWrite(operationToken) else {
                        print("[ManualParamWrite] stale WB auto completion ignored token=\(operationToken)")
                        return
                    }
                    self.selectedWhiteBalancePreset = .auto
                    self.currentWhiteBalanceTemperature = self.clampedWhiteBalanceTemperature(autoTempTint.temperature)
                    // TINT 合同：WB Auto 统一回收为 0，避免用户误解自动状态下仍存在手动色偏。
                    self.currentWhiteBalanceTint = 0
                    self.productAutoWhiteBalanceOptimizer.reset()
                    self.productAutoWhiteBalanceAppliedTemperature = nil
                    self.productAutoWhiteBalanceStatusText = "商品 WB 恢复"
                    if shouldShowHint {
                        self.captureHintText = "白平衡：Auto"
                    }
                    self.restoreAutomaticVirtualModeIfReady(reason: "whiteBalanceAuto")
                }
            } catch {
                DispatchQueue.main.async {
                    self.captureHintText = "白平衡调整失败"
                }
            }
        }
    }

    private func applyWhiteBalanceManualValues(
        requestedTemperature: Float,
        requestedTint: Float,
        semanticPreset: CaptureWhiteBalancePreset,
        shouldShowHint: Bool
    ) {
        guard !isPreviewInteractionTemporarilyRestricted else {
            captureHintText = previewInteractionRestrictedHintText
            return
        }
        if requestManualPhysicalModeIfNeeded(
            reason: "manualWhiteBalance",
            completion: { [weak self] in
                self?.applyWhiteBalanceManualValues(
                    requestedTemperature: requestedTemperature,
                    requestedTint: requestedTint,
                    semanticPreset: semanticPreset,
                    shouldShowHint: shouldShowHint
                )
            }
        ) {
            return
        }
        guard whiteBalanceManualAvailability.isWritable else {
            captureHintText = whiteBalanceManualAvailability.reasonText
            return
        }

        productAutoWhiteBalanceOptimizer.reset()
        productAutoWhiteBalanceAppliedTemperature = nil
        productAutoWhiteBalanceStatusText = "商品 WB 暂停 · 手动WB"

        let clampedTemperature = clampedWhiteBalanceTemperature(requestedTemperature)
        let quantizedTemperature = (clampedTemperature / Self.whiteBalanceDialStep).rounded() * Self.whiteBalanceDialStep
        let clampedTint = clampedWhiteBalanceTint(requestedTint)
        let quantizedTint = (clampedTint / Self.whiteBalanceTintDialStep).rounded() * Self.whiteBalanceTintDialStep

        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard let device = self.currentVideoInput?.device else { return }
            let whiteBalanceDevice = self.manualWhiteBalanceControlDevice(for: device)
            do {
                try whiteBalanceDevice.lockForConfiguration()
                guard whiteBalanceDevice.isWhiteBalanceModeSupported(.locked),
                      whiteBalanceDevice.isLockingWhiteBalanceWithCustomDeviceGainsSupported else {
                    whiteBalanceDevice.unlockForConfiguration()
                    DispatchQueue.main.async {
                        self.whiteBalanceManualAvailability = .unsupported(reason: "WB: customGainsUnsupported")
                        self.isWhiteBalancePresetSupported = false
                        self.captureHintText = "当前摄像头不支持固定白平衡"
                    }
                    return
                }
                let tempTint = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(
                    temperature: quantizedTemperature,
                    tint: quantizedTint
                )
                let writeToken = self.nextManualParameterWriteToken(for: whiteBalanceDevice, scope: .whiteBalance)
                if #available(iOS 26.0, *) {
                    whiteBalanceDevice.setWhiteBalanceModeLocked(whiteBalanceTemperatureAndTintValues: tempTint) { [weak self, weak whiteBalanceDevice] _ in
                        guard let self, let whiteBalanceDevice else { return }
                        let readback = whiteBalanceDevice.temperatureAndTintValues(for: whiteBalanceDevice.deviceWhiteBalanceGains)
                        DispatchQueue.main.async {
                            guard self.isCurrentManualParameterWrite(writeToken) else {
                                print("[ManualParamWrite] stale WB completion ignored token=\(writeToken)")
                                return
                            }
                            self.currentWhiteBalanceTemperature = self.clampedWhiteBalanceTemperature(readback.temperature)
                            self.currentWhiteBalanceTint = self.clampedWhiteBalanceTint(readback.tint)
                            self.selectedWhiteBalancePreset = semanticPreset == .auto ? .custom : semanticPreset
                            if shouldShowHint {
                                let tintDisplayText = self.formattedWhiteBalanceTintText(self.currentWhiteBalanceTint)
                                self.captureHintText = "白平衡：\(Int(self.currentWhiteBalanceTemperature.rounded()))K · \(tintDisplayText)"
                            }
                        }
                    }
                } else {
                    let rawGains = whiteBalanceDevice.deviceWhiteBalanceGains(for: tempTint)
                    let safeGains = self.normalizedWhiteBalanceGains(rawGains, for: whiteBalanceDevice)
                    whiteBalanceDevice.setWhiteBalanceModeLocked(with: safeGains) { [weak self, weak whiteBalanceDevice] _ in
                        guard let self, let whiteBalanceDevice else { return }
                        let readback = whiteBalanceDevice.temperatureAndTintValues(for: whiteBalanceDevice.deviceWhiteBalanceGains)
                        DispatchQueue.main.async {
                            guard self.isCurrentManualParameterWrite(writeToken) else {
                                print("[ManualParamWrite] stale WB gains completion ignored token=\(writeToken)")
                                return
                            }
                            self.currentWhiteBalanceTemperature = self.clampedWhiteBalanceTemperature(readback.temperature)
                            self.currentWhiteBalanceTint = self.clampedWhiteBalanceTint(readback.tint)
                            self.selectedWhiteBalancePreset = semanticPreset == .auto ? .custom : semanticPreset
                            if shouldShowHint {
                                let tintDisplayText = self.formattedWhiteBalanceTintText(self.currentWhiteBalanceTint)
                                self.captureHintText = "白平衡：\(Int(self.currentWhiteBalanceTemperature.rounded()))K · \(tintDisplayText)"
                            }
                        }
                    }
                }
                whiteBalanceDevice.unlockForConfiguration()
            } catch {
                DispatchQueue.main.async {
                    self.whiteBalanceManualAvailability = .failed(reason: "WB: lockFailed \(error.localizedDescription)")
                    self.isWhiteBalancePresetSupported = false
                    self.captureHintText = "白平衡调整失败"
                }
            }
        }
    }

    func setISODialValue(_ requestedValue: Double) {
        let clampedNormalized = max(0.0, min(1.0, requestedValue))
        let targetISO = isoValue(
            forNormalized: clampedNormalized,
            minISO: minimumISOValue,
            maxISO: maximumISOValue
        )
        currentManualISOValue = targetISO
        applyISOPreset(.custom, shouldShowHint: true)
    }

    func applyISOAuto() {
        applyISOPreset(.auto, shouldShowHint: true)
    }

    func resetISO() {
        applyISOPreset(.auto, shouldShowHint: true)
    }

    var isoDialValue: Double {
        let value = selectedISOPreset == .auto ? currentISOValue : currentManualISOValue
        return normalizedISOValue(value, minISO: minimumISOValue, maxISO: maximumISOValue)
    }

    var isoDialRange: ClosedRange<Double> {
        0...1
    }

    var isoDialStepValue: Double {
        Self.isoDialNormalizedStep
    }

    var isoLeftLabel: String {
        "ISO \(Int(minimumISOValue.rounded()))"
    }

    var isoCenterLabel: String {
        "ISO \(Int(isoValue(forNormalized: 0.5, minISO: minimumISOValue, maxISO: maximumISOValue).rounded()))"
    }

    var isoRightLabel: String {
        "ISO \(Int(maximumISOValue.rounded()))"
    }

    var isoDisplayText: String {
        let effectiveISO = selectedISOPreset == .auto ? currentISOValue : currentManualISOValue
        let isoText = "ISO \(Int(effectiveISO.rounded()))"
        if selectedISOPreset == .auto {
            guard effectiveISO > 0 else { return "Auto" }
            return "Auto · \(isoText)"
        }
        return isoText
    }

    private func applyISOPreset(
        _ preset: CaptureISOPreset,
        shouldShowHint: Bool
    ) {
        guard !isPreviewInteractionTemporarilyRestricted else {
            captureHintText = previewInteractionRestrictedHintText
            return
        }
        guard !isFocusExposureLocked else {
            captureHintText = "AE/AF 锁定中，先长按解锁后再调 ISO"
            return
        }
        guard !isExposureLocked else {
            captureHintText = "AE-L 已开启，先关闭后再调 ISO"
            return
        }

        switch preset {
        case .auto:
            break
        case .low, .medium, .high, .custom:
            if requestManualPhysicalModeIfNeeded(
                reason: "manualISO",
                completion: { [weak self] in
                    self?.applyISOPreset(preset, shouldShowHint: shouldShowHint)
                }
            ) {
                return
            }
        }

        switch preset {
        case .auto:
            guard isISOAutoSupported else {
                captureHintText = "当前摄像头不支持 ISO 自动模式"
                return
            }
        case .low, .medium, .high, .custom:
            guard isISOPresetSupported else {
                captureHintText = "当前摄像头不支持固定 ISO"
                return
            }
        }

        let usesSessionExposureDevice: Bool
        switch preset {
        case .auto:
            usesSessionExposureDevice = true
        case .low, .medium, .high, .custom:
            usesSessionExposureDevice = false
        }

        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard let device = self.currentVideoInput?.device else { return }
            let exposureDevice = usesSessionExposureDevice ? device : self.manualExposureControlDevice(for: device)
            do {
                try exposureDevice.lockForConfiguration()
                let appliedISO: Float
                switch preset {
                case .auto:
                    guard exposureDevice.isExposureModeSupported(.continuousAutoExposure) else {
                        exposureDevice.unlockForConfiguration()
                        DispatchQueue.main.async {
                            self.captureHintText = "当前摄像头不支持 ISO 自动模式"
                        }
                        return
                    }
                    exposureDevice.exposureMode = .continuousAutoExposure
                    appliedISO = exposureDevice.iso
                case .low, .medium, .high:
                    guard exposureDevice.isExposureModeSupported(.custom) else {
                        exposureDevice.unlockForConfiguration()
                        DispatchQueue.main.async {
                            self.captureHintText = "当前摄像头不支持固定 ISO"
                        }
                        return
                    }
                    let targetISO = self.targetISOValue(for: preset, device: exposureDevice)
                    let quantizedISO = self.quantizedISOValue(targetISO)
                    guard let exposureWrite = self.sanitizedCustomExposureWrite(
                        rawDuration: AVCaptureDevice.currentExposureDuration,
                        rawISO: quantizedISO,
                        device: exposureDevice,
                        context: "isoPreset"
                    ) else {
                        exposureDevice.unlockForConfiguration()
                        DispatchQueue.main.async {
                            self.captureHintText = "当前摄像头曝光能力异常，ISO 调整已跳过"
                        }
                        return
                    }
                    let writeToken = self.nextManualParameterWriteToken(for: exposureDevice, scope: .exposure)
                    exposureDevice.setExposureModeCustom(duration: exposureWrite.duration, iso: exposureWrite.iso) { [weak self, weak exposureDevice] _ in
                        guard let self, let exposureDevice else { return }
                        let readbackISO = exposureDevice.iso
                        let readbackShutterSeconds = CMTimeGetSeconds(exposureDevice.exposureDuration)
                        DispatchQueue.main.async {
                            guard self.isCurrentManualParameterWrite(writeToken) else {
                                print("[ManualParamWrite] stale ISO preset completion ignored token=\(writeToken)")
                                return
                            }
                            self.currentISOValue = readbackISO
                            self.currentManualISOValue = readbackISO
                            self.currentShutterDurationSeconds = readbackShutterSeconds.isFinite ? readbackShutterSeconds : 0
                            if shouldShowHint {
                                self.captureHintText = "ISO：\(Int(readbackISO.rounded()))"
                            }
                        }
                    }
                    appliedISO = exposureWrite.iso
                case .custom:
                    guard exposureDevice.isExposureModeSupported(.custom) else {
                        exposureDevice.unlockForConfiguration()
                        DispatchQueue.main.async {
                            self.captureHintText = "当前摄像头不支持固定 ISO"
                        }
                        return
                    }
                    let targetISO = self.clampedISOValue(self.currentManualISOValue, device: exposureDevice)
                    let quantizedISO = self.quantizedISOValue(targetISO)
                    guard let exposureWrite = self.sanitizedCustomExposureWrite(
                        rawDuration: AVCaptureDevice.currentExposureDuration,
                        rawISO: quantizedISO,
                        device: exposureDevice,
                        context: "isoCustom"
                    ) else {
                        exposureDevice.unlockForConfiguration()
                        DispatchQueue.main.async {
                            self.captureHintText = "当前摄像头曝光能力异常，ISO 调整已跳过"
                        }
                        return
                    }
                    let writeToken = self.nextManualParameterWriteToken(for: exposureDevice, scope: .exposure)
                    exposureDevice.setExposureModeCustom(duration: exposureWrite.duration, iso: exposureWrite.iso) { [weak self, weak exposureDevice] _ in
                        guard let self, let exposureDevice else { return }
                        let readbackISO = exposureDevice.iso
                        let readbackShutterSeconds = CMTimeGetSeconds(exposureDevice.exposureDuration)
                        DispatchQueue.main.async {
                            guard self.isCurrentManualParameterWrite(writeToken) else {
                                print("[ManualParamWrite] stale ISO custom completion ignored token=\(writeToken)")
                                return
                            }
                            self.currentISOValue = readbackISO
                            self.currentManualISOValue = readbackISO
                            self.currentShutterDurationSeconds = readbackShutterSeconds.isFinite ? readbackShutterSeconds : 0
                            if shouldShowHint {
                                self.captureHintText = "ISO：\(Int(readbackISO.rounded()))"
                            }
                        }
                    }
                    appliedISO = exposureWrite.iso
                }
                let updatedShutterSeconds = CMTimeGetSeconds(exposureDevice.exposureDuration)
                exposureDevice.unlockForConfiguration()
                DispatchQueue.main.async {
                    self.selectedISOPreset = preset == .auto ? .auto : .custom
                    self.currentISOValue = appliedISO
                    self.currentManualISOValue = appliedISO
                    self.currentShutterDurationSeconds = updatedShutterSeconds.isFinite ? updatedShutterSeconds : 0
                    if shouldShowHint {
                        self.captureHintText = preset == .auto
                            ? "ISO：Auto"
                            : "ISO：\(Int(appliedISO.rounded()))"
                    }
                    if preset == .auto {
                        self.restoreAutomaticVirtualModeIfReady(reason: "isoAuto")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.captureHintText = "ISO 调整失败"
                }
            }
        }
    }

    func setShutterDialValue(_ requestedValue: Double) {
        let clampedNormalized = max(0.0, min(1.0, requestedValue))
        let targetDurationSeconds = shutterDurationSeconds(
            forNormalized: clampedNormalized,
            minDuration: minimumShutterDurationSeconds,
            maxDuration: maximumShutterDurationSeconds
        )
        currentManualShutterDurationSeconds = targetDurationSeconds
        applyShutterPreset(.custom, shouldShowHint: true)
    }

    func applyShutterAuto() {
        applyShutterPreset(.auto, shouldShowHint: true)
    }

    func resetShutter() {
        applyShutterPreset(.auto, shouldShowHint: true)
    }

    var shutterDialValue: Double {
        let seconds = selectedShutterPreset == .auto
            ? currentShutterDurationSeconds
            : currentManualShutterDurationSeconds
        return normalizedShutterValue(
            seconds: seconds,
            minDuration: minimumShutterDurationSeconds,
            maxDuration: maximumShutterDurationSeconds
        )
    }

    var shutterDialRange: ClosedRange<Double> {
        0...1
    }

    var shutterDialStepValue: Double {
        Self.shutterDialNormalizedStep
    }

    var shutterLeftLabel: String {
        formattedShutterDurationText(seconds: maximumShutterDurationSeconds) ?? "慢"
    }

    var shutterCenterLabel: String {
        let middle = shutterDurationSeconds(
            forNormalized: 0.5,
            minDuration: minimumShutterDurationSeconds,
            maxDuration: maximumShutterDurationSeconds
        )
        return formattedShutterDurationText(seconds: middle) ?? "中"
    }

    var shutterRightLabel: String {
        formattedShutterDurationText(seconds: minimumShutterDurationSeconds) ?? "快"
    }

    var shutterDisplayText: String {
        let seconds = selectedShutterPreset == .auto
            ? currentShutterDurationSeconds
            : currentManualShutterDurationSeconds
        guard let durationText = formattedShutterDurationText(seconds: seconds) else {
            return selectedShutterPreset == .auto ? "Auto" : "手动"
        }
        return selectedShutterPreset == .auto ? "Auto · \(durationText)" : durationText
    }

    func setAspectRatioDialValue(_ requestedValue: Double) {
        let presets = CapturePhotoAspectRatioPreset.allCases
        guard !presets.isEmpty else { return }
        let clamped = max(0, min(Double(presets.count - 1), requestedValue))
        let index = Int(clamped.rounded())
        _ = selectAspectRatioPreset(index: index, source: "legacyDial")
    }

    func resetAspectRatio() {
        _ = selectAspectRatioPreset(index: CapturePhotoAspectRatioPreset.allCases.firstIndex(of: .ratio3x4) ?? 0, source: "reset")
    }

    var aspectRatioDialValue: Double {
        let presets = CapturePhotoAspectRatioPreset.allCases
        guard let index = presets.firstIndex(of: selectedAspectRatioPreset) else { return 0 }
        return Double(index)
    }

    var aspectRatioDisplayText: String {
        selectedAspectRatioPreset.displayText
    }

    var previewAspectRatioValue: CGFloat {
        selectedAspectRatioPreset.ratioValue
    }

    func setPixelDialValue(_ requestedValue: Double) {
        let presets = CapturePhotoPixelPreset.allCases
        guard !presets.isEmpty else { return }
        let clamped = max(0, min(Double(presets.count - 1), requestedValue))
        let index = Int(clamped.rounded())
        _ = selectPixelPreset(index: index, source: "legacyDial")
    }

    func resetPixelPreset() {
        _ = selectPixelPreset(index: CapturePhotoPixelPreset.allCases.firstIndex(of: .p1600) ?? 0, source: "reset")
    }

    var pixelDialValue: Double {
        let presets = CapturePhotoPixelPreset.allCases
        guard let index = presets.firstIndex(of: selectedPixelPreset) else { return 0 }
        return Double(index)
    }

    var pixelDisplayText: String {
        selectedPixelPreset.displayText(for: selectedAspectRatioPreset.ratioValue)
    }

    @discardableResult
    func selectAspectRatioPreset(index requestedIndex: Int, source: String) -> CaptureOptionSelectionResult {
        let presets = CapturePhotoAspectRatioPreset.allCases
        guard !presets.isEmpty else {
            return CaptureOptionSelectionResult(
                selectedIndex: 0,
                selectedValue: "--",
                runtimeAppliedValue: "--",
                fallbackReason: "noAspectRatioPresets",
                generation: aspectRatioSelectionGeneration
            )
        }

        aspectRatioSelectionGeneration &+= 1
        let index = max(0, min(presets.count - 1, requestedIndex))
        let preset = presets[index]
        let previousPreset = selectedAspectRatioPreset
        let didApply = applyAspectRatioPreset(preset, shouldShowHint: true)
        let selectedIndex = presets.firstIndex(of: selectedAspectRatioPreset) ?? index
        let fallbackReason = index == requestedIndex ? nil : "clampedIndex"
        logCaptureOptionSelection(
            scope: "aspectRatio",
            source: source,
            requestedIndex: requestedIndex,
            selectedIndex: selectedIndex,
            selectedValue: preset.displayText,
            runtimeAppliedValue: selectedAspectRatioPreset.displayText,
            fallbackReason: fallbackReason,
            generation: aspectRatioSelectionGeneration,
            changed: didApply || previousPreset != selectedAspectRatioPreset
        )
        return CaptureOptionSelectionResult(
            selectedIndex: selectedIndex,
            selectedValue: preset.displayText,
            runtimeAppliedValue: selectedAspectRatioPreset.displayText,
            fallbackReason: fallbackReason,
            generation: aspectRatioSelectionGeneration
        )
    }

    @discardableResult
    func selectPixelPreset(index requestedIndex: Int, source: String) -> CaptureOptionSelectionResult {
        let presets = CapturePhotoPixelPreset.allCases
        guard !presets.isEmpty else {
            return CaptureOptionSelectionResult(
                selectedIndex: 0,
                selectedValue: "--",
                runtimeAppliedValue: "--",
                fallbackReason: "noPixelPresets",
                generation: pixelSelectionGeneration
            )
        }

        pixelSelectionGeneration &+= 1
        let index = max(0, min(presets.count - 1, requestedIndex))
        let preset = presets[index]
        let previousPreset = selectedPixelPreset
        let didApply = applyPixelPreset(preset, shouldShowHint: true)
        let selectedIndex = presets.firstIndex(of: selectedPixelPreset) ?? index
        let fallbackReason: String? = {
            if index != requestedIndex { return "clampedIndex" }
            if preset.requiresRawSupport, !isRAWCaptureSupported { return "rawUnsupportedFallback" }
            return nil
        }()
        logCaptureOptionSelection(
            scope: "outputQuality",
            source: source,
            requestedIndex: requestedIndex,
            selectedIndex: selectedIndex,
            selectedValue: preset.shortLabel,
            runtimeAppliedValue: selectedPixelPreset.shortLabel,
            fallbackReason: fallbackReason,
            generation: pixelSelectionGeneration,
            changed: didApply || previousPreset != selectedPixelPreset
        )
        return CaptureOptionSelectionResult(
            selectedIndex: selectedIndex,
            selectedValue: preset.shortLabel,
            runtimeAppliedValue: selectedPixelPreset.shortLabel,
            fallbackReason: fallbackReason,
            generation: pixelSelectionGeneration
        )
    }

    @discardableResult
    private func applyAspectRatioPreset(
        _ preset: CapturePhotoAspectRatioPreset,
        shouldShowHint: Bool
    ) -> Bool {
        if selectedAspectRatioPreset == preset { return false }
        selectedAspectRatioPreset = preset
        if shouldShowHint {
            captureHintText = "比例：\(preset.displayText) · \(selectedPixelPreset.displayText(for: preset.ratioValue))"
        }
        return true
    }

    @discardableResult
    private func applyPixelPreset(
        _ preset: CapturePhotoPixelPreset,
        shouldShowHint: Bool
    ) -> Bool {
        if preset.requiresRawSupport, !isRAWCaptureSupported {
            let didFallback = selectedPixelPreset != .best
            selectedPixelPreset = .best
            captureHintText = "当前设备不支持 RAW，已回退最佳质量"
            return didFallback
        }
        if selectedPixelPreset == preset { return false }
        selectedPixelPreset = preset
        if shouldShowHint {
            if preset == .raw {
                captureHintText = "RAW：设备支持，当前保留最佳预览；RAW 文件保存后续接入"
            } else if preset == .best {
                captureHintText = "像素：最佳质量，不做固定长边压缩"
            } else {
                captureHintText = "像素：\(preset.displayText(for: selectedAspectRatioPreset.ratioValue))"
            }
        }
        return true
    }

    private func applyShutterPreset(
        _ preset: CaptureShutterPreset,
        shouldShowHint: Bool
    ) {
        guard !isPreviewInteractionTemporarilyRestricted else {
            captureHintText = previewInteractionRestrictedHintText
            return
        }
        guard !isFocusExposureLocked else {
            captureHintText = "AE/AF 锁定中，先长按解锁后再调快门"
            return
        }
        guard !isExposureLocked else {
            captureHintText = "AE-L 已开启，先关闭后再调快门"
            return
        }

        switch preset {
        case .auto:
            break
        case .s1_30, .s1_60, .s1_120, .s1_250, .s1_500, .custom:
            if requestManualPhysicalModeIfNeeded(
                reason: "manualShutter",
                completion: { [weak self] in
                    self?.applyShutterPreset(preset, shouldShowHint: shouldShowHint)
                }
            ) {
                return
            }
        }

        switch preset {
        case .auto:
            guard isShutterAutoSupported else {
                captureHintText = "当前摄像头不支持自动快门"
                return
            }
        case .s1_30, .s1_60, .s1_120, .s1_250, .s1_500, .custom:
            guard isShutterPresetSupported else {
                captureHintText = "当前摄像头不支持手动快门"
                return
            }
        }

        let usesSessionExposureDevice: Bool
        switch preset {
        case .auto:
            usesSessionExposureDevice = true
        case .s1_30, .s1_60, .s1_120, .s1_250, .s1_500, .custom:
            usesSessionExposureDevice = false
        }

        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard let device = self.currentVideoInput?.device else { return }
            let exposureDevice = usesSessionExposureDevice ? device : self.manualExposureControlDevice(for: device)

            do {
                try exposureDevice.lockForConfiguration()
                let appliedDuration: CMTime
                switch preset {
                case .auto:
                    guard exposureDevice.isExposureModeSupported(.continuousAutoExposure) else {
                        exposureDevice.unlockForConfiguration()
                        DispatchQueue.main.async {
                            self.captureHintText = "当前摄像头不支持自动快门"
                        }
                        return
                    }
                    exposureDevice.exposureMode = .continuousAutoExposure
                    appliedDuration = exposureDevice.exposureDuration
                case .s1_30, .s1_60, .s1_120, .s1_250, .s1_500:
                    guard exposureDevice.isExposureModeSupported(.custom) else {
                        exposureDevice.unlockForConfiguration()
                        DispatchQueue.main.async {
                            self.captureHintText = "当前摄像头不支持手动快门"
                        }
                        return
                    }
                    let targetDuration = self.clampedShutterDuration(for: preset, device: exposureDevice)
                    let quantizedDuration = self.quantizedShutterDuration(targetDuration, device: exposureDevice)
                    let isoForWrite = exposureDevice.iso
                    guard let exposureWrite = self.sanitizedCustomExposureWrite(
                        rawDuration: quantizedDuration,
                        rawISO: isoForWrite,
                        device: exposureDevice,
                        context: "shutterPreset"
                    ) else {
                        exposureDevice.unlockForConfiguration()
                        DispatchQueue.main.async {
                            self.captureHintText = "当前摄像头曝光能力异常，快门调整已跳过"
                        }
                        return
                    }
                    let writeToken = self.nextManualParameterWriteToken(for: exposureDevice, scope: .exposure)
                    exposureDevice.setExposureModeCustom(duration: exposureWrite.duration, iso: exposureWrite.iso) { [weak self, weak exposureDevice] _ in
                        guard let self, let exposureDevice else { return }
                        let readbackISO = exposureDevice.iso
                        let readbackSeconds = CMTimeGetSeconds(exposureDevice.exposureDuration)
                        DispatchQueue.main.async {
                            guard self.isCurrentManualParameterWrite(writeToken) else {
                                print("[ManualParamWrite] stale shutter preset completion ignored token=\(writeToken)")
                                return
                            }
                            self.currentISOValue = readbackISO
                            self.currentShutterDurationSeconds = readbackSeconds.isFinite ? readbackSeconds : 0
                            if readbackSeconds.isFinite, readbackSeconds > 0 {
                                self.currentManualShutterDurationSeconds = readbackSeconds
                            }
                            if shouldShowHint {
                                self.captureHintText = "快门：\(self.formattedShutterDurationText(seconds: readbackSeconds) ?? "手动")"
                            }
                        }
                    }
                    appliedDuration = exposureWrite.duration
                case .custom:
                    guard exposureDevice.isExposureModeSupported(.custom) else {
                        exposureDevice.unlockForConfiguration()
                        DispatchQueue.main.async {
                            self.captureHintText = "当前摄像头不支持手动快门"
                        }
                        return
                    }
                    let requestedDuration = CMTime(
                        seconds: self.currentManualShutterDurationSeconds,
                        preferredTimescale: 1_000_000_000
                    )
                    let targetDuration = self.clampedShutterDuration(requestedDuration, device: exposureDevice)
                    let quantizedDuration = self.quantizedShutterDuration(targetDuration, device: exposureDevice)
                    let isoForWrite = exposureDevice.iso
                    guard let exposureWrite = self.sanitizedCustomExposureWrite(
                        rawDuration: quantizedDuration,
                        rawISO: isoForWrite,
                        device: exposureDevice,
                        context: "shutterCustom"
                    ) else {
                        exposureDevice.unlockForConfiguration()
                        DispatchQueue.main.async {
                            self.captureHintText = "当前摄像头曝光能力异常，快门调整已跳过"
                        }
                        return
                    }
                    let writeToken = self.nextManualParameterWriteToken(for: exposureDevice, scope: .exposure)
                    exposureDevice.setExposureModeCustom(duration: exposureWrite.duration, iso: exposureWrite.iso) { [weak self, weak exposureDevice] _ in
                        guard let self, let exposureDevice else { return }
                        let readbackISO = exposureDevice.iso
                        let readbackSeconds = CMTimeGetSeconds(exposureDevice.exposureDuration)
                        DispatchQueue.main.async {
                            guard self.isCurrentManualParameterWrite(writeToken) else {
                                print("[ManualParamWrite] stale shutter custom completion ignored token=\(writeToken)")
                                return
                            }
                            self.currentISOValue = readbackISO
                            self.currentShutterDurationSeconds = readbackSeconds.isFinite ? readbackSeconds : 0
                            if readbackSeconds.isFinite, readbackSeconds > 0 {
                                self.currentManualShutterDurationSeconds = readbackSeconds
                            }
                            if shouldShowHint {
                                self.captureHintText = "快门：\(self.formattedShutterDurationText(seconds: readbackSeconds) ?? "手动")"
                            }
                        }
                    }
                    appliedDuration = exposureWrite.duration
                }
                exposureDevice.unlockForConfiguration()

                let seconds = CMTimeGetSeconds(appliedDuration)
                let updatedISO = exposureDevice.iso
                DispatchQueue.main.async {
                    self.selectedShutterPreset = preset == .auto ? .auto : .custom
                    self.currentShutterDurationSeconds = seconds.isFinite ? seconds : 0
                    if seconds.isFinite, seconds > 0 {
                        self.currentManualShutterDurationSeconds = seconds
                    }
                    self.currentISOValue = updatedISO
                    if shouldShowHint {
                        self.captureHintText = preset == .auto
                            ? "快门：Auto"
                            : "快门：\(self.formattedShutterDurationText(seconds: seconds) ?? "手动")"
                    }
                    if preset == .auto {
                        self.restoreAutomaticVirtualModeIfReady(reason: "shutterAuto")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.captureHintText = "快门调整失败"
                }
            }
        }
    }

    @discardableResult
    func manualFocusEntryCapability(reason: String) -> ManualFocusCapability {
        guard !isFocusExposureLocked else {
            let capability = ManualFocusCapability.unsupported(reason: "focusExposureLocked")
            logManualFocusGuard(device: currentVideoInput?.device, capability: capability, reason: reason)
            captureHintText = capability.userFacingHint
            return capability
        }
        guard !isPreviewInteractionTemporarilyRestricted else {
            let capability = ManualFocusCapability.unsupported(reason: "previewRestricted")
            logManualFocusGuard(device: currentVideoInput?.device, capability: capability, reason: reason)
            captureHintText = previewInteractionRestrictedHintText
            return capability
        }
        guard !isSwitchingCamera else {
            let capability = ManualFocusCapability.unsupported(reason: "lensSwitching")
            logManualFocusGuard(device: currentVideoInput?.device, capability: capability, reason: reason)
            captureHintText = capability.userFacingHint
            return capability
        }

        let capability = updateFocusCapabilityState(
            with: currentVideoInput?.device,
            reason: reason,
            resetsFocusMode: false
        )
        guard capability.canEnterManualFocusMode else {
            logManualFocusGuard(device: currentVideoInput?.device, capability: capability, reason: reason)
            captureHintText = capability.userFacingHint
            return capability
        }
        return capability
    }

    @discardableResult
    func canAdjustManualFocusPosition(reason: String) -> Bool {
        let capability = manualFocusEntryCapability(reason: reason)
        guard capability.isFull else {
            logManualFocusGuard(device: currentVideoInput?.device, capability: capability, reason: reason)
            captureHintText = capability.userFacingHint
            return false
        }
        return true
    }

    func lockCurrentManualFocus(reason: String) {
        guard !isFocusExposureLocked else {
            let capability = ManualFocusCapability.unsupported(reason: "focusExposureLocked")
            logManualFocusGuard(device: currentVideoInput?.device, capability: capability, reason: "lockCurrent:\(reason)")
            captureHintText = capability.userFacingHint
            return
        }
        guard !isPreviewInteractionTemporarilyRestricted else {
            let capability = ManualFocusCapability.unsupported(reason: "previewRestricted")
            logManualFocusGuard(device: currentVideoInput?.device, capability: capability, reason: "lockCurrent:\(reason)")
            captureHintText = previewInteractionRestrictedHintText
            return
        }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard let device = self.currentVideoInput?.device else {
                DispatchQueue.main.async {
                    let capability = ManualFocusCapability.unsupported(reason: "noActiveSessionDevice")
                    self.logManualFocusGuard(device: nil, capability: capability, reason: "lockCurrent:\(reason)")
                    self.isManualFocusEntrySupported = false
                    self.isManualFocusSupported = false
                    self.captureHintText = capability.userFacingHint
                }
                return
            }
            let capability = self.manualFocusCapability(for: device)
            guard capability.canEnterManualFocusMode else {
                self.logManualFocusGuard(device: device, capability: capability, reason: "lockCurrent:\(reason)")
                DispatchQueue.main.async {
                    self.isManualFocusEntrySupported = false
                    self.isManualFocusSupported = false
                    self.captureHintText = capability.userFacingHint
                }
                return
            }
            do {
                try device.lockForConfiguration()
                device.focusMode = .locked
                let quantized = self.quantizedManualFocusPosition(device.lensPosition)
                self.logManualFocusWrite(
                    device: device,
                    requested: quantized,
                    applied: quantized,
                    reason: "lockCurrent:\(reason)",
                    success: true,
                    error: nil
                )
                device.unlockForConfiguration()
                DispatchQueue.main.async {
                    self.isManualFocusEntrySupported = capability.canEnterManualFocusMode
                    self.isManualFocusSupported = capability.isFull
                    self.currentManualFocusPosition = quantized
                    self.lastAppliedManualFocusPosition = quantized
                    self.focusControlMode = .manual
                    self.captureHintText = capability.isFull
                        ? "MF \(self.manualFocusDisplayText)"
                        : capability.userFacingHint
                }
            } catch {
                self.logManualFocusWrite(
                    device: device,
                    requested: device.lensPosition,
                    applied: device.lensPosition,
                    reason: "lockCurrent:\(reason)",
                    success: false,
                    error: error
                )
                DispatchQueue.main.async {
                    self.captureHintText = "锁定当前焦点失败"
                }
            }
        }
    }

    func setManualFocusLensPosition(_ requestedLensPosition: Float) {
        focusFeedbackTask?.cancel()
        focusFeedbackTask = nil
        focusMarker = nil
        lastManualFocusInteractionAt = Date()
        productSharpnessBlurryHitCount = 0
        hasProductFocusAssistTriggeredForCurrentBlurEpisode = false
        guard !isFocusExposureLocked else {
            let capability = ManualFocusCapability.unsupported(reason: "focusExposureLocked")
            logManualFocusGuard(device: currentVideoInput?.device, capability: capability, reason: "writePreflight")
            captureHintText = "AE/AF 锁定中，先长按解锁后再切 MF"
            return
        }
        guard !isPreviewInteractionTemporarilyRestricted else {
            let capability = ManualFocusCapability.unsupported(reason: "previewRestricted")
            logManualFocusGuard(device: currentVideoInput?.device, capability: capability, reason: "writePreflight")
            captureHintText = previewInteractionRestrictedHintText
            return
        }
        let preflightCapability = updateFocusCapabilityState(
            with: currentVideoInput?.device,
            reason: "writePreflight",
            resetsFocusMode: false
        )
        guard preflightCapability.isFull else {
            logManualFocusGuard(device: currentVideoInput?.device, capability: preflightCapability, reason: "writePreflight")
            captureHintText = preflightCapability.userFacingHint
            return
        }
        let wasManualMode = focusControlMode == .manual
        let previousManualPosition = lastAppliedManualFocusPosition

        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard let device = self.currentVideoInput?.device else {
                DispatchQueue.main.async {
                    let capability = ManualFocusCapability.unsupported(reason: "noActiveSessionDevice")
                    self.logManualFocusGuard(device: nil, capability: capability, reason: "writeQueue")
                    self.isManualFocusEntrySupported = false
                    self.isManualFocusSupported = false
                    self.captureHintText = capability.userFacingHint
                }
                return
            }
            let capability = self.manualFocusCapability(for: device)
            guard capability.isFull else {
                self.logManualFocusGuard(device: device, capability: capability, reason: "writeQueue")
                DispatchQueue.main.async {
                    self.isManualFocusEntrySupported = capability.canEnterManualFocusMode
                    self.isManualFocusSupported = false
                    self.captureHintText = capability.userFacingHint
                    if self.focusControlMode == .manual {
                        self.focusControlMode = .auto
                    }
                }
                return
            }

            let clamped = max(0, min(1, requestedLensPosition))
            let quantized = quantizedManualFocusPosition(clamped)
            if wasManualMode,
               let previousManualPosition,
               abs(previousManualPosition - quantized) < 0.0001 {
                DispatchQueue.main.async {
                    self.currentManualFocusPosition = quantized
                }
                return
            }
            do {
                try device.lockForConfiguration()
                device.setFocusModeLocked(lensPosition: quantized)
                self.logManualFocusWrite(
                    device: device,
                    requested: requestedLensPosition,
                    applied: quantized,
                    reason: "user",
                    success: true,
                    error: nil
                )
                device.unlockForConfiguration()
                DispatchQueue.main.async {
                    self.isManualFocusEntrySupported = true
                    self.isManualFocusSupported = true
                    self.currentManualFocusPosition = quantized
                    self.lastAppliedManualFocusPosition = quantized
                    self.focusControlMode = .manual
                    self.captureHintText = "MF \(self.manualFocusDisplayText)"
                }
            } catch {
                self.logManualFocusWrite(
                    device: device,
                    requested: requestedLensPosition,
                    applied: quantized,
                    reason: "user",
                    success: false,
                    error: error
                )
                DispatchQueue.main.async {
                    self.captureHintText = "手动对焦失败"
                }
            }
        }
    }

    func restoreAutofocusMode() {
        focusFeedbackTask?.cancel()
        focusFeedbackTask = nil
        isProductFocusAssistSuppressedByManualFocusUI = false
        lastManualFocusInteractionAt = Date()
        guard !isPreviewInteractionTemporarilyRestricted else {
            captureHintText = previewInteractionRestrictedHintText
            return
        }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard let device = self.currentVideoInput?.device else {
                self.logManualFocusRestoreAF(device: nil, mode: "none", reason: "user", success: false, error: nil)
                return
            }
            do {
                try device.lockForConfiguration()
                let appliedMode: String
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                    appliedMode = "continuousAutoFocus"
                } else if device.isFocusModeSupported(.autoFocus) {
                    device.focusMode = .autoFocus
                    appliedMode = "autoFocus"
                } else {
                    appliedMode = "unchanged:\(device.focusMode.rawValue)"
                }
                let updatedLensPosition = device.lensPosition
                self.logManualFocusRestoreAF(device: device, mode: appliedMode, reason: "user", success: true, error: nil)
                device.unlockForConfiguration()
                DispatchQueue.main.async {
                    self.focusControlMode = .auto
                    let quantized = self.quantizedManualFocusPosition(updatedLensPosition)
                    self.currentManualFocusPosition = quantized
                    self.lastAppliedManualFocusPosition = quantized
                    self.updateFocusCapabilityState(with: device, reason: "restoreAF", resetsFocusMode: false)
                    self.captureHintText = "已切回 AF"
                }
            } catch {
                self.logManualFocusRestoreAF(device: device, mode: "failed", reason: "user", success: false, error: error)
                DispatchQueue.main.async {
                    self.captureHintText = "恢复 AF 失败"
                }
            }
        }
    }

    func setProductFocusAssistManualSuppression(_ isSuppressed: Bool) {
        if isSuppressed {
            focusFeedbackTask?.cancel()
            focusFeedbackTask = nil
            focusMarker = nil
        }
        isProductFocusAssistSuppressedByManualFocusUI = isSuppressed
        lastManualFocusInteractionAt = Date()
        productSharpnessBlurryHitCount = 0
        hasProductFocusAssistTriggeredForCurrentBlurEpisode = false
        if isSuppressed {
            productSharpnessStatusText = "MF 中，仅检测清晰度"
        }
    }

    var exposureBiasDisplayText: String {
        String(format: "%+.2f", currentExposureBias)
    }

    var productAutoExposureDisplayText: String {
        if isExposureBiasAutoMode, let productAutoExposureAppliedBias {
            return "商品Auto \(String(format: "%+.1f", productAutoExposureAppliedBias))"
        }
        return productAutoExposureStatusText
    }

    var lockStatusBadgeText: String {
        if isFocusExposureLocked {
            return "AEAF-L"
        }
        if isExposureLocked {
            return "AE-L"
        }
        return "自动"
    }

    var focusModeBadgeText: String {
        focusControlMode.shortText
    }

    var manualFocusZoneText: String {
        switch currentManualFocusPosition {
        case ..<0.34:
            return "近距"
        case 0.34..<0.67:
            return "中距"
        default:
            return "远距"
        }
    }

    var manualFocusPercentText: String {
        "\(Int((currentManualFocusPosition * 100).rounded()))%"
    }

    var manualFocusDisplayText: String {
        "\(manualFocusZoneText) · \(manualFocusPercentText)"
    }

    func toggleGrid() {
        isGridEnabled.toggle()
        captureHintText = isGridEnabled ? "网格线已开启" : "网格线已关闭"
    }

    func toggleLevelIndicator() {
        isLevelIndicatorEnabled.toggle()
        if isLevelIndicatorEnabled {
            startLevelMonitoringIfNeeded()
            captureHintText = "水平仪已开启"
        } else {
            levelRollDegrees = nil
            levelGravityX = nil
            levelGravityY = nil
            levelGravityZ = nil
            captureHintText = "水平仪已关闭"
        }
    }

    var selectedLensProfile: CaptureLensProfile? {
        availableLensProfiles.first(where: { $0.id == selectedLensProfileID })
    }

    var selectedLensDisplayText: String {
        selectedLensProfile?.displayText ?? (activeCameraPosition == .front ? "前置" : "24mm")
    }

    var selectedLensAndZoomDisplayText: String {
        "\(selectedLensDisplayText) \(String(format: "%.1fx", currentLensZoomMultiplier))"
    }

    var zoomOptionsForSelectedLens: [CGFloat] {
        let baseSteps: [CGFloat] = [1.0, 1.2, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0, 6.0]
        let available = baseSteps.filter { $0 <= currentLensMaximumZoomMultiplier + 0.01 }
        if available.isEmpty {
            return [1.0]
        }
        return available
    }

    var currentLensZoomMultiplier: CGFloat {
        guard let profile = selectedLensProfile else { return 1.0 }
        if profile.source == .virtual {
            return currentZoomFactor
        }
        let base = max(1.0, profile.baseZoomFactor)
        return max(1.0, currentZoomFactor / base)
    }

    var currentLensMaximumZoomMultiplier: CGFloat {
        guard let profile = selectedLensProfile else { return 1.0 }
        if profile.source == .virtual {
            return max(minimumZoomFactor, maximumZoomFactor)
        }
        let base = max(1.0, profile.baseZoomFactor)
        let absoluteMax = max(base, maximumZoomFactor)
        return max(1.0, absoluteMax / base)
    }

    var lensZoomDialRange: ClosedRange<Double> {
        if selectedLensProfile?.source == .virtual {
            return Double(minimumZoomFactor)...Double(max(minimumZoomFactor, maximumZoomFactor))
        }
        return 1.0...Double(currentLensMaximumZoomMultiplier)
    }

    var lensZoomDialValue: Double {
        Double(currentLensZoomMultiplier)
    }

    func setLensZoomDialValue(_ dialValue: Double) {
        setLensZoomMultiplier(CGFloat(dialValue))
    }

    func beginLensZoomRulerInteraction() {
        pendingLensRulerZoomTarget = nil
        lastLensRulerZoomWriteAt = .distantPast
        lastLensRulerInteractionAt = Date()
        sessionQueue.async { [weak self] in
            guard let self, let device = self.currentVideoInput?.device else { return }
            do {
                try device.lockForConfiguration()
                if device.isRampingVideoZoom {
                    device.cancelVideoZoomRamp()
                }
                device.unlockForConfiguration()
            } catch {
                // Zoom drag can continue with the next writable frame.
            }
        }
    }

    func setLensZoomDialValueFromRuler(_ dialValue: Double, isFinal: Bool = false) {
        guard let profile = selectedLensProfile else {
            setZoomFactor(CGFloat(dialValue), ramped: false, reason: isFinal ? "rulerFinalNoProfile" : "rulerDragNoProfile")
            return
        }
        let targetZoom: CGFloat
        if profile.source == .virtual {
            targetZoom = CGFloat(dialValue)
        } else {
            let clampedMultiplier = max(1.0, min(currentLensMaximumZoomMultiplier, CGFloat(dialValue)))
            targetZoom = profile.baseZoomFactor * clampedMultiplier
        }
        submitLensRulerZoomTarget(targetZoom, isFinal: isFinal)
    }

    func endLensZoomRulerInteraction(finalDialValue: Double) {
        setLensZoomDialValueFromRuler(finalDialValue, isFinal: true)
    }

    func lensProfile(for focal: CaptureSemanticFocal) -> CaptureLensProfile? {
        availableLensProfiles.first(where: { $0.semanticFocal == focal })
    }

    var selectedSemanticFocal: CaptureSemanticFocal? {
        selectedLensProfile?.semanticFocal
    }

    private var isActiveBackVirtualCamera: Bool {
        activeCameraPosition == .back && Self.isVirtualBackCameraDeviceType(activeCameraDeviceType)
    }

    var semanticFocalCapabilities: [CaptureSemanticFocalCapability] {
        CaptureSemanticFocal.allCases.map { focal in
            guard activeCameraPosition == .back, let profile = lensProfile(for: focal) else {
                return CaptureSemanticFocalCapability(
                    focal: focal,
                    availability: .unavailable,
                    lensID: nil,
                    lensZoomMultiplierRange: nil
                )
            }

            let availability: CaptureSemanticFocalAvailability = (profile.source == .physical)
                ? .physical
                : .derived
            let base = profile.source == .virtual ? 1.0 : max(1.0, profile.baseZoomFactor)
            let absoluteMax = max(base, min(activeDeviceMaximumZoomFactor, profile.lensMaxZoomFactor))
            let multiplierMax = max(1.0, absoluteMax / base)

            return CaptureSemanticFocalCapability(
                focal: focal,
                availability: availability,
                lensID: profile.id,
                lensZoomMultiplierRange: 1.0...Double(multiplierMax)
            )
        }
    }

    var availableSemanticFocalCapabilities: [CaptureSemanticFocalCapability] {
        semanticFocalCapabilities.filter(\.isAvailable)
    }

    private var isManualParameterModeRequested: Bool {
        selectedISOPreset != .auto
            || selectedShutterPreset != .auto
            || selectedWhiteBalancePreset != .auto
    }

    private var shouldUsePhysicalLensProfiles: Bool {
        isManualParameterModeRequested || captureDeviceOperatingMode.shouldUsePhysicalLensProfiles
    }

    private func nextManualParameterWriteToken(
        for device: AVCaptureDevice,
        scope: ManualParameterWriteScope
    ) -> ManualParameterWriteToken {
        let parameterGeneration: UInt64
        switch scope {
        case .exposure:
            exposureParameterWriteGeneration += 1
            parameterGeneration = exposureParameterWriteGeneration
        case .whiteBalance:
            whiteBalanceParameterWriteGeneration += 1
            parameterGeneration = whiteBalanceParameterWriteGeneration
        }
        return ManualParameterWriteToken(
            scope: scope,
            deviceGeneration: deviceSwitchGeneration,
            parameterGeneration: parameterGeneration,
            deviceID: device.uniqueID
        )
    }

    private func invalidateManualParameterWrites(scope: ManualParameterWriteScope) {
        switch scope {
        case .exposure:
            exposureParameterWriteGeneration += 1
        case .whiteBalance:
            whiteBalanceParameterWriteGeneration += 1
        }
    }

    private func isCurrentManualParameterWrite(_ token: ManualParameterWriteToken) -> Bool {
        let currentParameterGeneration: UInt64
        switch token.scope {
        case .exposure:
            currentParameterGeneration = exposureParameterWriteGeneration
        case .whiteBalance:
            currentParameterGeneration = whiteBalanceParameterWriteGeneration
        }
        return token.deviceGeneration == deviceSwitchGeneration
            && token.parameterGeneration == currentParameterGeneration
            && token.deviceID == currentVideoInput?.device.uniqueID
    }

    private func physicalProfile(for focal: CaptureSemanticFocal?) -> PhysicalCameraProfile {
        switch focal {
        case .mm13:
            return .ultraWide
        case .mm77:
            return .telephoto
        case .mm24, .mm48, .none:
            return .wide
        }
    }

    private func physicalLensID(for focal: CaptureSemanticFocal?, profile: PhysicalCameraProfile) -> String? {
        switch (focal, profile) {
        case (.mm13, .ultraWide):
            return "ultra-13"
        case (.mm48, .wide):
            return "wide-48-derived"
        case (.mm24, .wide), (.none, .wide):
            return "wide-24"
        case (.mm77, .telephoto):
            return "tele-77"
        default:
            return nil
        }
    }

    @discardableResult
    private func requestManualPhysicalModeIfNeeded(
        reason: String,
        completion: @escaping () -> Void
    ) -> Bool {
        guard activeCameraPosition == .back else { return false }
        let focal = selectedSemanticFocal ?? .mm24
        let profile = physicalProfile(for: focal)
        let targetDeviceType = profile.preferredDeviceType
        guard activeCameraDeviceType != targetDeviceType else {
            captureDeviceOperatingMode = .manualPhysical(profile: profile)
            return false
        }

        let preferredLensID = physicalLensID(for: focal, profile: profile)
        captureHintText = "切换\(focal.displayText)手动镜头..."
        switchToCamera(
            position: .back,
            preferredDeviceType: targetDeviceType,
            preferredLensID: preferredLensID,
            reason: reason,
            completion: completion
        )
        return true
    }

    private func restoreAutomaticVirtualModeIfReady(reason: String) {
        guard activeCameraPosition == .back else { return }
        guard !isManualParameterModeRequested else { return }
        guard !isSwitchingCamera else { return }
        guard !Self.isVirtualBackCameraDeviceType(activeCameraDeviceType) else {
            captureDeviceOperatingMode = .automaticVirtual
            return
        }

        switchToCamera(
            position: .back,
            preferredDeviceType: nil,
            preferredLensID: nil,
            reason: reason
        )
    }

    func selectLensProfile(_ lensID: String) {
        guard let profile = availableLensProfiles.first(where: { $0.id == lensID }) else { return }

        if activeCameraPosition != profile.position {
            switchToCamera(
                position: profile.position,
                preferredDeviceType: profile.preferredDeviceType,
                preferredLensID: profile.id
            )
            return
        }

        if profile.source == .virtual, isActiveBackVirtualCamera {
            applyLensSelection(profile, shouldShowHint: true)
            return
        }

        let needsDeviceSwitch = profile.position == .back
            && profile.preferredDeviceType != nil
            && activeCameraDeviceType != profile.preferredDeviceType

        if needsDeviceSwitch {
            switchToCamera(
                position: profile.position,
                preferredDeviceType: profile.preferredDeviceType,
                preferredLensID: profile.id
            )
            return
        }

        applyLensSelection(profile, shouldShowHint: true)
    }

    func selectSemanticFocal(_ focal: CaptureSemanticFocal) {
        guard activeCameraPosition == .back else {
            captureHintText = "前置镜头模式下不支持焦段切换"
            return
        }
        guard let profile = lensProfile(for: focal) else {
            captureHintText = "\(focal.displayText) 当前机型不可用"
            return
        }
        selectLensProfile(profile.id)
    }

    func setLensZoomFactor(_ zoomMultiplier: CGFloat) {
        setLensZoomMultiplier(zoomMultiplier)
    }

    func setLensZoomMultiplier(_ zoomMultiplier: CGFloat) {
        guard let profile = selectedLensProfile else {
            setZoomFactor(zoomMultiplier)
            return
        }
        if profile.source == .virtual {
            let clampedZoom = max(minimumZoomFactor, min(maximumZoomFactor, zoomMultiplier))
            setZoomFactor(clampedZoom, ramped: true, reason: "virtualLensRuler")
            return
        }
        let clampedMultiplier = max(1.0, min(currentLensMaximumZoomMultiplier, zoomMultiplier))
        let quantizedMultiplier = quantizedLensZoomMultiplier(
            clampedMultiplier,
            maximum: currentLensMaximumZoomMultiplier
        )
        let snappedMultiplier = snappedLensZoomMultiplier(
            quantizedMultiplier,
            maximum: currentLensMaximumZoomMultiplier
        )
        if shouldUseTele77StabilizationWindow(for: profile) {
            submitTele77StabilizedZoomWrite(multiplier: snappedMultiplier, lensID: profile.id)
            return
        }
        clearTele77StabilizationState()
        let targetZoom = profile.baseZoomFactor * snappedMultiplier
        setZoomFactor(targetZoom, ramped: true, reason: "lensRuler")
    }

    func cycleStabilizerMode() {
        guard let index = CaptureStabilizerMode.allCases.firstIndex(of: selectedStabilizerMode) else { return }
        let next = CaptureStabilizerMode.allCases[(index + 1) % CaptureStabilizerMode.allCases.count]
        selectedStabilizerMode = next
        UserDefaults.standard.set(next.rawValue, forKey: Self.stabilizerUserDefaultsKey)
        applyStabilizerModeToConnections(reason: "userToggle")
        captureHintText = "稳定器：\(next.displayText)"
    }

    func cycleZoomPreset() {
        guard !isPreviewInteractionTemporarilyRestricted else {
            captureHintText = previewInteractionRestrictedHintText
            return
        }
        let presets: [CGFloat] = [1.0, 2.0, 3.0]
        let available = presets.filter { $0 <= maximumZoomFactor + 0.01 }
        guard !available.isEmpty else { return }
        let current = currentZoomFactor
        let next = available.first(where: { $0 > current + 0.05 }) ?? available[0]
        setZoomFactor(next, ramped: true, reason: "cyclePreset")
    }

    func setZoomFactor(
        _ requestedZoom: CGFloat,
        ramped: Bool = true,
        reason: String = "direct"
    ) {
        guard !isSwitchingCamera, countdownSecondsRemaining == nil, !isBurstCapturing, quickPreviewImage == nil else {
            return
        }
        let clamped = max(minimumZoomFactor, min(maximumZoomFactor, requestedZoom))
        lensZoomReadbackGeneration += 1
        let readbackGeneration = lensZoomReadbackGeneration
        lastLensRulerInteractionAt = Date()
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard let device = self.currentVideoInput?.device else { return }
            do {
                try device.lockForConfiguration()
                if device.isRampingVideoZoom {
                    device.cancelVideoZoomRamp()
                }
                if ramped, abs(device.videoZoomFactor - clamped) > 0.015 {
                    device.ramp(toVideoZoomFactor: clamped, withRate: Self.lensZoomRampRate)
                } else {
                    device.videoZoomFactor = clamped
                }
                self.reapplyManualFocusAfterZoomIfNeeded(on: device, reason: reason)
#if DEBUG
                let switchFactors = device.virtualDeviceSwitchOverVideoZoomFactors
                    .map { String(format: "%.2f", CGFloat(truncating: $0)) }
                    .joined(separator: ",")
                print(
                    "[CaptureLensZoom] " +
                    "reason=\(reason) " +
                    "device=\(device.localizedName) " +
                    "type=\(device.deviceType.rawValue) " +
                    "requested=\(String(format: "%.2f", requestedZoom)) " +
                    "target=\(String(format: "%.2f", clamped)) " +
                    "actual=\(String(format: "%.2f", device.videoZoomFactor)) " +
                    "ramped=\(ramped) " +
                    "min=\(String(format: "%.2f", device.minAvailableVideoZoomFactor)) " +
                    "max=\(String(format: "%.2f", device.maxAvailableVideoZoomFactor)) " +
                    "selectedLens=\(self.selectedLensProfile?.displayText ?? "nil") " +
                    "switchOver=[\(switchFactors)]"
                )
#endif
                self.logManualParameterCompatibility(device: device, reason: "zoom:\(reason)", lockProbe: "success")
                device.unlockForConfiguration()
                DispatchQueue.main.async {
                    self.currentZoomFactor = clamped
                }
            } catch {
                DispatchQueue.main.async {
                    self.captureHintText = "缩放更新失败"
                }
            }
        }
#if DEBUG
        self.scheduleLensZoomReadback(
            reason: reason,
            requestedZoom: requestedZoom,
            clampedZoom: clamped,
            generation: readbackGeneration,
            delay: ramped ? 0.48 : 0.08
        )
#endif
    }

#if DEBUG
    private func scheduleLensZoomReadback(
        reason: String,
        requestedZoom: CGFloat,
        clampedZoom: CGFloat,
        generation: UInt64,
        delay: TimeInterval
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.lensZoomReadbackGeneration == generation else { return }
            let selectedLens = self.selectedLensProfile?.displayText ?? "nil"
            self.sessionQueue.async { [weak self] in
                guard let self, let device = self.currentVideoInput?.device else { return }
                let activePrimary: String
                if let active = device.activePrimaryConstituent {
                    activePrimary = self.formattedLensDeviceCapability(active)
                } else {
                    activePrimary = "nil"
                }
                print(
                    "[CaptureLensZoomReadback] " +
                    "reason=\(reason) " +
                    "generation=\(generation) " +
                    "selectedLens=\(selectedLens) " +
                    "requested=\(String(format: "%.3f", requestedZoom)) " +
                    "clamped=\(String(format: "%.3f", clampedZoom)) " +
                    "device=\(device.localizedName) " +
                    "type=\(device.deviceType.rawValue) " +
                    "videoZoom=\(String(format: "%.3f", device.videoZoomFactor)) " +
                    "isRamping=\(device.isRampingVideoZoom) " +
                    "activePrimary=\(activePrimary)"
                )
            }
        }
    }
#endif

    private func reapplyManualFocusAfterZoomIfNeeded(on device: AVCaptureDevice, reason: String) {
        guard focusControlMode == .manual,
              let manualPosition = lastAppliedManualFocusPosition else { return }
        let capability = manualFocusCapability(for: device)
        switch capability {
        case .full:
            let quantized = quantizedManualFocusPosition(manualPosition)
            device.setFocusModeLocked(lensPosition: quantized)
            logManualFocusWrite(
                device: device,
                requested: manualPosition,
                applied: quantized,
                reason: "zoomReapply:\(reason)",
                success: true,
                error: nil
            )
        case .lockCurrentOnly:
            device.focusMode = .locked
            let quantized = quantizedManualFocusPosition(device.lensPosition)
            logManualFocusWrite(
                device: device,
                requested: quantized,
                applied: quantized,
                reason: "zoomReapplyLockOnly:\(reason)",
                success: true,
                error: nil
            )
        case .unsupported:
            logManualFocusGuard(device: device, capability: capability, reason: "zoomReapply:\(reason)")
            DispatchQueue.main.async {
                self.isManualFocusEntrySupported = capability.canEnterManualFocusMode
                self.isManualFocusSupported = capability.isFull
                self.focusControlMode = .auto
                self.captureHintText = capability.userFacingHint
            }
        }
    }

    func applyStabilizerModeToConnections(reason: String = "refresh") {
        let requestedMode = selectedStabilizerMode.requestedVideoStabilizationMode
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let connections = [
                self.videoOutput.connection(with: .video),
                self.photoOutput.connection(with: .video)
            ].compactMap { $0 }

            for connection in connections {
                guard connection.isVideoStabilizationSupported else {
#if DEBUG
                    print("[CaptureStabilizer] reason=\(reason) supported=false requested=\(requestedMode.rawValue)")
#endif
                    continue
                }
                let modeToApply: AVCaptureVideoStabilizationMode
                switch self.selectedStabilizerMode {
                case .off:
                    modeToApply = .off
                case .standard:
                    modeToApply = .auto
                case .enhanced:
                    modeToApply = .cinematic
                }
                connection.preferredVideoStabilizationMode = modeToApply
#if DEBUG
                print(
                    "[CaptureStabilizer] " +
                    "reason=\(reason) " +
                    "supported=true " +
                    "requested=\(requestedMode.rawValue) " +
                    "applied=\(connection.preferredVideoStabilizationMode.rawValue) " +
                    "active=\(connection.activeVideoStabilizationMode.rawValue)"
                )
#endif
            }
        }
    }

    private func submitLensRulerZoomTarget(_ requestedZoom: CGFloat, isFinal: Bool) {
        guard !isSwitchingCamera, countdownSecondsRemaining == nil, !isBurstCapturing, quickPreviewImage == nil else {
            return
        }
        let clamped = max(minimumZoomFactor, min(maximumZoomFactor, requestedZoom))
        let adjusted = lensRulerSwitchOverProtectedZoomTarget(clamped, isFinal: isFinal)
        pendingLensRulerZoomTarget = adjusted
        lastLensRulerInteractionAt = Date()

        let now = Date()
        guard isFinal || now.timeIntervalSince(lastLensRulerZoomWriteAt) >= Self.lensRulerDirectWriteInterval else {
            return
        }
        lastLensRulerZoomWriteAt = now
        pendingLensRulerZoomTarget = nil
        setZoomFactor(adjusted, ramped: false, reason: isFinal ? "rulerFinal" : "rulerDrag")
    }

    private func lensRulerSwitchOverProtectedZoomTarget(_ requestedZoom: CGFloat, isFinal: Bool) -> CGFloat {
        guard !isFinal, let device = currentVideoInput?.device else { return requestedZoom }
        let switchFactors = device.virtualDeviceSwitchOverVideoZoomFactors.map { CGFloat(truncating: $0) }
        guard let nearest = switchFactors.min(by: { abs($0 - requestedZoom) < abs($1 - requestedZoom) }) else {
            return requestedZoom
        }
        guard abs(nearest - requestedZoom) <= Self.lensRulerSwitchOverHysteresis else {
            return requestedZoom
        }
        let current = currentZoomFactor
        guard abs(current - nearest) <= Self.lensRulerSwitchOverHysteresis * 2 else {
            return requestedZoom
        }
#if DEBUG
        print(
            "[CaptureLensZoom] switchOverHysteresis=true " +
            "requested=\(String(format: "%.3f", requestedZoom)) " +
            "held=\(String(format: "%.3f", current)) " +
            "switch=\(String(format: "%.3f", nearest))"
        )
#endif
        return current
    }

    func toggleCameraPosition() {
        if isBurstCapturing {
            captureHintText = "连拍进行中，暂不切换摄像头"
            return
        }
        if countdownSecondsRemaining != nil {
            cancelCountdownIfNeeded()
        }
        isSwitchingCamera = true
        captureHintText = "切换摄像头中..."
        clearTransientCaptureStates(clearCountdown: false)
        clearFocusExposureLockState()
        let target: AVCaptureDevice.Position = activeCameraPosition == .back ? .front : .back
        switchToCamera(position: target)
    }

    func handlePreviewTap(devicePoint: CGPoint, normalizedPoint: CGPoint) {
        let now = Date()
        guard now.timeIntervalSince(lastUserFocusInteractionAt) >= tapFocusThrottleInterval else {
            captureHintText = "正在对焦，请稍候"
            return
        }
        lastUserFocusInteractionAt = now
        productSharpnessBlurryHitCount = 0
        hasProductFocusAssistTriggeredForCurrentBlurEpisode = false
        guard !isPreviewInteractionTemporarilyRestricted else {
            captureHintText = previewInteractionRestrictedHintText
            return
        }
        if isFocusExposureLocked {
            captureHintText = "当前 AE/AF 已锁定，长按可解锁"
            focusMarker = CaptureFocusMarker(normalizedPoint: normalizedPoint, mode: .locked)
            return
        }
        if focusControlMode == .manual {
            captureHintText = isExposureLocked ? "MF + AE-L 生效，点按不改对焦" : "MF 生效，点按不改对焦"
            focusMarker = CaptureFocusMarker(normalizedPoint: normalizedPoint, mode: .locked)
            return
        }
        focusMarker = CaptureFocusMarker(normalizedPoint: normalizedPoint, mode: .focusing)
        captureHintText = isExposureLocked ? "对焦中 · AE-L" : "对焦中"
        applyFocusExposure(
            devicePoint: devicePoint,
            normalizedPoint: normalizedPoint,
            lockAfterFocus: false,
            source: .tap
        )
    }

    func handlePreviewLongPress(devicePoint: CGPoint, normalizedPoint: CGPoint) {
        lastUserFocusInteractionAt = Date()
        productSharpnessBlurryHitCount = 0
        hasProductFocusAssistTriggeredForCurrentBlurEpisode = false
        guard !isPreviewInteractionTemporarilyRestricted else {
            captureHintText = previewInteractionRestrictedHintText
            return
        }
        if focusControlMode == .manual {
            captureHintText = "MF 模式下不可进入 AE/AF 锁定，先切回 AF"
            focusMarker = CaptureFocusMarker(normalizedPoint: normalizedPoint, mode: .locked)
            return
        }
        if isFocusExposureLocked {
            clearFocusExposureLockState()
            focusMarker = CaptureFocusMarker(normalizedPoint: normalizedPoint, mode: .unlocked)
            applyFocusExposure(
                devicePoint: devicePoint,
                normalizedPoint: normalizedPoint,
                lockAfterFocus: false,
                source: .unlockByLongPress
            )
            return
        }

        focusMarker = CaptureFocusMarker(normalizedPoint: normalizedPoint, mode: .locked)
        applyFocusExposure(
            devicePoint: devicePoint,
            normalizedPoint: normalizedPoint,
            lockAfterFocus: true,
            source: .longPress
        )
    }

    func confirmLatestStillPhoto() -> Bool {
        guard let latestStillPhotoResult else {
            captureHintText = "暂无可确认结果"
            return false
        }
        resetLatestResultWorkflowState()
        latestPreservedSourceResult = nil
        confirmedStillPhotoResult = latestStillPhotoResult
        captureHintText = "已设为直接使用，可继续拍摄或生成白底图"
        refreshStatusSummary()
        return true
    }

    func preserveLatestAsSourceMaterial() -> Bool {
        guard let latestStillPhotoResult else {
            captureHintText = "暂无可保留结果"
            return false
        }
        resetLatestResultWorkflowState()
        confirmedStillPhotoResult = nil
        latestPreservedSourceResult = latestStillPhotoResult
        captureHintText = "已保留为采集素材，可后续再决定用途"
        refreshStatusSummary()
        return true
    }

    func triggerProcessingForConfirmedLatest() -> Bool {
        guard !isProcessingLatestResult else {
            return false
        }
        guard let latestStillPhotoResult else {
            captureHintText = "暂无可生成白底的结果"
            return false
        }
        if confirmedStillPhotoResult?.id != latestStillPhotoResult.id {
            confirmedStillPhotoResult = latestStillPhotoResult
        }
        let processingInput = confirmedStillPhotoResult ?? latestStillPhotoResult

        resetLatestResultWorkflowState()
        isProcessingLatestResult = true
        captureHintText = "正在生成白底图..."
        refreshStatusSummary()

        Task { [weak self] in
            guard let self else { return }
            do {
                let processed = try await CaptureWhiteBackgroundProcessor.process(confirmedStillPhoto: processingInput)
                await MainActor.run {
                    self.isProcessingLatestResult = false
                    self.latestProcessedResult = processed
                    self.captureHintText = processed.qualityHintDisplayText
                    self.refreshStatusSummary()
                }
            } catch {
                await MainActor.run {
                    self.isProcessingLatestResult = false
                    self.latestProcessingErrorText = error.localizedDescription
                    self.captureHintText = "白底图生成失败，可重试或返回拍摄"
                    self.refreshStatusSummary()
                }
            }
        }
        return true
    }

    func triggerSaveForLatestProcessed() -> Bool {
        guard let processed = latestProcessedResult else {
            captureHintText = "暂无可保存白底图"
            return false
        }
        guard !isSavingLatestProcessed else {
            return false
        }
        guard !isProcessingLatestResult else {
            captureHintText = "白底处理中，完成后再保存"
            return false
        }

        isSavingLatestProcessed = true
        isLatestProcessedSaveCompleted = false
        latestProcessedSaveFailureText = nil
        captureHintText = "正在保存白底图..."
        refreshStatusSummary()

        Task { [weak self] in
            guard let self else { return }
            do {
                try await CapturePhotoLibraryOutputWriter.exportSingleReadyResult(processed)
                await MainActor.run {
                    self.isSavingLatestProcessed = false
                    self.isLatestProcessedSaveCompleted = true
                    self.latestProcessedSaveFailureText = nil
                    self.captureHintText = "白底图已保存到系统相册"
                    self.refreshStatusSummary()
                }
            } catch {
                await MainActor.run {
                    self.isSavingLatestProcessed = false
                    self.isLatestProcessedSaveCompleted = false
                    self.latestProcessedSaveFailureText = error.localizedDescription
                    self.captureHintText = "白底图保存失败，可重试或返回拍摄"
                    self.refreshStatusSummary()
                }
            }
        }
        return true
    }

    func triggerSaveForLatestOriginal() -> Bool {
        guard let latestStillPhotoResult else {
            captureHintText = "暂无可保存原图"
            return false
        }
        guard !isSavingLatestOriginal else {
            return false
        }

        isSavingLatestOriginal = true
        isLatestOriginalSaveCompleted = false
        latestOriginalSaveFailureText = nil
        captureHintText = "正在保存原图..."
        refreshStatusSummary()

        Task { [weak self] in
            guard let self else { return }
            do {
                try await CapturePhotoLibraryOutputWriter.exportSingleOriginalResult(latestStillPhotoResult)
                await MainActor.run {
                    self.isSavingLatestOriginal = false
                    self.isLatestOriginalSaveCompleted = true
                    self.latestOriginalSaveFailureText = nil
                    self.captureHintText = "原图已保存到系统相册"
                    self.refreshStatusSummary()
                }
            } catch {
                await MainActor.run {
                    self.isSavingLatestOriginal = false
                    self.isLatestOriginalSaveCompleted = false
                    self.latestOriginalSaveFailureText = error.localizedDescription
                    self.captureHintText = "原图保存失败，可重试或返回拍摄"
                    self.refreshStatusSummary()
                }
            }
        }
        return true
    }

    func acceptLatestProcessedResult() -> Bool {
        guard let processed = latestProcessedResult else {
            captureHintText = "暂无可接受处理结果"
            return false
        }
        latestAcceptedProcessedResult = processed
        latestReadyForOutputProcessedResult = nil
        isOutputtingLatestReadyResult = false
        isLatestReadyResultOutputCompleted = false
        latestReadyOutputFailureText = nil
        captureHintText = "已采用白底结果"
        refreshStatusSummary()
        return true
    }

    func markLatestAcceptedResultReadyForOutput() -> Bool {
        guard let accepted = latestAcceptedProcessedResult else {
            captureHintText = "需先接受处理结果"
            return false
        }
        latestReadyForOutputProcessedResult = accepted
        isOutputtingLatestReadyResult = false
        isLatestReadyResultOutputCompleted = false
        latestReadyOutputFailureText = nil
        captureHintText = "已标记为可输出（未导出）"
        refreshStatusSummary()
        return true
    }

    func triggerOutputForLatestReadyResult() -> Bool {
        guard let ready = latestReadyForOutputProcessedResult else {
            captureHintText = "需先进入输出前状态"
            return false
        }
        guard !isOutputtingLatestReadyResult else {
            return false
        }

        isOutputtingLatestReadyResult = true
        isLatestReadyResultOutputCompleted = false
        latestReadyOutputFailureText = nil
        captureHintText = "正在输出当前结果..."
        refreshStatusSummary()

        Task { [weak self] in
            guard let self else { return }
            do {
                try await CapturePhotoLibraryOutputWriter.exportSingleReadyResult(ready)
                await MainActor.run {
                    self.isOutputtingLatestReadyResult = false
                    self.isLatestReadyResultOutputCompleted = true
                    self.latestReadyOutputFailureText = nil
                    self.captureHintText = "输出完成（系统相册）"
                    self.refreshStatusSummary()
                }
            } catch {
                await MainActor.run {
                    self.isOutputtingLatestReadyResult = false
                    self.isLatestReadyResultOutputCompleted = false
                    self.latestReadyOutputFailureText = error.localizedDescription
                    self.captureHintText = "输出失败，可重试或返回拍摄"
                    self.refreshStatusSummary()
                }
            }
        }
        return true
    }

    private func refreshStatusSummary() {
        if isBurstCapturing, let burstProgressText {
            latestCaptureStatusText = burstProgressText
            return
        }
        if let countdownSecondsRemaining {
            latestCaptureStatusText = "倒计时 \(countdownSecondsRemaining)s"
            return
        }
        if isSavingLatestOriginal {
            latestCaptureStatusText = "原图保存中"
            return
        }
        if isSavingLatestProcessed {
            latestCaptureStatusText = "白底保存中"
            return
        }
        if latestOriginalSaveFailureText != nil {
            latestCaptureStatusText = "原图保存失败"
            return
        }
        if latestProcessedSaveFailureText != nil {
            latestCaptureStatusText = "白底保存失败"
            return
        }
        if isLatestOriginalSaveCompleted {
            latestCaptureStatusText = "原图已保存"
            return
        }
        if isLatestProcessedSaveCompleted {
            latestCaptureStatusText = "白底已保存"
            return
        }
        if isOutputtingLatestReadyResult {
            latestCaptureStatusText = "输出中"
            return
        }
        if isLatestReadyResultOutputCompleted {
            latestCaptureStatusText = "已完成输出"
            return
        }
        if latestReadyOutputFailureText != nil {
            latestCaptureStatusText = "输出失败"
            return
        }
        if latestReadyForOutputProcessedResult != nil {
            latestCaptureStatusText = "可输出"
            return
        }
        if latestAcceptedProcessedResult != nil {
            latestCaptureStatusText = "白底已采用"
            return
        }
        if isProcessingLatestResult {
            latestCaptureStatusText = "白底处理中"
            return
        }
        if latestProcessedResult != nil {
            latestCaptureStatusText = "白底已生成"
            return
        }
        if confirmedStillPhotoResult != nil {
            latestCaptureStatusText = "可直用"
            return
        }
        if latestPreservedSourceResult?.id == latestStillPhotoResult?.id {
            latestCaptureStatusText = "素材已保留"
            return
        }
        if latestStillPhotoResult != nil {
            latestCaptureStatusText = "已拍摄"
            return
        }
        latestCaptureStatusText = "未拍摄"
    }

    private func startCountdown(seconds: Int) {
        countdownTask?.cancel()
        countdownSecondsRemaining = seconds
        refreshStatusSummary()
        captureHintText = "定时拍摄中"

        countdownTask = Task { [weak self] in
            guard let self else { return }
            var remaining = seconds
            while remaining > 0 {
                await MainActor.run {
                    self.countdownSecondsRemaining = remaining
                    self.refreshStatusSummary()
                }
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled {
                    return
                }
                remaining -= 1
            }

            await MainActor.run {
                self.countdownSecondsRemaining = nil
                self.refreshStatusSummary()
            }
            self.startBurstSequence()
        }
    }

    private func startBurstSequence() {
        burstTask?.cancel()
        let captureCount = selectedBurstOption.rawValue
        let shotCount = max(1, captureCount)

        burstTask = Task { [weak self] in
            guard let self else { return }
            await MainActor.run {
                self.isBurstCapturing = shotCount > 1
                self.burstProgressText = shotCount > 1 ? "连拍 0/\(shotCount)" : nil
                self.refreshStatusSummary()
            }

            for shot in 1...shotCount {
                if Task.isCancelled {
                    break
                }
                do {
                    let stillPhoto = try await self.captureSinglePhoto()
                    await MainActor.run {
                        self.handleCaptureSuccess(stillPhoto, shotIndex: shot, totalCount: shotCount)
                    }
                } catch {
                    await MainActor.run {
                        self.captureHintText = "拍照失败：\(error.localizedDescription)"
                    }
                }
                if shot < shotCount {
                    try? await Task.sleep(for: .milliseconds(180))
                }
            }

            await MainActor.run {
                self.isBurstCapturing = false
                self.burstProgressText = nil
                self.captureHintText = "连拍完成，可继续拍摄"
                self.refreshStatusSummary()
            }
        }
    }

    private func handleCaptureSuccess(_ result: CaptureStillPhotoResult, shotIndex: Int, totalCount: Int) {
        let outputAdjustedResult = applySelectedOutputPresetsIfNeeded(to: result)
        latestStillPhotoResult = outputAdjustedResult
        latestPreservedSourceResult = nil
        resetLatestOriginalSaveState()
        resetLatestProcessedSaveState()
        if totalCount > 1 {
            burstProgressText = "连拍 \(shotIndex)/\(totalCount)"
            captureHintText = "连拍进行中 \(shotIndex)/\(totalCount)"
        } else {
            captureHintText = "拍摄成功，可继续拍摄"
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        quickPreviewHideTask?.cancel()
        quickPreviewHideTask = nil
        quickPreviewImage = nil
        refreshStatusSummary()
    }

    private func applySelectedOutputPresetsIfNeeded(
        to result: CaptureStillPhotoResult
    ) -> CaptureStillPhotoResult {
        let targetRatio = selectedAspectRatioPreset.ratioValue
        guard targetRatio > 0 else {
            return result
        }
        guard let sourceImage = UIImage(data: result.imageData)?.normalizedForCapturePipeline(),
              let sourceCGImage = sourceImage.cgImage else {
            return result
        }

        let sourceWidth = CGFloat(sourceCGImage.width)
        let sourceHeight = CGFloat(sourceCGImage.height)
        guard sourceWidth > 1, sourceHeight > 1 else {
            return result
        }

        var workingCGImage = sourceCGImage
        var didMutateImage = false

        let sourceRatio = sourceWidth / sourceHeight
        if abs(sourceRatio - targetRatio) >= 0.002 {
            var cropRect = CGRect(origin: .zero, size: CGSize(width: sourceWidth, height: sourceHeight))
            if sourceRatio > targetRatio {
                let targetWidth = sourceHeight * targetRatio
                cropRect.origin.x = (sourceWidth - targetWidth) / 2.0
                cropRect.size.width = targetWidth
            } else {
                let targetHeight = sourceWidth / targetRatio
                cropRect.origin.y = (sourceHeight - targetHeight) / 2.0
                cropRect.size.height = targetHeight
            }
            cropRect = cropRect.integral
            if cropRect.width > 0, cropRect.height > 0,
               let croppedCGImage = sourceCGImage.cropping(to: cropRect) {
                workingCGImage = croppedCGImage
                didMutateImage = true
            }
        }

        if let targetPixelSize = selectedPixelPreset.fixedOutputPixelSize(for: targetRatio) {
            let targetWidth = Int(targetPixelSize.width)
            let targetHeight = Int(targetPixelSize.height)
            if targetWidth > 1, targetHeight > 1,
               (workingCGImage.width != targetWidth || workingCGImage.height != targetHeight),
               let resizedCGImage = resizedCGImage(from: workingCGImage, to: targetPixelSize) {
                workingCGImage = resizedCGImage
                didMutateImage = true
            }
        }

        var mergedMetadata = result.metadata
        mergedMetadata["capture_aspect_ratio"] = selectedAspectRatioPreset.displayText
        mergedMetadata["capture_aspect_ratio_value"] = String(format: "%.4f", selectedAspectRatioPreset.ratioValue)
        mergedMetadata["capture_pixel_preset"] = selectedPixelPreset.shortLabel
        mergedMetadata["capture_pixel_strategy"] = selectedPixelPreset.usesFixedOutputSize ? "fixed_long_edge" : "best_available"
        if selectedPixelPreset == .raw {
            mergedMetadata["capture_raw_requested"] = "true"
            mergedMetadata["capture_raw_file_saved"] = "false"
        }
        mergedMetadata["capture_output_size"] = "\(workingCGImage.width)x\(workingCGImage.height)"

        guard didMutateImage else {
            return CaptureStillPhotoResult(
                id: result.id,
                source: result.source,
                capturedAt: result.capturedAt,
                imageData: result.imageData,
                pixelSize: result.pixelSize,
                metadata: mergedMetadata
            )
        }

        let outputImage = UIImage(cgImage: workingCGImage, scale: sourceImage.scale, orientation: .up)
        guard let outputData = outputImage.jpegData(compressionQuality: 0.98) else {
            return CaptureStillPhotoResult(
                id: result.id,
                source: result.source,
                capturedAt: result.capturedAt,
                imageData: result.imageData,
                pixelSize: result.pixelSize,
                metadata: mergedMetadata
            )
        }

        return CaptureStillPhotoResult(
            id: result.id,
            source: result.source,
            capturedAt: result.capturedAt,
            imageData: outputData,
            pixelSize: CGSize(width: workingCGImage.width, height: workingCGImage.height),
            metadata: mergedMetadata
        )
    }

    private func resizedCGImage(from source: CGImage, to targetSize: CGSize) -> CGImage? {
        guard targetSize.width > 1, targetSize.height > 1 else { return nil }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let renderedImage = renderer.image { _ in
            UIImage(cgImage: source, scale: 1, orientation: .up).draw(
                in: CGRect(origin: .zero, size: targetSize)
            )
        }
        return renderedImage.cgImage
    }

    private func showQuickPreview(for result: CaptureStillPhotoResult) {
        quickPreviewHideTask?.cancel()
        let currentID = result.id

        Task(priority: .userInitiated) { [weak self] in
            let decoded = UIImage(data: result.imageData)
            await MainActor.run {
                guard let self else { return }
                guard self.latestStillPhotoResult?.id == currentID else { return }
                self.quickPreviewImage = decoded
            }
        }

        quickPreviewHideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.4))
            await MainActor.run {
                guard let self else { return }
                if self.latestStillPhotoResult?.id == currentID {
                    self.quickPreviewImage = nil
                }
            }
        }
    }

    private func resetLatestOriginalSaveState() {
        isSavingLatestOriginal = false
        isLatestOriginalSaveCompleted = false
        latestOriginalSaveFailureText = nil
    }

    private func resetLatestProcessedSaveState() {
        isSavingLatestProcessed = false
        isLatestProcessedSaveCompleted = false
        latestProcessedSaveFailureText = nil
    }

    private func resetLatestProcessedPipelineState() {
        isProcessingLatestResult = false
        latestProcessingErrorText = nil
        latestProcessedResult = nil
        latestAcceptedProcessedResult = nil
        latestReadyForOutputProcessedResult = nil
        isOutputtingLatestReadyResult = false
        isLatestReadyResultOutputCompleted = false
        latestReadyOutputFailureText = nil
    }

    private func resetLatestResultWorkflowState() {
        resetLatestOriginalSaveState()
        resetLatestProcessedSaveState()
        resetLatestProcessedPipelineState()
    }

    func prepareForReviewPresentation() {
        clearTransientCaptureStates(clearCountdown: true)
        if isFocusExposureLocked {
            captureHintText = "AE/AF 已锁定，返回后可继续拍摄"
        } else if isExposureLocked {
            captureHintText = "AE 已锁定，返回后可继续拍摄"
        } else {
            captureHintText = "进入结果复核"
        }
        refreshStatusSummary()
    }

    func restoreAfterReviewDismissed() {
        clearTransientCaptureStates(clearCountdown: true)
        if isFocusExposureLocked {
            captureHintText = "AE/AF 已锁定，长按可解锁并重设"
        } else if isExposureLocked {
            captureHintText = "AE 已锁定，轻触可重新对焦"
        } else {
            captureHintText = "轻触画面可对焦与测光"
        }
        refreshStatusSummary()
    }

    private func captureSinglePhoto() async throws -> CaptureStillPhotoResult {
        await waitForCaptureStabilizationIfNeeded()
#if DEBUG
        await logCurrentLensCaptureState(reason: "beforePhotoCapture")
#endif
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CaptureStillPhotoResult, Error>) in
            guard self.isSessionConfigured else {
                continuation.resume(throwing: NSError(domain: "CaptureCameraRuntime", code: -2))
                return
            }

            let captureID = UUID()
            let settings = AVCapturePhotoSettings()
            settings.photoQualityPrioritization = self.preferredPhotoQualityPrioritization()

            if self.isFlashModeSupported {
                settings.flashMode = self.selectedFlashMode.avFlashMode
            } else {
                settings.flashMode = .off
            }

            let proxy = CapturePhotoDelegateProxy(
                captureID: captureID,
                completion: { [weak self] captureID, result in
                    guard let self else { return }
                    self.pendingCaptureDelegates.removeValue(forKey: captureID)
                    continuation.resume(with: result)
                }
            )

            self.pendingCaptureDelegates[captureID] = proxy
            self.photoOutput.capturePhoto(with: settings, delegate: proxy)
        }
    }

    private func waitForCaptureStabilizationIfNeeded() async {
        let maxWaitNanoseconds = selectedStabilizerMode.captureSettleWaitNanoseconds
        guard maxWaitNanoseconds > 0 else { return }

        isCaptureStabilizerSettling = true
        defer { isCaptureStabilizerSettling = false }

        let maxWaitSeconds = Double(maxWaitNanoseconds) / 1_000_000_000.0
        let startedAt = Date()
        var didWait = false

        while Date().timeIntervalSince(startedAt) < maxWaitSeconds {
            let recentZoomWrite = Date().timeIntervalSince(lastLensRulerInteractionAt) < 0.18
            let zoomRamping = await isCurrentDeviceRampingZoom()
            let focusAdjusting = await isCurrentDeviceAdjustingFocus()
            guard recentZoomWrite || zoomRamping || focusAdjusting || isSwitchingCamera else {
                break
            }
            didWait = true
            try? await Task.sleep(for: .milliseconds(45))
        }

#if DEBUG
        if didWait {
            print(
                "[CaptureStabilizer] captureSettleWait " +
                "mode=\(selectedStabilizerMode.rawValue) " +
                "elapsed=\(String(format: "%.3f", Date().timeIntervalSince(startedAt))) " +
                "max=\(String(format: "%.3f", maxWaitSeconds))"
            )
        }
#endif
    }

#if DEBUG
    private func logCurrentLensCaptureState(reason: String) async {
        let selectedLens = selectedLensProfile?.displayText ?? "nil"
        let selectedLensID = selectedLensProfileID
        let runtimeZoom = currentZoomFactor
        await withCheckedContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self, let device = self.currentVideoInput?.device else {
                    continuation.resume()
                    return
                }
                let activePrimary: String
                if let active = device.activePrimaryConstituent {
                    activePrimary = self.formattedLensDeviceCapability(active)
                } else {
                    activePrimary = "nil"
                }
                print(
                    "[CaptureLensCaptureState] " +
                    "reason=\(reason) " +
                    "selectedLens=\(selectedLens) " +
                    "selectedLensID=\(selectedLensID) " +
                    "runtimeZoom=\(String(format: "%.3f", runtimeZoom)) " +
                    "device=\(device.localizedName) " +
                    "type=\(device.deviceType.rawValue) " +
                    "videoZoom=\(String(format: "%.3f", device.videoZoomFactor)) " +
                    "isRamping=\(device.isRampingVideoZoom) " +
                    "activePrimary=\(activePrimary)"
                )
                continuation.resume()
            }
        }
    }
#endif

    private func preferredPhotoQualityPrioritization() -> AVCapturePhotoOutput.QualityPrioritization {
        switch photoOutput.maxPhotoQualityPrioritization {
        case .quality:
            return .quality
        case .balanced:
            return .balanced
        case .speed:
            return .speed
        @unknown default:
            return photoOutput.maxPhotoQualityPrioritization
        }
    }

    private func ensureVideoPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    private func configureSessionIfNeeded() async {
        guard !isSessionConfigured else { return }

        await withCheckedContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self else {
                    continuation.resume()
                    return
                }

                self.session.beginConfiguration()
                self.session.sessionPreset = .photo
                defer { self.session.commitConfiguration() }

                guard let backCamera = self.resolveCamera(
                    position: .back
                ),
                      let input = try? AVCaptureDeviceInput(device: backCamera),
                      self.session.canAddInput(input),
                      self.session.canAddOutput(self.photoOutput) else {
                    continuation.resume()
                    return
                }

                self.session.addInput(input)
                self.session.addOutput(self.photoOutput)
                self.photoOutput.maxPhotoQualityPrioritization = .quality
                self.configureProductAutoExposureVideoOutputIfPossible()
                self.applyStabilizerModeToConnections(reason: "configureSession")
                self.currentVideoInput = input
                self.isSessionConfigured = true

                let frontAvailable = self.resolveCamera(position: .front) != nil
                let maxZoom = self.normalizedDeviceMaxZoom(for: backCamera)
                let rawSupported = !self.photoOutput.availableRawPhotoPixelFormatTypes.isEmpty
                self.logLensDeviceState(backCamera, uiFocalLabel: nil, reason: "configureSession")

                DispatchQueue.main.async {
                    self.activeCameraPosition = .back
                    self.activeCameraDeviceType = backCamera.deviceType
                    self.canSwitchCamera = frontAvailable
                    self.isFlashModeSupported = backCamera.hasFlash
                    self.minimumZoomFactor = 1.0
                    self.activeDeviceMaximumZoomFactor = maxZoom
                    self.maximumZoomFactor = maxZoom
                    self.currentZoomFactor = 1.0
                    self.isRAWCaptureSupported = rawSupported
                    self.refreshLensProfiles(
                        position: .back,
                        activeDevice: backCamera,
                        preferredLensID: nil
                    )
                    self.updateExposureCapabilityState(with: backCamera)
                    self.updateISOCapabilityState(with: backCamera)
                    self.updateShutterCapabilityState(with: backCamera)
                    self.updateWhiteBalanceCapabilityState(with: backCamera)
                    self.updateFocusCapabilityState(with: backCamera)
                    self.logManualParameterCompatibility(device: backCamera, reason: "configureSessionCapability", lockProbe: nil)
                    self.productAutoWhiteBalanceOptimizer.reset()
                    self.productAutoWhiteBalanceAppliedTemperature = nil
                    self.productAutoWhiteBalanceStatusText = self.isWhiteBalanceAutoSupported && self.isWhiteBalancePresetSupported
                        ? "商品 WB 待机"
                        : "商品 WB 不可用"
                    self.applyISOPreset(self.selectedISOPreset, shouldShowHint: false)
                    self.applyShutterPreset(self.selectedShutterPreset, shouldShowHint: false)
                    self.applyWhiteBalancePreset(self.selectedWhiteBalancePreset, shouldShowHint: false)
                    self.refreshStatusSummary()
                }

                continuation.resume()
            }
        }
    }

    private func startSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.isSessionConfigured else { return }
            if !self.session.isRunning {
                self.session.startRunning()
                DispatchQueue.main.async {
                    self.lastSessionStartAt = Date()
                }
            }
        }
    }

    private func configureProductAutoExposureVideoOutputIfPossible() {
        guard !session.outputs.contains(where: { $0 === videoOutput }), session.canAddOutput(videoOutput) else { return }
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.setSampleBufferDelegate(self, queue: videoAnalysisQueue)
        session.addOutput(videoOutput)
    }

    private func switchToCamera(
        position: AVCaptureDevice.Position,
        preferredDeviceType: AVCaptureDevice.DeviceType? = nil,
        preferredLensID: String? = nil,
        reason: String = "user",
        completion: (() -> Void)? = nil
    ) {
        isSwitchingCamera = true
        isoManualAvailability = .temporarilyUnavailable(reason: "ISO: deviceSwitching")
        shutterManualAvailability = .temporarilyUnavailable(reason: "Shutter: deviceSwitching")
        whiteBalanceManualAvailability = .temporarilyUnavailable(reason: "WB: deviceSwitching")
        let sourceIdentity = currentVideoInput.map { CaptureDeviceIdentity(device: $0.device) }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let currentDeviceType = self.currentVideoInput?.device.deviceType
            let requiresDeviceTypeSwitch = self.activeCameraPosition == position
                && preferredDeviceType != nil
                && currentDeviceType != preferredDeviceType
            let requiresAutomaticVirtualSwitch = self.activeCameraPosition == position
                && position == .back
                && preferredDeviceType == nil
                && !self.isManualParameterModeRequested
                && !Self.isVirtualBackCameraDeviceType(currentDeviceType)

            guard self.activeCameraPosition != position || requiresDeviceTypeSwitch || requiresAutomaticVirtualSwitch else {
                DispatchQueue.main.async {
                    if let preferredLensID {
                        self.selectLensProfile(preferredLensID)
                    }
                    self.isSwitchingCamera = false
                    completion?()
                }
                return
            }
            guard let camera = self.resolveCamera(position: position, preferredDeviceType: preferredDeviceType),
                  let newInput = try? AVCaptureDeviceInput(device: camera) else {
                DispatchQueue.main.async {
                    self.isSwitchingCamera = false
                    self.captureDeviceOperatingMode = .unavailable(reason: "switchTargetUnavailable:\(reason)")
                    self.captureHintText = "摄像头切换失败"
                }
                return
            }
            let targetIdentity = CaptureDeviceIdentity(device: camera)
            let switchGeneration = self.deviceSwitchGeneration + 1
            self.deviceSwitchGeneration = switchGeneration
            DispatchQueue.main.async {
                self.captureDeviceOperatingMode = .switching(
                    from: sourceIdentity,
                    to: targetIdentity,
                    reason: reason
                )
            }

            self.session.beginConfiguration()
            if let currentInput = self.currentVideoInput {
                self.session.removeInput(currentInput)
            }
            if self.session.canAddInput(newInput) {
                self.session.addInput(newInput)
                self.currentVideoInput = newInput
            } else if let currentInput = self.currentVideoInput, self.session.canAddInput(currentInput) {
                self.session.addInput(currentInput)
                self.session.commitConfiguration()
                DispatchQueue.main.async {
                    self.isSwitchingCamera = false
                    self.captureDeviceOperatingMode = .unavailable(reason: "switchAddRejected:\(reason)")
                    self.captureHintText = "当前无法切换摄像头"
                }
                return
            }
            self.session.commitConfiguration()

            let maxZoom = self.normalizedDeviceMaxZoom(for: camera)
            let rawSupported = !self.photoOutput.availableRawPhotoPixelFormatTypes.isEmpty
            self.logLensDeviceState(camera, uiFocalLabel: preferredLensID, reason: "switchCamera")
            do {
                try camera.lockForConfiguration()
                camera.videoZoomFactor = max(1.0, camera.minAvailableVideoZoomFactor)
                camera.unlockForConfiguration()
            } catch {
                // Keep minimum stable zoom.
            }

            DispatchQueue.main.async {
                guard self.deviceSwitchGeneration == switchGeneration else {
                    print("[CaptureDeviceMode] stale switch ignored generation=\(switchGeneration) reason=\(reason)")
                    return
                }
                self.isSwitchingCamera = false
                self.activeCameraPosition = position
                self.activeCameraDeviceType = camera.deviceType
                if position == .back, Self.isVirtualBackCameraDeviceType(camera.deviceType), !self.isManualParameterModeRequested {
                    self.captureDeviceOperatingMode = .automaticVirtual
                } else if position == .back {
                    self.captureDeviceOperatingMode = .manualPhysical(profile: self.physicalProfile(for: self.selectedSemanticFocal))
                } else {
                    self.captureDeviceOperatingMode = .unavailable(reason: "frontCamera")
                }
                self.minimumZoomFactor = 1.0
                self.activeDeviceMaximumZoomFactor = maxZoom
                self.maximumZoomFactor = maxZoom
                self.currentZoomFactor = 1.0
                self.isRAWCaptureSupported = rawSupported
                if !rawSupported, self.selectedPixelPreset == .raw {
                    self.selectedPixelPreset = .best
                }
                self.isFlashModeSupported = camera.hasFlash
                self.refreshLensProfiles(
                    position: position,
                    activeDevice: camera,
                    preferredLensID: preferredLensID
                )
                self.updateExposureCapabilityState(with: camera)
                self.updateISOCapabilityState(with: camera)
                self.updateShutterCapabilityState(with: camera)
                self.updateWhiteBalanceCapabilityState(with: camera)
                self.updateFocusCapabilityState(with: camera)
                self.logManualParameterCompatibility(device: camera, reason: "switchCameraCapability", lockProbe: nil)
                self.applyStabilizerModeToConnections(reason: "switchCamera")
                self.productAutoWhiteBalanceOptimizer.reset()
                self.productAutoWhiteBalanceAppliedTemperature = nil
                self.productAutoWhiteBalanceStatusText = self.isWhiteBalanceAutoSupported && self.isWhiteBalancePresetSupported
                    ? "商品 WB 待机"
                    : "商品 WB 不可用"
                if !camera.hasFlash {
                    self.selectedFlashMode = .off
                }
                let isPreparingManualPhysicalMode = reason.hasPrefix("manual")
                if !isPreparingManualPhysicalMode {
                    self.applyISOPreset(self.selectedISOPreset, shouldShowHint: false)
                    self.applyShutterPreset(self.selectedShutterPreset, shouldShowHint: false)
                    self.applyWhiteBalancePreset(self.selectedWhiteBalancePreset, shouldShowHint: false)
                }
                if let selectedProfile = self.selectedLensProfile {
                    self.captureHintText = "已切换\(selectedProfile.displayText)"
                } else {
                    self.captureHintText = position == .back ? "已切换后摄" : "已切换前摄"
                }
                print(
                    "[CaptureDeviceMode] switch committed " +
                    "generation=\(switchGeneration) " +
                    "reason=\(reason) " +
                    "from=\(sourceIdentity?.localizedName ?? "nil") " +
                    "to=\(targetIdentity.localizedName) " +
                    "mode=\(self.captureDeviceOperatingMode)"
                )
                completion?()
            }
        }
    }

    private func updateExposureCapabilityState(with device: AVCaptureDevice) {
        minimumExposureBias = device.minExposureTargetBias
        maximumExposureBias = device.maxExposureTargetBias
        currentExposureBias = device.exposureTargetBias
        isExposureBiasAutoMode = true
        isExposureBiasSupported = minimumExposureBias < maximumExposureBias
        isExposureLockSupported = device.isExposureModeSupported(.locked)
        isExposureLocked = false
        productAutoExposureOptimizer.reset()
        productAutoExposureAppliedBias = nil
        productAutoExposureStatusText = isExposureBiasSupported ? "商品 Auto 待机" : "商品 Auto 不可用"
    }

    private func updateISOCapabilityState(with device: AVCaptureDevice) {
        isISOAutoSupported = device.isExposureModeSupported(.continuousAutoExposure)
        isoManualAvailability = manualExposureAvailability(for: device, parameter: "ISO")
        isISOPresetSupported = isoManualAvailability.isWritable
        let exposureDevice = manualExposureControlDevice(for: device)
        let minISO = exposureDevice.activeFormat.minISO
        let maxISO = exposureDevice.activeFormat.maxISO
        if maxISO > minISO {
            minimumISOValue = minISO
            maximumISOValue = maxISO
        } else {
            minimumISOValue = minISO
            maximumISOValue = max(minISO + 1, minISO)
        }

        let currentISO = clampedISOValue(exposureDevice.iso, device: exposureDevice)
        currentISOValue = currentISO
        currentManualISOValue = currentISO

        if !isISOPresetSupported {
            selectedISOPreset = .auto
            return
        }
        if !isISOAutoSupported, selectedISOPreset == .auto {
            selectedISOPreset = .custom
        }

        if let legacyNormalizedPosition = selectedISOPreset.normalizedPosition {
            currentManualISOValue = isoValue(
                forNormalized: Double(legacyNormalizedPosition),
                minISO: minimumISOValue,
                maxISO: maximumISOValue
            )
            selectedISOPreset = .custom
        }
    }

    private func updateShutterCapabilityState(with device: AVCaptureDevice) {
        isShutterAutoSupported = device.isExposureModeSupported(.continuousAutoExposure)
        shutterManualAvailability = manualExposureAvailability(for: device, parameter: "Shutter")
        isShutterPresetSupported = shutterManualAvailability.isWritable
        let exposureDevice = manualExposureControlDevice(for: device)
        let minSeconds = CMTimeGetSeconds(exposureDevice.activeFormat.minExposureDuration)
        let maxSeconds = CMTimeGetSeconds(exposureDevice.activeFormat.maxExposureDuration)
        if minSeconds.isFinite, maxSeconds.isFinite, minSeconds > 0, maxSeconds > 0 {
            minimumShutterDurationSeconds = min(minSeconds, maxSeconds)
            maximumShutterDurationSeconds = max(minSeconds, maxSeconds)
        } else {
            minimumShutterDurationSeconds = 1.0 / 1000.0
            maximumShutterDurationSeconds = 1.0 / 30.0
        }

        let seconds = CMTimeGetSeconds(exposureDevice.exposureDuration)
        let currentSeconds: Double
        if seconds.isFinite, seconds > 0 {
            currentSeconds = max(minimumShutterDurationSeconds, min(maximumShutterDurationSeconds, seconds))
        } else {
            currentSeconds = minimumShutterDurationSeconds
        }
        currentShutterDurationSeconds = currentSeconds
        currentManualShutterDurationSeconds = currentSeconds

        if !isShutterPresetSupported {
            selectedShutterPreset = .auto
            return
        }
        if !isShutterAutoSupported, selectedShutterPreset == .auto {
            selectedShutterPreset = .custom
        }

        if selectedShutterPreset.durationSeconds != nil {
            let legacyDuration = clampedShutterDuration(for: selectedShutterPreset, device: exposureDevice)
            let legacySeconds = CMTimeGetSeconds(legacyDuration)
            if legacySeconds.isFinite, legacySeconds > 0 {
                currentManualShutterDurationSeconds = legacySeconds
            }
            selectedShutterPreset = .custom
        }
    }

    private func updateWhiteBalanceCapabilityState(with device: AVCaptureDevice) {
        isWhiteBalanceAutoSupported = device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance)
        whiteBalanceManualAvailability = manualWhiteBalanceAvailability(for: device)
        isWhiteBalancePresetSupported = whiteBalanceManualAvailability.isWritable
        let whiteBalanceDevice = manualWhiteBalanceControlDevice(for: device)
        let tempTint = whiteBalanceDevice.temperatureAndTintValues(for: whiteBalanceDevice.deviceWhiteBalanceGains)
        currentWhiteBalanceTemperature = clampedWhiteBalanceTemperature(tempTint.temperature)
        currentWhiteBalanceTint = clampedWhiteBalanceTint(tempTint.tint)

        if !isWhiteBalancePresetSupported {
            selectedWhiteBalancePreset = .auto
            return
        }
        if !isWhiteBalanceAutoSupported, selectedWhiteBalancePreset == .auto {
            selectedWhiteBalancePreset = .neutral
            currentWhiteBalanceTemperature = clampedWhiteBalanceTemperature(CaptureWhiteBalancePreset.neutral.temperature)
            currentWhiteBalanceTint = 0
        } else if selectedWhiteBalancePreset != .auto && selectedWhiteBalancePreset != .custom {
            currentWhiteBalanceTemperature = clampedWhiteBalanceTemperature(selectedWhiteBalancePreset.temperature)
            currentWhiteBalanceTint = 0
        } else if selectedWhiteBalancePreset == .auto {
            currentWhiteBalanceTint = 0
        }
    }

    private func manualExposureAvailability(
        for device: AVCaptureDevice,
        parameter: String
    ) -> ManualParameterAvailability {
        let exposureDevice = manualExposureControlDevice(for: device)
        guard exposureDevice.isConnected else {
            return .temporarilyUnavailable(reason: "\(parameter): deviceDisconnected")
        }
        if device.isVirtualDevice, exposureDevice === device, !device.constituentDevices.isEmpty {
            return .temporarilyUnavailable(reason: "\(parameter): activeConstituentPending")
        }
        guard exposureDevice.isExposureModeSupported(.custom) else {
            return .unsupported(reason: "\(parameter): customExposureUnsupported")
        }
        let minISO = exposureDevice.activeFormat.minISO
        let maxISO = exposureDevice.activeFormat.maxISO
        guard minISO.isFinite, maxISO.isFinite, minISO > 0, maxISO > minISO else {
            return .unsupported(reason: "\(parameter): invalidISORange \(minISO)-\(maxISO)")
        }
        let minDuration = exposureDevice.activeFormat.minExposureDuration
        let maxDuration = exposureDevice.activeFormat.maxExposureDuration
        guard isValidExposureDuration(minDuration),
              isValidExposureDuration(maxDuration),
              CMTimeCompare(maxDuration, minDuration) > 0 else {
            return .unsupported(reason: "\(parameter): invalidDurationRange")
        }
        if isSwitchingCamera || device.isRampingVideoZoom || exposureDevice.isRampingVideoZoom {
            return .temporarilyUnavailable(reason: "\(parameter): lensSwitching")
        }
        return .available
    }

    private func manualExposureControlDevice(for device: AVCaptureDevice) -> AVCaptureDevice {
        if device.isExposureModeSupported(.custom) {
            return device
        }
        if let activeConstituent = device.activePrimaryConstituent,
           activeConstituent.isExposureModeSupported(.custom) {
            return activeConstituent
        }
        return device
    }

    private func manualWhiteBalanceAvailability(for device: AVCaptureDevice) -> ManualParameterAvailability {
        let whiteBalanceDevice = manualWhiteBalanceControlDevice(for: device)
        guard whiteBalanceDevice.isConnected else {
            return .temporarilyUnavailable(reason: "WB: deviceDisconnected")
        }
        if device.isVirtualDevice, whiteBalanceDevice === device, !device.constituentDevices.isEmpty {
            return .temporarilyUnavailable(reason: "WB: activeConstituentPending")
        }
        guard whiteBalanceDevice.isWhiteBalanceModeSupported(.locked) else {
            return .unsupported(reason: "WB: lockedModeUnsupported")
        }
        guard whiteBalanceDevice.isLockingWhiteBalanceWithCustomDeviceGainsSupported else {
            return .unsupported(reason: "WB: customGainsUnsupported")
        }
        return isSwitchingCamera ? .temporarilyUnavailable(reason: "WB: lensSwitching") : .available
    }

    private func manualWhiteBalanceControlDevice(for device: AVCaptureDevice) -> AVCaptureDevice {
        if device.isWhiteBalanceModeSupported(.locked),
           device.isLockingWhiteBalanceWithCustomDeviceGainsSupported {
            return device
        }
        if let activeConstituent = device.activePrimaryConstituent,
           activeConstituent.isWhiteBalanceModeSupported(.locked),
           activeConstituent.isLockingWhiteBalanceWithCustomDeviceGainsSupported {
            return activeConstituent
        }
        return device
    }

    @discardableResult
    private func updateFocusCapabilityState(
        with device: AVCaptureDevice,
        reason: String = "capabilityUpdate",
        resetsFocusMode: Bool = true
    ) -> ManualFocusCapability {
        updateFocusCapabilityState(with: Optional(device), reason: reason, resetsFocusMode: resetsFocusMode)
    }

    @discardableResult
    private func updateFocusCapabilityState(
        with device: AVCaptureDevice?,
        reason: String,
        resetsFocusMode: Bool
    ) -> ManualFocusCapability {
        let capability = manualFocusCapability(for: device)
        isManualFocusEntrySupported = capability.canEnterManualFocusMode
        isManualFocusSupported = capability.isFull
        if let device {
            let quantized = quantizedManualFocusPosition(device.lensPosition)
            currentManualFocusPosition = quantized
            if resetsFocusMode || focusControlMode != .manual {
                lastAppliedManualFocusPosition = quantized
            }
        }
        if resetsFocusMode {
            focusControlMode = .auto
        }
        logManualFocusSupport(device: device, capability: capability, reason: reason)
        return capability
    }

    private func manualFocusCapability(for device: AVCaptureDevice?) -> ManualFocusCapability {
        guard let device else {
            return .unsupported(reason: "noActiveSessionDevice")
        }
        guard device.isFocusModeSupported(.locked) else {
            return .unsupported(reason: "lockedFocusUnsupported")
        }
        guard device.isLockingFocusWithCustomLensPositionSupported else {
            return .lockCurrentOnly(reason: "customLensPositionUnsupported")
        }
        return .full
    }

    private func normalizedWhiteBalanceGains(
        _ gains: AVCaptureDevice.WhiteBalanceGains,
        for device: AVCaptureDevice
    ) -> AVCaptureDevice.WhiteBalanceGains {
        AVCaptureDevice.WhiteBalanceGains(
            redGain: max(1.0, min(device.maxWhiteBalanceGain, gains.redGain)),
            greenGain: max(1.0, min(device.maxWhiteBalanceGain, gains.greenGain)),
            blueGain: max(1.0, min(device.maxWhiteBalanceGain, gains.blueGain))
        )
    }

    private func targetISOValue(for preset: CaptureISOPreset, device: AVCaptureDevice) -> Float {
        guard let position = preset.normalizedPosition else { return device.iso }
        let minISO = device.activeFormat.minISO
        let maxISO = device.activeFormat.maxISO
        guard maxISO > minISO else { return minISO }
        let minLog = log2(Double(minISO))
        let maxLog = log2(Double(maxISO))
        let targetLog = minLog + ((maxLog - minLog) * Double(position))
        let targetISO = Float(pow(2.0, targetLog))
        return max(minISO, min(maxISO, targetISO))
    }

    private func isoValue(
        forNormalized normalized: Double,
        minISO: Float,
        maxISO: Float
    ) -> Float {
        guard maxISO > minISO else { return minISO }
        let clampedNormalized = max(0.0, min(1.0, normalized))
        let minLog = log2(Double(minISO))
        let maxLog = log2(Double(maxISO))
        let targetLog = minLog + ((maxLog - minLog) * clampedNormalized)
        let targetISO = Float(pow(2.0, targetLog))
        return max(minISO, min(maxISO, targetISO))
    }

    private func normalizedISOValue(
        _ value: Float,
        minISO: Float,
        maxISO: Float
    ) -> Double {
        guard maxISO > minISO else { return 0 }
        let clampedValue = max(minISO, min(maxISO, value))
        let minLog = log2(Double(minISO))
        let maxLog = log2(Double(maxISO))
        let valueLog = log2(Double(clampedValue))
        let denominator = maxLog - minLog
        guard denominator > .ulpOfOne else { return 0 }
        return max(0.0, min(1.0, (valueLog - minLog) / denominator))
    }

    private func clampedISOValue(_ requestedISO: Float, device: AVCaptureDevice) -> Float {
        let minISO = device.activeFormat.minISO
        let maxISO = device.activeFormat.maxISO
        guard maxISO > minISO else { return minISO }
        return max(minISO, min(maxISO, requestedISO))
    }

    private struct SanitizedCustomExposureWrite {
        let duration: CMTime
        let iso: Float
    }

    private func sanitizedCustomExposureWrite(
        rawDuration: CMTime,
        rawISO: Float,
        device: AVCaptureDevice,
        context: String
    ) -> SanitizedCustomExposureWrite? {
        let minISO = device.activeFormat.minISO
        let maxISO = device.activeFormat.maxISO
        guard minISO.isFinite, maxISO.isFinite, minISO > 0, maxISO >= minISO else {
            logCustomExposureWrite(
                context: context,
                rawISO: rawISO,
                safeISO: nil,
                minISO: minISO,
                maxISO: maxISO,
                rawDuration: rawDuration,
                safeDuration: nil,
                reason: "skippedInvalidISORange"
            )
            return nil
        }

        var reasons: [String] = []
        let fallbackISO = device.iso.isFinite && device.iso > 0 ? device.iso : minISO
        let finiteISO: Float
        if rawISO.isFinite, rawISO > 0 {
            finiteISO = rawISO
        } else {
            finiteISO = fallbackISO
            reasons.append("invalidISO")
        }
        let safeISO = max(minISO, min(maxISO, finiteISO))
        if safeISO != rawISO {
            reasons.append("clampedISO")
        }

        let minDuration = device.activeFormat.minExposureDuration
        let maxDuration = device.activeFormat.maxExposureDuration
        guard isValidExposureDuration(minDuration),
              isValidExposureDuration(maxDuration),
              CMTimeCompare(maxDuration, minDuration) >= 0 else {
            logCustomExposureWrite(
                context: context,
                rawISO: rawISO,
                safeISO: safeISO,
                minISO: minISO,
                maxISO: maxISO,
                rawDuration: rawDuration,
                safeDuration: nil,
                reason: "skippedInvalidDurationRange"
            )
            return nil
        }

        let fallbackDuration = isValidExposureDuration(device.exposureDuration)
            ? device.exposureDuration
            : minDuration
        var safeDuration: CMTime
        if isValidExposureDuration(rawDuration) {
            safeDuration = rawDuration
        } else {
            safeDuration = fallbackDuration
            reasons.append("invalidDuration")
        }
        if CMTimeCompare(safeDuration, minDuration) < 0 {
            safeDuration = minDuration
            reasons.append("clampedDuration")
        } else if CMTimeCompare(safeDuration, maxDuration) > 0 {
            safeDuration = maxDuration
            reasons.append("clampedDuration")
        }

        logCustomExposureWrite(
            context: context,
            rawISO: rawISO,
            safeISO: safeISO,
            minISO: minISO,
            maxISO: maxISO,
            rawDuration: rawDuration,
            safeDuration: safeDuration,
            reason: reasons.isEmpty ? "normal" : reasons.joined(separator: "+")
        )

        return SanitizedCustomExposureWrite(duration: safeDuration, iso: safeISO)
    }

    private func isValidExposureDuration(_ duration: CMTime) -> Bool {
        let seconds = CMTimeGetSeconds(duration)
        return duration.isValid && seconds.isFinite && seconds > 0
    }

    private func logCustomExposureWrite(
        context: String,
        rawISO: Float,
        safeISO: Float?,
        minISO: Float,
        maxISO: Float,
        rawDuration: CMTime,
        safeDuration: CMTime?,
        reason: String
    ) {
        #if DEBUG
        let rawDurationSeconds = CMTimeGetSeconds(rawDuration)
        let safeDurationSeconds = safeDuration.map(CMTimeGetSeconds)
        let safeISOText = safeISO.map { String(format: "%.3f", Double($0)) } ?? "nil"
        let safeDurationText = safeDurationSeconds.map { String(format: "%.8f", $0) } ?? "nil"
        print(
            "[CaptureExposureWrite] context=\(context) rawISO=\(String(format: "%.3f", Double(rawISO))) safeISO=\(safeISOText) minISO=\(String(format: "%.3f", Double(minISO))) maxISO=\(String(format: "%.3f", Double(maxISO))) rawDuration=\(String(format: "%.8f", rawDurationSeconds)) safeDuration=\(safeDurationText) reason=\(reason)"
        )
        #endif
    }

    private func logExposureTriangle(_ message: String) {
        #if DEBUG
        print("[CaptureExposureTriangle] \(message)")
        #endif
    }

    private func logShutterRange(_ message: String) {
        #if DEBUG
        print("[CaptureShutterRange] \(message)")
        #endif
    }

    private func quantizedISOValue(_ value: Float) -> Float {
        let step: Float = 1
        return max(1, (value / step).rounded() * step)
    }

    private func shutterDurationSeconds(
        forNormalized normalized: Double,
        minDuration: Double,
        maxDuration: Double
    ) -> Double {
        guard minDuration > 0, maxDuration > 0, maxDuration > minDuration else {
            return max(minDuration, maxDuration)
        }
        let clampedNormalized = max(0.0, min(1.0, normalized))
        let minLog = log2(minDuration)
        let maxLog = log2(maxDuration)
        let targetLog = maxLog + ((minLog - maxLog) * clampedNormalized)
        return max(minDuration, min(maxDuration, pow(2.0, targetLog)))
    }

    private func normalizedShutterValue(
        seconds: Double,
        minDuration: Double,
        maxDuration: Double
    ) -> Double {
        guard seconds > 0, minDuration > 0, maxDuration > 0, maxDuration > minDuration else {
            return 0
        }
        let clampedSeconds = max(minDuration, min(maxDuration, seconds))
        let minLog = log2(minDuration)
        let maxLog = log2(maxDuration)
        let denominator = minLog - maxLog
        guard abs(denominator) > .ulpOfOne else { return 0 }
        let valueLog = log2(clampedSeconds)
        return max(0.0, min(1.0, (valueLog - maxLog) / denominator))
    }

    private func clampedShutterDuration(_ target: CMTime, device: AVCaptureDevice) -> CMTime {
        let minDuration = device.activeFormat.minExposureDuration
        let maxDuration = device.activeFormat.maxExposureDuration
        var clamped = target
        if CMTimeCompare(clamped, minDuration) < 0 {
            clamped = minDuration
        }
        if CMTimeCompare(clamped, maxDuration) > 0 {
            clamped = maxDuration
        }
        return clamped
    }

    private func clampedShutterDuration(for preset: CaptureShutterPreset, device: AVCaptureDevice) -> CMTime {
        guard let seconds = preset.durationSeconds else {
            let customDuration = CMTime(
                seconds: currentManualShutterDurationSeconds,
                preferredTimescale: 1_000_000_000
            )
            return clampedShutterDuration(customDuration, device: device)
        }
        let target = CMTime(seconds: seconds, preferredTimescale: 1_000_000_000)
        return clampedShutterDuration(target, device: device)
    }

    private func quantizedShutterDuration(_ duration: CMTime, device: AVCaptureDevice) -> CMTime {
        let seconds = CMTimeGetSeconds(duration)
        guard seconds.isFinite, seconds > 0 else { return clampedShutterDuration(duration, device: device) }

        let clampedDuration = clampedShutterDuration(duration, device: device)
        let clampedSeconds = CMTimeGetSeconds(clampedDuration)
        guard clampedSeconds.isFinite, clampedSeconds > 0 else { return clampedDuration }

        let quantized = CMTime(seconds: clampedSeconds, preferredTimescale: 1_000_000_000)
        logShutterRange(
            "min=\(formattedShutterDurationText(seconds: CMTimeGetSeconds(device.activeFormat.minExposureDuration)) ?? "--") " +
            "max=\(formattedShutterDurationText(seconds: CMTimeGetSeconds(device.activeFormat.maxExposureDuration)) ?? "--") " +
            "duration=\(formattedShutterDurationText(seconds: seconds) ?? "--") " +
            "quantized=\(formattedShutterDurationText(seconds: CMTimeGetSeconds(quantized)) ?? "--")"
        )
        return quantized
    }

    private func formattedShutterDurationText(seconds: Double) -> String? {
        guard seconds.isFinite, seconds > 0 else { return nil }
        if seconds >= 1 {
            return String(format: "%.1fs", seconds)
        }
        let denominator = max(1, Int((1.0 / seconds).rounded()))
        return "1/\(denominator)"
    }

    private func quantizedManualFocusPosition(_ position: Float) -> Float {
        let clamped = max(0, min(1, position))
        let step: Float = 0.01
        let snapped = (clamped / step).rounded() * step
        return max(0, min(1, snapped))
    }

    private func clampedWhiteBalanceTemperature(_ value: Float) -> Float {
        max(Self.whiteBalanceMinimumTemperature, min(Self.whiteBalanceMaximumTemperature, value))
    }

    private func clampedWhiteBalanceTint(_ value: Float) -> Float {
        max(Self.whiteBalanceMinimumTint, min(Self.whiteBalanceMaximumTint, value))
    }

    private func formattedWhiteBalanceTintText(_ value: Float) -> String {
        let rounded = Int(value.rounded())
        if rounded == 0 { return "T0" }
        if rounded > 0 { return "M\(rounded)" }
        return "G\(abs(rounded))"
    }

    private func refreshLensProfiles(
        position: AVCaptureDevice.Position,
        activeDevice: AVCaptureDevice,
        preferredLensID: String?
    ) {
        let previousSemanticFocal = selectedSemanticFocal
        let profiles = buildLensProfiles(position: position)
        availableLensProfiles = profiles

        if profiles.isEmpty {
            selectedLensProfileID = ""
            maximumZoomFactor = activeDeviceMaximumZoomFactor
            return
        }

        let selectedProfile: CaptureLensProfile
        if let preferredLensID,
           let preferred = profiles.first(where: { $0.id == preferredLensID }) {
            selectedProfile = preferred
        } else if Self.isVirtualBackCameraDeviceType(activeDevice.deviceType),
                  let previousSemanticFocal,
                  let matchedVirtualFocal = profiles.first(where: { $0.source == .virtual && $0.semanticFocal == previousSemanticFocal }) {
            selectedProfile = matchedVirtualFocal
        } else if Self.isVirtualBackCameraDeviceType(activeDevice.deviceType),
                  let defaultVirtualWide = profiles.first(where: { $0.source == .virtual && $0.semanticFocal == .mm24 }) {
            selectedProfile = defaultVirtualWide
        } else if let matchedByDevice = profiles.first(where: { $0.preferredDeviceType == activeDevice.deviceType }) {
            selectedProfile = matchedByDevice
        } else {
            selectedProfile = profiles[0]
        }

        applyLensSelection(selectedProfile, shouldShowHint: false)
    }

    private func applyLensSelection(
        _ profile: CaptureLensProfile,
        shouldShowHint: Bool
    ) {
        configureTele77Stabilization(for: profile)
        selectedLensProfileID = profile.id
        if profile.source == .virtual {
            let lower = minimumAvailableZoomForCurrentDevice()
            let upper = max(lower, min(activeDeviceMaximumZoomFactor, profile.lensMaxZoomFactor))
            minimumZoomFactor = lower
            maximumZoomFactor = upper
            let targetZoom = max(lower, min(upper, profile.baseZoomFactor))
            currentZoomFactor = targetZoom
            setZoomFactor(targetZoom, ramped: shouldShowHint, reason: "semanticFocal:\(profile.displayText)")
            if shouldShowHint {
                captureHintText = "焦段 \(profile.displayText)"
            }
            return
        }
        minimumZoomFactor = max(1.0, profile.baseZoomFactor)
        maximumZoomFactor = max(
            minimumZoomFactor,
            min(activeDeviceMaximumZoomFactor, profile.lensMaxZoomFactor)
        )

        let resetZoom = minimumZoomFactor
        currentZoomFactor = resetZoom

        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard let device = self.currentVideoInput?.device else { return }
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = resetZoom
                device.unlockForConfiguration()
            } catch {
                if shouldShowHint {
                    DispatchQueue.main.async {
                        self.captureHintText = "镜头切换失败"
                    }
                }
            }
        }
    }

    private func minimumAvailableZoomForCurrentDevice() -> CGFloat {
        if let device = currentVideoInput?.device {
            return max(1.0, device.minAvailableVideoZoomFactor)
        }
        return max(1.0, minimumZoomFactor)
    }

    private func shouldUseTele77StabilizationWindow(for profile: CaptureLensProfile) -> Bool {
        guard profile.semanticFocal == .mm77 else { return false }
        return nowTimestamp() < tele77StabilizationUntil
    }

    private func configureTele77Stabilization(for profile: CaptureLensProfile) {
        clearTele77StabilizationState()
        guard profile.semanticFocal == .mm77 else { return }
        tele77StabilizationUntil = nowTimestamp() + Self.tele77PostSwitchStabilizationWindow
    }

    private func clearTele77StabilizationState() {
        tele77StabilizationUntil = 0
        tele77LastWriteTimestamp = 0
        tele77PendingMultiplier = nil
        tele77StabilizationToken = UUID()
    }

    private func submitTele77StabilizedZoomWrite(multiplier: CGFloat, lensID: String) {
        if let pending = tele77PendingMultiplier,
           abs(pending - multiplier) <= Self.tele77PostSwitchHysteresis {
            return
        }
        tele77PendingMultiplier = multiplier

        let now = nowTimestamp()
        if now - tele77LastWriteTimestamp >= Self.tele77PostSwitchWriteInterval {
            flushTele77PendingZoomWrite(expectedLensID: lensID)
            return
        }

        let remaining = max(0, Self.tele77PostSwitchWriteInterval - (now - tele77LastWriteTimestamp))
        let delay = min(remaining, max(0, tele77StabilizationUntil - now))
        guard delay > 0 else {
            flushTele77PendingZoomWrite(expectedLensID: lensID)
            return
        }

        let token = UUID()
        tele77StabilizationToken = token
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            guard self.tele77StabilizationToken == token else { return }
            self.flushTele77PendingZoomWrite(expectedLensID: lensID)
        }
    }

    private func flushTele77PendingZoomWrite(expectedLensID: String) {
        guard selectedLensProfileID == expectedLensID else {
            tele77PendingMultiplier = nil
            return
        }
        guard let profile = selectedLensProfile, profile.id == expectedLensID else {
            tele77PendingMultiplier = nil
            return
        }
        guard let pending = tele77PendingMultiplier else { return }
        tele77PendingMultiplier = nil
        tele77LastWriteTimestamp = nowTimestamp()
        let targetZoom = profile.baseZoomFactor * pending
        setZoomFactor(targetZoom, ramped: true, reason: "tele77Stabilized")
    }

    private func nowTimestamp() -> TimeInterval {
        Date().timeIntervalSinceReferenceDate
    }

    private func buildLensProfiles(position: AVCaptureDevice.Position) -> [CaptureLensProfile] {
        if position == .front {
            return [
                CaptureLensProfile(
                    id: "front",
                    kind: .front,
                    source: .physical,
                    position: .front,
                    semanticFocal: nil,
                    displayText: "前置",
                    menuText: "前置镜头",
                    preferredDeviceType: .builtInWideAngleCamera,
                    baseZoomFactor: 1.0,
                    lensMaxZoomFactor: 3.0
                )
            ]
        }

        let backDevices = discoverCameras(position: .back)
        var profiles: [CaptureLensProfile] = []

        if let virtualBack = preferredVirtualBackCamera(in: backDevices),
           !shouldUsePhysicalLensProfiles {
            let virtualMaxZoom = normalizedDeviceMaxZoom(for: virtualBack)
            let virtualProfiles = CaptureSemanticFocal.allCases.compactMap { focal -> CaptureLensProfile? in
                guard let target = resolveLensTarget(for: focal, device: virtualBack) else {
                    logLensTargetResolution(
                        focal: focal,
                        target: nil,
                        device: virtualBack,
                        reason: "buildVirtualProfile.unavailable"
                    )
                    return nil
                }
                logLensTargetResolution(
                    focal: focal,
                    target: target,
                    device: virtualBack,
                    reason: "buildVirtualProfile"
                )
                return CaptureLensProfile(
                    id: "virtual-\(focal.millimeters)",
                    kind: lensKind(for: focal),
                    source: .virtual,
                    position: .back,
                    semanticFocal: focal,
                    displayText: focal.displayText,
                    menuText: lensMenuText(for: focal),
                    preferredDeviceType: target.preferredDeviceType,
                    baseZoomFactor: target.clampedZoomFactor,
                    lensMaxZoomFactor: virtualMaxZoom
                )
            }

            return virtualProfiles
        } else if let virtualBack = preferredVirtualBackCamera(in: backDevices) {
            logManualParameterCompatibility(
                device: virtualBack,
                reason: "virtualBackSkippedForPhysicalManualProfiles",
                lockProbe: nil
            )
        }

        if let ultraWide = backDevices.first(where: { $0.deviceType == .builtInUltraWideCamera }) {
            profiles.append(
                CaptureLensProfile(
                    id: "ultra-13",
                    kind: .ultraWide,
                    source: .physical,
                    position: .back,
                    semanticFocal: .mm13,
                    displayText: "13mm",
                    menuText: "超广角 13mm",
                    preferredDeviceType: .builtInUltraWideCamera,
                    baseZoomFactor: 1.0,
                    lensMaxZoomFactor: normalizedDeviceMaxZoom(for: ultraWide)
                )
            )
        }

        if let wide = backDevices.first(where: { $0.deviceType == .builtInWideAngleCamera }) {
            profiles.append(
                CaptureLensProfile(
                    id: "wide-24",
                    kind: .wide,
                    source: .physical,
                    position: .back,
                    semanticFocal: .mm24,
                    displayText: "24mm",
                    menuText: "主摄 24mm",
                    preferredDeviceType: .builtInWideAngleCamera,
                    baseZoomFactor: 1.0,
                    lensMaxZoomFactor: normalizedDeviceMaxZoom(for: wide)
                )
            )

            if shouldExposeDerived48mm(wide: wide, backDevices: backDevices) {
                profiles.append(
                    CaptureLensProfile(
                        id: "wide-48-derived",
                        kind: .wide,
                        source: .derived,
                        position: .back,
                        semanticFocal: .mm48,
                        displayText: "48mm",
                        menuText: "主摄 48mm",
                        preferredDeviceType: .builtInWideAngleCamera,
                        baseZoomFactor: 2.0,
                        lensMaxZoomFactor: normalizedDeviceMaxZoom(for: wide)
                    )
                )
            }
        }

        if let tele = backDevices.first(where: { $0.deviceType == .builtInTelephotoCamera }) {
            profiles.append(
                CaptureLensProfile(
                    id: "tele-77",
                    kind: .tele,
                    source: .physical,
                    position: .back,
                    semanticFocal: .mm77,
                    displayText: "77mm",
                    menuText: "长焦 77mm",
                    preferredDeviceType: .builtInTelephotoCamera,
                    baseZoomFactor: 1.0,
                    lensMaxZoomFactor: normalizedDeviceMaxZoom(for: tele)
                )
            )
        }

        if profiles.isEmpty {
            let fallbackMaxZoom = max(1.0, normalizedDeviceMaxZoom(for: backDevices.first))
            profiles.append(
                CaptureLensProfile(
                    id: "back-default",
                    kind: .wide,
                    source: .physical,
                    position: .back,
                    semanticFocal: .mm24,
                    displayText: "24mm",
                    menuText: "后摄主镜头",
                    preferredDeviceType: nil,
                    baseZoomFactor: 1.0,
                    lensMaxZoomFactor: fallbackMaxZoom
                )
            )
        }

        return tunedLensProfiles(profiles)
    }

    private func resolveLensTarget(
        millimeters: Int,
        device: AVCaptureDevice
    ) -> SellerCameraLensTarget? {
        guard let focal = CaptureSemanticFocal.allCases.first(where: { $0.millimeters == millimeters }) else {
            return nil
        }
        return resolveLensTarget(for: focal, device: device)
    }

    private func resolveLensTarget(
        for focal: CaptureSemanticFocal,
        device: AVCaptureDevice
    ) -> SellerCameraLensTarget? {
        let lower = minimumAvailableZoom(for: device)
        let upper = max(lower, normalizedDeviceMaxZoom(for: device))

        let requestedZoomFactor: CGFloat?
        if device.isVirtualDevice {
            requestedZoomFactor = resolveVirtualLensZoomFactor(
                for: focal,
                device: device,
                lower: lower,
                upper: upper
            )
        } else {
            requestedZoomFactor = resolvePhysicalLensZoomFactor(
                for: focal,
                device: device,
                lower: lower,
                upper: upper
            )
        }

        guard let requestedZoomFactor else { return nil }
        return SellerCameraLensTarget(
            displayMillimeters: focal.millimeters,
            requestedZoomFactor: requestedZoomFactor,
            clampedZoomFactor: clampedZoomFactor(requestedZoomFactor, lower: lower, upper: upper),
            preferredDeviceType: device.deviceType
        )
    }

    private func resolveVirtualLensZoomFactor(
        for focal: CaptureSemanticFocal,
        device: AVCaptureDevice,
        lower: CGFloat,
        upper: CGFloat
    ) -> CGFloat? {
        let constituents = device.constituentDevices
        let hasUltraWide = constituents.contains { $0.deviceType == .builtInUltraWideCamera }
            || device.deviceType == .builtInTripleCamera
            || device.deviceType == .builtInDualWideCamera
        let hasWide = constituents.contains { $0.deviceType == .builtInWideAngleCamera }
            || device.deviceType == .builtInTripleCamera
            || device.deviceType == .builtInDualWideCamera
            || device.deviceType == .builtInDualCamera
        let hasTele = constituents.contains { $0.deviceType == .builtInTelephotoCamera }
            || device.deviceType == .builtInTripleCamera
            || device.deviceType == .builtInDualCamera
        let switchFactors = normalizedSwitchOverFactors(for: device, lower: lower, upper: upper)
        let wideAnchor: CGFloat = {
            guard hasUltraWide, hasWide else { return lower }
            if let firstSwitch = switchFactors.first {
                return firstSwitch
            }
            return clampedZoomFactor(lower * CGFloat(24.0 / 13.0), lower: lower, upper: upper)
        }()
        let teleAnchor: CGFloat? = {
            guard hasTele else { return nil }
            if switchFactors.count >= 2, let lastSwitch = switchFactors.last {
                return lastSwitch
            }
            let fallback = wideAnchor * CGFloat(77.0 / 24.0)
            return fallback <= upper + 0.01 ? fallback : nil
        }()

        switch focal {
        case .mm13:
            guard hasUltraWide else { return nil }
            return lower
        case .mm24:
            guard hasWide else { return nil }
            return wideAnchor
        case .mm48:
            guard hasWide else { return nil }
            let target = wideAnchor * 2.0
            guard target <= upper + 0.01 else { return nil }
            return target
        case .mm77:
            return teleAnchor
        }
    }

    private func resolvePhysicalLensZoomFactor(
        for focal: CaptureSemanticFocal,
        device: AVCaptureDevice,
        lower: CGFloat,
        upper: CGFloat
    ) -> CGFloat? {
        switch (focal, device.deviceType) {
        case (.mm13, .builtInUltraWideCamera),
             (.mm24, .builtInWideAngleCamera),
             (.mm77, .builtInTelephotoCamera):
            return lower
        case (.mm48, .builtInWideAngleCamera):
            let target = max(lower, 2.0)
            return target <= upper + 0.01 ? target : nil
        default:
            return nil
        }
    }

    private func normalizedSwitchOverFactors(
        for device: AVCaptureDevice,
        lower: CGFloat,
        upper: CGFloat
    ) -> [CGFloat] {
        let rawFactors = device.virtualDeviceSwitchOverVideoZoomFactors
            .map { CGFloat(truncating: $0) }
            .filter { $0 >= lower - 0.001 && $0 <= upper + 0.001 }
            .sorted()
        var uniqueFactors: [CGFloat] = []
        for factor in rawFactors {
            if uniqueFactors.last.map({ abs($0 - factor) > 0.001 }) ?? true {
                uniqueFactors.append(factor)
            }
        }
        return uniqueFactors
    }

    private func minimumAvailableZoom(for device: AVCaptureDevice) -> CGFloat {
        max(1.0, device.minAvailableVideoZoomFactor)
    }

    private func clampedZoomFactor(
        _ requestedZoomFactor: CGFloat,
        lower: CGFloat,
        upper: CGFloat
    ) -> CGFloat {
        max(lower, min(upper, requestedZoomFactor))
    }

    private func lensKind(for focal: CaptureSemanticFocal) -> CaptureLensProfile.Kind {
        switch focal {
        case .mm13:
            return .ultraWide
        case .mm24, .mm48:
            return .wide
        case .mm77:
            return .tele
        }
    }

    private func lensMenuText(for focal: CaptureSemanticFocal) -> String {
        switch focal {
        case .mm13:
            return "超广角 13mm"
        case .mm24:
            return "主摄 24mm"
        case .mm48:
            return "主摄 48mm"
        case .mm77:
            return "长焦 77mm"
        }
    }

    private func discoverCameras(position: AVCaptureDevice.Position) -> [AVCaptureDevice] {
        let types: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,
            .builtInDualWideCamera,
            .builtInDualCamera,
            .builtInWideAngleCamera,
            .builtInUltraWideCamera,
            .builtInTelephotoCamera
        ]

        return AVCaptureDevice.DiscoverySession(
            deviceTypes: types,
            mediaType: .video,
            position: position
        ).devices
    }

    private func normalizedDeviceMaxZoom(for device: AVCaptureDevice?) -> CGFloat {
        guard let device else { return 1.0 }
        return max(
            1.0,
            min(device.activeFormat.videoMaxZoomFactor, device.maxAvailableVideoZoomFactor)
        )
    }

    private func logLensDeviceState(
        _ device: AVCaptureDevice,
        uiFocalLabel: String?,
        reason: String
    ) {
#if DEBUG
        let switchFactors = device.virtualDeviceSwitchOverVideoZoomFactors
            .map { String(format: "%.2f", CGFloat(truncating: $0)) }
            .joined(separator: ",")
        let constituents = device.constituentDevices.map { constituent in
            formattedLensDeviceCapability(constituent)
        }.joined(separator: ";")
        let activePrimary: String
        if let active = device.activePrimaryConstituent {
            activePrimary = formattedLensDeviceCapability(active)
        } else {
            activePrimary = "nil"
        }
        print(
            "[CaptureLensDevice] " +
            "reason=\(reason) " +
            "uniqueID=\(device.uniqueID) " +
            "activeDevice=\(device.localizedName) " +
            "deviceType=\(device.deviceType.rawValue) " +
            "isVirtual=\(device.isVirtualDevice) " +
            "constituents=[\(constituents)] " +
            "activePrimary=\(activePrimary) " +
            "virtualSwitchOver=[\(switchFactors)] " +
            "minZoom=\(String(format: "%.2f", device.minAvailableVideoZoomFactor)) " +
            "maxZoom=\(String(format: "%.2f", device.maxAvailableVideoZoomFactor)) " +
            "videoZoom=\(String(format: "%.2f", device.videoZoomFactor)) " +
            "activeFormatFOV=\(String(format: "%.2f", device.activeFormat.videoFieldOfView)) " +
            "uiFocal=\(uiFocalLabel ?? selectedLensProfile?.displayText ?? "nil")"
        )
#endif
    }

    private func logLensTargetResolution(
        focal: CaptureSemanticFocal,
        target: SellerCameraLensTarget?,
        device: AVCaptureDevice,
        reason: String
    ) {
#if DEBUG
        let switchFactors = device.virtualDeviceSwitchOverVideoZoomFactors
            .map { String(format: "%.2f", CGFloat(truncating: $0)) }
            .joined(separator: ",")
        let requested = target.map { String(format: "%.3f", $0.requestedZoomFactor) } ?? "nil"
        let clamped = target.map { String(format: "%.3f", $0.clampedZoomFactor) } ?? "nil"
        print(
            "[CaptureLensTarget] " +
            "reason=\(reason) " +
            "focal=\(focal.displayText) " +
            "requested=\(requested) " +
            "clamped=\(clamped) " +
            "device=\(device.localizedName) " +
            "type=\(device.deviceType.rawValue) " +
            "isVirtual=\(device.isVirtualDevice) " +
            "min=\(String(format: "%.3f", minimumAvailableZoom(for: device))) " +
            "max=\(String(format: "%.3f", normalizedDeviceMaxZoom(for: device))) " +
            "videoZoom=\(String(format: "%.3f", device.videoZoomFactor)) " +
            "switchOver=[\(switchFactors)]"
        )
#endif
    }

    private func formattedLensDeviceCapability(_ device: AVCaptureDevice) -> String {
        [
            device.localizedName,
            device.deviceType.rawValue,
            device.uniqueID,
            "fov=\(String(format: "%.2f", device.activeFormat.videoFieldOfView))",
            "min=\(String(format: "%.2f", device.minAvailableVideoZoomFactor))",
            "max=\(String(format: "%.2f", device.maxAvailableVideoZoomFactor))"
        ].joined(separator: "|")
    }

    private func formattedManualFocusDeviceState(_ device: AVCaptureDevice?) -> String {
        guard let device else {
            return "device=nil type=nil uniqueID=nil isVirtual=false activePrimary=nil focusMode=nil focusLocked=false focusCustomLens=false lens=nil adjustingFocus=false selectedLens=\(selectedLensProfile?.displayText ?? "nil") selectedLensID=\(selectedLensProfileID)"
        }
        let activePrimary = device.activePrimaryConstituent.map { formattedLensDeviceCapability($0) } ?? "nil"
        return [
            "device=\(device.localizedName)",
            "type=\(device.deviceType.rawValue)",
            "uniqueID=\(device.uniqueID)",
            "isVirtual=\(device.isVirtualDevice)",
            "activePrimary=\(activePrimary)",
            "zoom=\(String(format: "%.3f", device.videoZoomFactor))",
            "focusMode=\(device.focusMode.rawValue)",
            "focusLocked=\(device.isFocusModeSupported(.locked))",
            "focusAuto=\(device.isFocusModeSupported(.autoFocus))",
            "focusContinuous=\(device.isFocusModeSupported(.continuousAutoFocus))",
            "focusCustomLens=\(device.isLockingFocusWithCustomLensPositionSupported)",
            "lens=\(String(format: "%.3f", Double(device.lensPosition)))",
            "adjustingFocus=\(device.isAdjustingFocus)",
            "selectedLens=\(selectedLensProfile?.displayText ?? "nil")",
            "selectedLensID=\(selectedLensProfileID)"
        ].joined(separator: " ")
    }

    private func logManualFocusSupport(
        device: AVCaptureDevice?,
        capability: ManualFocusCapability,
        reason: String
    ) {
#if DEBUG
        print(
            "[CaptureMFSupport] " +
            "reason=\(reason) " +
            "sessionRunning=\(session.isRunning) " +
            "capability=\(capability.reasonText) " +
            "supported=\(capability.isFull) " +
            formattedManualFocusDeviceState(device)
        )
#endif
    }

    private func logManualFocusGuard(
        device: AVCaptureDevice?,
        capability: ManualFocusCapability,
        reason: String
    ) {
#if DEBUG
        print(
            "[CaptureMFGuard] " +
            "reason=\(reason) " +
            "capability=\(capability.reasonText) " +
            "supported=\(capability.isFull) " +
            formattedManualFocusDeviceState(device)
        )
#endif
    }

    private func logManualFocusWrite(
        device: AVCaptureDevice,
        requested: Float,
        applied: Float,
        reason: String,
        success: Bool,
        error: Error?
    ) {
#if DEBUG
        print(
            "[CaptureMFWrite] " +
            "reason=\(reason) " +
            "success=\(success) " +
            "requested=\(String(format: "%.3f", Double(requested))) " +
            "applied=\(String(format: "%.3f", Double(applied))) " +
            "error=\(error?.localizedDescription ?? "nil") " +
            formattedManualFocusDeviceState(device)
        )
#endif
    }

    private func logManualFocusRestoreAF(
        device: AVCaptureDevice?,
        mode: String,
        reason: String,
        success: Bool,
        error: Error?
    ) {
#if DEBUG
        print(
            "[CaptureMFRestoreAF] " +
            "reason=\(reason) " +
            "success=\(success) " +
            "mode=\(mode) " +
            "error=\(error?.localizedDescription ?? "nil") " +
            formattedManualFocusDeviceState(device)
        )
#endif
    }

    func logManualParameterCompatibilityForPanel(reason: String) {
#if DEBUG
        sessionQueue.async { [weak self] in
            guard let self, let device = self.currentVideoInput?.device else { return }
            let lockProbe: String
            do {
                try device.lockForConfiguration()
                lockProbe = "success"
                device.unlockForConfiguration()
            } catch {
                lockProbe = "failed:\(error.localizedDescription)"
            }
            self.logManualParameterCompatibility(device: device, reason: reason, lockProbe: lockProbe)
            DispatchQueue.main.async {
                self.updateISOCapabilityState(with: device)
                self.updateShutterCapabilityState(with: device)
                self.updateWhiteBalanceCapabilityState(with: device)
            }
        }
#endif
    }

    private func logManualParameterCompatibility(
        device: AVCaptureDevice,
        reason: String,
        lockProbe: String?
    ) {
#if DEBUG
        let dimensions = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
        let durationSeconds = CMTimeGetSeconds(device.exposureDuration)
        let minDurationSeconds = CMTimeGetSeconds(device.activeFormat.minExposureDuration)
        let maxDurationSeconds = CMTimeGetSeconds(device.activeFormat.maxExposureDuration)
        let gains = device.deviceWhiteBalanceGains
        let grayGains = device.grayWorldDeviceWhiteBalanceGains
        let constituents = device.constituentDevices.map {
            "\($0.localizedName)|\($0.deviceType.rawValue)|\($0.uniqueID)"
        }.joined(separator: ";")
        let activePrimary: String
        if let active = device.activePrimaryConstituent {
            activePrimary = "\(active.localizedName)|\(active.deviceType.rawValue)|\(active.uniqueID)"
        } else {
            activePrimary = "nil"
        }
        let switchFactors = device.virtualDeviceSwitchOverVideoZoomFactors
            .map { String(format: "%.2f", CGFloat(truncating: $0)) }
            .joined(separator: ",")
        let exposureDevice = manualExposureControlDevice(for: device)
        let exposureTarget = "\(exposureDevice.localizedName)|\(exposureDevice.deviceType.rawValue)|\(exposureDevice.uniqueID)"
        let whiteBalanceDevice = manualWhiteBalanceControlDevice(for: device)
        let whiteBalanceTarget = "\(whiteBalanceDevice.localizedName)|\(whiteBalanceDevice.deviceType.rawValue)|\(whiteBalanceDevice.uniqueID)"
        let focusCapability = manualFocusCapability(for: device)
        print(
            "[ManualParamCompat] " +
            "reason=\(reason) " +
            "sessionRunning=\(session.isRunning) " +
            "lockProbe=\(lockProbe ?? "n/a") " +
            "uniqueID=\(device.uniqueID) " +
            "name=\(device.localizedName) " +
            "type=\(device.deviceType.rawValue) " +
            "position=\(device.position.rawValue) " +
            "isVirtual=\(device.isVirtualDevice) " +
            "constituents=[\(constituents)] " +
            "activePrimary=\(activePrimary) " +
            "manualExposureTarget=\(exposureTarget) " +
            "manualWhiteBalanceTarget=\(whiteBalanceTarget) " +
            "activeFormat=\(dimensions.width)x\(dimensions.height) " +
            "formats=\(device.formats.count) " +
            "zoom=\(String(format: "%.3f", device.videoZoomFactor)) " +
            "switchOver=[\(switchFactors)] " +
            "connected=\(device.isConnected) " +
            "suspended=\(device.isSuspended) " +
            "exposureMode=\(device.exposureMode.rawValue) " +
            "expAuto=\(device.isExposureModeSupported(.continuousAutoExposure)) " +
            "expCustom=\(device.isExposureModeSupported(.custom)) " +
            "minISO=\(String(format: "%.2f", Double(device.activeFormat.minISO))) " +
            "maxISO=\(String(format: "%.2f", Double(device.activeFormat.maxISO))) " +
            "iso=\(String(format: "%.2f", Double(device.iso))) " +
            "minDuration=\(String(format: "%.8f", minDurationSeconds)) " +
            "maxDuration=\(String(format: "%.8f", maxDurationSeconds)) " +
            "duration=\(String(format: "%.8f", durationSeconds)) " +
            "adjustingExposure=\(device.isAdjustingExposure) " +
            "wbMode=\(device.whiteBalanceMode.rawValue) " +
            "wbAuto=\(device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance)) " +
            "wbLocked=\(device.isWhiteBalanceModeSupported(.locked)) " +
            "wbCustomGains=\(device.isLockingWhiteBalanceWithCustomDeviceGainsSupported) " +
            "wbGains=(\(String(format: "%.3f", gains.redGain)),\(String(format: "%.3f", gains.greenGain)),\(String(format: "%.3f", gains.blueGain))) " +
            "grayGains=(\(String(format: "%.3f", grayGains.redGain)),\(String(format: "%.3f", grayGains.greenGain)),\(String(format: "%.3f", grayGains.blueGain))) " +
            "maxWBGain=\(String(format: "%.3f", device.maxWhiteBalanceGain)) " +
            "adjustingWB=\(device.isAdjustingWhiteBalance) " +
            "focusMode=\(device.focusMode.rawValue) " +
            "focusLocked=\(device.isFocusModeSupported(.locked)) " +
            "focusAuto=\(device.isFocusModeSupported(.autoFocus)) " +
            "focusContinuous=\(device.isFocusModeSupported(.continuousAutoFocus)) " +
            "focusCustomLens=\(device.isLockingFocusWithCustomLensPositionSupported) " +
            "lensPosition=\(String(format: "%.3f", Double(device.lensPosition))) " +
            "adjustingFocus=\(device.isAdjustingFocus) " +
            "mfAvailability=\(focusCapability.reasonText) " +
            "isoAvailability=\(manualExposureAvailability(for: device, parameter: "ISO").reasonText) " +
            "shutterAvailability=\(manualExposureAvailability(for: device, parameter: "Shutter").reasonText) " +
            "wbAvailability=\(manualWhiteBalanceAvailability(for: device).reasonText)"
        )
#endif
    }

    private static func isVirtualBackCameraDeviceType(_ deviceType: AVCaptureDevice.DeviceType?) -> Bool {
        guard let deviceType else { return false }
        return deviceType == .builtInTripleCamera
            || deviceType == .builtInDualWideCamera
            || deviceType == .builtInDualCamera
    }

    private func preferredVirtualBackCamera(in devices: [AVCaptureDevice]) -> AVCaptureDevice? {
        devices.first(where: { $0.deviceType == .builtInTripleCamera })
            ?? devices.first(where: { $0.deviceType == .builtInDualWideCamera })
            ?? devices.first(where: { $0.deviceType == .builtInDualCamera })
    }

    private func shouldPreferVirtualBackCameraForManualParameters(_ device: AVCaptureDevice) -> Bool {
        manualExposureAvailability(for: device, parameter: "virtualExposure").isWritable
            && manualWhiteBalanceAvailability(for: device).isWritable
    }

    private func maximumSupportedPhotoLongEdge(for device: AVCaptureDevice) -> Int {
        var maxLongEdge = 0
        for format in device.formats {
            if #available(iOS 16.0, *) {
                let candidate = format.supportedMaxPhotoDimensions
                    .map { max(Int($0.width), Int($0.height)) }
                    .max() ?? 0
                maxLongEdge = max(maxLongEdge, candidate)
            } else {
                let highRes = format.highResolutionStillImageDimensions
                maxLongEdge = max(maxLongEdge, max(Int(highRes.width), Int(highRes.height)))
            }
        }
        return maxLongEdge
    }

    private func hasVirtualBackSwitchPointNear2x(in backDevices: [AVCaptureDevice]) -> Bool {
        backDevices.contains { device in
            let isVirtualBack = device.position == .back && (
                device.deviceType == .builtInDualWideCamera
                || device.deviceType == .builtInDualCamera
                || device.deviceType == .builtInTripleCamera
            )
            guard isVirtualBack else { return false }
            let switchFactors = device.virtualDeviceSwitchOverVideoZoomFactors
            return switchFactors.contains { factor in
                abs(CGFloat(truncating: factor) - 2.0) <= Self.derived48SwitchOverTolerance
            }
        }
    }

    private func shouldExposeDerived48mm(
        wide: AVCaptureDevice,
        backDevices: [AVCaptureDevice]
    ) -> Bool {
        let maxLongEdge = maximumSupportedPhotoLongEdge(for: wide)
        guard maxLongEdge >= Self.derived48PreferredLongEdge else { return false }
        guard normalizedDeviceMaxZoom(for: wide) >= 2.0 else { return false }

        let hasTele = backDevices.contains { $0.deviceType == .builtInTelephotoCamera }
        if maxLongEdge >= Self.derived48StrongConfidenceLongEdge {
            return true
        }
        if hasVirtualBackSwitchPointNear2x(in: backDevices) {
            return true
        }
        // 没有长焦的机型，48mm 派生焦段通常是更重要的构图档位，保守暴露。
        return !hasTele
    }

    private func tunedLensProfiles(_ profiles: [CaptureLensProfile]) -> [CaptureLensProfile] {
        var tuned = profiles

        if let derived48Index = tuned.firstIndex(where: { $0.semanticFocal == .mm48 && $0.source == .derived }),
           let wide24Index = tuned.firstIndex(where: { $0.semanticFocal == .mm24 && $0.kind == .wide }) {
            let anchor48 = max(1.0, tuned[derived48Index].baseZoomFactor)
            let wide24Max = anchor48 * Self.wideLensBoundaryHeadroom
            if tuned[wide24Index].lensMaxZoomFactor > wide24Max {
                tuned[wide24Index] = tuned[wide24Index].updating(lensMaxZoomFactor: wide24Max)
            }

            if tuned.contains(where: { $0.semanticFocal == .mm77 && $0.kind == .tele }) {
                let teleAnchorOnWide = CGFloat(77.0 / 24.0)
                let derived48Max = teleAnchorOnWide * Self.teleLensBoundaryHeadroom
                if tuned[derived48Index].lensMaxZoomFactor > derived48Max {
                    tuned[derived48Index] = tuned[derived48Index].updating(lensMaxZoomFactor: derived48Max)
                }
            }
        }

        for index in tuned.indices {
            guard let focal = tuned[index].semanticFocal else { continue }
            guard focal == .mm13 || focal == .mm77 else { continue }

            let localAnchor = max(1.0, tuned[index].baseZoomFactor)
            let stageCap = localAnchor * Self.stageLensLocalMaxMultiplierCap
            if tuned[index].lensMaxZoomFactor > stageCap {
                tuned[index] = tuned[index].updating(lensMaxZoomFactor: stageCap)
            }
        }

        return tuned
    }

    private func quantizedLensZoomMultiplier(_ multiplier: CGFloat, maximum: CGFloat) -> CGFloat {
        let step: CGFloat
        if maximum <= 1.6 {
            step = 0.01
        } else if maximum <= 3.0 {
            step = 0.02
        } else {
            step = 0.05
        }
        let snapped = (multiplier / step).rounded() * step
        return max(1.0, min(maximum, snapped))
    }

    private func snappedLensZoomMultiplier(_ multiplier: CGFloat, maximum: CGFloat) -> CGFloat {
        let anchors: [CGFloat] = [1.0, 1.2, 1.5, 2.0, 3.0, 4.0, 5.0, 6.0]
            .filter { $0 >= 1.0 && $0 <= maximum + 0.001 }
        guard let nearest = anchors.min(by: { abs($0 - multiplier) < abs($1 - multiplier) }) else {
            return multiplier
        }
        let threshold = max(Self.lensZoomSnapThresholdBase, maximum * 0.008)
        if abs(nearest - multiplier) <= threshold {
            return nearest
        }
        return multiplier
    }

    private func resolveCamera(
        position: AVCaptureDevice.Position,
        preferredDeviceType: AVCaptureDevice.DeviceType? = nil
    ) -> AVCaptureDevice? {
        let cameras = discoverCameras(position: position)

        if let preferredDeviceType,
           let matched = cameras.first(where: { $0.deviceType == preferredDeviceType }) {
            return matched
        }

        if position == .back {
            if preferredDeviceType == nil,
               !isManualParameterModeRequested,
               let virtualBack = preferredVirtualBackCamera(in: cameras) {
                return virtualBack
            }
            return cameras.first(where: { $0.deviceType == .builtInWideAngleCamera })
                ?? cameras.first(where: { $0.deviceType == .builtInUltraWideCamera })
                ?? cameras.first(where: { $0.deviceType == .builtInTelephotoCamera })
                ?? preferredVirtualBackCamera(in: cameras)
                ?? cameras.first
        }

        return cameras.first
    }

    private func startLevelMonitoringIfNeeded() {
        guard !levelMotionStarted else { return }
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self else { return }
            guard self.isLevelIndicatorEnabled else { return }
            guard let motion else {
                self.levelRollDegrees = nil
                self.levelGravityX = nil
                self.levelGravityY = nil
                self.levelGravityZ = nil
                return
            }
            let roll = motion.attitude.roll * 180.0 / .pi
            self.levelRollDegrees = roll
            self.levelGravityX = motion.gravity.x
            self.levelGravityY = motion.gravity.y
            self.levelGravityZ = motion.gravity.z
        }
        levelMotionStarted = true
    }

    private func clearTransientCaptureStates(clearCountdown: Bool) {
        focusFeedbackTask?.cancel()
        focusFeedbackTask = nil
        focusMarker = nil
        quickPreviewHideTask?.cancel()
        quickPreviewHideTask = nil
        quickPreviewImage = nil

        if clearCountdown {
            countdownTask?.cancel()
            countdownTask = nil
            countdownSecondsRemaining = nil
        }

        burstTask?.cancel()
        burstTask = nil
        isBurstCapturing = false
        burstProgressText = nil
    }

    private func clearFocusExposureLockState() {
        guard isFocusExposureLocked || isExposureLocked else { return }
        isFocusExposureLocked = false
        isExposureLocked = false
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard let device = self.currentVideoInput?.device else { return }
            do {
                try device.lockForConfiguration()
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                } else if device.isFocusModeSupported(.autoFocus) {
                    device.focusMode = .autoFocus
                }
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
                let updatedBias = device.exposureTargetBias
                let updatedISO = device.iso
                let updatedShutterSeconds = CMTimeGetSeconds(device.exposureDuration)
                let updatedLensPosition = device.lensPosition
                device.unlockForConfiguration()
                DispatchQueue.main.async {
                    self.currentExposureBias = updatedBias
                    self.isExposureBiasAutoMode = true
                    self.currentISOValue = updatedISO
                    self.currentShutterDurationSeconds = updatedShutterSeconds.isFinite ? updatedShutterSeconds : 0
                    self.selectedISOPreset = .auto
                    self.selectedShutterPreset = .auto
                    let quantized = self.quantizedManualFocusPosition(updatedLensPosition)
                    self.currentManualFocusPosition = quantized
                    self.lastAppliedManualFocusPosition = quantized
                    self.focusControlMode = .auto
                }
            } catch {
                // Keep non-blocking behavior.
            }
        }
    }

    private enum ExposureBiasWriteSource {
        case user
        case productAuto
    }

    private func setExposureBias(
        _ requestedBias: Float,
        switchesToManual: Bool,
        source: ExposureBiasWriteSource = .user
    ) {
        guard !isManualExposurePresetActive else {
            if source == .productAuto {
                productAutoExposureStatusText = "商品 Auto 暂停 · 手动曝光"
            }
            captureHintText = manualExposureEVLockHintText
            logExposureTriangle("EV write blocked isoMode=\(selectedISOPreset == .auto ? "auto" : "manual") shutterMode=\(selectedShutterPreset == .auto ? "auto" : "manual") evState=locked")
            return
        }
        if source == .user, switchesToManual {
            productAutoExposureOptimizer.reset()
            productAutoExposureStatusText = "商品 Auto 暂停 · 手动EV"
            productAutoExposureAppliedBias = nil
        }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard let device = self.currentVideoInput?.device else { return }
            let clamped = max(device.minExposureTargetBias, min(device.maxExposureTargetBias, requestedBias))

            do {
                try device.lockForConfiguration()
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
                device.setExposureTargetBias(clamped) { [weak self] _ in
                    DispatchQueue.main.async {
                        guard let self else { return }
                        self.currentExposureBias = clamped
                        self.isExposureBiasAutoMode = !switchesToManual
                        self.currentISOValue = device.iso
                        let seconds = CMTimeGetSeconds(device.exposureDuration)
                        self.currentShutterDurationSeconds = seconds.isFinite ? seconds : 0
                        self.selectedISOPreset = .auto
                        self.selectedShutterPreset = .auto
                        if source == .productAuto {
                            self.productAutoExposureAppliedBias = clamped
                            self.productAutoExposureStatusText = "商品 Auto \(String(format: "%+.2f", clamped))"
                        } else {
                            self.productAutoExposureAppliedBias = switchesToManual ? nil : clamped
                            self.captureHintText = switchesToManual
                                ? "EV \(String(format: "%+.2f", clamped))"
                                : "EV：Auto"
                        }
                    }
                }
                device.unlockForConfiguration()
            } catch {
                DispatchQueue.main.async {
                    self.captureHintText = "EV 调节失败"
                }
            }
        }
    }

    private func handleProductAutoExposureMetrics(_ metrics: ProductAutoExposureMetrics) {
        let availability = productAutoExposureAvailability()
        guard availability.canWrite else {
            productAutoExposureOptimizer.reset()
            productAutoExposureAppliedBias = nil
            productAutoExposureStatusText = availability.statusText
            logProductAutoExposureSummary(
                metrics,
                availability: availability,
                recommendation: nil,
                skippedReason: "unavailable"
            )
            return
        }

        guard Date().timeIntervalSince(lastProductAutoExposureWriteAt) >= productAutoExposureWriteInterval else {
            logProductAutoExposureSummary(
                metrics,
                availability: availability,
                recommendation: nil,
                skippedReason: "writeInterval"
            )
            return
        }

        guard let recommendation = productAutoExposureOptimizer.recommendation(
            metrics: metrics,
            currentBias: currentExposureBias,
            minimumDeviceBias: minimumExposureBias,
            maximumDeviceBias: maximumExposureBias
        ) else {
            productAutoExposureStatusText = "商品 Auto 稳定"
            logProductAutoExposureSummary(
                metrics,
                availability: availability,
                recommendation: nil,
                skippedReason: "stable"
            )
            return
        }

        lastProductAutoExposureWriteAt = Date()
        logProductAutoExposureSummary(
            metrics,
            availability: availability,
            recommendation: recommendation,
            skippedReason: nil
        )
        setExposureBias(recommendation.nextBias, switchesToManual: false, source: .productAuto)
    }

    private func handleProductAutoWhiteBalanceMetrics(_ metrics: ProductAutoWhiteBalanceMetrics) {
        let availability = productAutoWhiteBalanceAvailability()
        guard availability.canWrite else {
            productAutoWhiteBalanceOptimizer.reset()
            productAutoWhiteBalanceAppliedTemperature = nil
            productAutoWhiteBalanceStatusText = availability.statusText
            logProductAutoWhiteBalanceSummary(
                metrics,
                availability: availability,
                recommendation: nil,
                skippedReason: "unavailable"
            )
            return
        }

        guard Date().timeIntervalSince(lastProductAutoWhiteBalanceWriteAt) >= productAutoWhiteBalanceWriteInterval else {
            logProductAutoWhiteBalanceSummary(
                metrics,
                availability: availability,
                recommendation: nil,
                skippedReason: "writeInterval"
            )
            return
        }

        guard let recommendation = productAutoWhiteBalanceOptimizer.recommendation(
            metrics: metrics,
            currentTemperature: currentWhiteBalanceTemperature,
            minimumTemperature: Self.whiteBalanceMinimumTemperature,
            maximumTemperature: Self.whiteBalanceMaximumTemperature
        ) else {
            productAutoWhiteBalanceStatusText = "商品 WB 稳定"
            logProductAutoWhiteBalanceSummary(
                metrics,
                availability: availability,
                recommendation: nil,
                skippedReason: "stable"
            )
            return
        }

        lastProductAutoWhiteBalanceWriteAt = Date()
        logProductAutoWhiteBalanceSummary(
            metrics,
            availability: availability,
            recommendation: recommendation,
            skippedReason: nil
        )
        applyProductAutoWhiteBalance(temperature: recommendation.nextTemperature)
    }

    private func handleProductSharpnessMetrics(_ metrics: ProductSharpnessMetrics) {
        let now = Date()
        var autoFocusResult = "notRequested"

        switch metrics.state {
        case .sharp:
            productSharpnessSharpHitCount += 1
            productSharpnessBlurryHitCount = 0
            if productSharpnessSharpHitCount >= 3 {
                productSharpnessStatusText = "商品清晰"
                hasProductFocusAssistTriggeredForCurrentBlurEpisode = false
            }
        case .slightlySoft:
            productSharpnessSharpHitCount = 0
            productSharpnessBlurryHitCount = 0
            hasProductFocusAssistTriggeredForCurrentBlurEpisode = false
            productSharpnessStatusText = "画面略虚"
        case .blurry:
            productSharpnessBlurryHitCount += 1
            productSharpnessSharpHitCount = 0
            productSharpnessStatusText = "商品可能未对焦"

            if productSharpnessBlurryHitCount >= 3 {
                if now.timeIntervalSince(lastProductSharpnessHintAt) >= 3.0 {
                    captureHintText = "商品可能未对焦，建议重新对焦"
                    lastProductSharpnessHintAt = now
                }

                let availability = productFocusAssistAvailability(now: now)
                if hasProductFocusAssistTriggeredForCurrentBlurEpisode {
                    autoFocusResult = "skipped:episodeAlreadyAssisted"
                } else if availability.canTrigger {
                    lastProductFocusAssistAt = now
                    hasProductFocusAssistTriggeredForCurrentBlurEpisode = true
                    productSharpnessStatusText = "正在辅助对焦"
                    focusMarker = CaptureFocusMarker(normalizedPoint: CGPoint(x: 0.5, y: 0.5), mode: .focusing)
                    autoFocusResult = "triggered"
                    applyFocusExposure(
                        devicePoint: CGPoint(x: 0.5, y: 0.5),
                        normalizedPoint: CGPoint(x: 0.5, y: 0.5),
                        lockAfterFocus: false,
                        source: .productAutoFocus
                    )
                } else {
                    autoFocusResult = "skipped:\(availability.reason)"
                }
            }
        case .lowConfidence:
            productSharpnessSharpHitCount = 0
            productSharpnessBlurryHitCount = 0
            hasProductFocusAssistTriggeredForCurrentBlurEpisode = false
            productSharpnessStatusText = "清晰度置信度不足"
            autoFocusResult = "skipped:lowConfidence"
        }

        logProductSharpnessSummary(metrics, autoFocusResult: autoFocusResult)
    }

    private func applyProductAutoWhiteBalance(temperature: Float) {
        let requestedTemperature = clampedWhiteBalanceTemperature(temperature)
        let quantizedTemperature = (requestedTemperature / Self.whiteBalanceDialStep).rounded() * Self.whiteBalanceDialStep

        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard let device = self.currentVideoInput?.device else { return }
            do {
                try device.lockForConfiguration()
                guard device.isLockingWhiteBalanceWithCustomDeviceGainsSupported else {
                    device.unlockForConfiguration()
                    DispatchQueue.main.async {
                        self.productAutoWhiteBalanceStatusText = "商品 WB 不可用"
                    }
                    return
                }
                let tempTint = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(
                    temperature: quantizedTemperature,
                    tint: 0
                )
                let rawGains = device.deviceWhiteBalanceGains(for: tempTint)
                let safeGains = self.normalizedWhiteBalanceGains(rawGains, for: device)
                device.setWhiteBalanceModeLocked(with: safeGains)
                device.unlockForConfiguration()

                DispatchQueue.main.async {
                    self.currentWhiteBalanceTemperature = quantizedTemperature
                    self.currentWhiteBalanceTint = 0
                    self.selectedWhiteBalancePreset = .auto
                    self.productAutoWhiteBalanceAppliedTemperature = quantizedTemperature
                    self.productAutoWhiteBalanceStatusText = "商品 WB \(Int(quantizedTemperature.rounded()))K"
                }
            } catch {
                DispatchQueue.main.async {
                    self.productAutoWhiteBalanceStatusText = "商品 WB 写入失败"
                }
            }
        }
    }

    private func logProductAutoExposureSummary(
        _ metrics: ProductAutoExposureMetrics,
        availability: (canWrite: Bool, statusText: String),
        recommendation: ProductAutoExposureRecommendation?,
        skippedReason: String?
    ) {
#if DEBUG
        let now = Date()
        guard now.timeIntervalSince(lastProductAutoExposureDebugLogAt) >= productAutoExposureDebugLogInterval else {
            return
        }
        lastProductAutoExposureDebugLogAt = now

        let targetText = recommendation.map { String(format: "%+.2f", $0.targetBias) } ?? "nil"
        let nextText = recommendation.map { String(format: "%+.2f", $0.nextBias) } ?? "nil"
        let reasonText = recommendation?.reason ?? skippedReason ?? availability.statusText
        let optimizerStateText = recommendation
            .map { "decision=\($0.reason) stableBrightCount=\($0.stableBrightCount)" }
            ?? productAutoExposureOptimizer.debugStateSummary
        print(
            "[ProductAutoExposure] metrics " +
            "mean=\(String(format: "%.3f", metrics.meanLuma)) " +
            "highlight=\(String(format: "%.3f", metrics.highlightRatio)) " +
            "clipped=\(String(format: "%.3f", metrics.clippedRatio)) " +
            "shadow=\(String(format: "%.3f", metrics.shadowRatio)) " +
            "nearWhite=\(String(format: "%.3f", metrics.nearWhiteRatio)) " +
            "nearWhiteLuma=\(String(format: "%.3f", metrics.nearWhiteMeanLuma)) " +
            "target=\(targetText) " +
            "next=\(nextText) " +
            "applied=\(String(format: "%+.2f", currentExposureBias)) " +
            "reason=\(reasonText) " +
            "\(optimizerStateText) " +
            "status=\(availability.statusText)"
        )
#endif
    }

    private func logProductAutoWhiteBalanceSummary(
        _ metrics: ProductAutoWhiteBalanceMetrics,
        availability: (canWrite: Bool, statusText: String),
        recommendation: ProductAutoWhiteBalanceRecommendation?,
        skippedReason: String?
    ) {
#if DEBUG
        let now = Date()
        guard now.timeIntervalSince(lastProductAutoWhiteBalanceDebugLogAt) >= productAutoWhiteBalanceDebugLogInterval else {
            return
        }
        lastProductAutoWhiteBalanceDebugLogAt = now

        let targetText = recommendation.map { "\(Int($0.targetTemperature.rounded()))K" } ?? "nil"
        let nextText = recommendation.map { "\(Int($0.nextTemperature.rounded()))K" } ?? "nil"
        let reasonText = recommendation?.reason ?? skippedReason ?? availability.statusText
        let optimizerStateText = recommendation
            .map { "decision=\($0.reason) stableHitCount=\($0.stableHitCount)" }
            ?? productAutoWhiteBalanceOptimizer.debugStateSummary
        print(
            "[ProductAutoWB] " +
            "whiteCount=\(metrics.nearWhiteSampleCount) " +
            "whiteRatio=\(String(format: "%.3f", metrics.nearWhiteRatio)) " +
            "R=\(String(format: "%.3f", metrics.meanRed)) " +
            "G=\(String(format: "%.3f", metrics.meanGreen)) " +
            "B=\(String(format: "%.3f", metrics.meanBlue)) " +
            "Y=\(String(format: "%.3f", metrics.meanLuma)) " +
            "redBlue=\(String(format: "%+.3f", metrics.redBlueDelta)) " +
            "greenCast=\(String(format: "%+.3f", metrics.greenCast)) " +
            "confidence=\(String(format: "%.2f", metrics.confidence)) " +
            "target=\(targetText) " +
            "next=\(nextText) " +
            "current=\(Int(currentWhiteBalanceTemperature.rounded()))K " +
            "confidenceReason=\(productAutoWhiteBalanceConfidenceReason(for: metrics)) " +
            "reason=\(reasonText) " +
            "\(optimizerStateText) " +
            "status=\(availability.statusText)"
        )
#endif
    }

    private func productAutoWhiteBalanceConfidenceReason(for metrics: ProductAutoWhiteBalanceMetrics) -> String {
        if metrics.confidence < 0.30 { return "lowNearWhite" }
        if metrics.nearWhiteRatio < 0.08 { return "marginalNearWhite" }
        return "usableNearWhite"
    }

    private func logProductSharpnessSummary(
        _ metrics: ProductSharpnessMetrics,
        autoFocusResult: String
    ) {
#if DEBUG
        let now = Date()
        guard now.timeIntervalSince(lastProductSharpnessDebugLogAt) >= productSharpnessDebugLogInterval else {
            return
        }
        lastProductSharpnessDebugLogAt = now

        let cooldownRemaining = max(0, productFocusAssistCooldown - now.timeIntervalSince(lastProductFocusAssistAt))
        let blockedReason: String = {
            guard autoFocusResult.hasPrefix("skipped:") else { return "none" }
            return String(autoFocusResult.dropFirst("skipped:".count))
        }()
        print(
            "[ProductSharpness] " +
            "score=\(String(format: "%.2f", metrics.sharpnessScore)) " +
            "edge=\(String(format: "%.3f", metrics.edgeDensity)) " +
            "conf=\(String(format: "%.2f", metrics.confidence)) " +
            "state=\(metrics.state.rawValue) " +
            "reason=\(metrics.reason) " +
            "blurHit=\(productSharpnessBlurryHitCount) " +
            "sharpHit=\(productSharpnessSharpHitCount) " +
            "autoAF=\(autoFocusResult) " +
            "blocked=\(blockedReason) " +
            "cooldown=\(String(format: "%.1f", cooldownRemaining))"
        )
#endif
    }

    private func logProductAutoSceneSummary(_ analysis: ProductPreviewFrameAnalysis) {
#if DEBUG
        let now = Date()
        guard now.timeIntervalSince(lastProductAutoSceneDebugLogAt) >= productAutoSceneDebugLogInterval else {
            return
        }
        lastProductAutoSceneDebugLogAt = now

        let ev = analysis.exposureMetrics
        let wb = analysis.whiteBalanceMetrics
        let focus = analysis.sharpnessMetrics
        let frame = analysis.frameDiagnostics
        let evSummary = [
            productAutoExposureOptimizer.debugStateSummary,
            "applied=\(String(format: "%+.2f", currentExposureBias))",
            "mean=\(String(format: "%.3f", ev.meanLuma))",
            "shadow=\(String(format: "%.3f", ev.shadowRatio))",
            "hi=\(String(format: "%.3f", ev.highlightRatio))",
            "clip=\(String(format: "%.3f", ev.clippedRatio))",
            "white=\(String(format: "%.3f", ev.nearWhiteRatio))",
            "whiteY=\(String(format: "%.3f", ev.nearWhiteMeanLuma))"
        ].joined(separator: " ")
        let wbSummary = [
            productAutoWhiteBalanceOptimizer.debugStateSummary,
            "current=\(Int(currentWhiteBalanceTemperature.rounded()))K",
            "whiteRatio=\(String(format: "%.3f", wb.nearWhiteRatio))",
            "whiteCount=\(wb.nearWhiteSampleCount)",
            "rb=\(String(format: "%+.3f", wb.redBlueDelta))",
            "green=\(String(format: "%+.3f", wb.greenCast))",
            "conf=\(String(format: "%.2f", wb.confidence))",
            "confReason=\(productAutoWhiteBalanceConfidenceReason(for: wb))"
        ].joined(separator: " ")
        let focusSummary = [
            "state=\(focus.state.rawValue)",
            "score=\(String(format: "%.2f", focus.sharpnessScore))",
            "edge=\(String(format: "%.3f", focus.edgeDensity))",
            "conf=\(String(format: "%.2f", focus.confidence))",
            "reason=\(focus.reason)"
        ].joined(separator: " ")
        let sceneSummary = [
            "[ProductAutoScene]",
            "sceneId=unlabeled",
            "t=\(String(format: "%.1f", now.timeIntervalSince1970))",
            "EV(\(evSummary))",
            "WB(\(wbSummary))",
            "Focus(\(focusSummary))"
        ].joined(separator: " ")
        print(sceneSummary)
        print(
            "[ProductAutoSceneFrame] " +
            "format=\(frame.pixelFormatName) " +
            "rawFormat=\(frame.pixelFormat) " +
            "width=\(frame.width) " +
            "height=\(frame.height) " +
            "planes=\(frame.planeCount) " +
            "bytesPerRow=\(frame.bytesPerRow) " +
            "timestamp=\(String(format: "%.3f", frame.timestampSeconds)) " +
            "age=\(String(format: "%.3f", frame.frameAgeSeconds))"
        )
        print(
            "[ProductAutoSceneROI] " +
            "normalized=x:\(String(format: "%.2f", frame.normalizedROI.minX))," +
            "y:\(String(format: "%.2f", frame.normalizedROI.minY))," +
            "w:\(String(format: "%.2f", frame.normalizedROI.width))," +
            "h:\(String(format: "%.2f", frame.normalizedROI.height)) " +
            "pixel=x:\(Int(frame.pixelROI.minX))," +
            "y:\(Int(frame.pixelROI.minY))," +
            "w:\(Int(frame.pixelROI.width))," +
            "h:\(Int(frame.pixelROI.height)) " +
            "valid=\(frame.validPixelCount) " +
            "skipped=\(frame.skippedPixelCount) " +
            "sampled=\(frame.sampledPixelCount)"
        )
#endif
    }

    private func logProductAutoSceneFrameGuard(_ skip: ProductAutoSceneFrameSkip) {
#if DEBUG
        let now = Date()
        guard now.timeIntervalSince(lastProductAutoSceneFrameGuardLogAt) >= productAutoSceneDebugLogInterval else {
            return
        }
        lastProductAutoSceneFrameGuardLogAt = now

        print(
            "[ProductAutoSceneFrameGuard] " +
            "skipped reason=\(skip.reason) " +
            "format=\(skip.pixelFormatName) " +
            "rawFormat=\(skip.pixelFormat) " +
            "width=\(skip.width) " +
            "height=\(skip.height) " +
            "planes=\(skip.planeCount) " +
            "bytesPerRow=\(skip.bytesPerRow) " +
            "timestamp=\(String(format: "%.3f", skip.timestampSeconds)) " +
            "age=\(String(format: "%.3f", skip.frameAgeSeconds))"
        )
#endif
    }

    private func logCaptureOptionSelection(
        scope: String,
        source: String,
        requestedIndex: Int,
        selectedIndex: Int,
        selectedValue: String,
        runtimeAppliedValue: String,
        fallbackReason: String?,
        generation: UInt64,
        changed: Bool
    ) {
#if DEBUG
        print(
            "[CaptureOptionControl] " +
            "scope=\(scope) " +
            "source=\(source) " +
            "requestedIndex=\(requestedIndex) " +
            "selectedIndex=\(selectedIndex) " +
            "selectedValue=\(selectedValue) " +
            "runtimeAppliedValue=\(runtimeAppliedValue) " +
            "fallbackReason=\(fallbackReason ?? "none") " +
            "generation=\(generation) " +
            "changed=\(changed)"
        )
#endif
    }

    private func productFocusAssistAvailability(now: Date) -> (canTrigger: Bool, reason: String) {
        guard !isProductFocusAssistSuppressedByManualFocusUI, focusControlMode != .manual else {
            return (false, "manualFocus")
        }
        guard !isFocusExposureLocked else { return (false, "AEAF-L") }
        guard !isExposureLocked else { return (false, "AE-L") }
        guard !isPreviewInteractionTemporarilyRestricted else { return (false, "restricted") }
        guard !isSwitchingCamera else { return (false, "switchingCamera") }
        guard now.timeIntervalSince(lastUserFocusInteractionAt) >= productFocusAssistManualCooldown else {
            return (false, "recentUserFocus")
        }
        guard now.timeIntervalSince(lastManualFocusInteractionAt) >= productFocusAssistManualCooldown else {
            return (false, "recentManualFocus")
        }
        guard now.timeIntervalSince(lastProductFocusAssistAt) >= productFocusAssistCooldown else {
            return (false, "cooldown")
        }
        guard let device = currentVideoInput?.device else { return (false, "noDevice") }
        let supportsFocusMode = device.isFocusModeSupported(.autoFocus)
            || device.isFocusModeSupported(.continuousAutoFocus)
        guard supportsFocusMode else { return (false, "unsupportedFocusMode") }
        return (true, "ready")
    }

    private func productAutoExposureAvailability() -> (canWrite: Bool, statusText: String) {
        guard isExposureBiasSupported else { return (false, "商品 Auto 不可用") }
        guard isExposureBiasAutoMode else { return (false, "商品 Auto 暂停 · 手动EV") }
        guard !isManualExposurePresetActive else { return (false, "商品 Auto 暂停 · 手动曝光") }
        guard !isFocusExposureLocked else { return (false, "商品 Auto 暂停 · AEAF-L") }
        guard !isExposureLocked else { return (false, "商品 Auto 暂停 · AE-L") }
        guard !isPreviewInteractionTemporarilyRestricted else { return (false, "商品 Auto 暂停 · 拍摄中") }
        guard !isSwitchingCamera else { return (false, "商品 Auto 暂停 · 切镜头") }
        return (true, "商品 Auto")
    }

    private func productAutoWhiteBalanceAvailability() -> (canWrite: Bool, statusText: String) {
        guard isWhiteBalanceAutoSupported else { return (false, "商品 WB 不可用 · 系统Auto") }
        guard isWhiteBalancePresetSupported else { return (false, "商品 WB 不可用 · 设备Gains") }
        guard selectedWhiteBalancePreset == .auto else { return (false, "商品 WB 暂停 · 手动WB") }
        guard !isFocusExposureLocked else { return (false, "商品 WB 暂停 · AEAF-L") }
        guard !isExposureLocked else { return (false, "商品 WB 暂停 · AE-L") }
        guard !isPreviewInteractionTemporarilyRestricted else { return (false, "商品 WB 暂停 · 拍摄中") }
        guard !isSwitchingCamera else { return (false, "商品 WB 暂停 · 切镜头") }
        return (true, "商品 WB")
    }

    private enum FocusExposureInteractionSource {
        case tap
        case longPress
        case unlockByLongPress
        case productAutoFocus
    }

    private func applyFocusExposure(
        devicePoint: CGPoint,
        normalizedPoint: CGPoint,
        lockAfterFocus: Bool,
        source: FocusExposureInteractionSource
    ) {
        let exposureLockSnapshot = isExposureLocked
        let shutterPresetSnapshot = selectedShutterPreset
        let isoPresetSnapshot = selectedISOPreset
        let manualShutterSecondsSnapshot = currentManualShutterDurationSeconds
        let manualISOSnapshot = currentManualISOValue

        let isShutterAutoSnapshot: Bool = {
            if case .auto = shutterPresetSnapshot {
                return true
            }
            return false
        }()

        let isISOAutoSnapshot: Bool = {
            if case .auto = isoPresetSnapshot {
                return true
            }
            return false
        }()

        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard let device = self.currentVideoInput?.device else { return }
            do {
                try device.lockForConfiguration()
                var didApplyAny = false
                var didLockAny = false

                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = devicePoint
                }
                if device.isSmoothAutoFocusSupported {
                    device.isSmoothAutoFocusEnabled = false
                }
                if lockAfterFocus {
                    if device.isFocusModeSupported(.locked) {
                        device.focusMode = .locked
                        didApplyAny = true
                        didLockAny = true
                    } else if device.isFocusModeSupported(.autoFocus) {
                        device.focusMode = .autoFocus
                        didApplyAny = true
                    }
                } else if device.isFocusModeSupported(.autoFocus) {
                    device.focusMode = .autoFocus
                    didApplyAny = true
                } else if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                    didApplyAny = true
                }

                let shouldPreserveExposureLock = exposureLockSnapshot && !lockAfterFocus
                let shouldPreserveFullManualExposure = !isShutterAutoSnapshot
                    && !isISOAutoSnapshot
                    && !lockAfterFocus
                    && !shouldPreserveExposureLock
                let shouldPreserveManualShutter = !isShutterAutoSnapshot
                    && !lockAfterFocus
                    && !shouldPreserveExposureLock
                    && !shouldPreserveFullManualExposure
                    && isISOAutoSnapshot
                let shouldPreserveManualISO = !isISOAutoSnapshot
                    && !lockAfterFocus
                    && !shouldPreserveExposureLock
                    && !shouldPreserveFullManualExposure
                    && !shouldPreserveManualShutter
                if device.isExposurePointOfInterestSupported, !shouldPreserveExposureLock {
                    device.exposurePointOfInterest = devicePoint
                }
                if lockAfterFocus {
                    if device.isExposureModeSupported(.locked) {
                        device.exposureMode = .locked
                        didApplyAny = true
                        didLockAny = true
                    } else if device.isExposureModeSupported(.continuousAutoExposure) {
                        device.exposureMode = .continuousAutoExposure
                        didApplyAny = true
                    }
                } else if shouldPreserveExposureLock, device.isExposureModeSupported(.locked) {
                    device.exposureMode = .locked
                    didApplyAny = true
                } else if shouldPreserveFullManualExposure, device.isExposureModeSupported(.custom) {
                    let targetDuration: CMTime
                    if let presetDuration = shutterPresetSnapshot.durationSeconds {
                        targetDuration = self.clampedShutterDuration(
                            CMTime(seconds: presetDuration, preferredTimescale: 1_000_000_000),
                            device: device
                        )
                    } else {
                        targetDuration = self.clampedShutterDuration(
                            CMTime(seconds: manualShutterSecondsSnapshot, preferredTimescale: 1_000_000_000),
                            device: device
                        )
                    }
                    guard let exposureWrite = self.sanitizedCustomExposureWrite(
                        rawDuration: targetDuration,
                        rawISO: manualISOSnapshot,
                        device: device,
                        context: "tapFocusPreserveFullManualExposure"
                    ) else {
                        device.unlockForConfiguration()
                        DispatchQueue.main.async {
                            self.captureHintText = "当前摄像头曝光能力异常，已跳过手动曝光保持"
                        }
                        return
                    }
                    device.setExposureModeCustom(duration: exposureWrite.duration, iso: exposureWrite.iso)
                    didApplyAny = true
                } else if shouldPreserveManualShutter, device.isExposureModeSupported(.custom) {
                    let targetDuration: CMTime
                    if let presetDuration = shutterPresetSnapshot.durationSeconds {
                        targetDuration = self.clampedShutterDuration(
                            CMTime(seconds: presetDuration, preferredTimescale: 1_000_000_000),
                            device: device
                        )
                    } else {
                        targetDuration = self.clampedShutterDuration(
                            CMTime(seconds: manualShutterSecondsSnapshot, preferredTimescale: 1_000_000_000),
                            device: device
                        )
                    }
                    let isoForWrite = device.iso
                    guard let exposureWrite = self.sanitizedCustomExposureWrite(
                        rawDuration: targetDuration,
                        rawISO: isoForWrite,
                        device: device,
                        context: "tapFocusPreserveShutter"
                    ) else {
                        device.unlockForConfiguration()
                        DispatchQueue.main.async {
                            self.captureHintText = "当前摄像头曝光能力异常，已跳过手动曝光保持"
                        }
                        return
                    }
                    device.setExposureModeCustom(duration: exposureWrite.duration, iso: exposureWrite.iso)
                    didApplyAny = true
                } else if shouldPreserveManualISO, device.isExposureModeSupported(.custom) {
                    let currentISO = device.iso
                    guard let exposureWrite = self.sanitizedCustomExposureWrite(
                        rawDuration: AVCaptureDevice.currentExposureDuration,
                        rawISO: currentISO,
                        device: device,
                        context: "tapFocusPreserveISO"
                    ) else {
                        device.unlockForConfiguration()
                        DispatchQueue.main.async {
                            self.captureHintText = "当前摄像头曝光能力异常，已跳过手动 ISO 保持"
                        }
                        return
                    }
                    device.setExposureModeCustom(duration: exposureWrite.duration, iso: exposureWrite.iso)
                    didApplyAny = true
                } else if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                    didApplyAny = true
                }

                let updatedBias = device.exposureTargetBias
                let updatedISO = device.iso
                let updatedShutterSeconds = CMTimeGetSeconds(device.exposureDuration)
                let updatedLensPosition = device.lensPosition
                let updatedFocusMode = device.focusMode
                let isAdjustingFocus = device.isAdjustingFocus
#if DEBUG
                let sourceText: String
                switch source {
                case .tap:
                    sourceText = "tap"
                case .longPress:
                    sourceText = "longPress"
                case .unlockByLongPress:
                    sourceText = "unlockByLongPress"
                case .productAutoFocus:
                    sourceText = "productAutoFocus"
                }
                print(
                    "[CaptureTapFocus] " +
                    "source=\(sourceText) " +
                    "devicePoint=(\(String(format: "%.3f", devicePoint.x)),\(String(format: "%.3f", devicePoint.y))) " +
                    "normalized=(\(String(format: "%.3f", normalizedPoint.x)),\(String(format: "%.3f", normalizedPoint.y))) " +
                    "focusMode=\(updatedFocusMode.rawValue) " +
                    "isAdjustingFocus=\(isAdjustingFocus) " +
                    "lens=\(String(format: "%.3f", Double(updatedLensPosition))) " +
                    "iso=\(String(format: "%.1f", Double(updatedISO))) " +
                    "shutter=\(String(format: "%.6f", updatedShutterSeconds)) " +
                    "aeLocked=\(exposureLockSnapshot) " +
                    "isoMode=\(isISOAutoSnapshot ? "auto" : "manual") " +
                    "shutterMode=\(isShutterAutoSnapshot ? "auto" : "manual")"
                )
#endif

                device.unlockForConfiguration()

                DispatchQueue.main.async {
                    guard didApplyAny else {
                        self.captureHintText = lockAfterFocus
                            ? "当前设备不支持 AE/AF 锁定"
                            : "当前设备不支持该点对焦/测光"
                        self.isFocusExposureLocked = false
                        self.focusMarker = nil
                        return
                    }

                    if lockAfterFocus {
                        if didLockAny {
                            self.isFocusExposureLocked = true
                            self.isExposureLocked = true
                            self.focusControlMode = .auto
                            let quantized = self.quantizedManualFocusPosition(updatedLensPosition)
                            self.currentManualFocusPosition = quantized
                            self.lastAppliedManualFocusPosition = quantized
                            self.currentISOValue = updatedISO
                            self.currentShutterDurationSeconds = updatedShutterSeconds.isFinite ? updatedShutterSeconds : 0
                            self.selectedISOPreset = .auto
                            self.selectedShutterPreset = .auto
                            self.focusMarker = CaptureFocusMarker(normalizedPoint: normalizedPoint, mode: .locked)
                            self.captureHintText = "AE/AF 已锁定，长按可解锁"
                        } else {
                            self.isFocusExposureLocked = false
                            self.isExposureLocked = false
                            self.focusControlMode = .auto
                            let quantized = self.quantizedManualFocusPosition(updatedLensPosition)
                            self.currentManualFocusPosition = quantized
                            self.lastAppliedManualFocusPosition = quantized
                            self.currentISOValue = updatedISO
                            self.currentShutterDurationSeconds = updatedShutterSeconds.isFinite ? updatedShutterSeconds : 0
                            self.selectedISOPreset = .auto
                            self.selectedShutterPreset = .auto
                            self.focusMarker = CaptureFocusMarker(normalizedPoint: normalizedPoint, mode: .warning)
                            self.captureHintText = "当前设备不支持 AE/AF 锁定"
                        }
                    } else {
                        self.isFocusExposureLocked = false
                        self.focusControlMode = .auto
                        let quantized = self.quantizedManualFocusPosition(updatedLensPosition)
                        self.currentManualFocusPosition = quantized
                        self.lastAppliedManualFocusPosition = quantized
                        self.currentExposureBias = updatedBias
                        self.currentISOValue = updatedISO
                        self.currentShutterDurationSeconds = updatedShutterSeconds.isFinite ? updatedShutterSeconds : 0
                        if !shouldPreserveManualISO && !shouldPreserveFullManualExposure {
                            self.selectedISOPreset = .auto
                        }
                        if !shouldPreserveManualShutter && !shouldPreserveFullManualExposure {
                            self.selectedShutterPreset = .auto
                        }
                        let feedbackMode: CaptureFocusMarker.Mode
                        switch source {
                        case .tap:
                            feedbackMode = .focusing
                            self.captureHintText = self.isExposureLocked
                                ? "对焦中 · AE-L"
                                : "对焦中"
                        case .unlockByLongPress:
                            feedbackMode = .unlocked
                            self.captureHintText = "已解除锁定并重新对焦测光"
                        case .longPress:
                            feedbackMode = .focused
                            self.captureHintText = "已设置对焦与测光点"
                        case .productAutoFocus:
                            feedbackMode = .focusing
                            self.captureHintText = "对焦中"
                        }
                        self.focusMarker = CaptureFocusMarker(normalizedPoint: normalizedPoint, mode: feedbackMode)
                    }
                    if source == .tap || source == .productAutoFocus {
                        self.scheduleFocusFeedback(for: normalizedPoint, source: source)
                    } else {
                        self.hideFocusMarkerLaterIfNeeded()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.captureHintText = lockAfterFocus
                        ? "AE/AF 锁定失败"
                        : "当前设备不支持该点对焦/测光"
                    self.isFocusExposureLocked = false
                    self.focusMarker = nil
                }
            }
        }
    }

    private func hideFocusMarkerLaterIfNeeded() {
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(900))
            await MainActor.run {
                guard let self else { return }
                if !self.isFocusExposureLocked {
                    self.focusMarker = nil
                }
            }
        }
    }

    private func scheduleFocusFeedback(
        for normalizedPoint: CGPoint,
        source: FocusExposureInteractionSource
    ) {
        focusFeedbackTask?.cancel()
        let expectedMarkerID = focusMarker?.id
        focusFeedbackTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(self.tapFocusSettleDelay))
            if Task.isCancelled { return }

            let isStillAdjustingAfterSettle = await self.isCurrentDeviceAdjustingFocus()
            await MainActor.run {
                guard self.focusMarker?.id == expectedMarkerID else { return }
                if !isStillAdjustingAfterSettle {
                    self.focusMarker = CaptureFocusMarker(normalizedPoint: normalizedPoint, mode: .focused)
                    self.captureHintText = source == .productAutoFocus ? "AF 稳定" : "AF 稳定"
                    if source == .tap {
                        self.restoreContinuousAutoFocusAfterTapIfPossible()
                    }
                }
            }

            let remainingDelay = max(0, self.tapFocusTimeout - self.tapFocusSettleDelay)
            try? await Task.sleep(for: .seconds(remainingDelay))
            if Task.isCancelled { return }

            let isStillAdjustingAtTimeout = await self.isCurrentDeviceAdjustingFocus()
            await MainActor.run {
                guard self.focusMarker?.id == expectedMarkerID else { return }
                if isStillAdjustingAtTimeout {
                    self.focusMarker = CaptureFocusMarker(normalizedPoint: normalizedPoint, mode: .warning)
                    self.captureHintText = "对焦偏慢"
                    if source == .tap {
                        self.triggerCloseFocusFallbackIfNeeded(normalizedPoint: normalizedPoint)
                    }
#if DEBUG
                    print(
                        "[CaptureTapFocus] timeout=true " +
                        "normalized=(\(String(format: "%.3f", normalizedPoint.x)),\(String(format: "%.3f", normalizedPoint.y))) " +
                        "timeout=\(String(format: "%.2f", self.tapFocusTimeout))"
                    )
#endif
                } else {
                    self.focusMarker = CaptureFocusMarker(normalizedPoint: normalizedPoint, mode: .focused)
                    if source == .productAutoFocus {
                        self.captureHintText = "AF 稳定"
                    }
                    if source == .tap {
                        self.restoreContinuousAutoFocusAfterTapIfPossible()
                    }
                }
                self.hideFocusMarkerLaterIfNeeded()
            }
        }
    }

    private func restoreContinuousAutoFocusAfterTapIfPossible() {
        guard !isFocusExposureLocked, focusControlMode != .manual else { return }
        sessionQueue.async { [weak self] in
            guard let self, let device = self.currentVideoInput?.device else { return }
            guard device.isFocusModeSupported(.continuousAutoFocus) else { return }
            do {
                try device.lockForConfiguration()
                if device.focusMode != .continuousAutoFocus {
                    device.focusMode = .continuousAutoFocus
                }
                if device.isSmoothAutoFocusSupported {
                    device.isSmoothAutoFocusEnabled = true
                }
#if DEBUG
                print(
                    "[CaptureTapFocus] restoreContinuousAutoFocus=true " +
                    "lens=\(String(format: "%.3f", Double(device.lensPosition))) " +
                    "isAdjustingFocus=\(device.isAdjustingFocus)"
                )
#endif
                device.unlockForConfiguration()
            } catch {
#if DEBUG
                print("[CaptureTapFocus] restoreContinuousAutoFocus=false error=\(error.localizedDescription)")
#endif
            }
        }
    }

    private func triggerCloseFocusFallbackIfNeeded(normalizedPoint: CGPoint) {
        let now = Date()
        guard activeCameraPosition == .back else { return }
        guard focusControlMode != .manual else { return }
        guard !isFocusExposureLocked, !isExposureLocked else { return }
        guard !isPreviewInteractionTemporarilyRestricted, !isSwitchingCamera else { return }
        guard selectedSemanticFocal != .mm77 else { return }
        guard now.timeIntervalSince(lastCloseFocusFallbackAt) >= Self.closeFocusFallbackCooldown else { return }
        guard let device = currentVideoInput?.device else { return }
        let canUseVirtualOrUltraWide = Self.isVirtualBackCameraDeviceType(device.deviceType)
            || discoverCameras(position: .back).contains(where: { $0.deviceType == .builtInUltraWideCamera })
        guard canUseVirtualOrUltraWide else { return }

        lastCloseFocusFallbackAt = now
        let stableZoom = closeFocusFallbackZoomTarget(for: device)
#if DEBUG
        print(
            "[CaptureLensMacroFallback] " +
            "trigger=focusTimeout " +
            "device=\(device.localizedName) " +
            "type=\(device.deviceType.rawValue) " +
            "currentZoom=\(String(format: "%.2f", currentZoomFactor)) " +
            "targetZoom=\(String(format: "%.2f", stableZoom)) " +
            "iso=\(String(format: "%.1f", Double(currentISOValue))) " +
            "shutter=\(String(format: "%.5f", currentShutterDurationSeconds))"
        )
#endif
        captureHintText = "近距辅助对焦"
        setZoomFactor(stableZoom, ramped: true, reason: "closeFocusFallback")
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.closeFocusFallbackDelay) { [weak self] in
            guard let self else { return }
            guard self.focusControlMode != .manual else { return }
            guard !self.isFocusExposureLocked, !self.isExposureLocked else { return }
            guard !self.isPreviewInteractionTemporarilyRestricted, !self.isSwitchingCamera else { return }
            self.applyFocusExposure(
                devicePoint: normalizedPoint,
                normalizedPoint: normalizedPoint,
                lockAfterFocus: false,
                source: .tap
            )
        }
    }

    private func closeFocusFallbackZoomTarget(for device: AVCaptureDevice) -> CGFloat {
        let minZoom = max(1.0, device.minAvailableVideoZoomFactor)
        let maxZoom = max(minZoom, min(device.maxAvailableVideoZoomFactor, activeDeviceMaximumZoomFactor))
        // Virtual multi-camera devices can choose their best constituent lens around the stable wide range.
        return max(minZoom, min(maxZoom, 1.0))
    }

    private func isCurrentDeviceAdjustingFocus() async -> Bool {
        await withCheckedContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self, let device = self.currentVideoInput?.device else {
                    continuation.resume(returning: false)
                    return
                }
                continuation.resume(returning: device.isAdjustingFocus)
            }
        }
    }

    private func isCurrentDeviceRampingZoom() async -> Bool {
        await withCheckedContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self, let device = self.currentVideoInput?.device else {
                    continuation.resume(returning: false)
                    return
                }
                continuation.resume(returning: device.isRampingVideoZoom)
            }
        }
    }

    private var isPreviewInteractionTemporarilyRestricted: Bool {
        isSwitchingCamera || countdownSecondsRemaining != nil || isBurstCapturing || quickPreviewImage != nil
    }

    private var isManualExposurePresetActive: Bool {
        selectedISOPreset != .auto || selectedShutterPreset != .auto
    }

    private var manualExposureEVLockHintText: String {
        if selectedISOPreset != .auto {
            return "手动 ISO 生效中，先恢复 ISO Auto 后再调 EV"
        }
        if selectedShutterPreset != .auto {
            return "手动快门生效中，先恢复快门 Auto 后再调 EV"
        }
        return "手动曝光生效中，先恢复 ISO / 快门 Auto 后再调 EV"
    }

    private var previewInteractionRestrictedHintText: String {
        if isSwitchingCamera {
            return "切换摄像头中，请稍候"
        }
        if countdownSecondsRemaining != nil {
            return "倒计时中，暂不调整对焦测光"
        }
        if isBurstCapturing {
            return "连拍中，暂不调整对焦测光"
        }
        if quickPreviewImage != nil {
            return "快速预览中，请稍后再调焦"
        }
        return "当前状态不可操作"
    }
}

private struct ProductPreviewFrameAnalysis {
    let exposureMetrics: ProductAutoExposureMetrics
    let whiteBalanceMetrics: ProductAutoWhiteBalanceMetrics
    let sharpnessMetrics: ProductSharpnessMetrics
    let frameDiagnostics: ProductAutoSceneFrameDiagnostics
}

private struct ProductAutoSceneFrameDiagnostics {
    let pixelFormat: OSType
    let pixelFormatName: String
    let width: Int
    let height: Int
    let planeCount: Int
    let bytesPerRow: Int
    let timestampSeconds: Double
    let frameAgeSeconds: Double
    let normalizedROI: CGRect
    let pixelROI: CGRect
    let validPixelCount: Int
    let skippedPixelCount: Int
    let sampledPixelCount: Int
}

private struct ProductAutoSceneFrameSkip {
    let reason: String
    let pixelFormat: OSType
    let pixelFormatName: String
    let width: Int
    let height: Int
    let planeCount: Int
    let bytesPerRow: Int
    let timestampSeconds: Double
    let frameAgeSeconds: Double
}

extension CaptureCameraRuntime: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = CACurrentMediaTime()
        guard now - lastProductAutoExposureAnalysisAt >= productAutoExposureAnalysisInterval else { return }
        lastProductAutoExposureAnalysisAt = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            let skip = Self.productAutoSceneFrameSkip(
                reason: "missingPixelBuffer",
                pixelBuffer: nil,
                timestamp: timestamp,
                now: now
            )
            DispatchQueue.main.async { [weak self] in
                self?.logProductAutoSceneFrameGuard(skip)
            }
            return
        }

        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if let skipReason = productAutoSceneFrameSkipReason(
            pixelBuffer: pixelBuffer,
            timestamp: timestamp,
            now: now
        ) {
            let skip = Self.productAutoSceneFrameSkip(
                reason: skipReason,
                pixelBuffer: pixelBuffer,
                timestamp: timestamp,
                now: now
            )
            DispatchQueue.main.async { [weak self] in
                self?.logProductAutoSceneFrameGuard(skip)
            }
            return
        }

        let frameTiming = Self.productAutoSceneFrameTiming(timestamp: timestamp, now: now)
        guard let analysis = Self.productPreviewFrameAnalysis(
            from: pixelBuffer,
            timestampSeconds: frameTiming.timestampSeconds,
            frameAgeSeconds: frameTiming.frameAgeSeconds
        ) else {
            let skip = Self.productAutoSceneFrameSkip(
                reason: "invalidROIOrSamples",
                pixelBuffer: pixelBuffer,
                timestamp: timestamp,
                now: now
            )
            DispatchQueue.main.async { [weak self] in
                self?.logProductAutoSceneFrameGuard(skip)
            }
            return
        }

        if Self.isProductAutoSceneNearBlackProbeFrame(analysis) {
            productAutoSceneNearBlackFrameStreak += 1
            if productAutoSceneNearBlackFrameStreak <= Self.productAutoSceneNearBlackProbeLimit {
                let skip = Self.productAutoSceneFrameSkip(
                    reason: "nearBlackProbe",
                    pixelBuffer: pixelBuffer,
                    timestamp: timestamp,
                    now: now
                )
                DispatchQueue.main.async { [weak self] in
                    self?.logProductAutoSceneFrameGuard(skip)
                }
                return
            }
        } else {
            productAutoSceneNearBlackFrameStreak = 0
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.handleProductAutoExposureMetrics(analysis.exposureMetrics)
            self.handleProductAutoWhiteBalanceMetrics(analysis.whiteBalanceMetrics)
            self.handleProductSharpnessMetrics(analysis.sharpnessMetrics)
            self.logProductAutoSceneSummary(analysis)
        }
    }

    private func productAutoSceneFrameSkipReason(
        pixelBuffer: CVPixelBuffer,
        timestamp: CMTime,
        now: CFTimeInterval
    ) -> String? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        guard width > 0, height > 0 else { return "invalidFrameSize" }

        guard timestamp.isValid, timestamp.seconds.isFinite else {
            return "invalidTimestamp"
        }

        let timing = Self.productAutoSceneFrameTiming(timestamp: timestamp, now: now)
        if timing.frameAgeSeconds > 2.0 {
            return "staleFrame"
        }

        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        guard Self.isSupportedProductAutoScenePixelFormat(pixelFormat) else {
            return "unsupportedPixelFormat"
        }

        guard isSessionConfigured, session.isRunning else { return "sessionNotRunning" }
        if Date().timeIntervalSince(lastSessionStartAt) < Self.productAutoSceneSessionWarmupInterval {
            return "sessionWarmup"
        }
        if isSwitchingCamera { return "unstableLensState:switchingCamera" }
        if isCaptureStabilizerSettling { return "stabilizerSettle" }
        if Date().timeIntervalSince(lastLensRulerInteractionAt) < 0.45 {
            return "unstableLensState:recentZoom"
        }
        if Date().timeIntervalSince(lastCloseFocusFallbackAt) < 0.6 {
            return "unstableLensState:macroFallback"
        }
        if currentVideoInput?.device.isRampingVideoZoom == true {
            return "unstableLensState:zoomRamping"
        }

        return nil
    }

    private static func productPreviewFrameAnalysis(
        from pixelBuffer: CVPixelBuffer,
        timestampSeconds: Double,
        frameAgeSeconds: Double
    ) -> ProductPreviewFrameAnalysis? {
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        guard isSupportedProductAutoScenePixelFormat(pixelFormat) else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        guard width > 0, height > 0 else { return nil }

        let normalizedROI = CGRect(x: 0.20, y: 0.20, width: 0.60, height: 0.60)
        let roiMinX = max(0, min(width - 1, Int((CGFloat(width) * normalizedROI.minX).rounded(.down))))
        let roiMinY = max(0, min(height - 1, Int((CGFloat(height) * normalizedROI.minY).rounded(.down))))
        let roiMaxX = max(roiMinX + 1, min(width, Int((CGFloat(width) * normalizedROI.maxX).rounded(.up))))
        let roiMaxY = max(roiMinY + 1, min(height, Int((CGFloat(height) * normalizedROI.maxY).rounded(.up))))
        let roiWidth = roiMaxX - roiMinX
        let roiHeight = roiMaxY - roiMinY
        guard roiWidth >= 8, roiHeight >= 8 else { return nil }

        let lumaGridWidth = 36
        let lumaGridHeight = 36
        let totalGridSamples = lumaGridWidth * lumaGridHeight

        var sampleCount: Float = 0
        var skippedPixelCount = 0
        var lumaSum: Float = 0
        var highlightCount: Float = 0
        var clippedCount: Float = 0
        var shadowCount: Float = 0
        var nearWhiteCount: Float = 0
        var nearWhiteLumaSum: Float = 0
        var autoWBNearWhiteCount: Float = 0
        var autoWBNearWhiteLumaSum: Float = 0
        var nearWhiteRedSum: Float = 0
        var nearWhiteGreenSum: Float = 0
        var nearWhiteBlueSum: Float = 0
        var lumaGrid: [Float] = []
        lumaGrid.reserveCapacity(totalGridSamples)

        func clamp01(_ value: Float) -> Float {
            max(0, min(1, value))
        }

        func recordSample(red: Float, green: Float, blue: Float, luma: Float) {
            let safeRed = clamp01(red)
            let safeGreen = clamp01(green)
            let safeBlue = clamp01(blue)
            let safeLuma = clamp01(luma)
            let channelMax = max(safeRed, max(safeGreen, safeBlue))
            let channelMin = min(safeRed, min(safeGreen, safeBlue))
            let saturation = channelMax - channelMin

            lumaGrid.append(safeLuma)
            sampleCount += 1
            lumaSum += safeLuma
            if safeLuma > 0.92 { highlightCount += 1 }
            if safeLuma > 0.98 { clippedCount += 1 }
            if safeLuma < 0.20 { shadowCount += 1 }
            if safeLuma > 0.65, saturation < 0.16 {
                nearWhiteCount += 1
                nearWhiteLumaSum += safeLuma
            }

            let isWhiteBalanceCandidate = safeLuma > 0.50
                && safeLuma < 0.96
                && saturation < 0.22
                && channelMax < 0.97
            if isWhiteBalanceCandidate {
                autoWBNearWhiteCount += 1
                autoWBNearWhiteLumaSum += safeLuma
                nearWhiteRedSum += safeRed
                nearWhiteGreenSum += safeGreen
                nearWhiteBlueSum += safeBlue
            }
        }

        let bytesPerRow: Int
        switch pixelFormat {
        case kCVPixelFormatType_32BGRA:
            guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
            bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
            guard bytesPerRow > 0 else { return nil }
            let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)

            for gridY in 0..<lumaGridHeight {
                let normalizedY = lumaGridHeight == 1 ? 0 : Double(gridY) / Double(lumaGridHeight - 1)
                let y = min(roiMaxY - 1, roiMinY + Int((Double(roiHeight - 1) * normalizedY).rounded()))
                let row = buffer + y * bytesPerRow
                for gridX in 0..<lumaGridWidth {
                    let normalizedX = lumaGridWidth == 1 ? 0 : Double(gridX) / Double(lumaGridWidth - 1)
                    let x = min(roiMaxX - 1, roiMinX + Int((Double(roiWidth - 1) * normalizedX).rounded()))
                    let pixel = row + x * 4
                    guard pixel[3] > 0 else {
                        skippedPixelCount += 1
                        lumaGrid.append(0)
                        continue
                    }
                    let blue = Float(pixel[0]) / 255.0
                    let green = Float(pixel[1]) / 255.0
                    let red = Float(pixel[2]) / 255.0
                    let luma = 0.2126 * red + 0.7152 * green + 0.0722 * blue
                    recordSample(red: red, green: green, blue: blue, luma: luma)
                }
            }

        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
             kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
            let planeCount = CVPixelBufferGetPlaneCount(pixelBuffer)
            guard planeCount >= 2,
                  let yBaseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0),
                  let uvBaseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1) else {
                return nil
            }
            let yBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
            let uvBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1)
            let uvHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1)
            guard yBytesPerRow > 0, uvBytesPerRow >= 2, uvHeight > 0 else { return nil }
            bytesPerRow = yBytesPerRow
            let yBuffer = yBaseAddress.assumingMemoryBound(to: UInt8.self)
            let uvBuffer = uvBaseAddress.assumingMemoryBound(to: UInt8.self)
            let isVideoRange = pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange

            for gridY in 0..<lumaGridHeight {
                let normalizedY = lumaGridHeight == 1 ? 0 : Double(gridY) / Double(lumaGridHeight - 1)
                let y = min(roiMaxY - 1, roiMinY + Int((Double(roiHeight - 1) * normalizedY).rounded()))
                let yRow = yBuffer + y * yBytesPerRow
                let uvY = min(uvHeight - 1, max(0, y / 2))
                let uvRow = uvBuffer + uvY * uvBytesPerRow
                for gridX in 0..<lumaGridWidth {
                    let normalizedX = lumaGridWidth == 1 ? 0 : Double(gridX) / Double(lumaGridWidth - 1)
                    let x = min(roiMaxX - 1, roiMinX + Int((Double(roiWidth - 1) * normalizedX).rounded()))
                    let yByte = yRow[x]
                    let uvOffset = min(max(0, (x / 2) * 2), max(0, uvBytesPerRow - 2))
                    let cbByte = uvRow[uvOffset]
                    let crByte = uvRow[uvOffset + 1]

                    let yNorm: Float = isVideoRange
                        ? clamp01((Float(yByte) - 16.0) / 219.0)
                        : Float(yByte) / 255.0
                    let cb = (Float(cbByte) - 128.0) / 255.0
                    let cr = (Float(crByte) - 128.0) / 255.0
                    let red = yNorm + 1.402 * cr
                    let green = yNorm - 0.344136 * cb - 0.714136 * cr
                    let blue = yNorm + 1.772 * cb
                    recordSample(red: red, green: green, blue: blue, luma: yNorm)
                }
            }

        default:
            return nil
        }

        guard sampleCount >= 96, lumaGrid.count == totalGridSamples else { return nil }

        let exposureMetrics = ProductAutoExposureMetrics(
            meanLuma: lumaSum / sampleCount,
            highlightRatio: highlightCount / sampleCount,
            clippedRatio: clippedCount / sampleCount,
            shadowRatio: shadowCount / sampleCount,
            nearWhiteRatio: nearWhiteCount / sampleCount,
            nearWhiteMeanLuma: nearWhiteCount > 0 ? nearWhiteLumaSum / nearWhiteCount : 0
        )

        let whiteBalanceMetrics: ProductAutoWhiteBalanceMetrics
        if autoWBNearWhiteCount > 0 {
            let meanRed = nearWhiteRedSum / autoWBNearWhiteCount
            let meanGreen = nearWhiteGreenSum / autoWBNearWhiteCount
            let meanBlue = nearWhiteBlueSum / autoWBNearWhiteCount
            let meanLuma = autoWBNearWhiteLumaSum / autoWBNearWhiteCount
            let nearWhiteRatio = autoWBNearWhiteCount / sampleCount
            let confidence = min(1.0, nearWhiteRatio / 0.16)
            whiteBalanceMetrics = ProductAutoWhiteBalanceMetrics(
                nearWhiteSampleCount: Int(autoWBNearWhiteCount),
                nearWhiteRatio: nearWhiteRatio,
                meanRed: meanRed,
                meanGreen: meanGreen,
                meanBlue: meanBlue,
                meanLuma: meanLuma,
                redBlueDelta: meanRed - meanBlue,
                greenCast: meanGreen - ((meanRed + meanBlue) * 0.5),
                confidence: confidence
            )
        } else {
            whiteBalanceMetrics = ProductAutoWhiteBalanceMetrics(
                nearWhiteSampleCount: 0,
                nearWhiteRatio: 0,
                meanRed: 0,
                meanGreen: 0,
                meanBlue: 0,
                meanLuma: 0,
                redBlueDelta: 0,
                greenCast: 0,
                confidence: 0
            )
        }

        let sharpnessMetrics = ProductSharpnessAnalyzer.metrics(
            lumaGrid: lumaGrid,
            width: lumaGridWidth,
            height: lumaGridHeight,
            exposureMetrics: exposureMetrics
        )

        return ProductPreviewFrameAnalysis(
            exposureMetrics: exposureMetrics,
            whiteBalanceMetrics: whiteBalanceMetrics,
            sharpnessMetrics: sharpnessMetrics,
            frameDiagnostics: ProductAutoSceneFrameDiagnostics(
                pixelFormat: pixelFormat,
                pixelFormatName: productAutoScenePixelFormatName(pixelFormat),
                width: width,
                height: height,
                planeCount: CVPixelBufferGetPlaneCount(pixelBuffer),
                bytesPerRow: bytesPerRow,
                timestampSeconds: timestampSeconds,
                frameAgeSeconds: frameAgeSeconds,
                normalizedROI: normalizedROI,
                pixelROI: CGRect(x: roiMinX, y: roiMinY, width: roiWidth, height: roiHeight),
                validPixelCount: Int(sampleCount),
                skippedPixelCount: skippedPixelCount,
                sampledPixelCount: totalGridSamples
            )
        )
    }

    private static func productAutoSceneFrameSkip(
        reason: String,
        pixelBuffer: CVPixelBuffer?,
        timestamp: CMTime,
        now: CFTimeInterval
    ) -> ProductAutoSceneFrameSkip {
        let timing = productAutoSceneFrameTiming(timestamp: timestamp, now: now)
        guard let pixelBuffer else {
            return ProductAutoSceneFrameSkip(
                reason: reason,
                pixelFormat: 0,
                pixelFormatName: "none",
                width: 0,
                height: 0,
                planeCount: 0,
                bytesPerRow: 0,
                timestampSeconds: timing.timestampSeconds,
                frameAgeSeconds: timing.frameAgeSeconds
            )
        }

        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        let planeCount = CVPixelBufferGetPlaneCount(pixelBuffer)
        let bytesPerRow = planeCount > 0
            ? CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
            : CVPixelBufferGetBytesPerRow(pixelBuffer)
        return ProductAutoSceneFrameSkip(
            reason: reason,
            pixelFormat: pixelFormat,
            pixelFormatName: productAutoScenePixelFormatName(pixelFormat),
            width: CVPixelBufferGetWidth(pixelBuffer),
            height: CVPixelBufferGetHeight(pixelBuffer),
            planeCount: planeCount,
            bytesPerRow: bytesPerRow,
            timestampSeconds: timing.timestampSeconds,
            frameAgeSeconds: timing.frameAgeSeconds
        )
    }

    private static func productAutoSceneFrameTiming(
        timestamp: CMTime,
        now: CFTimeInterval
    ) -> (timestampSeconds: Double, frameAgeSeconds: Double) {
        guard timestamp.isValid, timestamp.seconds.isFinite else {
            return (-1, -1)
        }
        let rawAge = now - timestamp.seconds
        let age = rawAge.isFinite && rawAge >= 0 && rawAge < 60 ? rawAge : -1
        return (timestamp.seconds, age)
    }

    private static func isSupportedProductAutoScenePixelFormat(_ pixelFormat: OSType) -> Bool {
        pixelFormat == kCVPixelFormatType_32BGRA
            || pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            || pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
    }

    private static func isProductAutoSceneNearBlackProbeFrame(_ analysis: ProductPreviewFrameAnalysis) -> Bool {
        let metrics = analysis.exposureMetrics
        return metrics.meanLuma < 0.015
            && metrics.shadowRatio > 0.985
            && metrics.highlightRatio == 0
            && metrics.clippedRatio == 0
            && metrics.nearWhiteRatio == 0
    }

    private static func productAutoScenePixelFormatName(_ pixelFormat: OSType) -> String {
        switch pixelFormat {
        case kCVPixelFormatType_32BGRA:
            return "32BGRA"
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
            return "420YpCbCr8BiPlanarFullRange"
        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
            return "420YpCbCr8BiPlanarVideoRange"
        case 0:
            return "none"
        default:
            return String(format: "0x%08X", pixelFormat)
        }
    }
}

@preconcurrency
private final class CapturePhotoDelegateProxy: NSObject, AVCapturePhotoCaptureDelegate {
    typealias Completion = (UUID, Result<CaptureStillPhotoResult, Error>) -> Void

    private let captureID: UUID
    private let completion: Completion

    init(captureID: UUID, completion: @escaping Completion) {
        self.captureID = captureID
        self.completion = completion
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            completion(captureID, .failure(error))
            return
        }

        guard let imageData = photo.fileDataRepresentation() else {
            completion(
                captureID,
                .failure(NSError(domain: "CapturePhotoDelegateProxy", code: -3))
            )
            return
        }

        let metadata = photo.metadata
        let width = metadata[kCGImagePropertyPixelWidth as String] as? CGFloat
        let height = metadata[kCGImagePropertyPixelHeight as String] as? CGFloat
        let pixelSize: CGSize?
        if let width, let height {
            pixelSize = CGSize(width: width, height: height)
        } else {
            pixelSize = nil
        }

        var compactMetadata: [String: String] = [:]
        if let exif = metadata[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            if let fNumber = exif[kCGImagePropertyExifFNumber as String] {
                compactMetadata["fNumber"] = "\(fNumber)"
            }
            if let exposureTime = exif[kCGImagePropertyExifExposureTime as String] {
                compactMetadata["exposureTime"] = "\(exposureTime)"
            }
        }

        let result = CaptureStillPhotoResult(
            imageData: imageData,
            pixelSize: pixelSize,
            metadata: compactMetadata
        )
        completion(captureID, .success(result))
    }
}

private extension UIImage {
    func normalizedForCapturePipeline() -> UIImage {
        guard imageOrientation != .up else {
            return self
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

struct CaptureLivePreviewView: View {
    @ObservedObject var cameraRuntime: CaptureCameraRuntime
    var onTapPreviewBeforeFocus: (() -> Bool)? = nil
    @State private var pinchBaselineLensZoomMultiplier: CGFloat?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                CameraPreviewLayerView(
                    session: cameraRuntime.session,
                    stabilizerMode: cameraRuntime.selectedStabilizerMode,
                    onTapPreview: { devicePoint, normalizedPoint in
                        if onTapPreviewBeforeFocus?() == true {
                            return
                        }
                        cameraRuntime.handlePreviewTap(devicePoint: devicePoint, normalizedPoint: normalizedPoint)
                    },
                    onLongPressPreview: { devicePoint, normalizedPoint in
                        cameraRuntime.handlePreviewLongPress(devicePoint: devicePoint, normalizedPoint: normalizedPoint)
                    }
                )
                .contentShape(Rectangle())
                .gesture(
                    MagnificationGesture()
                        .onChanged { scale in
                            let baseline = pinchBaselineLensZoomMultiplier
                                ?? cameraRuntime.currentLensZoomMultiplier
                            if pinchBaselineLensZoomMultiplier == nil {
                                pinchBaselineLensZoomMultiplier = baseline
                            }
                            cameraRuntime.setLensZoomMultiplier(baseline * scale)
                        }
                        .onEnded { _ in
                            pinchBaselineLensZoomMultiplier = nil
                        }
                )

                if cameraRuntime.isGridEnabled {
                    CaptureGridOverlay()
                        .allowsHitTesting(false)
                }

                if cameraRuntime.isLevelIndicatorEnabled {
                    CaptureLevelOverlay(
                        rollDegrees: cameraRuntime.levelRollDegrees,
                        gravityX: cameraRuntime.levelGravityX,
                        gravityY: cameraRuntime.levelGravityY,
                        gravityZ: cameraRuntime.levelGravityZ
                    )
                        .allowsHitTesting(false)
                }

                if let focusMarker = cameraRuntime.focusMarker {
                    CaptureFocusMarkerOverlay(
                        normalizedPoint: focusMarker.normalizedPoint,
                        mode: focusMarker.mode
                    )
                        .allowsHitTesting(false)
                }

                if cameraRuntime.isFocusExposureLocked {
                    CapturePreviewStatusBadge(
                        text: "AE/AF 锁定中",
                        systemImage: "lock.fill",
                        state: .locked
                    )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(.top, 46)
                        .padding(.leading, 14)
                        .allowsHitTesting(false)
                } else if cameraRuntime.isExposureLocked {
                    CapturePreviewStatusBadge(
                        text: "AE 锁定中",
                        systemImage: "lock.fill",
                        state: .active
                    )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(.top, 46)
                        .padding(.leading, 14)
                        .allowsHitTesting(false)
                }

                if let remaining = cameraRuntime.countdownSecondsRemaining {
                    CaptureCountdownOverlay(remainingSeconds: remaining)
                        .allowsHitTesting(false)
                }

                if let quickPreviewImage = cameraRuntime.quickPreviewImage {
                    CaptureQuickPreviewOverlay(image: quickPreviewImage)
                        .padding(12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        .allowsHitTesting(false)
                }

                if cameraRuntime.isBurstCapturing, let burstProgressText = cameraRuntime.burstProgressText {
                    CapturePreviewStatusBadge(
                        text: burstProgressText,
                        systemImage: "square.stack.3d.up.fill",
                        state: .active
                    )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.top, 14)
                        .allowsHitTesting(false)
                }
            }
            .onAppear {
                cameraRuntime.startRunningSessionIfNeeded()
                if proxy.size.width > 0 {
                    cameraRuntime.captureHintText = "轻触画面可对焦与测光"
                }
            }
            .onDisappear {
                cameraRuntime.stopRunningSessionIfPossible()
            }
        }
    }
}

private struct CapturePreviewStatusBadge: View {
    let text: String
    let systemImage: String?
    let state: SellerCameraControlState
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let controlStyle = SellerCameraControlVisualStyle.style(for: state)

        HStack(spacing: SellerCameraSpacing.xs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .sellerCameraGlyphStyle(state: state, prominence: .status)
                    .accessibilityHidden(true)
            }

            Text(text)
                .font(SellerCameraTypography.statusLabel.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.86)
        }
        .foregroundStyle(SellerCameraPreviewStyle.overlayPrimary)
        .padding(.horizontal, SellerCameraSpacing.md + 2)
        .padding(.vertical, SellerCameraSpacing.sm)
        .background(
            Capsule(style: .continuous)
                .fill(reduceTransparency ? SellerCameraColor.controlSurfaceSecondary : SellerCameraPreviewStyle.hudSurface)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(controlStyle.stroke.opacity(0.92), lineWidth: SellerCameraPreviewMetrics.hairlineWidth)
        )
        .shadow(color: SellerCameraPreviewStyle.contrastOutline.opacity(0.42), radius: 4, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
        .accessibilityValue(state.accessibilityText)
    }
}

private struct CaptureAspectRatioGuideOverlay: View {
    let aspectRatio: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let canvasSize = proxy.size
            let safeAspectRatio = max(0.01, aspectRatio)
            let targetFrame = pixelAligned(fittedRect(for: canvasSize, targetRatio: safeAspectRatio))

            ZStack {
                Path { path in
                    path.addRect(CGRect(origin: .zero, size: canvasSize))
                    path.addRect(targetFrame)
                }
                .fill(
                    SellerCameraPreviewStyle.maskFill,
                    style: FillStyle(eoFill: true, antialiased: true)
                )

                if SellerCameraPreviewMetrics.guideBorderWidth > 0 {
                    RoundedRectangle(cornerRadius: SellerCameraRadius.compact, style: .continuous)
                        .stroke(SellerCameraPreviewStyle.guideBorder, lineWidth: SellerCameraPreviewMetrics.guideBorderWidth)
                        .frame(width: targetFrame.width, height: targetFrame.height)
                        .position(x: targetFrame.midX, y: targetFrame.midY)
                }
            }
            .accessibilityHidden(true)
        }
    }

    private func pixelAligned(_ rect: CGRect, scale: CGFloat = UIScreen.main.scale) -> CGRect {
        guard scale > 0 else { return rect }
        let minX = (rect.minX * scale).rounded(.toNearestOrAwayFromZero) / scale
        let minY = (rect.minY * scale).rounded(.toNearestOrAwayFromZero) / scale
        let maxX = (rect.maxX * scale).rounded(.toNearestOrAwayFromZero) / scale
        let maxY = (rect.maxY * scale).rounded(.toNearestOrAwayFromZero) / scale
        return CGRect(x: minX, y: minY, width: max(0, maxX - minX), height: max(0, maxY - minY))
    }

    private func fittedRect(for size: CGSize, targetRatio: CGFloat) -> CGRect {
        guard size.width > 0, size.height > 0 else {
            return .zero
        }

        let containerRatio = size.width / size.height
        if containerRatio > targetRatio {
            let width = size.height * targetRatio
            let x = (size.width - width) / 2.0
            return CGRect(x: x, y: 0, width: width, height: size.height)
        } else {
            let height = size.width / targetRatio
            let y = (size.height - height) / 2.0
            return CGRect(x: 0, y: y, width: size.width, height: height)
        }
    }
}

private struct CameraPreviewLayerView: UIViewRepresentable {
    let session: AVCaptureSession
    let stabilizerMode: CaptureStabilizerMode
    let onTapPreview: (CGPoint, CGPoint) -> Void
    let onLongPressPreview: (CGPoint, CGPoint) -> Void

    func makeUIView(context: Context) -> PreviewContainerUIView {
        let view = PreviewContainerUIView()
        view.previewLayer.videoGravity = .resizeAspectFill
        view.onTapPreview = onTapPreview
        view.onLongPressPreview = onLongPressPreview
        view.previewLayer.session = session
        applyPreviewStabilization(to: view.previewLayer.connection)
        return view
    }

    func updateUIView(_ uiView: PreviewContainerUIView, context: Context) {
        uiView.onTapPreview = onTapPreview
        uiView.onLongPressPreview = onLongPressPreview
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }
        applyPreviewStabilization(to: uiView.previewLayer.connection)
    }

    private func applyPreviewStabilization(to connection: AVCaptureConnection?) {
        guard let connection, connection.isVideoStabilizationSupported else { return }
        switch stabilizerMode {
        case .off:
            connection.preferredVideoStabilizationMode = .off
        case .standard:
            connection.preferredVideoStabilizationMode = .auto
        case .enhanced:
            connection.preferredVideoStabilizationMode = .cinematic
        }
    }
}

private final class PreviewContainerUIView: UIView {
    var onTapPreview: ((CGPoint, CGPoint) -> Void)?
    var onLongPressPreview: ((CGPoint, CGPoint) -> Void)?

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupTapGesture()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTapGesture()
    }

    private func setupTapGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.6
        longPress.allowableMovement = 8
        addGestureRecognizer(longPress)
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        let point = recognizer.location(in: self)
        let normalizedPoint = CGPoint(
            x: max(0, min(1, point.x / max(bounds.width, 1))),
            y: max(0, min(1, point.y / max(bounds.height, 1)))
        )
        let devicePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: point)
        onTapPreview?(devicePoint, normalizedPoint)
    }

    @objc private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }
        let point = recognizer.location(in: self)
        let normalizedPoint = CGPoint(
            x: max(0, min(1, point.x / max(bounds.width, 1))),
            y: max(0, min(1, point.y / max(bounds.height, 1)))
        )
        let devicePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: point)
        onLongPressPreview?(devicePoint, normalizedPoint)
    }
}

private struct CaptureGridOverlay: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            Path { path in
                let x1 = width / 3
                let x2 = width * 2 / 3
                let y1 = height / 3
                let y2 = height * 2 / 3

                path.move(to: CGPoint(x: x1, y: 0))
                path.addLine(to: CGPoint(x: x1, y: height))
                path.move(to: CGPoint(x: x2, y: 0))
                path.addLine(to: CGPoint(x: x2, y: height))

                path.move(to: CGPoint(x: 0, y: y1))
                path.addLine(to: CGPoint(x: width, y: y1))
                path.move(to: CGPoint(x: 0, y: y2))
                path.addLine(to: CGPoint(x: width, y: y2))
            }
            .stroke(SellerCameraPreviewStyle.gridLine, lineWidth: SellerCameraPreviewMetrics.hairlineWidth)
        }
        .accessibilityHidden(true)
    }
}

private struct CaptureLevelOverlay: View {
    let rollDegrees: Double?
    let gravityX: Double?
    let gravityY: Double?
    let gravityZ: Double?

    private enum GuideMode {
        case uprightLine
        case flatCross
    }

    @State private var guideMode: GuideMode = .uprightLine
    @State private var pendingMode: GuideMode?
    @State private var pendingSince: TimeInterval = 0
    @State private var uprightIsLandscapeHold = false
    @State private var smoothedUprightTiltDegrees: Double = 0
    @State private var smoothedCrossOffset: CGSize = .zero
    @State private var isNearLevelVisual: Bool = false

    private static let flatEnterAbsZ: Double = 0.78
    private static let uprightEnterAbsZ: Double = 0.62
    private static let modeSwitchHoldDuration: TimeInterval = 0.16
    private static let maxDisplayedTilt: Double = 18
    private static let nearLevelEnterThreshold: Double = 1.1
    private static let nearLevelExitThreshold: Double = 1.9
    private static let uprightTiltSmoothingAlpha: Double = 0.24
    private static let crossOffsetSmoothingAlpha: CGFloat = 0.2
    private static let uprightTiltDeadbandDegrees: Double = 0.16
    private static let crossOffsetDeadbandPoints: CGFloat = 0.45
    private static let uprightLandscapeEnterDelta: Double = 0.14
    private static let uprightPortraitEnterDelta: Double = -0.14
    private static let uprightLandscapeBaseRotationDegrees: Double = 90
    private static let maxCrossOffset: CGFloat = 24

    private var hasGravitySample: Bool {
        gravityX != nil && gravityY != nil && gravityZ != nil
    }

    private var absGravityZ: Double {
        abs(gravityZ ?? 0)
    }

    private var absGravityX: Double {
        abs(gravityX ?? 0)
    }

    private var absGravityY: Double {
        abs(gravityY ?? 0)
    }

    private var uprightBaseRotationDegrees: Double {
        uprightIsLandscapeHold ? Self.uprightLandscapeBaseRotationDegrees : 0
    }

    private var uprightRawTiltDegrees: Double {
        guard let gravityX, let gravityY else {
            return clampedTilt(rollDegrees ?? 0)
        }
        let tilt: Double
        if uprightIsLandscapeHold {
            tilt = atan2(gravityY, max(0.0001, abs(gravityX))) * 180 / .pi
        } else {
            tilt = atan2(gravityX, max(0.0001, abs(gravityY))) * 180 / .pi
        }
        return clampedTilt(tilt)
    }

    private var flatRawTiltDegreesX: Double {
        guard let gravityX, let gravityZ else {
            return clampedTilt(rollDegrees ?? 0)
        }
        let tilt = atan2(gravityX, max(0.0001, abs(gravityZ))) * 180 / .pi
        return clampedTilt(tilt)
    }

    private var flatRawTiltDegreesY: Double {
        guard let gravityY, let gravityZ else {
            return 0
        }
        let tilt = atan2(gravityY, max(0.0001, abs(gravityZ))) * 180 / .pi
        return clampedTilt(tilt)
    }

    private var rawDynamicCrossOffset: CGSize {
        let normalizedX = max(-1, min(1, flatRawTiltDegreesX / Self.maxDisplayedTilt))
        let normalizedY = max(-1, min(1, flatRawTiltDegreesY / Self.maxDisplayedTilt))
        let rawX = CGFloat(normalizedX) * Self.maxCrossOffset
        let rawY = CGFloat(-normalizedY) * Self.maxCrossOffset
        let offsetX = abs(rawX) < 0.9 ? 0 : rawX
        let offsetY = abs(rawY) < 0.9 ? 0 : rawY
        return CGSize(
            width: offsetX,
            height: offsetY
        )
    }

    private var activeTiltMagnitude: Double {
        switch guideMode {
        case .uprightLine:
            return abs(smoothedUprightTiltDegrees)
        case .flatCross:
            let xMagnitude = abs(smoothedCrossOffset.width / Self.maxCrossOffset) * Self.maxDisplayedTilt
            let yMagnitude = abs(smoothedCrossOffset.height / Self.maxCrossOffset) * Self.maxDisplayedTilt
            return max(xMagnitude, yMagnitude)
        }
    }

    var body: some View {
        ZStack {
            switch guideMode {
            case .uprightLine:
                uprightGuide
            case .flatCross:
                flatGuide
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            syncGuideMode(force: true)
            syncUprightHoldMode(force: true)
            updateSmoothedVisualState(force: true)
        }
        .onChange(of: gravityX) { _ in
            handleMotionUpdate()
        }
        .onChange(of: gravityY) { _ in
            handleMotionUpdate()
        }
        .onChange(of: gravityZ) { _ in
            handleMotionUpdate()
        }
    }

    private var uprightGuide: some View {
        let strokeColor = isNearLevelVisual
            ? SellerCameraPreviewStyle.levelAligned.opacity(SellerCameraPreviewMetrics.levelActiveOpacity)
            : SellerCameraPreviewStyle.levelNeutral.opacity(SellerCameraPreviewMetrics.levelInactiveOpacity)
        return ZStack {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(strokeColor)
                    .frame(width: SellerCameraPreviewMetrics.levelShortTickWidth, height: SellerCameraPreviewMetrics.levelShortTickHeight)
                Rectangle()
                    .fill(strokeColor)
                    .frame(width: SellerCameraPreviewMetrics.levelHorizontalWidth, height: SellerCameraPreviewMetrics.levelHorizontalHeight)
                    .overlay(alignment: .center) {
                        Rectangle()
                            .fill(strokeColor)
                            .frame(width: SellerCameraPreviewMetrics.levelCenterTickWidth, height: SellerCameraPreviewMetrics.levelShortTickHeight)
                    }
                Rectangle()
                    .fill(strokeColor)
                    .frame(width: SellerCameraPreviewMetrics.levelShortTickWidth, height: SellerCameraPreviewMetrics.levelShortTickHeight)
            }
            .rotationEffect(.degrees(-smoothedUprightTiltDegrees))
            .rotationEffect(.degrees(-uprightBaseRotationDegrees))
            .shadow(color: SellerCameraPreviewStyle.contrastOutline.opacity(0.28), radius: isNearLevelVisual ? 4 : 2)
        }
        .accessibilityHidden(true)
    }

    private var flatGuide: some View {
        let dynamicColor = isNearLevelVisual
            ? SellerCameraPreviewStyle.levelAligned.opacity(SellerCameraPreviewMetrics.levelActiveOpacity)
            : SellerCameraPreviewStyle.levelNeutral.opacity(SellerCameraPreviewMetrics.levelInactiveOpacity)
        return ZStack {
            crossSymbol(
                color: SellerCameraPreviewStyle.levelNeutral.opacity(SellerCameraPreviewMetrics.levelReferenceOpacity),
                lineWidth: SellerCameraPreviewMetrics.hairlineWidth,
                size: SellerCameraPreviewMetrics.levelCrossSize
            )

            crossSymbol(
                color: dynamicColor,
                lineWidth: SellerCameraPreviewMetrics.standardLineWidth,
                size: SellerCameraPreviewMetrics.levelCrossSize
            )
                .offset(smoothedCrossOffset)
                .shadow(color: SellerCameraPreviewStyle.contrastOutline.opacity(0.24), radius: isNearLevelVisual ? 4 : 2)
        }
        .accessibilityHidden(true)
    }

    private func crossSymbol(color: Color, lineWidth: CGFloat, size: CGFloat) -> some View {
        ZStack {
            Rectangle()
                .fill(color)
                .frame(width: size, height: lineWidth)
            Rectangle()
                .fill(color)
                .frame(width: lineWidth, height: size)
        }
    }

    private func syncGuideMode(force: Bool) {
        guard hasGravitySample else { return }
        let nextMode = preferredGuideMode()
        if force {
            guideMode = nextMode
            pendingMode = nil
            pendingSince = 0
            return
        }

        if nextMode == guideMode {
            pendingMode = nil
            pendingSince = 0
            return
        }

        let now = Date().timeIntervalSinceReferenceDate
        if pendingMode != nextMode {
            pendingMode = nextMode
            pendingSince = now
            return
        }

        guard now - pendingSince >= Self.modeSwitchHoldDuration else { return }
        guideMode = nextMode
        pendingMode = nil
        pendingSince = 0
    }

    private func handleMotionUpdate() {
        syncGuideMode(force: false)
        syncUprightHoldMode(force: false)
        updateSmoothedVisualState(force: false)
    }

    private func syncUprightHoldMode(force: Bool) {
        let dominance = absGravityX - absGravityY
        if force {
            uprightIsLandscapeHold = dominance >= 0
            return
        }

        if uprightIsLandscapeHold {
            if dominance < Self.uprightPortraitEnterDelta {
                uprightIsLandscapeHold = false
            }
        } else if dominance > Self.uprightLandscapeEnterDelta {
            uprightIsLandscapeHold = true
        }
    }

    private func updateSmoothedVisualState(force: Bool) {
        let targetUprightTilt = uprightRawTiltDegrees
        let targetCrossOffset = rawDynamicCrossOffset

        if force {
            smoothedUprightTiltDegrees = targetUprightTilt
            smoothedCrossOffset = targetCrossOffset
            isNearLevelVisual = activeTiltMagnitude <= Self.nearLevelEnterThreshold
            return
        }

        let uprightDelta = targetUprightTilt - smoothedUprightTiltDegrees
        if abs(uprightDelta) > Self.uprightTiltDeadbandDegrees {
            smoothedUprightTiltDegrees = smoothedUprightTiltDegrees + uprightDelta * Self.uprightTiltSmoothingAlpha
        }

        let crossDeltaX = targetCrossOffset.width - smoothedCrossOffset.width
        let crossDeltaY = targetCrossOffset.height - smoothedCrossOffset.height
        smoothedCrossOffset = CGSize(
            width: abs(crossDeltaX) > Self.crossOffsetDeadbandPoints
                ? smoothedCrossOffset.width + crossDeltaX * Self.crossOffsetSmoothingAlpha
                : smoothedCrossOffset.width,
            height: abs(crossDeltaY) > Self.crossOffsetDeadbandPoints
                ? smoothedCrossOffset.height + crossDeltaY * Self.crossOffsetSmoothingAlpha
                : smoothedCrossOffset.height
        )

        if isNearLevelVisual {
            if activeTiltMagnitude > Self.nearLevelExitThreshold {
                isNearLevelVisual = false
            }
        } else if activeTiltMagnitude < Self.nearLevelEnterThreshold {
            isNearLevelVisual = true
        }
    }

    private func preferredGuideMode() -> GuideMode {
        let absZ = absGravityZ
        switch guideMode {
        case .uprightLine:
            return absZ >= Self.flatEnterAbsZ ? .flatCross : .uprightLine
        case .flatCross:
            return absZ <= Self.uprightEnterAbsZ ? .uprightLine : .flatCross
        }
    }

    private func clampedTilt(_ tilt: Double) -> Double {
        max(-Self.maxDisplayedTilt, min(Self.maxDisplayedTilt, tilt))
    }
}

private struct CaptureFocusMarkerOverlay: View {
    let normalizedPoint: CGPoint
    let mode: CaptureFocusMarker.Mode
    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let point = CGPoint(
                x: normalizedPoint.x * proxy.size.width,
                y: normalizedPoint.y * proxy.size.height
            )
            ZStack {
                focusCorners

                statusBadge
            }
            .scaleEffect(reduceMotion ? 1 : (hasAppeared ? 1.0 : 0.84))
            .opacity(hasAppeared ? 1.0 : 0.0)
            .animation(SellerCameraMotionToken.resolved(SellerCameraMotionToken.focus, reduceMotion: reduceMotion), value: hasAppeared)
            .animation(SellerCameraMotionToken.resolved(SellerCameraMotionToken.warning, reduceMotion: reduceMotion), value: mode)
            .onAppear {
                hasAppeared = true
            }
            .onChange(of: mode) { nextMode in
                if nextMode == .warning {
                    hasAppeared = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        hasAppeared = true
                    }
                }
            }
            .position(point)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
    }

    private var focusCorners: some View {
        ZStack {
            cornerPath(
                size: SellerCameraPreviewMetrics.focusOuterPathSize,
                length: SellerCameraPreviewMetrics.focusCornerLength,
                inset: SellerCameraPreviewMetrics.focusInset
            )
                .stroke(SellerCameraPreviewStyle.contrastOutline, style: StrokeStyle(lineWidth: SellerCameraPreviewMetrics.contrastOutlineWidth, lineCap: .round, lineJoin: .round))
                .frame(width: SellerCameraPreviewMetrics.focusOuterFrame, height: SellerCameraPreviewMetrics.focusOuterFrame)

            cornerPath(
                size: SellerCameraPreviewMetrics.focusOuterPathSize,
                length: SellerCameraPreviewMetrics.focusCornerLength,
                inset: SellerCameraPreviewMetrics.focusInset
            )
                .stroke(strokeColor.opacity(0.98), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .frame(width: SellerCameraPreviewMetrics.focusOuterFrame, height: SellerCameraPreviewMetrics.focusOuterFrame)
                .shadow(color: strokeColor.opacity(shadowOpacity), radius: shadowRadius)

            if mode == .focusing {
                cornerPath(
                    size: SellerCameraPreviewMetrics.focusInnerPathSize,
                    length: SellerCameraPreviewMetrics.focusInnerCornerLength,
                    inset: 0
                )
                    .stroke(strokeColor.opacity(0.34), style: StrokeStyle(lineWidth: SellerCameraPreviewMetrics.focusInnerLineWidth, lineCap: .round, lineJoin: .round))
                    .frame(width: SellerCameraPreviewMetrics.focusInnerFrame, height: SellerCameraPreviewMetrics.focusInnerFrame)
            }
        }
    }

    private var statusBadge: some View {
        Group {
            switch mode {
            case .focused:
                Circle()
                    .fill(strokeColor.opacity(0.92))
                    .frame(width: SellerCameraGlyphMetrics.standardDot, height: SellerCameraGlyphMetrics.standardDot)
                    .offset(y: SellerCameraPreviewMetrics.focusBadgeOffset)
            case .warning:
                Circle()
                    .stroke(strokeColor.opacity(0.94), lineWidth: SellerCameraGlyphMetrics.standardStrokeWidth)
                    .frame(width: SellerCameraGlyphMetrics.compactFrame, height: SellerCameraGlyphMetrics.compactFrame)
                    .offset(y: SellerCameraPreviewMetrics.focusBadgeOffset)
            case .locked, .unlocked:
                Image(systemName: mode == .locked ? "lock.fill" : "lock.open.fill")
                    .sellerCameraGlyphStyle(state: mode == .locked ? .locked : .active, prominence: .status)
                    .foregroundStyle(SellerCameraPreviewStyle.overlayPrimary)
                    .padding(SellerCameraSpacing.xs)
                    .background(strokeColor.opacity(0.78), in: Circle())
                    .overlay(Circle().stroke(SellerCameraPreviewStyle.contrastOutline, lineWidth: SellerCameraPreviewMetrics.hairlineWidth))
                    .offset(y: SellerCameraPreviewMetrics.focusIconOffset)
            case .focusing:
                Circle()
                    .fill(strokeColor.opacity(0.72))
                    .frame(width: SellerCameraGlyphMetrics.emphasizedDot, height: SellerCameraGlyphMetrics.emphasizedDot)
                    .offset(y: SellerCameraPreviewMetrics.focusBadgeOffset)
            }
        }
    }

    private func cornerPath(size: CGFloat, length: CGFloat, inset: CGFloat) -> Path {
        let minValue = inset
        let maxValue = size - inset
        return Path { path in
            path.move(to: CGPoint(x: minValue, y: minValue + length))
            path.addLine(to: CGPoint(x: minValue, y: minValue))
            path.addLine(to: CGPoint(x: minValue + length, y: minValue))

            path.move(to: CGPoint(x: maxValue - length, y: minValue))
            path.addLine(to: CGPoint(x: maxValue, y: minValue))
            path.addLine(to: CGPoint(x: maxValue, y: minValue + length))

            path.move(to: CGPoint(x: maxValue, y: maxValue - length))
            path.addLine(to: CGPoint(x: maxValue, y: maxValue))
            path.addLine(to: CGPoint(x: maxValue - length, y: maxValue))

            path.move(to: CGPoint(x: minValue + length, y: maxValue))
            path.addLine(to: CGPoint(x: minValue, y: maxValue))
            path.addLine(to: CGPoint(x: minValue, y: maxValue - length))
        }
    }

    private var strokeColor: Color {
        switch mode {
        case .focusing:
            return SellerCameraPreviewStyle.focusNormal
        case .focused:
            return SellerCameraPreviewStyle.focusConfirmed
        case .warning:
            return SellerCameraPreviewStyle.focusWarning
        case .locked:
            return SellerCameraPreviewStyle.focusLocked
        case .unlocked:
            return SellerCameraPreviewStyle.focusUnlocked
        }
    }

    private var lineWidth: CGFloat {
        switch mode {
        case .focusing:
            return SellerCameraPreviewMetrics.emphasizedLineWidth
        case .focused, .locked, .unlocked:
            return SellerCameraPreviewMetrics.focusLineWidth
        case .warning:
            return SellerCameraPreviewMetrics.focusWarningLineWidth
        }
    }

    private var shadowOpacity: CGFloat {
        mode == .warning ? 0.32 : 0.22
    }

    private var shadowRadius: CGFloat {
        mode == .focusing ? 6 : 4
    }

    private var accessibilityLabel: String {
        switch mode {
        case .focusing:
            return "正在对焦"
        case .focused:
            return "对焦完成"
        case .warning:
            return "对焦可能失败"
        case .locked:
            return "对焦与曝光已锁定"
        case .unlocked:
            return "对焦与曝光已解锁"
        }
    }

    private var accessibilityValue: String {
        switch mode {
        case .locked:
            return SellerCameraControlState.locked.accessibilityText
        case .warning:
            return SellerCameraControlState.warning.accessibilityText
        case .focusing:
            return SellerCameraControlState.active.accessibilityText
        case .focused, .unlocked:
            return SellerCameraControlState.selected.accessibilityText
        }
    }
}

private struct CaptureCountdownOverlay: View {
    let remainingSeconds: Int

    var body: some View {
        ZStack {
            Circle()
                .fill(SellerCameraPreviewStyle.hudSurface)
                .frame(width: 86, height: 86)
                .overlay(
                    Circle()
                        .stroke(SellerCameraPreviewStyle.hudStroke, lineWidth: SellerCameraPreviewMetrics.hairlineWidth)
                )
                .shadow(color: SellerCameraPreviewStyle.contrastOutline.opacity(0.36), radius: 8, x: 0, y: 4)
            Text("\(remainingSeconds)")
                .font(SellerCameraTypography.previewCountdown)
                .monospacedDigit()
                .foregroundStyle(SellerCameraPreviewStyle.overlayPrimary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("倒计时")
        .accessibilityValue("\(remainingSeconds) 秒")
    }
}

private struct CaptureQuickPreviewOverlay: View {
    let image: UIImage

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("拍后快速预览")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(SellerCameraPreviewStyle.overlaySecondary)

            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(8)
        .background(
            SellerCameraPreviewStyle.hudSurface,
            in: RoundedRectangle(cornerRadius: SellerCameraRadius.control, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: SellerCameraRadius.control, style: .continuous)
                .stroke(SellerCameraPreviewStyle.hudStroke, lineWidth: SellerCameraPreviewMetrics.hairlineWidth)
        )
        .shadow(color: SellerCameraPreviewStyle.contrastOutline.opacity(0.30), radius: 8, x: 0, y: 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("拍后快速预览")
    }
}

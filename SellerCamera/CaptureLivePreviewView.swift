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
    case ratio9x16
    case ratio16x9

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

    var longEdgePixels: Int {
        switch self {
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
        "\(longEdgePixels)"
    }

    func outputPixelSize(for ratio: CGFloat) -> CGSize {
        let safeRatio = max(0.01, ratio)
        let longEdge = CGFloat(longEdgePixels)
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
        let size = outputPixelSize(for: ratio)
        return "\(Int(size.width))×\(Int(size.height))"
    }
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

enum CaptureSemanticFocal: Int, CaseIterable, Identifiable {
    case mm13
    case mm24
    case mm48
    case mm77

    var id: Int { rawValue }

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
        case auto
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
    private static let wideLensBoundaryHeadroom: CGFloat = 1.06
    private static let teleLensBoundaryHeadroom: CGFloat = 1.06
    private static let lensZoomSnapThresholdBase: CGFloat = 0.03

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
    @Published var isGridEnabled = false
    @Published var isLevelIndicatorEnabled = false
    @Published var isFlashModeSupported = false
    @Published var isExposureLockSupported = false
    @Published var isExposureBiasSupported = false
    @Published var isWhiteBalanceAutoSupported = false
    @Published var isWhiteBalancePresetSupported = false
    @Published var selectedWhiteBalancePreset: CaptureWhiteBalancePreset = .auto
    @Published var currentWhiteBalanceTemperature: Float = 5000
    @Published var currentWhiteBalanceTint: Float = 0
    @Published var isISOAutoSupported = false
    @Published var isISOPresetSupported = false
    @Published var selectedISOPreset: CaptureISOPreset = .auto
    @Published var minimumISOValue: Float = 0
    @Published var maximumISOValue: Float = 0
    @Published var currentManualISOValue: Float = 0
    @Published var isShutterAutoSupported = false
    @Published var isShutterPresetSupported = false
    @Published var selectedShutterPreset: CaptureShutterPreset = .auto
    @Published var minimumShutterDurationSeconds: Double = 0
    @Published var maximumShutterDurationSeconds: Double = 0
    @Published var currentManualShutterDurationSeconds: Double = 1.0 / 120.0
    @Published var selectedAspectRatioPreset: CapturePhotoAspectRatioPreset = .ratio3x4
    @Published var selectedPixelPreset: CapturePhotoPixelPreset = .p1600
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
    private var lastAppliedManualFocusPosition: Float?
    private var tele77StabilizationUntil: TimeInterval = 0
    private var tele77LastWriteTimestamp: TimeInterval = 0
    private var tele77PendingMultiplier: CGFloat?
    private var tele77StabilizationToken = UUID()
    private let productAutoExposureOptimizer = ProductAutoExposureOptimizer()
    private var lastProductAutoExposureAnalysisAt: CFTimeInterval = 0
    private var lastProductAutoExposureWriteAt = Date.distantPast
    private var lastProductAutoExposureDebugLogAt = Date.distantPast
    private let productAutoExposureAnalysisInterval: CFTimeInterval = 0.35
    private let productAutoExposureWriteInterval: TimeInterval = 0.35
    private let productAutoExposureDebugLogInterval: TimeInterval = 1.0

    private let motionManager = CMMotionManager()
    private var levelMotionStarted = false

    deinit {
        countdownTask?.cancel()
        burstTask?.cancel()
        quickPreviewHideTask?.cancel()
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
                device.whiteBalanceMode = .continuousAutoWhiteBalance
                let autoTempTint = device.temperatureAndTintValues(for: device.deviceWhiteBalanceGains)
                device.unlockForConfiguration()
                DispatchQueue.main.async {
                    self.selectedWhiteBalancePreset = .auto
                    self.currentWhiteBalanceTemperature = self.clampedWhiteBalanceTemperature(autoTempTint.temperature)
                    // TINT 合同：WB Auto 统一回收为 0，避免用户误解自动状态下仍存在手动色偏。
                    self.currentWhiteBalanceTint = 0
                    if shouldShowHint {
                        self.captureHintText = "白平衡：Auto"
                    }
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
        guard isWhiteBalancePresetSupported else {
            captureHintText = "当前摄像头不支持固定白平衡"
            return
        }

        let clampedTemperature = clampedWhiteBalanceTemperature(requestedTemperature)
        let quantizedTemperature = (clampedTemperature / Self.whiteBalanceDialStep).rounded() * Self.whiteBalanceDialStep
        let clampedTint = clampedWhiteBalanceTint(requestedTint)
        let quantizedTint = (clampedTint / Self.whiteBalanceTintDialStep).rounded() * Self.whiteBalanceTintDialStep

        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard let device = self.currentVideoInput?.device else { return }
            do {
                try device.lockForConfiguration()
                guard device.isLockingWhiteBalanceWithCustomDeviceGainsSupported else {
                    device.unlockForConfiguration()
                    DispatchQueue.main.async {
                        self.captureHintText = "当前摄像头不支持固定白平衡"
                    }
                    return
                }
                let tempTint = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(
                    temperature: quantizedTemperature,
                    tint: quantizedTint
                )
                let rawGains = device.deviceWhiteBalanceGains(for: tempTint)
                let safeGains = self.normalizedWhiteBalanceGains(rawGains, for: device)
                device.setWhiteBalanceModeLocked(with: safeGains)
                device.unlockForConfiguration()

                DispatchQueue.main.async {
                    self.currentWhiteBalanceTemperature = quantizedTemperature
                    self.currentWhiteBalanceTint = quantizedTint
                    self.selectedWhiteBalancePreset = semanticPreset == .auto ? .custom : semanticPreset
                    if shouldShowHint {
                        let tintDisplayText = self.formattedWhiteBalanceTintText(quantizedTint)
                        self.captureHintText = "白平衡：\(Int(quantizedTemperature.rounded()))K · \(tintDisplayText)"
                    }
                }
            } catch {
                DispatchQueue.main.async {
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

        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard let device = self.currentVideoInput?.device else { return }
            do {
                try device.lockForConfiguration()
                let appliedISO: Float
                switch preset {
                case .auto:
                    guard device.isExposureModeSupported(.continuousAutoExposure) else {
                        device.unlockForConfiguration()
                        DispatchQueue.main.async {
                            self.captureHintText = "当前摄像头不支持 ISO 自动模式"
                        }
                        return
                    }
                    device.exposureMode = .continuousAutoExposure
                    appliedISO = device.iso
                case .low, .medium, .high:
                    guard device.isExposureModeSupported(.custom) else {
                        device.unlockForConfiguration()
                        DispatchQueue.main.async {
                            self.captureHintText = "当前摄像头不支持固定 ISO"
                        }
                        return
                    }
                    let targetISO = self.targetISOValue(for: preset, device: device)
                    let quantizedISO = self.quantizedISOValue(targetISO)
                    guard let exposureWrite = self.sanitizedCustomExposureWrite(
                        rawDuration: AVCaptureDevice.currentExposureDuration,
                        rawISO: quantizedISO,
                        device: device,
                        context: "isoPreset"
                    ) else {
                        device.unlockForConfiguration()
                        DispatchQueue.main.async {
                            self.captureHintText = "当前摄像头曝光能力异常，ISO 调整已跳过"
                        }
                        return
                    }
                    device.setExposureModeCustom(duration: exposureWrite.duration, iso: exposureWrite.iso)
                    appliedISO = exposureWrite.iso
                case .custom:
                    guard device.isExposureModeSupported(.custom) else {
                        device.unlockForConfiguration()
                        DispatchQueue.main.async {
                            self.captureHintText = "当前摄像头不支持固定 ISO"
                        }
                        return
                    }
                    let targetISO = self.clampedISOValue(self.currentManualISOValue, device: device)
                    let quantizedISO = self.quantizedISOValue(targetISO)
                    guard let exposureWrite = self.sanitizedCustomExposureWrite(
                        rawDuration: AVCaptureDevice.currentExposureDuration,
                        rawISO: quantizedISO,
                        device: device,
                        context: "isoCustom"
                    ) else {
                        device.unlockForConfiguration()
                        DispatchQueue.main.async {
                            self.captureHintText = "当前摄像头曝光能力异常，ISO 调整已跳过"
                        }
                        return
                    }
                    device.setExposureModeCustom(duration: exposureWrite.duration, iso: exposureWrite.iso)
                    appliedISO = exposureWrite.iso
                }
                let updatedShutterSeconds = CMTimeGetSeconds(device.exposureDuration)
                device.unlockForConfiguration()
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
        applyAspectRatioPreset(presets[index], shouldShowHint: true)
    }

    func resetAspectRatio() {
        applyAspectRatioPreset(.ratio3x4, shouldShowHint: true)
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
        applyPixelPreset(presets[index], shouldShowHint: true)
    }

    func resetPixelPreset() {
        applyPixelPreset(.p1600, shouldShowHint: true)
    }

    var pixelDialValue: Double {
        let presets = CapturePhotoPixelPreset.allCases
        guard let index = presets.firstIndex(of: selectedPixelPreset) else { return 0 }
        return Double(index)
    }

    var pixelDisplayText: String {
        selectedPixelPreset.displayText(for: selectedAspectRatioPreset.ratioValue)
    }

    private func applyAspectRatioPreset(
        _ preset: CapturePhotoAspectRatioPreset,
        shouldShowHint: Bool
    ) {
        if selectedAspectRatioPreset == preset { return }
        selectedAspectRatioPreset = preset
        if shouldShowHint {
            captureHintText = "比例：\(preset.displayText) · \(selectedPixelPreset.displayText(for: preset.ratioValue))"
        }
    }

    private func applyPixelPreset(
        _ preset: CapturePhotoPixelPreset,
        shouldShowHint: Bool
    ) {
        if selectedPixelPreset == preset { return }
        selectedPixelPreset = preset
        if shouldShowHint {
            captureHintText = "像素：\(preset.displayText(for: selectedAspectRatioPreset.ratioValue))"
        }
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

        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard let device = self.currentVideoInput?.device else { return }

            do {
                try device.lockForConfiguration()
                let appliedDuration: CMTime
                switch preset {
                case .auto:
                    guard device.isExposureModeSupported(.continuousAutoExposure) else {
                        device.unlockForConfiguration()
                        DispatchQueue.main.async {
                            self.captureHintText = "当前摄像头不支持自动快门"
                        }
                        return
                    }
                    device.exposureMode = .continuousAutoExposure
                    appliedDuration = device.exposureDuration
                case .s1_30, .s1_60, .s1_120, .s1_250, .s1_500:
                    guard device.isExposureModeSupported(.custom) else {
                        device.unlockForConfiguration()
                        DispatchQueue.main.async {
                            self.captureHintText = "当前摄像头不支持手动快门"
                        }
                        return
                    }
                    let targetDuration = self.clampedShutterDuration(for: preset, device: device)
                    let quantizedDuration = self.quantizedShutterDuration(targetDuration, device: device)
                    let isoForWrite = device.iso
                    guard let exposureWrite = self.sanitizedCustomExposureWrite(
                        rawDuration: quantizedDuration,
                        rawISO: isoForWrite,
                        device: device,
                        context: "shutterPreset"
                    ) else {
                        device.unlockForConfiguration()
                        DispatchQueue.main.async {
                            self.captureHintText = "当前摄像头曝光能力异常，快门调整已跳过"
                        }
                        return
                    }
                    device.setExposureModeCustom(duration: exposureWrite.duration, iso: exposureWrite.iso)
                    appliedDuration = exposureWrite.duration
                case .custom:
                    guard device.isExposureModeSupported(.custom) else {
                        device.unlockForConfiguration()
                        DispatchQueue.main.async {
                            self.captureHintText = "当前摄像头不支持手动快门"
                        }
                        return
                    }
                    let requestedDuration = CMTime(
                        seconds: self.currentManualShutterDurationSeconds,
                        preferredTimescale: 1_000_000_000
                    )
                    let targetDuration = self.clampedShutterDuration(requestedDuration, device: device)
                    let quantizedDuration = self.quantizedShutterDuration(targetDuration, device: device)
                    let isoForWrite = device.iso
                    guard let exposureWrite = self.sanitizedCustomExposureWrite(
                        rawDuration: quantizedDuration,
                        rawISO: isoForWrite,
                        device: device,
                        context: "shutterCustom"
                    ) else {
                        device.unlockForConfiguration()
                        DispatchQueue.main.async {
                            self.captureHintText = "当前摄像头曝光能力异常，快门调整已跳过"
                        }
                        return
                    }
                    device.setExposureModeCustom(duration: exposureWrite.duration, iso: exposureWrite.iso)
                    appliedDuration = exposureWrite.duration
                }
                device.unlockForConfiguration()

                let seconds = CMTimeGetSeconds(appliedDuration)
                let updatedISO = device.iso
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
                }
            } catch {
                DispatchQueue.main.async {
                    self.captureHintText = "快门调整失败"
                }
            }
        }
    }

    func setManualFocusLensPosition(_ requestedLensPosition: Float) {
        guard isManualFocusSupported else {
            captureHintText = "当前摄像头不支持手动对焦"
            return
        }
        guard !isFocusExposureLocked else {
            captureHintText = "AE/AF 锁定中，先长按解锁后再切 MF"
            return
        }
        guard !isPreviewInteractionTemporarilyRestricted else {
            captureHintText = previewInteractionRestrictedHintText
            return
        }
        let wasManualMode = focusControlMode == .manual
        let previousManualPosition = lastAppliedManualFocusPosition

        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard let device = self.currentVideoInput?.device else { return }
            guard device.isLockingFocusWithCustomLensPositionSupported else {
                DispatchQueue.main.async {
                    self.captureHintText = "当前摄像头不支持手动对焦"
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
                device.unlockForConfiguration()
                DispatchQueue.main.async {
                    self.currentManualFocusPosition = quantized
                    self.lastAppliedManualFocusPosition = quantized
                    self.focusControlMode = .manual
                    self.captureHintText = "MF \(self.manualFocusDisplayText)"
                }
            } catch {
                DispatchQueue.main.async {
                    self.captureHintText = "手动对焦失败"
                }
            }
        }
    }

    func restoreAutofocusMode() {
        guard !isPreviewInteractionTemporarilyRestricted else {
            captureHintText = previewInteractionRestrictedHintText
            return
        }
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
                let updatedLensPosition = device.lensPosition
                device.unlockForConfiguration()
                DispatchQueue.main.async {
                    self.focusControlMode = .auto
                    let quantized = self.quantizedManualFocusPosition(updatedLensPosition)
                    self.currentManualFocusPosition = quantized
                    self.lastAppliedManualFocusPosition = quantized
                    self.captureHintText = "已切回 AF"
                }
            } catch {
                DispatchQueue.main.async {
                    self.captureHintText = "恢复 AF 失败"
                }
            }
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
        let base = max(1.0, profile.baseZoomFactor)
        return max(1.0, currentZoomFactor / base)
    }

    var currentLensMaximumZoomMultiplier: CGFloat {
        guard let profile = selectedLensProfile else { return 1.0 }
        let base = max(1.0, profile.baseZoomFactor)
        let absoluteMax = max(base, maximumZoomFactor)
        return max(1.0, absoluteMax / base)
    }

    var lensZoomDialRange: ClosedRange<Double> {
        1.0...Double(currentLensMaximumZoomMultiplier)
    }

    var lensZoomDialValue: Double {
        Double(currentLensZoomMultiplier)
    }

    func setLensZoomDialValue(_ dialValue: Double) {
        setLensZoomMultiplier(CGFloat(dialValue))
    }

    func lensProfile(for focal: CaptureSemanticFocal) -> CaptureLensProfile? {
        availableLensProfiles.first(where: { $0.semanticFocal == focal })
    }

    var selectedSemanticFocal: CaptureSemanticFocal? {
        selectedLensProfile?.semanticFocal
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
            let base = max(1.0, profile.baseZoomFactor)
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
        setZoomFactor(targetZoom)
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
        setZoomFactor(next)
    }

    func setZoomFactor(_ requestedZoom: CGFloat) {
        guard !isSwitchingCamera, countdownSecondsRemaining == nil, !isBurstCapturing, quickPreviewImage == nil else {
            return
        }
        let clamped = max(minimumZoomFactor, min(maximumZoomFactor, requestedZoom))
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard let device = self.currentVideoInput?.device else { return }
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clamped
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
        focusMarker = CaptureFocusMarker(normalizedPoint: normalizedPoint, mode: .auto)
        applyFocusExposure(
            devicePoint: devicePoint,
            normalizedPoint: normalizedPoint,
            lockAfterFocus: false,
            source: .tap
        )
    }

    func handlePreviewLongPress(devicePoint: CGPoint, normalizedPoint: CGPoint) {
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
        resetLatestOriginalSaveState()
        resetLatestProcessedSaveState()
        latestPreservedSourceResult = nil
        confirmedStillPhotoResult = latestStillPhotoResult
        latestProcessingErrorText = nil
        isProcessingLatestResult = false
        latestProcessedResult = nil
        latestAcceptedProcessedResult = nil
        latestReadyForOutputProcessedResult = nil
        isOutputtingLatestReadyResult = false
        isLatestReadyResultOutputCompleted = false
        latestReadyOutputFailureText = nil
        captureHintText = "已设为直接使用，可继续拍摄或生成白底图"
        refreshStatusSummary()
        return true
    }

    func preserveLatestAsSourceMaterial() -> Bool {
        guard let latestStillPhotoResult else {
            captureHintText = "暂无可保留结果"
            return false
        }
        resetLatestOriginalSaveState()
        resetLatestProcessedSaveState()
        confirmedStillPhotoResult = nil
        latestProcessingErrorText = nil
        isProcessingLatestResult = false
        latestProcessedResult = nil
        latestAcceptedProcessedResult = nil
        latestReadyForOutputProcessedResult = nil
        isOutputtingLatestReadyResult = false
        isLatestReadyResultOutputCompleted = false
        latestReadyOutputFailureText = nil
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

        resetLatestOriginalSaveState()
        resetLatestProcessedSaveState()
        isProcessingLatestResult = true
        latestProcessingErrorText = nil
        latestProcessedResult = nil
        latestAcceptedProcessedResult = nil
        latestReadyForOutputProcessedResult = nil
        isOutputtingLatestReadyResult = false
        isLatestReadyResultOutputCompleted = false
        latestReadyOutputFailureText = nil
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
            captureHintText = "拍摄成功，可快速复核"
        }
        refreshStatusSummary()
        showQuickPreview(for: outputAdjustedResult)
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

        let targetPixelSize = selectedPixelPreset.outputPixelSize(for: targetRatio)
        let targetWidth = Int(targetPixelSize.width)
        let targetHeight = Int(targetPixelSize.height)
        if targetWidth > 1, targetHeight > 1,
           (workingCGImage.width != targetWidth || workingCGImage.height != targetHeight),
           let resizedCGImage = resizedCGImage(from: workingCGImage, to: targetPixelSize) {
            workingCGImage = resizedCGImage
            didMutateImage = true
        }

        var mergedMetadata = result.metadata
        mergedMetadata["capture_aspect_ratio"] = selectedAspectRatioPreset.displayText
        mergedMetadata["capture_aspect_ratio_value"] = String(format: "%.4f", selectedAspectRatioPreset.ratioValue)
        mergedMetadata["capture_pixel_preset"] = selectedPixelPreset.shortLabel
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
        try await withCheckedThrowingContinuation { continuation in
            guard self.isSessionConfigured else {
                continuation.resume(throwing: NSError(domain: "CaptureCameraRuntime", code: -2))
                return
            }

            let captureID = UUID()
            let settings = AVCapturePhotoSettings()

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
                    position: .back,
                    preferredDeviceType: .builtInWideAngleCamera
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
                self.currentVideoInput = input
                self.isSessionConfigured = true

                let frontAvailable = self.resolveCamera(position: .front) != nil
                let maxZoom = self.normalizedDeviceMaxZoom(for: backCamera)

                DispatchQueue.main.async {
                    self.activeCameraPosition = .back
                    self.activeCameraDeviceType = backCamera.deviceType
                    self.canSwitchCamera = frontAvailable
                    self.isFlashModeSupported = backCamera.hasFlash
                    self.minimumZoomFactor = 1.0
                    self.activeDeviceMaximumZoomFactor = maxZoom
                    self.maximumZoomFactor = maxZoom
                    self.currentZoomFactor = 1.0
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
        preferredLensID: String? = nil
    ) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let currentDeviceType = self.currentVideoInput?.device.deviceType
            let requiresDeviceTypeSwitch = self.activeCameraPosition == position
                && preferredDeviceType != nil
                && currentDeviceType != preferredDeviceType

            guard self.activeCameraPosition != position || requiresDeviceTypeSwitch else {
                DispatchQueue.main.async {
                    if let preferredLensID {
                        self.selectLensProfile(preferredLensID)
                    }
                    self.isSwitchingCamera = false
                }
                return
            }
            guard let camera = self.resolveCamera(position: position, preferredDeviceType: preferredDeviceType),
                  let newInput = try? AVCaptureDeviceInput(device: camera) else {
                DispatchQueue.main.async {
                    self.isSwitchingCamera = false
                    self.captureHintText = "摄像头切换失败"
                }
                return
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
                    self.captureHintText = "当前无法切换摄像头"
                }
                return
            }
            self.session.commitConfiguration()

            let maxZoom = self.normalizedDeviceMaxZoom(for: camera)
            do {
                try camera.lockForConfiguration()
                camera.videoZoomFactor = 1.0
                camera.unlockForConfiguration()
            } catch {
                // Keep minimum stable zoom.
            }

            DispatchQueue.main.async {
                self.isSwitchingCamera = false
                self.activeCameraPosition = position
                self.activeCameraDeviceType = camera.deviceType
                self.minimumZoomFactor = 1.0
                self.activeDeviceMaximumZoomFactor = maxZoom
                self.maximumZoomFactor = maxZoom
                self.currentZoomFactor = 1.0
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
                if !camera.hasFlash {
                    self.selectedFlashMode = .off
                }
                self.applyISOPreset(self.selectedISOPreset, shouldShowHint: false)
                self.applyShutterPreset(self.selectedShutterPreset, shouldShowHint: false)
                self.applyWhiteBalancePreset(self.selectedWhiteBalancePreset, shouldShowHint: false)
                if let selectedProfile = self.selectedLensProfile {
                    self.captureHintText = "已切换\(selectedProfile.displayText)"
                } else {
                    self.captureHintText = position == .back ? "已切换后摄" : "已切换前摄"
                }
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
        isISOPresetSupported = device.isExposureModeSupported(.custom)
        let minISO = device.activeFormat.minISO
        let maxISO = device.activeFormat.maxISO
        if maxISO > minISO {
            minimumISOValue = minISO
            maximumISOValue = maxISO
        } else {
            minimumISOValue = minISO
            maximumISOValue = max(minISO + 1, minISO)
        }

        let currentISO = clampedISOValue(device.iso, device: device)
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
        isShutterPresetSupported = device.isExposureModeSupported(.custom)
        let minSeconds = CMTimeGetSeconds(device.activeFormat.minExposureDuration)
        let maxSeconds = CMTimeGetSeconds(device.activeFormat.maxExposureDuration)
        if minSeconds.isFinite, maxSeconds.isFinite, minSeconds > 0, maxSeconds > 0 {
            minimumShutterDurationSeconds = min(minSeconds, maxSeconds)
            maximumShutterDurationSeconds = max(minSeconds, maxSeconds)
        } else {
            minimumShutterDurationSeconds = 1.0 / 1000.0
            maximumShutterDurationSeconds = 1.0 / 30.0
        }

        let seconds = CMTimeGetSeconds(device.exposureDuration)
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
            let legacyDuration = clampedShutterDuration(for: selectedShutterPreset, device: device)
            let legacySeconds = CMTimeGetSeconds(legacyDuration)
            if legacySeconds.isFinite, legacySeconds > 0 {
                currentManualShutterDurationSeconds = legacySeconds
            }
            selectedShutterPreset = .custom
        }
    }

    private func updateWhiteBalanceCapabilityState(with device: AVCaptureDevice) {
        isWhiteBalanceAutoSupported = device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance)
        isWhiteBalancePresetSupported = device.isLockingWhiteBalanceWithCustomDeviceGainsSupported
        let tempTint = device.temperatureAndTintValues(for: device.deviceWhiteBalanceGains)
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

    private func updateFocusCapabilityState(with device: AVCaptureDevice) {
        isManualFocusSupported = device.isLockingFocusWithCustomLensPositionSupported
        currentManualFocusPosition = quantizedManualFocusPosition(device.lensPosition)
        lastAppliedManualFocusPosition = currentManualFocusPosition
        focusControlMode = .auto
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
        setZoomFactor(targetZoom)
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

    private func discoverCameras(position: AVCaptureDevice.Position) -> [AVCaptureDevice] {
        let types: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera,
            .builtInUltraWideCamera,
            .builtInTelephotoCamera,
            .builtInTripleCamera,
            .builtInDualWideCamera,
            .builtInDualCamera
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
            return cameras.first(where: { $0.deviceType == .builtInWideAngleCamera })
                ?? cameras.first(where: { $0.deviceType == .builtInTripleCamera })
                ?? cameras.first(where: { $0.deviceType == .builtInDualWideCamera })
                ?? cameras.first(where: { $0.deviceType == .builtInDualCamera })
                ?? cameras.first(where: { $0.deviceType == .builtInUltraWideCamera })
                ?? cameras.first(where: { $0.deviceType == .builtInTelephotoCamera })
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
            "status=\(availability.statusText)"
        )
#endif
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

    private enum FocusExposureInteractionSource {
        case tap
        case longPress
        case unlockByLongPress
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
                let shouldPreserveManualShutter = !isShutterAutoSnapshot
                    && !lockAfterFocus
                    && !shouldPreserveExposureLock
                    && isISOAutoSnapshot
                let shouldPreserveManualISO = !isISOAutoSnapshot
                    && !lockAfterFocus
                    && !shouldPreserveExposureLock
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
                            self.focusMarker = CaptureFocusMarker(normalizedPoint: normalizedPoint, mode: .auto)
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
                        if !shouldPreserveManualISO {
                            self.selectedISOPreset = .auto
                        }
                        if !shouldPreserveManualShutter {
                            self.selectedShutterPreset = .auto
                        }
                        let feedbackMode: CaptureFocusMarker.Mode
                        switch source {
                        case .tap:
                            feedbackMode = .auto
                            self.captureHintText = self.isExposureLocked
                                ? "已更新对焦点（AE-L 生效）"
                                : "已设置对焦与测光点"
                        case .unlockByLongPress:
                            feedbackMode = .unlocked
                            self.captureHintText = "已解除锁定并重新对焦测光"
                        case .longPress:
                            feedbackMode = .auto
                            self.captureHintText = "已设置对焦与测光点"
                        }
                        self.focusMarker = CaptureFocusMarker(normalizedPoint: normalizedPoint, mode: feedbackMode)
                    }
                    self.hideFocusMarkerLaterIfNeeded()
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

extension CaptureCameraRuntime: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = CACurrentMediaTime()
        guard now - lastProductAutoExposureAnalysisAt >= productAutoExposureAnalysisInterval else { return }
        lastProductAutoExposureAnalysisAt = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let metrics = Self.productAutoExposureMetrics(from: pixelBuffer) else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.handleProductAutoExposureMetrics(metrics)
        }
    }

    private static func productAutoExposureMetrics(from pixelBuffer: CVPixelBuffer) -> ProductAutoExposureMetrics? {
        guard CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_32BGRA else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        guard width > 0, height > 0, bytesPerRow > 0 else { return nil }

        let sampleStride = max(1, min(width, height) / 96)
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)

        var sampleCount: Float = 0
        var lumaSum: Float = 0
        var highlightCount: Float = 0
        var clippedCount: Float = 0
        var shadowCount: Float = 0
        var nearWhiteCount: Float = 0
        var nearWhiteLumaSum: Float = 0

        for y in stride(from: 0, to: height, by: sampleStride) {
            let row = buffer + y * bytesPerRow
            for x in stride(from: 0, to: width, by: sampleStride) {
                let pixel = row + x * 4
                let blue = Float(pixel[0]) / 255.0
                let green = Float(pixel[1]) / 255.0
                let red = Float(pixel[2]) / 255.0
                let luma = 0.2126 * red + 0.7152 * green + 0.0722 * blue
                let channelMax = max(red, max(green, blue))
                let channelMin = min(red, min(green, blue))
                let saturation = channelMax - channelMin

                sampleCount += 1
                lumaSum += luma
                if luma > 0.92 { highlightCount += 1 }
                if luma > 0.98 { clippedCount += 1 }
                if luma < 0.20 { shadowCount += 1 }
                if luma > 0.65, saturation < 0.16 {
                    nearWhiteCount += 1
                    nearWhiteLumaSum += luma
                }
            }
        }

        guard sampleCount > 0 else { return nil }

        return ProductAutoExposureMetrics(
            meanLuma: lumaSum / sampleCount,
            highlightRatio: highlightCount / sampleCount,
            clippedRatio: clippedCount / sampleCount,
            shadowRatio: shadowCount / sampleCount,
            nearWhiteRatio: nearWhiteCount / sampleCount,
            nearWhiteMeanLuma: nearWhiteCount > 0 ? nearWhiteLumaSum / nearWhiteCount : 0
        )
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

                CaptureAspectRatioGuideOverlay(aspectRatio: cameraRuntime.previewAspectRatioValue)
                    .allowsHitTesting(false)

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
                    Text("AE/AF 锁定中")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.95))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.green.opacity(0.42), in: Capsule())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(.top, 46)
                        .padding(.leading, 14)
                        .allowsHitTesting(false)
                } else if cameraRuntime.isExposureLocked {
                    Text("AE 锁定中")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.95))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.blue.opacity(0.42), in: Capsule())
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
                    Text(burstProgressText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.95))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.55), in: Capsule())
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

private struct CaptureAspectRatioGuideOverlay: View {
    let aspectRatio: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let canvasSize = proxy.size
            let safeAspectRatio = max(0.01, aspectRatio)
            let targetFrame = fittedRect(for: canvasSize, targetRatio: safeAspectRatio)

            ZStack {
                Path { path in
                    path.addRect(CGRect(origin: .zero, size: canvasSize))
                    path.addRect(targetFrame)
                }
                .fill(
                    .black.opacity(0.28),
                    style: FillStyle(eoFill: true, antialiased: true)
                )

                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(.white.opacity(0.07), lineWidth: 0.6)
                    .frame(width: targetFrame.width, height: targetFrame.height)
                    .position(x: targetFrame.midX, y: targetFrame.midY)
            }
        }
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
    let onTapPreview: (CGPoint, CGPoint) -> Void
    let onLongPressPreview: (CGPoint, CGPoint) -> Void

    func makeUIView(context: Context) -> PreviewContainerUIView {
        let view = PreviewContainerUIView()
        view.previewLayer.videoGravity = .resizeAspectFill
        view.onTapPreview = onTapPreview
        view.onLongPressPreview = onLongPressPreview
        view.previewLayer.session = session
        return view
    }

    func updateUIView(_ uiView: PreviewContainerUIView, context: Context) {
        uiView.onTapPreview = onTapPreview
        uiView.onLongPressPreview = onLongPressPreview
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
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
            .stroke(Color.white.opacity(0.34), lineWidth: 0.8)
        }
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
        let strokeColor = isNearLevelVisual ? Color.green.opacity(0.92) : Color.white.opacity(0.82)
        return ZStack {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(strokeColor.opacity(0.92))
                    .frame(width: 1.4, height: 8)
                Rectangle()
                    .fill(strokeColor)
                    .frame(width: 96, height: 2)
                    .overlay(alignment: .center) {
                        Rectangle()
                            .fill(strokeColor)
                            .frame(width: 1.6, height: 8)
                    }
                Rectangle()
                    .fill(strokeColor.opacity(0.92))
                    .frame(width: 1.4, height: 8)
            }
            .rotationEffect(.degrees(-smoothedUprightTiltDegrees))
            .rotationEffect(.degrees(-uprightBaseRotationDegrees))
            .shadow(color: strokeColor.opacity(isNearLevelVisual ? 0.32 : 0.12), radius: isNearLevelVisual ? 4 : 1.5)
        }
    }

    private var flatGuide: some View {
        let dynamicColor = isNearLevelVisual ? Color.green.opacity(0.94) : Color.white.opacity(0.86)
        return ZStack {
            crossSymbol(color: .white.opacity(0.34), lineWidth: 1, size: 24)

            crossSymbol(color: dynamicColor, lineWidth: 1.4, size: 24)
                .offset(smoothedCrossOffset)
                .shadow(color: dynamicColor.opacity(isNearLevelVisual ? 0.24 : 0.08), radius: isNearLevelVisual ? 4 : 1.5)
        }
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

    var body: some View {
        GeometryReader { proxy in
            let point = CGPoint(
                x: normalizedPoint.x * proxy.size.width,
                y: normalizedPoint.y * proxy.size.height
            )
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(strokeColor.opacity(0.95), lineWidth: 1.5)
                    .frame(width: 74, height: 74)
                    .shadow(color: strokeColor.opacity(0.35), radius: 5, x: 0, y: 0)

                if mode == .locked {
                    Image(systemName: "lock.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.95))
                        .padding(4)
                        .background(.green.opacity(0.72), in: Circle())
                        .offset(x: 0, y: -50)
                } else if mode == .unlocked {
                    Image(systemName: "lock.open.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.95))
                        .padding(4)
                        .background(.blue.opacity(0.72), in: Circle())
                        .offset(x: 0, y: -50)
                }
            }
            .position(point)
        }
    }

    private var strokeColor: Color {
        switch mode {
        case .auto:
            return .yellow
        case .locked:
            return .green
        case .unlocked:
            return .blue
        }
    }
}

private struct CaptureCountdownOverlay: View {
    let remainingSeconds: Int

    var body: some View {
        ZStack {
            Circle()
                .fill(.black.opacity(0.45))
                .frame(width: 86, height: 86)
            Text("\(remainingSeconds)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}

private struct CaptureQuickPreviewOverlay: View {
    let image: UIImage

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("拍后快速预览")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.88))

            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(8)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

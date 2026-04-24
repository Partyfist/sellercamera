//
//  WhiteBackgroundBaselineSupport.swift
//  SellerCamera
//
//  Created by Codex on 2026/4/18.
//

import Darwin
import Foundation
import UIKit

enum WhiteBackgroundProblemTag: String, CaseIterable, Codable {
    case edgeGrayFringe = "edge_gray_fringe"
    case edgeContamination = "edge_contamination"
    case foregroundWashout = "foreground_washout"
    case smallTextLoss = "small_text_loss"
    case thinStructureLoss = "thin_structure_loss"
    case contactEdgeAbnormal = "contact_edge_abnormal"
    case backgroundResidual = "background_residual"
    case whiteBackgroundImpure = "white_background_impure"
    case globalHaze = "global_haze"
    case hardCaseFallbackAcceptable = "hard_case_fallback_acceptable"
    case hardCaseFallbackUnacceptable = "hard_case_fallback_unacceptable"
}

struct WhiteBackgroundBaselineSample: Codable, Hashable {
    let sampleID: String
    let sourceFileName: String
    let tags: [WhiteBackgroundProblemTag]
    let note: String?

    enum CodingKeys: String, CodingKey {
        case sampleID = "sample_id"
        case sourceFileName = "source_file_name"
        case tags
        case note
    }
}

struct WhiteBackgroundBaselineManifest: Codable {
    let version: Int
    let suiteName: String
    let samples: [WhiteBackgroundBaselineSample]

    enum CodingKeys: String, CodingKey {
        case version
        case suiteName = "suite_name"
        case samples
    }
}

struct WhiteBackgroundBaselineEnvironmentSnapshot: Codable {
    let deviceModel: String
    let deviceName: String
    let systemVersion: String
    let appVersion: String
}

struct WhiteBackgroundBaselineRunRecord: Codable {
    let schemaVersion: Int
    let recordedAtISO8601: String
    let sampleID: String
    let sourceStillPhotoID: String
    let processedPhotoID: String
    let captureSource: String
    let environment: WhiteBackgroundBaselineEnvironmentSnapshot
    let metadata: [String: String]
}

enum WhiteBackgroundBaselineRecorder {
    private static let enableFlag = "SELLERCAMERA_BASELINE_RECORD"
    private static let segmentationProviderFlag = "SELLERCAMERA_SEGMENTATION_PROVIDER"
    private static let outputFolderName = "WhiteBackgroundBaselineRuns"

    static var currentEnvironmentSnapshot: WhiteBackgroundBaselineEnvironmentSnapshot {
        WhiteBackgroundBaselineEnvironmentSnapshot(
            deviceModel: hardwareIdentifier(),
            deviceName: UIDevice.current.model,
            systemVersion: UIDevice.current.systemVersion,
            appVersion: appVersionText()
        )
    }

    static func recordIfEnabled(
        sourceStillPhoto: CaptureStillPhotoResult,
        processedResult: CaptureProcessedPhotoResult
    ) {
        guard isEnabled else { return }
        let sampleID = resolveSampleID(from: sourceStillPhoto)
        let record = WhiteBackgroundBaselineRunRecord(
            schemaVersion: 1,
            recordedAtISO8601: iso8601Now(),
            sampleID: sampleID,
            sourceStillPhotoID: sourceStillPhoto.id.uuidString,
            processedPhotoID: processedResult.id.uuidString,
            captureSource: sourceStillPhoto.source.rawValue,
            environment: currentEnvironmentSnapshot,
            metadata: processedResult.metadata
        )
        try? append(record: record)
    }

    static func recordFailureIfEnabled(
        sampleID: String,
        captureSource: String,
        error: Error,
        suiteName: String,
        stage: String,
        providerHint: String?
    ) {
        guard isEnabled else { return }
        let nsError = error as NSError
        var metadata: [String: String] = [
            "quality_level": "failed",
            "hard_case_signal": "unknown",
            "baseline_autorun_state": "failed",
            "baseline_failure_stage": stage,
            "baseline_failure_domain": nsError.domain,
            "baseline_failure_code": String(nsError.code),
            "baseline_failure_description": nsError.localizedDescription,
            "baseline_suite_name": suiteName
        ]
        let provider = providerHint?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let provider, !provider.isEmpty {
            metadata["segmentation_provider"] = provider
        } else {
            metadata["segmentation_provider"] = ProcessInfo.processInfo.environment[segmentationProviderFlag] ?? "vision"
        }
        let record = WhiteBackgroundBaselineRunRecord(
            schemaVersion: 1,
            recordedAtISO8601: iso8601Now(),
            sampleID: sampleID,
            sourceStillPhotoID: "failed-\(sampleID)",
            processedPhotoID: "failed-\(sampleID)",
            captureSource: captureSource,
            environment: currentEnvironmentSnapshot,
            metadata: metadata
        )
        try? append(record: record)
    }

    private static var isEnabled: Bool {
        ProcessInfo.processInfo.environment[enableFlag] == "1"
    }

    private static func resolveSampleID(from sourceStillPhoto: CaptureStillPhotoResult) -> String {
        if let explicit = sourceStillPhoto.metadata["baseline_sample_id"], !explicit.isEmpty {
            return explicit
        }
        return "still-\(sourceStillPhoto.id.uuidString)"
    }

    private static func append(record: WhiteBackgroundBaselineRunRecord) throws {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let outputFolderURL = documentsURL.appendingPathComponent(outputFolderName, isDirectory: true)
        try fileManager.createDirectory(at: outputFolderURL, withIntermediateDirectories: true)

        let fileURL = outputFolderURL.appendingPathComponent("baseline-\(dateStamp()).jsonl")
        if !fileManager.fileExists(atPath: fileURL.path) {
            _ = fileManager.createFile(atPath: fileURL.path, contents: nil)
        }
        let encoded = try JSONEncoder().encode(record)
        guard var line = String(data: encoded, encoding: .utf8) else { return }
        line.append("\n")
        guard let lineData = line.data(using: .utf8) else { return }

        let handle = try FileHandle(forWritingTo: fileURL)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: lineData)
    }

    private static func dateStamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: Date())
    }

    private static func iso8601Now() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    private static func appVersionText() -> String {
        let info = Bundle.main.infoDictionary
        let shortVersion = info?["CFBundleShortVersionString"] as? String ?? "unknown"
        let buildVersion = info?["CFBundleVersion"] as? String ?? "unknown"
        return "\(shortVersion)(\(buildVersion))"
    }

    private static func hardwareIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        return mirror.children.reduce(into: "") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            identifier.append(String(UnicodeScalar(UInt8(value))))
        }
    }
}

@MainActor
enum WhiteBackgroundBaselineAutorun {
    private static let enableFlag = "SELLERCAMERA_BASELINE_AUTORUN_SUITE"
    private static let defaultManifestFileName = "sample_manifest.core_v1"
    private static let fallbackManifestFileName = "sample_manifest.template"
    private static var hasStarted = false

    static func triggerIfNeeded() {
        guard !hasStarted else { return }
        guard let suiteName = ProcessInfo.processInfo.environment[enableFlag], !suiteName.isEmpty else { return }
        hasStarted = true

        Task.detached(priority: .utility) {
            await runSuite(named: suiteName)
        }
    }

    private static func runSuite(named suiteName: String) async {
        guard #available(iOS 17.0, *) else {
            print("[BaselineAutorun] iOS version unsupported for white background processing.")
            return
        }
        do {
            let manifest = try loadManifest(preferredSuiteName: suiteName)
            print("[BaselineAutorun] suite=\(manifest.suiteName), samples=\(manifest.samples.count)")

            for (index, sample) in manifest.samples.enumerated() {
                do {
                    let still = try makeStillPhoto(from: sample)
                    do {
                        let processed = try await CaptureWhiteBackgroundProcessor.process(confirmedStillPhoto: still)
                        WhiteBackgroundBaselineRecorder.recordIfEnabled(
                            sourceStillPhoto: still,
                            processedResult: processed
                        )
                        print("[BaselineAutorun] \(index + 1)/\(manifest.samples.count) OK \(sample.sampleID)")
                    } catch {
                        WhiteBackgroundBaselineRecorder.recordFailureIfEnabled(
                            sampleID: sample.sampleID,
                            captureSource: still.source.rawValue,
                            error: error,
                            suiteName: manifest.suiteName,
                            stage: "processing",
                            providerHint: still.metadata["baseline_segmentation_provider"]
                        )
                        print("[BaselineAutorun] \(index + 1)/\(manifest.samples.count) FAILED \(sample.sampleID): \(error)")
                    }
                } catch {
                    WhiteBackgroundBaselineRecorder.recordFailureIfEnabled(
                        sampleID: sample.sampleID,
                        captureSource: "photoLibrary",
                        error: error,
                        suiteName: manifest.suiteName,
                        stage: "input",
                        providerHint: baselineSegmentationProviderOverride()
                    )
                    print("[BaselineAutorun] \(index + 1)/\(manifest.samples.count) FAILED \(sample.sampleID): \(error)")
                }
            }
            print("[BaselineAutorun] suite finished.")
        } catch {
            print("[BaselineAutorun] failed to run suite \(suiteName): \(error)")
        }
    }

    private static func loadManifest(preferredSuiteName: String) throws -> WhiteBackgroundBaselineManifest {
        let bundle = Bundle.main
        let candidateResourceNames = manifestResourceCandidates(for: preferredSuiteName)
        var defaultManifest: WhiteBackgroundBaselineManifest?
        for candidateName in candidateResourceNames {
            guard let candidateURL = bundle.url(forResource: candidateName, withExtension: "json") else {
                continue
            }
            let data = try Data(contentsOf: candidateURL)
            let manifest = try JSONDecoder().decode(WhiteBackgroundBaselineManifest.self, from: data)
            if manifest.suiteName == preferredSuiteName {
                return manifest
            }
            if candidateName == defaultManifestFileName {
                defaultManifest = manifest
                continue
            }
            if candidateName != fallbackManifestFileName {
                return manifest
            }
        }
        if let defaultManifest {
            return defaultManifest
        }
        throw NSError(domain: "WhiteBackgroundBaselineAutorun", code: -1, userInfo: [
            NSLocalizedDescriptionKey: "Manifest for suite \(preferredSuiteName) not found in bundle."
        ])
    }

    private static func manifestResourceCandidates(for preferredSuiteName: String) -> [String] {
        var names: [String] = []
        names.append("sample_manifest.\(preferredSuiteName)")
        names.append("sample_manifest.\(preferredSuiteName.replacingOccurrences(of: "-", with: "_"))")

        if preferredSuiteName.hasPrefix("whitebg-vision-") {
            let suffix = String(preferredSuiteName.dropFirst("whitebg-vision-".count))
            names.append("sample_manifest.\(suffix)")
            names.append("sample_manifest.\(suffix.replacingOccurrences(of: "-", with: "_"))")
        }
        if preferredSuiteName.hasPrefix("whitebg-") {
            let suffix = String(preferredSuiteName.dropFirst("whitebg-".count))
            names.append("sample_manifest.\(suffix)")
            names.append("sample_manifest.\(suffix.replacingOccurrences(of: "-", with: "_"))")
        }

        names.append(defaultManifestFileName)
        names.append(fallbackManifestFileName)

        var seen = Set<String>()
        return names.filter { seen.insert($0).inserted }
    }

    private static func makeStillPhoto(from sample: WhiteBackgroundBaselineSample) throws -> CaptureStillPhotoResult {
        guard let sampleURL = Bundle.main.url(forResource: sample.sourceFileName, withExtension: nil) else {
            throw NSError(domain: "WhiteBackgroundBaselineAutorun", code: -2, userInfo: [
                NSLocalizedDescriptionKey: "Sample file not found in bundle: \(sample.sourceFileName)"
            ])
        }
        let imageData = try Data(contentsOf: sampleURL)
        guard let image = UIImage(data: imageData) else {
            throw NSError(domain: "WhiteBackgroundBaselineAutorun", code: -3, userInfo: [
                NSLocalizedDescriptionKey: "Sample decode failed: \(sample.sourceFileName)"
            ])
        }
        return CaptureStillPhotoResult(
            source: .photoLibrary,
            imageData: imageData,
            pixelSize: image.size,
            metadata: makeStillMetadata(sampleID: sample.sampleID)
        )
    }

    private static func makeStillMetadata(sampleID: String) -> [String: String] {
        var metadata: [String: String] = [
            "baseline_sample_id": sampleID
        ]
        if let provider = baselineSegmentationProviderOverride(), !provider.isEmpty {
            metadata["baseline_segmentation_provider"] = provider
        }
        return metadata
    }

    private static func baselineSegmentationProviderOverride() -> String? {
        ProcessInfo.processInfo.environment["SELLERCAMERA_SEGMENTATION_PROVIDER"]
    }
}

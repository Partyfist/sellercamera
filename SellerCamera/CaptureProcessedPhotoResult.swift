//
//  CaptureProcessedPhotoResult.swift
//  SellerCamera
//
//  Created by Codex on 2026/4/1.
//

import CoreGraphics
import Foundation

struct CaptureProcessedPhotoResult: Identifiable {
    let id: UUID
    let sourceStillPhotoID: UUID
    let processedAt: Date
    let imageData: Data
    let byteCount: Int
    let pixelSize: CGSize?
    let metadata: [String: String]

    nonisolated init(
        id: UUID = UUID(),
        sourceStillPhotoID: UUID,
        processedAt: Date = Date(),
        imageData: Data,
        pixelSize: CGSize?,
        metadata: [String: String]
    ) {
        self.id = id
        self.sourceStillPhotoID = sourceStillPhotoID
        self.processedAt = processedAt
        self.imageData = imageData
        self.byteCount = imageData.count
        self.pixelSize = pixelSize
        self.metadata = metadata
    }
}

extension CaptureProcessedPhotoResult {
    private static let processedAtFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private static let byteSizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.includesCount = true
        formatter.isAdaptive = true
        return formatter
    }()

    var processedAtDisplayText: String {
        Self.processedAtFormatter.string(from: processedAt)
    }

    var resolutionDisplayText: String {
        if let pixelSize {
            return "\(Int(pixelSize.width))×\(Int(pixelSize.height))"
        }
        return "暂无"
    }

    var byteSizeDisplayText: String {
        Self.byteSizeFormatter.string(fromByteCount: Int64(byteCount))
    }

    var qualityLevelDisplayText: String {
        switch metadata["quality_level"] {
        case "ready":
            return "可直接使用"
        case "review":
            return "建议复核"
        case "risk":
            return "风险较高"
        default:
            return "待复核"
        }
    }

    var qualityHintDisplayText: String {
        metadata["quality_hint"] ?? "白底结果可复核后使用"
    }

    var hardCaseHintDisplayText: String? {
        guard let rawSignal = metadata["hard_case_signal"], rawSignal != "stable" else {
            return nil
        }
        return metadata["hard_case_hint"] ?? "边缘复杂，建议复核"
    }
}

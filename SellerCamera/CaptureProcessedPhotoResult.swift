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
    private enum QualityLevel: String {
        case ready
        case review
        case risk
    }

    private enum HardCaseSignal: String {
        case stable
        case foregroundWashout
        case darkEdgeWashout
        case hardEdgeInstability
        case fringeEdge
        case highlightCutEdge
        case thinDetailEdge
        case softEdge
    }

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
        case QualityLevel.ready.rawValue:
            return "可直接使用"
        case QualityLevel.review.rawValue:
            return "建议复核"
        case QualityLevel.risk.rawValue:
            return "风险较高"
        default:
            return "待复核"
        }
    }

    var qualityHintDisplayText: String {
        if let hint = metadata["quality_hint"], !hint.isEmpty {
            return hint
        }
        switch metadata["quality_level"].flatMap(QualityLevel.init(rawValue:)) {
        case .ready:
            return "白底质量可直接使用"
        case .review:
            return "白底边缘建议复核"
        case .risk:
            return "白底风险较高，建议补拍"
        case .none:
            return "白底结果可复核后使用"
        }
    }

    var hardCaseHintDisplayText: String? {
        if let hint = metadata["hard_case_hint"], !hint.isEmpty {
            return hint
        }
        guard let rawSignal = metadata["hard_case_signal"],
              let signal = HardCaseSignal(rawValue: rawSignal),
              signal != .stable else {
            return nil
        }
        switch signal {
        case .stable:
            return nil
        case .foregroundWashout:
            return "主体有泛白风险，建议复核"
        case .darkEdgeWashout:
            return "深色边缘有发灰风险，建议复核"
        case .hardEdgeInstability:
            return "硬边连续性风险，建议复核"
        case .fringeEdge:
            return "边缘有溢色风险，建议复核"
        case .highlightCutEdge:
            return "反光边界风险，建议复核"
        case .thinDetailEdge:
            return "细边缘易丢失，建议复核"
        case .softEdge:
            return "软边缘/弱透明风险"
        }
    }
}

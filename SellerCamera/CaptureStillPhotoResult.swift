//
//  CaptureStillPhotoResult.swift
//  SellerCamera
//
//  Created by Codex on 2026/3/31.
//

import CoreGraphics
import Foundation

enum CaptureStillPhotoSource: String {
    case camera
    case photoLibrary

    var displayText: String {
        switch self {
        case .camera:
            return "相机拍摄"
        case .photoLibrary:
            return "相册导入"
        }
    }
}

struct CaptureStillPhotoResult: Identifiable {
    let id: UUID
    let source: CaptureStillPhotoSource
    let capturedAt: Date
    let imageData: Data
    let byteCount: Int
    let pixelSize: CGSize?
    let metadata: [String: String]

    init(
        id: UUID = UUID(),
        source: CaptureStillPhotoSource = .camera,
        capturedAt: Date = Date(),
        imageData: Data,
        pixelSize: CGSize?,
        metadata: [String: String]
    ) {
        self.id = id
        self.source = source
        self.capturedAt = capturedAt
        self.imageData = imageData
        self.byteCount = imageData.count
        self.pixelSize = pixelSize
        self.metadata = metadata
    }
}

extension CaptureStillPhotoResult {
    private static let capturedAtFormatter: DateFormatter = {
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

    var capturedAtDisplayText: String {
        Self.capturedAtFormatter.string(from: capturedAt)
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
}

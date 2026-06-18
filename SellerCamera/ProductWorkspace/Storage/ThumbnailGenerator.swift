//
//  ThumbnailGenerator.swift
//  SellerCamera
//
//  Created by Codex on 2026/6/18.
//

import Foundation
import ImageIO
import UniformTypeIdentifiers

nonisolated final class ThumbnailGenerator {
    func generateThumbnailJPEGData(from data: Data, maxPixelDimension: Int = 512) async throws -> Data {
        try await Task.detached(priority: .utility) {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
                throw ProductWorkspaceError.unsupportedFileFormat
            }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelDimension
            ]
            guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                throw ProductWorkspaceError.unsupportedFileFormat
            }

            let outputData = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(
                outputData,
                UTType.jpeg.identifier as CFString,
                1,
                nil
            ) else {
                throw ProductWorkspaceError.fileWriteFailed("thumbnail")
            }

            let destinationOptions: [CFString: Any] = [
                kCGImageDestinationLossyCompressionQuality: 0.82
            ]
            CGImageDestinationAddImage(destination, thumbnail, destinationOptions as CFDictionary)
            guard CGImageDestinationFinalize(destination) else {
                throw ProductWorkspaceError.fileWriteFailed("thumbnail")
            }
            return outputData as Data
        }.value
    }
}

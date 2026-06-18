//
//  ProjectAsset.swift
//  SellerCamera
//
//  Created by Codex on 2026/6/18.
//

import Foundation

nonisolated enum CaptureCategory: String, Codable, CaseIterable, Equatable {
    case standard
    case detail
    case sku
    case video

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue {
        case "whiteBackground", "white", "white_background":
            self = .sku
        default:
            guard let value = CaptureCategory(rawValue: rawValue) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unsupported capture category: \(rawValue)"
                )
            }
            self = value
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

nonisolated enum ProjectAssetType: String, Codable, CaseIterable, Equatable {
    case photo
    case video
    case thumbnail
    case processedImage
    case export
}

nonisolated enum AssetOrigin: String, Codable, CaseIterable, Equatable {
    case camera
    case photoLibrary
    case importedFile
    case generated
    case externalAI
}

nonisolated struct ProjectAsset: Identifiable, Codable, Equatable {
    var id: UUID
    var schemaVersion: Int
    var projectID: UUID
    var category: CaptureCategory
    var mediaType: ProjectAssetType
    var origin: AssetOrigin
    var originalFilename: String?
    var relativePath: String
    var thumbnailRelativePath: String?
    var createdAt: Date
    var updatedAt: Date
    var width: Int?
    var height: Int?
    var duration: Double?
    var fileSize: Int64?
    var isFavorite: Bool
    var isDeleted: Bool
    var version: Int
    var parentAssetID: UUID?
    var skuID: UUID?

    var assetType: ProjectAssetType {
        get { mediaType }
        set { mediaType = newValue }
    }

    init(
        id: UUID = UUID(),
        schemaVersion: Int = 1,
        projectID: UUID,
        category: CaptureCategory,
        assetType: ProjectAssetType = .photo,
        origin: AssetOrigin = .camera,
        originalFilename: String? = nil,
        relativePath: String,
        thumbnailRelativePath: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        width: Int? = nil,
        height: Int? = nil,
        duration: Double? = nil,
        fileSize: Int64? = nil,
        isFavorite: Bool = false,
        isDeleted: Bool = false,
        version: Int = 1,
        parentAssetID: UUID? = nil,
        skuID: UUID? = nil
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.projectID = projectID
        self.category = category
        self.mediaType = assetType
        self.origin = origin
        self.originalFilename = originalFilename
        self.relativePath = relativePath
        self.thumbnailRelativePath = thumbnailRelativePath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.width = width
        self.height = height
        self.duration = duration
        self.fileSize = fileSize
        self.isFavorite = isFavorite
        self.isDeleted = isDeleted
        self.version = version
        self.parentAssetID = parentAssetID
        self.skuID = skuID
    }
}

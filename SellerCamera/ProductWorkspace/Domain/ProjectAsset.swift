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

nonisolated enum ProjectAssetMediaType: String, Codable, CaseIterable, Equatable {
    case photo
    case video
}

nonisolated enum ProjectAssetSourceType: String, Codable, CaseIterable, Equatable {
    case camera
    case photoLibrary
    case fileImport
    case generated
    case external
}

nonisolated enum AssetDeletionState: String, Codable, CaseIterable, Equatable {
    case active
    case trashed
}

nonisolated enum AssetRole: String, Codable, CaseIterable, Equatable {
    case original
    case processed
    case generated
    case export
}

nonisolated enum AssetProcessingState: String, Codable, CaseIterable, Equatable {
    case original
    case pending
    case processing
    case completed
    case failed
}

nonisolated enum AssetFilter: Equatable {
    case all
    case category(CaptureCategory)
    case photo
    case video
    case favorite
    case best
    case trash
}

nonisolated enum AssetSort: Equatable {
    case newest
    case oldest
    case filename
    case fileSize
}

nonisolated struct ProjectAsset: Identifiable, Codable, Equatable {
    var id: UUID
    var schemaVersion: Int
    var projectID: UUID
    var category: CaptureCategory
    var mediaType: ProjectAssetMediaType
    var sourceType: ProjectAssetSourceType
    var originalFilename: String?
    var relativePath: String
    var thumbnailRelativePath: String?
    var createdAt: Date
    var importedAt: Date?
    var updatedAt: Date
    var pixelWidth: Int?
    var pixelHeight: Int?
    var durationSeconds: Double?
    var fileSizeBytes: Int64?
    var isFavorite: Bool
    var isBest: Bool
    var isDeleted: Bool
    var deletionState: AssetDeletionState
    var deletedAt: Date?
    var parentAssetID: UUID?
    var rootAssetID: UUID?
    var assetRole: AssetRole
    var processingState: AssetProcessingState
    var versionNumber: Int
    var skuID: UUID?

    var assetType: ProjectAssetType {
        get {
            switch mediaType {
            case .photo:
                return .photo
            case .video:
                return .video
            }
        }
        set {
            mediaType = newValue == .video ? .video : .photo
        }
    }

    var origin: AssetOrigin {
        get {
            switch sourceType {
            case .camera:
                return .camera
            case .photoLibrary:
                return .photoLibrary
            case .fileImport:
                return .importedFile
            case .generated:
                return .generated
            case .external:
                return .externalAI
            }
        }
        set {
            sourceType = ProjectAssetSourceType(origin: newValue)
        }
    }

    var width: Int? {
        get { pixelWidth }
        set { pixelWidth = newValue }
    }

    var height: Int? {
        get { pixelHeight }
        set { pixelHeight = newValue }
    }

    var duration: Double? {
        get { durationSeconds }
        set { durationSeconds = newValue }
    }

    var fileSize: Int64? {
        get { fileSizeBytes }
        set { fileSizeBytes = newValue }
    }

    var version: Int {
        get { versionNumber }
        set { versionNumber = newValue }
    }

    init(
        id: UUID = UUID(),
        schemaVersion: Int = 2,
        projectID: UUID,
        category: CaptureCategory,
        assetType: ProjectAssetType = .photo,
        origin: AssetOrigin = .camera,
        mediaType: ProjectAssetMediaType? = nil,
        sourceType: ProjectAssetSourceType? = nil,
        originalFilename: String? = nil,
        relativePath: String,
        thumbnailRelativePath: String? = nil,
        createdAt: Date = Date(),
        importedAt: Date? = nil,
        updatedAt: Date = Date(),
        width: Int? = nil,
        height: Int? = nil,
        duration: Double? = nil,
        fileSize: Int64? = nil,
        isFavorite: Bool = false,
        isBest: Bool = false,
        isDeleted: Bool = false,
        deletionState: AssetDeletionState? = nil,
        deletedAt: Date? = nil,
        version: Int = 1,
        parentAssetID: UUID? = nil,
        rootAssetID: UUID? = nil,
        assetRole: AssetRole = .original,
        processingState: AssetProcessingState = .original,
        skuID: UUID? = nil
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.projectID = projectID
        self.category = category
        self.mediaType = mediaType ?? ProjectAssetMediaType(assetType: assetType)
        self.sourceType = sourceType ?? ProjectAssetSourceType(origin: origin)
        self.originalFilename = originalFilename
        self.relativePath = relativePath
        self.thumbnailRelativePath = thumbnailRelativePath
        self.createdAt = createdAt
        self.importedAt = importedAt
        self.updatedAt = updatedAt
        self.pixelWidth = width
        self.pixelHeight = height
        self.durationSeconds = duration
        self.fileSizeBytes = fileSize
        self.isFavorite = isFavorite
        self.isBest = isBest
        self.isDeleted = isDeleted
        self.deletionState = deletionState ?? (isDeleted ? .trashed : .active)
        self.deletedAt = deletedAt
        self.parentAssetID = parentAssetID
        self.rootAssetID = rootAssetID ?? id
        self.assetRole = assetRole
        self.processingState = processingState
        self.versionNumber = version
        self.skuID = skuID
    }
}

extension ProjectAssetMediaType {
    nonisolated init(assetType: ProjectAssetType) {
        self = assetType == .video ? .video : .photo
    }
}

extension ProjectAssetSourceType {
    nonisolated init(origin: AssetOrigin) {
        switch origin {
        case .camera:
            self = .camera
        case .photoLibrary:
            self = .photoLibrary
        case .importedFile:
            self = .fileImport
        case .generated:
            self = .generated
        case .externalAI:
            self = .external
        }
    }
}

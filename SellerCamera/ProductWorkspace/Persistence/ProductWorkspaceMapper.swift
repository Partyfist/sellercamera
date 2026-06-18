//
//  ProductWorkspaceMapper.swift
//  SellerCamera
//
//  Created by Codex on 2026/6/18.
//

import Foundation

nonisolated struct ProductProjectRecord: Codable, Equatable {
    var id: UUID
    var schemaVersion: Int
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var status: ProjectStatus
    var coverAssetID: UUID?
    var isArchived: Bool
    var sortOrder: Int?
    var lastSelectedCaptureCategory: CaptureCategory?

    init(
        id: UUID,
        schemaVersion: Int,
        name: String,
        createdAt: Date,
        updatedAt: Date,
        status: ProjectStatus,
        coverAssetID: UUID?,
        isArchived: Bool,
        sortOrder: Int?,
        lastSelectedCaptureCategory: CaptureCategory?
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.status = status
        self.coverAssetID = coverAssetID
        self.isArchived = isArchived
        self.sortOrder = sortOrder
        self.lastSelectedCaptureCategory = lastSelectedCaptureCategory
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        name = try container.decode(String.self, forKey: .name)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        status = try container.decodeIfPresent(ProjectStatus.self, forKey: .status) ?? .active
        coverAssetID = try container.decodeIfPresent(UUID.self, forKey: .coverAssetID)
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? (status == .archived)
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder)
        lastSelectedCaptureCategory = try container.decodeIfPresent(CaptureCategory.self, forKey: .lastSelectedCaptureCategory)
    }
}

nonisolated struct ProjectAssetRecord: Codable, Equatable {
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

    enum CodingKeys: String, CodingKey {
        case id
        case schemaVersion
        case projectID
        case category
        case mediaType
        case assetType
        case sourceType
        case origin
        case originalFilename
        case relativePath
        case thumbnailRelativePath
        case createdAt
        case importedAt
        case updatedAt
        case pixelWidth
        case pixelHeight
        case width
        case height
        case durationSeconds
        case duration
        case fileSizeBytes
        case fileSize
        case isFavorite
        case isBest
        case isDeleted
        case deletionState
        case deletedAt
        case version
        case parentAssetID
        case rootAssetID
        case assetRole
        case processingState
        case versionNumber
        case skuID
    }

    init(
        id: UUID,
        schemaVersion: Int,
        projectID: UUID,
        category: CaptureCategory,
        mediaType: ProjectAssetMediaType,
        sourceType: ProjectAssetSourceType,
        originalFilename: String?,
        relativePath: String,
        thumbnailRelativePath: String?,
        createdAt: Date,
        importedAt: Date?,
        updatedAt: Date,
        pixelWidth: Int?,
        pixelHeight: Int?,
        durationSeconds: Double?,
        fileSizeBytes: Int64?,
        isFavorite: Bool,
        isBest: Bool,
        isDeleted: Bool,
        deletionState: AssetDeletionState,
        deletedAt: Date?,
        parentAssetID: UUID?,
        rootAssetID: UUID?,
        assetRole: AssetRole,
        processingState: AssetProcessingState,
        versionNumber: Int,
        skuID: UUID?
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.projectID = projectID
        self.category = category
        self.mediaType = mediaType
        self.sourceType = sourceType
        self.originalFilename = originalFilename
        self.relativePath = relativePath
        self.thumbnailRelativePath = thumbnailRelativePath
        self.createdAt = createdAt
        self.importedAt = importedAt
        self.updatedAt = updatedAt
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.durationSeconds = durationSeconds
        self.fileSizeBytes = fileSizeBytes
        self.isFavorite = isFavorite
        self.isBest = isBest
        self.isDeleted = isDeleted
        self.deletionState = deletionState
        self.deletedAt = deletedAt
        self.parentAssetID = parentAssetID
        self.rootAssetID = rootAssetID
        self.assetRole = assetRole
        self.processingState = processingState
        self.versionNumber = versionNumber
        self.skuID = skuID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        let decodedSchemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        schemaVersion = max(decodedSchemaVersion, 2)
        projectID = try container.decode(UUID.self, forKey: .projectID)
        category = try container.decode(CaptureCategory.self, forKey: .category)
        if let decodedMediaType = try container.decodeIfPresent(ProjectAssetMediaType.self, forKey: .mediaType) {
            mediaType = decodedMediaType
        } else {
            let legacyType = try container.decodeIfPresent(ProjectAssetType.self, forKey: .assetType) ?? .photo
            mediaType = ProjectAssetMediaType(assetType: legacyType)
        }
        if let decodedSourceType = try container.decodeIfPresent(ProjectAssetSourceType.self, forKey: .sourceType) {
            sourceType = decodedSourceType
        } else {
            let legacyOrigin = try container.decodeIfPresent(AssetOrigin.self, forKey: .origin) ?? .camera
            sourceType = ProjectAssetSourceType(origin: legacyOrigin)
        }
        originalFilename = try container.decodeIfPresent(String.self, forKey: .originalFilename)
        relativePath = try container.decode(String.self, forKey: .relativePath)
        thumbnailRelativePath = try container.decodeIfPresent(String.self, forKey: .thumbnailRelativePath)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        importedAt = try container.decodeIfPresent(Date.self, forKey: .importedAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        pixelWidth = try container.decodeIfPresent(Int.self, forKey: .pixelWidth)
            ?? container.decodeIfPresent(Int.self, forKey: .width)
        pixelHeight = try container.decodeIfPresent(Int.self, forKey: .pixelHeight)
            ?? container.decodeIfPresent(Int.self, forKey: .height)
        durationSeconds = try container.decodeIfPresent(Double.self, forKey: .durationSeconds)
            ?? container.decodeIfPresent(Double.self, forKey: .duration)
        fileSizeBytes = try container.decodeIfPresent(Int64.self, forKey: .fileSizeBytes)
            ?? container.decodeIfPresent(Int64.self, forKey: .fileSize)
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        isBest = try container.decodeIfPresent(Bool.self, forKey: .isBest) ?? false
        let legacyIsDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        deletionState = try container.decodeIfPresent(AssetDeletionState.self, forKey: .deletionState)
            ?? (legacyIsDeleted ? .trashed : .active)
        isDeleted = legacyIsDeleted || deletionState == .trashed
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        parentAssetID = try container.decodeIfPresent(UUID.self, forKey: .parentAssetID)
        rootAssetID = try container.decodeIfPresent(UUID.self, forKey: .rootAssetID) ?? id
        assetRole = try container.decodeIfPresent(AssetRole.self, forKey: .assetRole) ?? .original
        processingState = try container.decodeIfPresent(AssetProcessingState.self, forKey: .processingState) ?? .original
        versionNumber = try container.decodeIfPresent(Int.self, forKey: .versionNumber)
            ?? (try container.decodeIfPresent(Int.self, forKey: .version) ?? 1)
        skuID = try container.decodeIfPresent(UUID.self, forKey: .skuID)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(projectID, forKey: .projectID)
        try container.encode(category, forKey: .category)
        try container.encode(mediaType, forKey: .mediaType)
        try container.encode(sourceType, forKey: .sourceType)
        try container.encodeIfPresent(originalFilename, forKey: .originalFilename)
        try container.encode(relativePath, forKey: .relativePath)
        try container.encodeIfPresent(thumbnailRelativePath, forKey: .thumbnailRelativePath)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(importedAt, forKey: .importedAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(pixelWidth, forKey: .pixelWidth)
        try container.encodeIfPresent(pixelHeight, forKey: .pixelHeight)
        try container.encodeIfPresent(durationSeconds, forKey: .durationSeconds)
        try container.encodeIfPresent(fileSizeBytes, forKey: .fileSizeBytes)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encode(isBest, forKey: .isBest)
        try container.encode(isDeleted, forKey: .isDeleted)
        try container.encode(deletionState, forKey: .deletionState)
        try container.encodeIfPresent(deletedAt, forKey: .deletedAt)
        try container.encodeIfPresent(parentAssetID, forKey: .parentAssetID)
        try container.encodeIfPresent(rootAssetID, forKey: .rootAssetID)
        try container.encode(assetRole, forKey: .assetRole)
        try container.encode(processingState, forKey: .processingState)
        try container.encode(versionNumber, forKey: .versionNumber)
        try container.encodeIfPresent(skuID, forKey: .skuID)
    }
}

nonisolated enum ProductWorkspaceMapper {
    static func record(from project: ProductProject) -> ProductProjectRecord {
        ProductProjectRecord(
            id: project.id,
            schemaVersion: project.schemaVersion,
            name: project.name,
            createdAt: project.createdAt,
            updatedAt: project.updatedAt,
            status: project.status,
            coverAssetID: project.coverAssetID,
            isArchived: project.isArchived,
            sortOrder: project.sortOrder,
            lastSelectedCaptureCategory: project.lastSelectedCaptureCategory
        )
    }

    static func domain(from record: ProductProjectRecord) -> ProductProject {
        ProductProject(
            id: record.id,
            schemaVersion: record.schemaVersion,
            name: record.name,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt,
            status: record.status,
            coverAssetID: record.coverAssetID,
            isArchived: record.isArchived,
            sortOrder: record.sortOrder,
            lastSelectedCaptureCategory: record.lastSelectedCaptureCategory ?? .standard
        )
    }

    static func record(from asset: ProjectAsset) -> ProjectAssetRecord {
        ProjectAssetRecord(
            id: asset.id,
            schemaVersion: asset.schemaVersion,
            projectID: asset.projectID,
            category: asset.category,
            mediaType: asset.mediaType,
            sourceType: asset.sourceType,
            originalFilename: asset.originalFilename,
            relativePath: asset.relativePath,
            thumbnailRelativePath: asset.thumbnailRelativePath,
            createdAt: asset.createdAt,
            importedAt: asset.importedAt,
            updatedAt: asset.updatedAt,
            pixelWidth: asset.pixelWidth,
            pixelHeight: asset.pixelHeight,
            durationSeconds: asset.durationSeconds,
            fileSizeBytes: asset.fileSizeBytes,
            isFavorite: asset.isFavorite,
            isBest: asset.isBest,
            isDeleted: asset.isDeleted,
            deletionState: asset.deletionState,
            deletedAt: asset.deletedAt,
            parentAssetID: asset.parentAssetID,
            rootAssetID: asset.rootAssetID,
            assetRole: asset.assetRole,
            processingState: asset.processingState,
            versionNumber: asset.versionNumber,
            skuID: asset.skuID
        )
    }

    static func domain(from record: ProjectAssetRecord) -> ProjectAsset {
        ProjectAsset(
            id: record.id,
            schemaVersion: record.schemaVersion,
            projectID: record.projectID,
            category: record.category,
            mediaType: record.mediaType,
            sourceType: record.sourceType,
            originalFilename: record.originalFilename,
            relativePath: record.relativePath,
            thumbnailRelativePath: record.thumbnailRelativePath,
            createdAt: record.createdAt,
            importedAt: record.importedAt,
            updatedAt: record.updatedAt,
            width: record.pixelWidth,
            height: record.pixelHeight,
            duration: record.durationSeconds,
            fileSize: record.fileSizeBytes,
            isFavorite: record.isFavorite,
            isBest: record.isBest,
            isDeleted: record.isDeleted,
            deletionState: record.deletionState,
            deletedAt: record.deletedAt,
            version: record.versionNumber,
            parentAssetID: record.parentAssetID,
            rootAssetID: record.rootAssetID,
            assetRole: record.assetRole,
            processingState: record.processingState,
            skuID: record.skuID
        )
    }
}

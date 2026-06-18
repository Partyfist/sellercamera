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

    enum CodingKeys: String, CodingKey {
        case id
        case schemaVersion
        case projectID
        case category
        case mediaType
        case assetType
        case origin
        case originalFilename
        case relativePath
        case thumbnailRelativePath
        case createdAt
        case updatedAt
        case width
        case height
        case duration
        case fileSize
        case isFavorite
        case isDeleted
        case version
        case parentAssetID
        case skuID
    }

    init(
        id: UUID,
        schemaVersion: Int,
        projectID: UUID,
        category: CaptureCategory,
        mediaType: ProjectAssetType,
        origin: AssetOrigin,
        originalFilename: String?,
        relativePath: String,
        thumbnailRelativePath: String?,
        createdAt: Date,
        updatedAt: Date,
        width: Int?,
        height: Int?,
        duration: Double?,
        fileSize: Int64?,
        isFavorite: Bool,
        isDeleted: Bool,
        version: Int,
        parentAssetID: UUID?,
        skuID: UUID?
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.projectID = projectID
        self.category = category
        self.mediaType = mediaType
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        projectID = try container.decode(UUID.self, forKey: .projectID)
        category = try container.decode(CaptureCategory.self, forKey: .category)
        mediaType = try container.decodeIfPresent(ProjectAssetType.self, forKey: .mediaType)
            ?? (try container.decodeIfPresent(ProjectAssetType.self, forKey: .assetType) ?? .photo)
        origin = try container.decodeIfPresent(AssetOrigin.self, forKey: .origin) ?? .camera
        originalFilename = try container.decodeIfPresent(String.self, forKey: .originalFilename)
        relativePath = try container.decode(String.self, forKey: .relativePath)
        thumbnailRelativePath = try container.decodeIfPresent(String.self, forKey: .thumbnailRelativePath)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        width = try container.decodeIfPresent(Int.self, forKey: .width)
        height = try container.decodeIfPresent(Int.self, forKey: .height)
        duration = try container.decodeIfPresent(Double.self, forKey: .duration)
        fileSize = try container.decodeIfPresent(Int64.self, forKey: .fileSize)
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        parentAssetID = try container.decodeIfPresent(UUID.self, forKey: .parentAssetID)
        skuID = try container.decodeIfPresent(UUID.self, forKey: .skuID)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(projectID, forKey: .projectID)
        try container.encode(category, forKey: .category)
        try container.encode(mediaType, forKey: .mediaType)
        try container.encode(origin, forKey: .origin)
        try container.encodeIfPresent(originalFilename, forKey: .originalFilename)
        try container.encode(relativePath, forKey: .relativePath)
        try container.encodeIfPresent(thumbnailRelativePath, forKey: .thumbnailRelativePath)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(width, forKey: .width)
        try container.encodeIfPresent(height, forKey: .height)
        try container.encodeIfPresent(duration, forKey: .duration)
        try container.encodeIfPresent(fileSize, forKey: .fileSize)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encode(isDeleted, forKey: .isDeleted)
        try container.encode(version, forKey: .version)
        try container.encodeIfPresent(parentAssetID, forKey: .parentAssetID)
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
            origin: asset.origin,
            originalFilename: asset.originalFilename,
            relativePath: asset.relativePath,
            thumbnailRelativePath: asset.thumbnailRelativePath,
            createdAt: asset.createdAt,
            updatedAt: asset.updatedAt,
            width: asset.width,
            height: asset.height,
            duration: asset.duration,
            fileSize: asset.fileSize,
            isFavorite: asset.isFavorite,
            isDeleted: asset.isDeleted,
            version: asset.version,
            parentAssetID: asset.parentAssetID,
            skuID: asset.skuID
        )
    }

    static func domain(from record: ProjectAssetRecord) -> ProjectAsset {
        ProjectAsset(
            id: record.id,
            schemaVersion: record.schemaVersion,
            projectID: record.projectID,
            category: record.category,
            assetType: record.mediaType,
            origin: record.origin,
            originalFilename: record.originalFilename,
            relativePath: record.relativePath,
            thumbnailRelativePath: record.thumbnailRelativePath,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt,
            width: record.width,
            height: record.height,
            duration: record.duration,
            fileSize: record.fileSize,
            isFavorite: record.isFavorite,
            isDeleted: record.isDeleted,
            version: record.version,
            parentAssetID: record.parentAssetID,
            skuID: record.skuID
        )
    }
}

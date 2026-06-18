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
}

nonisolated struct ProjectAssetRecord: Codable, Equatable {
    var id: UUID
    var schemaVersion: Int
    var projectID: UUID
    var category: CaptureCategory
    var assetType: ProjectAssetType
    var origin: AssetOrigin
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
            sortOrder: project.sortOrder
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
            sortOrder: record.sortOrder
        )
    }

    static func record(from asset: ProjectAsset) -> ProjectAssetRecord {
        ProjectAssetRecord(
            id: asset.id,
            schemaVersion: asset.schemaVersion,
            projectID: asset.projectID,
            category: asset.category,
            assetType: asset.assetType,
            origin: asset.origin,
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
            parentAssetID: asset.parentAssetID
        )
    }

    static func domain(from record: ProjectAssetRecord) -> ProjectAsset {
        ProjectAsset(
            id: record.id,
            schemaVersion: record.schemaVersion,
            projectID: record.projectID,
            category: record.category,
            assetType: record.assetType,
            origin: record.origin,
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
            parentAssetID: record.parentAssetID
        )
    }
}

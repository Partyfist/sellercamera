//
//  ProductProject.swift
//  SellerCamera
//
//  Created by Codex on 2026/6/18.
//

import Foundation

nonisolated enum ProjectStatus: String, Codable, CaseIterable, Equatable {
    case active
    case completed
    case archived
}

nonisolated struct ProductProject: Identifiable, Codable, Equatable {
    var id: UUID
    var schemaVersion: Int
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var status: ProjectStatus
    var coverAssetID: UUID?
    var isArchived: Bool
    var sortOrder: Int?
    var lastSelectedCaptureCategory: CaptureCategory

    init(
        id: UUID = UUID(),
        schemaVersion: Int = 1,
        name: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        status: ProjectStatus = .active,
        coverAssetID: UUID? = nil,
        isArchived: Bool = false,
        sortOrder: Int? = nil,
        lastSelectedCaptureCategory: CaptureCategory = .standard
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
}

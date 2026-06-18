//
//  CurrentProjectSummary.swift
//  SellerCamera
//
//  Created by Codex on 2026/6/18.
//

import Foundation

nonisolated struct CurrentProjectSummary: Identifiable, Equatable {
    var projectID: UUID
    var projectName: String
    var coverThumbnailPath: String?
    var standardCount: Int
    var detailCount: Int
    var skuCount: Int
    var videoCount: Int
    var updatedAt: Date
    var isCurrent: Bool
    var isArchived: Bool

    var id: UUID { projectID }
    var totalCount: Int { standardCount + detailCount + skuCount + videoCount }

    init(
        projectID: UUID,
        projectName: String,
        coverThumbnailPath: String?,
        counts: ProjectAssetCounts,
        updatedAt: Date,
        isCurrent: Bool,
        isArchived: Bool
    ) {
        self.projectID = projectID
        self.projectName = projectName
        self.coverThumbnailPath = coverThumbnailPath
        self.standardCount = counts.standard
        self.detailCount = counts.detail
        self.skuCount = counts.sku
        self.videoCount = counts.video
        self.updatedAt = updatedAt
        self.isCurrent = isCurrent
        self.isArchived = isArchived
    }
}

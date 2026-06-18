//
//  ProjectAssetCountService.swift
//  SellerCamera
//
//  Created by Codex on 2026/6/18.
//

import Foundation

nonisolated final class ProjectAssetCountService: ProjectAssetCounting {
    private let assetCounter: ProjectAssetCounting

    init(assetCounter: ProjectAssetCounting) {
        self.assetCounter = assetCounter
    }

    func counts(projectID: UUID) throws -> ProjectAssetCounts {
        try assetCounter.counts(projectID: projectID)
    }
}

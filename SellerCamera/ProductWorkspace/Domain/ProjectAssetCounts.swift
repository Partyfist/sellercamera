//
//  ProjectAssetCounts.swift
//  SellerCamera
//
//  Created by Codex on 2026/6/18.
//

import Foundation

nonisolated struct ProjectAssetCounts: Codable, Equatable {
    var standard: Int
    var detail: Int
    var video: Int

    var total: Int {
        standard + detail + video
    }

    static let empty = ProjectAssetCounts(standard: 0, detail: 0, video: 0)
}

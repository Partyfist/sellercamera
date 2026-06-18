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
    var sku: Int
    var video: Int

    var total: Int {
        standard + detail + sku + video
    }

    static let empty = ProjectAssetCounts(standard: 0, detail: 0, sku: 0, video: 0)

    init(standard: Int, detail: Int, sku: Int = 0, video: Int) {
        self.standard = standard
        self.detail = detail
        self.sku = sku
        self.video = video
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        standard = try container.decodeIfPresent(Int.self, forKey: .standard) ?? 0
        detail = try container.decodeIfPresent(Int.self, forKey: .detail) ?? 0
        sku = try container.decodeIfPresent(Int.self, forKey: .sku) ?? 0
        video = try container.decodeIfPresent(Int.self, forKey: .video) ?? 0
    }
}

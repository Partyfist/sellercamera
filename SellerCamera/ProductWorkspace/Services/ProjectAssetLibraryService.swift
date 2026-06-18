//
//  ProjectAssetLibraryService.swift
//  SellerCamera
//
//  Created by Codex on 2026/6/19.
//

import Foundation

nonisolated struct AssetBatchOperationResult: Equatable {
    var requestedCount: Int
    var succeededCount: Int
    var failedCount: Int

    static func success(count: Int) -> AssetBatchOperationResult {
        AssetBatchOperationResult(requestedCount: count, succeededCount: count, failedCount: 0)
    }
}

nonisolated final class ProjectAssetLibraryService {
    private let projectRepository: ProductProjectRepository
    private let assetRepository: ProjectAssetRepository
    private let projectService: ProductProjectService
    private let countService: ProjectAssetCounting
    private let fileStore: ProjectFileStoring

    init(
        projectRepository: ProductProjectRepository,
        assetRepository: ProjectAssetRepository,
        projectService: ProductProjectService,
        countService: ProjectAssetCounting,
        fileStore: ProjectFileStoring
    ) {
        self.projectRepository = projectRepository
        self.assetRepository = assetRepository
        self.projectService = projectService
        self.countService = countService
        self.fileStore = fileStore
    }

    func fetchAssets(projectID: UUID, filter: AssetFilter, sort: AssetSort = .newest) throws -> [ProjectAsset] {
        assetLog("fetch started projectID=\(projectID.uuidString) filter=\(filter.debugName)")
        let startedAt = Date()
        let assets = try assetRepository.fetchAssets(projectID: projectID, filter: filter, sort: sort)
        assetLog("fetch completed projectID=\(projectID.uuidString) count=\(assets.count) duration=\(String(format: "%.3f", Date().timeIntervalSince(startedAt)))")
        return assets
    }

    func updateCategory(assetIDs: [UUID], category: CaptureCategory) throws -> AssetBatchOperationResult {
        try assetRepository.updateCategory(assetIDs: assetIDs, category: category)
        batchLog("category changed count=\(assetIDs.count) category=\(category.rawValue)")
        return .success(count: assetIDs.count)
    }

    func updateFavorite(assetIDs: [UUID], isFavorite: Bool) throws -> AssetBatchOperationResult {
        try assetRepository.updateFavorite(assetIDs: assetIDs, isFavorite: isFavorite)
        batchLog("favorite changed count=\(assetIDs.count) value=\(isFavorite)")
        return .success(count: assetIDs.count)
    }

    func updateBest(assetIDs: [UUID], isBest: Bool) throws -> AssetBatchOperationResult {
        try assetRepository.updateBest(assetIDs: assetIDs, isBest: isBest)
        batchLog("best changed count=\(assetIDs.count) value=\(isBest)")
        return .success(count: assetIDs.count)
    }

    func setProjectCover(projectID: UUID, assetID: UUID?) throws {
        _ = try projectService.setProjectCover(projectID: projectID, assetID: assetID)
        coverLog("updated projectID=\(projectID.uuidString) assetID=\(assetID?.uuidString ?? "nil")")
    }

    func moveToTrash(assetIDs: [UUID]) throws -> AssetBatchOperationResult {
        let assets = try assetsForOperation(assetIDs)
        try assetRepository.moveToTrash(assetIDs: assetIDs, deletedAt: Date())
        try refreshCoversIfNeeded(afterRemoving: assets)
        trashLog("moved count=\(assetIDs.count)")
        return .success(count: assetIDs.count)
    }

    func restoreFromTrash(assetIDs: [UUID]) throws -> AssetBatchOperationResult {
        try assetRepository.restoreFromTrash(assetIDs: assetIDs)
        trashLog("restored count=\(assetIDs.count)")
        return .success(count: assetIDs.count)
    }

    func permanentlyDelete(assetIDs: [UUID]) throws -> AssetBatchOperationResult {
        let deletedAssets = try assetRepository.permanentlyDelete(assetIDs: assetIDs)
        for asset in deletedAssets {
            try? fileStore.deleteFile(relativePath: asset.relativePath)
            if let thumbnailPath = asset.thumbnailRelativePath {
                try? fileStore.deleteFile(relativePath: thumbnailPath)
            }
        }
        try refreshCoversIfNeeded(afterRemoving: deletedAssets)
        trashLog("permanently deleted count=\(deletedAssets.count)")
        return .success(count: assetIDs.count)
    }

    func emptyTrash(projectID: UUID) throws -> AssetBatchOperationResult {
        let trashedAssets = try assetRepository.fetchAssets(projectID: projectID, filter: .trash, sort: .newest)
        return try permanentlyDelete(assetIDs: trashedAssets.map(\.id))
    }

    func counts(projectID: UUID) throws -> ProjectAssetCounts {
        try countService.counts(projectID: projectID)
    }

    private func assetsForOperation(_ assetIDs: [UUID]) throws -> [ProjectAsset] {
        try assetIDs.map { id in
            guard let asset = try assetRepository.fetchAsset(id: id) else {
                throw ProductWorkspaceError.assetNotFound(id)
            }
            return asset
        }
    }

    private func refreshCoversIfNeeded(afterRemoving removedAssets: [ProjectAsset]) throws {
        let affectedProjectIDs = Set(removedAssets.map(\.projectID))
        for projectID in affectedProjectIDs {
            guard let project = try projectRepository.fetchProject(id: projectID),
                  let coverAssetID = project.coverAssetID,
                  removedAssets.contains(where: { $0.id == coverAssetID }) else {
                continue
            }
            let replacementID = try replacementCoverID(projectID: projectID, excluding: Set(removedAssets.map(\.id)))
            try setProjectCover(projectID: projectID, assetID: replacementID)
        }
    }

    private func replacementCoverID(projectID: UUID, excluding deletedIDs: Set<UUID>) throws -> UUID? {
        try assetRepository.fetchAssets(projectID: projectID, filter: .all, sort: .oldest)
            .filter { !deletedIDs.contains($0.id) && $0.mediaType == .photo }
            .sorted { lhs, rhs in
                coverRank(lhs) == coverRank(rhs) ? lhs.createdAt < rhs.createdAt : coverRank(lhs) < coverRank(rhs)
            }
            .first?.id
    }

    private func coverRank(_ asset: ProjectAsset) -> Int {
        if asset.isBest && asset.category == .standard { return 0 }
        if asset.category == .standard { return 1 }
        if asset.category == .sku { return 2 }
        if asset.category == .detail { return 3 }
        return 4
    }
}

extension AssetFilter {
    nonisolated var debugName: String {
        switch self {
        case .all:
            return "all"
        case .category(let category):
            return "category:\(category.rawValue)"
        case .photo:
            return "photo"
        case .video:
            return "video"
        case .favorite:
            return "favorite"
        case .best:
            return "best"
        case .trash:
            return "trash"
        }
    }
}

#if DEBUG
nonisolated private func assetLog(_ message: String) {
    print("[AssetLibrary] \(message)")
}

nonisolated private func batchLog(_ message: String) {
    print("[AssetBatch] \(message)")
}

nonisolated private func trashLog(_ message: String) {
    print("[AssetTrash] \(message)")
}

nonisolated private func coverLog(_ message: String) {
    print("[AssetCover] \(message)")
}
#else
nonisolated private func assetLog(_ message: String) {}
nonisolated private func batchLog(_ message: String) {}
nonisolated private func trashLog(_ message: String) {}
nonisolated private func coverLog(_ message: String) {}
#endif

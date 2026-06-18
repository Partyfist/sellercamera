//
//  ProductAssetLibrarySession.swift
//  SellerCamera
//
//  Created by Codex on 2026/6/19.
//

import Combine
import Foundation

nonisolated struct ProjectAssetImportItem: Equatable {
    var data: Data
    var mediaType: ProjectAssetMediaType
    var originalFilename: String?
    var fileExtension: String?
    var pixelWidth: Int?
    var pixelHeight: Int?
    var durationSeconds: Double?
}

@MainActor
final class ProductAssetLibrarySession: ObservableObject {
    @Published private(set) var visibleAssets: [ProjectAsset] = []
    @Published private(set) var selectedAssetIDs: Set<UUID> = []
    @Published private(set) var isSelectionMode = false
    @Published private(set) var isImporting = false
    @Published private(set) var importProgressText: String?
    @Published private(set) var lastStatusText: String?
    @Published private(set) var lastErrorText: String?
    @Published var selectedFilter: AssetFilter = .all
    @Published var sortOrder: AssetSort = .newest

    let environment: ProductWorkspaceEnvironment
    private var currentProjectID: UUID?

    init(environment: ProductWorkspaceEnvironment = .shared) {
        self.environment = environment
    }

    func load(projectID: UUID?) async {
        currentProjectID = projectID
        selectedAssetIDs = selectedAssetIDs.filter { id in
            visibleAssets.contains(where: { $0.id == id })
        }
        guard let projectID else {
            visibleAssets = []
            return
        }
        do {
            let filter = selectedFilter
            let sort = sortOrder
            let assets = try await Task.detached(priority: .utility) { [environment] in
                try environment.assetLibraryService.fetchAssets(projectID: projectID, filter: filter, sort: sort)
            }.value
            visibleAssets = assets
            selectedAssetIDs = selectedAssetIDs.filter { id in assets.contains(where: { $0.id == id }) }
        } catch {
            lastErrorText = "资产读取失败"
        }
    }

    func setFilter(_ filter: AssetFilter) async {
        selectedFilter = filter
        selectedAssetIDs.removeAll()
        await load(projectID: currentProjectID)
    }

    func setSort(_ sort: AssetSort) async {
        sortOrder = sort
        await load(projectID: currentProjectID)
    }

    func enterSelectionMode(assetID: UUID? = nil) {
        isSelectionMode = true
        if let assetID {
            selectedAssetIDs.insert(assetID)
        }
    }

    func exitSelectionMode() {
        isSelectionMode = false
        selectedAssetIDs.removeAll()
    }

    func toggleSelection(assetID: UUID) {
        if selectedAssetIDs.contains(assetID) {
            selectedAssetIDs.remove(assetID)
        } else {
            selectedAssetIDs.insert(assetID)
        }
        isSelectionMode = true
    }

    func selectAllVisible() {
        selectedAssetIDs = Set(visibleAssets.map(\.id))
        isSelectionMode = true
    }

    func updateCategory(_ category: CaptureCategory) async {
        await performBatch("分类已更新") { service, ids in
            try service.updateCategory(assetIDs: ids, category: category)
        }
    }

    func updateFavorite(_ isFavorite: Bool) async {
        await performBatch(isFavorite ? "已收藏" : "已取消收藏") { service, ids in
            try service.updateFavorite(assetIDs: ids, isFavorite: isFavorite)
        }
    }

    func updateBest(_ isBest: Bool) async {
        await performBatch(isBest ? "已标记最佳" : "已取消最佳") { service, ids in
            try service.updateBest(assetIDs: ids, isBest: isBest)
        }
    }

    func moveSelectedToTrash() async {
        await performBatch("已移入回收站") { service, ids in
            try service.moveToTrash(assetIDs: ids)
        }
    }

    func restoreSelectedFromTrash() async {
        await performBatch("已恢复") { service, ids in
            try service.restoreFromTrash(assetIDs: ids)
        }
    }

    func permanentlyDeleteSelected() async {
        await performBatch("已永久删除") { service, ids in
            try service.permanentlyDelete(assetIDs: ids)
        }
    }

    func emptyTrash() async {
        guard let currentProjectID else { return }
        do {
            let result = try await Task.detached(priority: .utility) { [environment] in
                try environment.assetLibraryService.emptyTrash(projectID: currentProjectID)
            }.value
            lastStatusText = "已清空回收站：\(result.succeededCount) 项"
            await load(projectID: currentProjectID)
        } catch {
            lastErrorText = "清空回收站失败"
        }
    }

    func setCover(assetID: UUID) async {
        guard let asset = visibleAssets.first(where: { $0.id == assetID }) else { return }
        do {
            try await Task.detached(priority: .utility) { [environment] in
                try environment.assetLibraryService.setProjectCover(projectID: asset.projectID, assetID: asset.id)
            }.value
            lastStatusText = "封面已更新"
            await load(projectID: currentProjectID)
        } catch {
            lastErrorText = "封面更新失败"
        }
    }

    func importItems(
        _ items: [ProjectAssetImportItem],
        projectID: UUID,
        category: CaptureCategory
    ) async -> AssetBatchOperationResult {
        guard !items.isEmpty else {
            return AssetBatchOperationResult(requestedCount: 0, succeededCount: 0, failedCount: 0)
        }
        isImporting = true
        defer { isImporting = false }

        var succeeded = 0
        var failed = 0
        var seenKeys: Set<String> = []
        for (index, item) in items.enumerated() {
            importProgressText = "导入 \(index + 1)/\(items.count)"
            let transactionKey = "\(item.originalFilename ?? "item")-\(item.data.count)-\(item.mediaType.rawValue)"
            guard !seenKeys.contains(transactionKey) else { continue }
            seenKeys.insert(transactionKey)
            do {
                let targetCategory = item.mediaType == .video ? CaptureCategory.video : category
                let input = ProjectPhotoArchiveInput(
                    data: item.data,
                    targetProjectID: projectID,
                    capturedAt: Date(),
                    category: targetCategory,
                    origin: .photoLibrary,
                    mediaType: item.mediaType,
                    width: item.pixelWidth,
                    height: item.pixelHeight,
                    duration: item.durationSeconds,
                    metadata: ["source": "asset-library-import"],
                    originalFilename: item.originalFilename,
                    fileExtension: item.fileExtension
                )
                let archiveService = environment.archiveService
                _ = try await Task.detached(priority: .utility) {
                    try await archiveService.archivePhoto(input)
                }.value
                importLog("item succeeded projectID=\(projectID.uuidString) category=\(targetCategory.rawValue)")
                succeeded += 1
            } catch {
                importLog("item failed projectID=\(projectID.uuidString) error=\(error.localizedDescription)")
                failed += 1
            }
        }

        let result = AssetBatchOperationResult(
            requestedCount: items.count,
            succeededCount: succeeded,
            failedCount: failed
        )
        importProgressText = "导入完成：成功 \(succeeded)，失败 \(failed)"
        lastStatusText = importProgressText
        await load(projectID: currentProjectID)
        return result
    }

    private func performBatch(
        _ successText: String,
        operation: @escaping (ProjectAssetLibraryService, [UUID]) throws -> AssetBatchOperationResult
    ) async {
        let ids = Array(selectedAssetIDs)
        guard !ids.isEmpty else {
            lastStatusText = "请先选择图片"
            return
        }
        do {
            let result = try await Task.detached(priority: .utility) { [environment] in
                try operation(environment.assetLibraryService, ids)
            }.value
            lastStatusText = "\(successText)：成功 \(result.succeededCount)，失败 \(result.failedCount)"
            selectedAssetIDs.removeAll()
            isSelectionMode = false
            await load(projectID: currentProjectID)
        } catch {
            lastErrorText = "\(successText)失败"
        }
    }
}

#if DEBUG
nonisolated private func importLog(_ message: String) {
    print("[AssetImport] \(message)")
}
#else
nonisolated private func importLog(_ message: String) {}
#endif

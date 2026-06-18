//
//  ProductWorkspaceJSONRepository.swift
//  SellerCamera
//
//  Created by Codex on 2026/6/18.
//

import Foundation

private nonisolated struct ProductWorkspaceSnapshot: Codable {
    var schemaVersion: Int
    var projects: [ProductProjectRecord]
    var assets: [ProjectAssetRecord]

    static let empty = ProductWorkspaceSnapshot(schemaVersion: 1, projects: [], assets: [])
}

nonisolated final class ProductWorkspaceJSONRepository: ProductProjectRepository, ProjectAssetRepository, ProjectAssetCounting {
    let metadataURL: URL
    private let lock = NSRecursiveLock()
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(metadataURL: URL) {
        self.metadataURL = metadataURL
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func createProject(name: String?) throws -> ProductProject {
        let trimmedName = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw ProductWorkspaceError.invalidProjectName
        }

        return try mutateSnapshot { snapshot in
            guard !snapshot.projects.contains(where: { $0.name == trimmedName }) else {
                throw ProductWorkspaceError.invalidProjectName
            }
            let now = Date()
            let nextSortOrder = ((snapshot.projects.compactMap(\.sortOrder).max() ?? -1) + 1)
            let project = ProductProject(
                name: trimmedName,
                createdAt: now,
                updatedAt: now,
                sortOrder: nextSortOrder
            )
            snapshot.projects.append(ProductWorkspaceMapper.record(from: project))
            return project
        }
    }

    func fetchProject(id: UUID) throws -> ProductProject? {
        try readSnapshot().projects
            .first(where: { $0.id == id })
            .map(ProductWorkspaceMapper.domain(from:))
    }

    func fetchProjects(includeArchived: Bool) throws -> [ProductProject] {
        try readSnapshot().projects
            .map(ProductWorkspaceMapper.domain(from:))
            .filter { includeArchived || !$0.isArchived }
            .sorted {
                if ($0.sortOrder ?? Int.max) != ($1.sortOrder ?? Int.max) {
                    return ($0.sortOrder ?? Int.max) < ($1.sortOrder ?? Int.max)
                }
                return $0.createdAt < $1.createdAt
            }
    }

    func updateProject(_ project: ProductProject) throws {
        try mutateSnapshot { snapshot in
            guard let index = snapshot.projects.firstIndex(where: { $0.id == project.id }) else {
                throw ProductWorkspaceError.projectNotFound(project.id)
            }
            snapshot.projects[index] = ProductWorkspaceMapper.record(from: project)
            return ()
        }
    }

    func archiveProject(id: UUID) throws {
        try mutateSnapshot { snapshot in
            guard let index = snapshot.projects.firstIndex(where: { $0.id == id }) else {
                throw ProductWorkspaceError.projectNotFound(id)
            }
            var project = ProductWorkspaceMapper.domain(from: snapshot.projects[index])
            project.status = .archived
            project.isArchived = true
            project.updatedAt = Date()
            snapshot.projects[index] = ProductWorkspaceMapper.record(from: project)
            return ()
        }
    }

    func restoreProject(id: UUID) throws {
        try mutateSnapshot { snapshot in
            guard let index = snapshot.projects.firstIndex(where: { $0.id == id }) else {
                throw ProductWorkspaceError.projectNotFound(id)
            }
            var project = ProductWorkspaceMapper.domain(from: snapshot.projects[index])
            project.status = .active
            project.isArchived = false
            project.updatedAt = Date()
            snapshot.projects[index] = ProductWorkspaceMapper.record(from: project)
            return ()
        }
    }

    func createAsset(_ asset: ProjectAsset) throws {
        try mutateSnapshot { snapshot in
            guard snapshot.projects.contains(where: { $0.id == asset.projectID }) else {
                throw ProductWorkspaceError.projectNotFound(asset.projectID)
            }
            guard !snapshot.assets.contains(where: { $0.id == asset.id }) else {
                throw ProductWorkspaceError.metadataSaveFailed("duplicate asset id")
            }
            snapshot.assets.append(ProductWorkspaceMapper.record(from: asset))
            return ()
        }
    }

    func fetchAsset(id: UUID) throws -> ProjectAsset? {
        try readSnapshot().assets
            .first(where: { $0.id == id })
            .map(ProductWorkspaceMapper.domain(from:))
    }

    func fetchAssets(includeDeleted: Bool) throws -> [ProjectAsset] {
        try readSnapshot().assets
            .map(ProductWorkspaceMapper.domain(from:))
            .filter { includeDeleted || $0.deletionState == .active && !$0.isDeleted }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func fetchAssets(projectID: UUID, filter: AssetFilter, sort: AssetSort) throws -> [ProjectAsset] {
        let includeDeleted = filter == .trash
        return try sortedAssets(
            fetchAssets(includeDeleted: includeDeleted)
                .filter { $0.projectID == projectID }
                .filter { assetMatches($0, filter: filter) },
            sort: sort
        )
    }

    func fetchAssets(projectID: UUID) throws -> [ProjectAsset] {
        try readSnapshot().assets
            .map(ProductWorkspaceMapper.domain(from:))
            .filter { $0.projectID == projectID && $0.deletionState == .active && !$0.isDeleted }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func fetchAssets(projectID: UUID, category: CaptureCategory) throws -> [ProjectAsset] {
        try fetchAssets(projectID: projectID)
            .filter { $0.category == category }
    }

    func counts(projectID: UUID) throws -> ProjectAssetCounts {
        let assets = try fetchAssets(projectID: projectID)
        return ProjectAssetCounts(
            standard: assets.filter { $0.category == .standard }.count,
            detail: assets.filter { $0.category == .detail }.count,
            sku: assets.filter { $0.category == .sku }.count,
            video: assets.filter { $0.category == .video }.count
        )
    }

    func updateCategory(assetIDs: [UUID], category: CaptureCategory) throws {
        try updateAssets(assetIDs: assetIDs) { asset in
            guard asset.mediaType != .video else { return }
            asset.category = category
            asset.updatedAt = Date()
        }
    }

    func updateFavorite(assetIDs: [UUID], isFavorite: Bool) throws {
        try updateAssets(assetIDs: assetIDs) { asset in
            asset.isFavorite = isFavorite
            asset.updatedAt = Date()
        }
    }

    func updateBest(assetIDs: [UUID], isBest: Bool) throws {
        try updateAssets(assetIDs: assetIDs) { asset in
            asset.isBest = isBest
            asset.updatedAt = Date()
        }
    }

    func moveToTrash(assetIDs: [UUID], deletedAt: Date = Date()) throws {
        try updateAssets(assetIDs: assetIDs) { asset in
            asset.deletionState = .trashed
            asset.isDeleted = true
            asset.deletedAt = deletedAt
            asset.updatedAt = deletedAt
        }
    }

    func restoreFromTrash(assetIDs: [UUID]) throws {
        try updateAssets(assetIDs: assetIDs) { asset in
            asset.deletionState = .active
            asset.isDeleted = false
            asset.deletedAt = nil
            asset.updatedAt = Date()
        }
    }

    func permanentlyDelete(assetIDs: [UUID]) throws -> [ProjectAsset] {
        let ids = Set(assetIDs)
        return try mutateSnapshot { snapshot in
            let allAssets = snapshot.assets.map(ProductWorkspaceMapper.domain(from:))
            for id in ids {
                let activeChildren = allAssets.filter {
                    ($0.parentAssetID == id || ($0.rootAssetID == id && $0.id != id))
                        && $0.deletionState == .active
                        && !$0.isDeleted
                }
                guard activeChildren.isEmpty else {
                    throw ProductWorkspaceError.metadataSaveFailed("asset has active derived versions")
                }
            }
            let deletedAssets = allAssets.filter { ids.contains($0.id) }
            snapshot.assets.removeAll { ids.contains($0.id) }

            for projectIndex in snapshot.projects.indices {
                var project = ProductWorkspaceMapper.domain(from: snapshot.projects[projectIndex])
                if let coverAssetID = project.coverAssetID, ids.contains(coverAssetID) {
                    project.coverAssetID = replacementCoverID(for: project.id, excluding: ids, in: snapshot.assets)
                    project.updatedAt = Date()
                    snapshot.projects[projectIndex] = ProductWorkspaceMapper.record(from: project)
                }
            }
            return deletedAssets
        }
    }

    func activeDerivedAssets(parentAssetID: UUID) throws -> [ProjectAsset] {
        try fetchAssets(includeDeleted: true)
            .filter {
                ($0.parentAssetID == parentAssetID || ($0.rootAssetID == parentAssetID && $0.id != parentAssetID))
                    && $0.deletionState == .active
                    && !$0.isDeleted
            }
    }

    private func readSnapshot() throws -> ProductWorkspaceSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return try loadSnapshot()
    }

    private func mutateSnapshot<Result>(_ mutation: (inout ProductWorkspaceSnapshot) throws -> Result) throws -> Result {
        lock.lock()
        defer { lock.unlock() }

        var snapshot = try loadSnapshot()
        let result = try mutation(&snapshot)
        try saveSnapshot(snapshot)
        return result
    }

    private func loadSnapshot() throws -> ProductWorkspaceSnapshot {
        guard FileManager.default.fileExists(atPath: metadataURL.path) else {
            return .empty
        }
        do {
            let data = try Data(contentsOf: metadataURL)
            return try decoder.decode(ProductWorkspaceSnapshot.self, from: data)
        } catch {
            throw ProductWorkspaceError.metadataLoadFailed(error.localizedDescription)
        }
    }

    private func saveSnapshot(_ snapshot: ProductWorkspaceSnapshot) throws {
        do {
            let directoryURL = metadataURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let data = try encoder.encode(snapshot)
            try data.write(to: metadataURL, options: .atomic)
        } catch {
            throw ProductWorkspaceError.metadataSaveFailed(error.localizedDescription)
        }
    }

    private func updateAssets(assetIDs: [UUID], update: (inout ProjectAsset) throws -> Void) throws {
        let ids = Set(assetIDs)
        try mutateSnapshot { snapshot in
            var updatedCount = 0
            for index in snapshot.assets.indices {
                var asset = ProductWorkspaceMapper.domain(from: snapshot.assets[index])
                guard ids.contains(asset.id) else { continue }
                try update(&asset)
                snapshot.assets[index] = ProductWorkspaceMapper.record(from: asset)
                updatedCount += 1
            }
            guard updatedCount == ids.count else {
                let existingIDs = Set(snapshot.assets.map(\.id))
                let missing = ids.first { !existingIDs.contains($0) } ?? UUID()
                throw ProductWorkspaceError.assetNotFound(missing)
            }
        }
    }

    private func assetMatches(_ asset: ProjectAsset, filter: AssetFilter) -> Bool {
        switch filter {
        case .all:
            return asset.deletionState == .active && !asset.isDeleted
        case .category(let category):
            return asset.category == category && asset.deletionState == .active && !asset.isDeleted
        case .photo:
            return asset.mediaType == .photo && asset.deletionState == .active && !asset.isDeleted
        case .video:
            return asset.mediaType == .video && asset.deletionState == .active && !asset.isDeleted
        case .favorite:
            return asset.isFavorite && asset.deletionState == .active && !asset.isDeleted
        case .best:
            return asset.isBest && asset.deletionState == .active && !asset.isDeleted
        case .trash:
            return asset.deletionState == .trashed || asset.isDeleted
        }
    }

    private func sortedAssets(_ assets: [ProjectAsset], sort: AssetSort) -> [ProjectAsset] {
        switch sort {
        case .newest:
            return assets.sorted { $0.createdAt > $1.createdAt }
        case .oldest:
            return assets.sorted { $0.createdAt < $1.createdAt }
        case .filename:
            return assets.sorted { ($0.originalFilename ?? $0.relativePath) < ($1.originalFilename ?? $1.relativePath) }
        case .fileSize:
            return assets.sorted { ($0.fileSizeBytes ?? 0) > ($1.fileSizeBytes ?? 0) }
        }
    }

    private func replacementCoverID(
        for projectID: UUID,
        excluding deletedIDs: Set<UUID>,
        in records: [ProjectAssetRecord]
    ) -> UUID? {
        let assets = records
            .map(ProductWorkspaceMapper.domain(from:))
            .filter {
                $0.projectID == projectID
                    && !deletedIDs.contains($0.id)
                    && $0.mediaType == .photo
                    && $0.deletionState == .active
                    && !$0.isDeleted
            }
        return assets
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

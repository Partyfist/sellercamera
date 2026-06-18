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

    func fetchAssets(projectID: UUID) throws -> [ProjectAsset] {
        try readSnapshot().assets
            .filter { $0.projectID == projectID && !$0.isDeleted }
            .map(ProductWorkspaceMapper.domain(from:))
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
            video: assets.filter { $0.category == .video }.count
        )
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
}

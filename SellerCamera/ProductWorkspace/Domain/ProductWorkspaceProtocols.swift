//
//  ProductWorkspaceProtocols.swift
//  SellerCamera
//
//  Created by Codex on 2026/6/18.
//

import Foundation

nonisolated protocol ProductProjectRepository {
    func createProject(name: String?) throws -> ProductProject
    func fetchProject(id: UUID) throws -> ProductProject?
    func fetchProjects(includeArchived: Bool) throws -> [ProductProject]
    func updateProject(_ project: ProductProject) throws
    func archiveProject(id: UUID) throws
}

nonisolated protocol ProjectAssetRepository {
    func createAsset(_ asset: ProjectAsset) throws
    func fetchAsset(id: UUID) throws -> ProjectAsset?
    func fetchAssets(projectID: UUID) throws -> [ProjectAsset]
    func fetchAssets(projectID: UUID, category: CaptureCategory) throws -> [ProjectAsset]
}

nonisolated protocol CurrentProjectStore {
    var currentProjectID: UUID? { get }
    func setCurrentProject(_ id: UUID?)
}

nonisolated protocol ProjectNameGenerating {
    func generateName(existingNames: [String], date: Date) -> String
}

nonisolated protocol ProjectFileStoring {
    var rootURL: URL { get }
    func createProjectDirectories(projectID: UUID) throws
    func saveOriginalPhoto(
        data: Data,
        projectID: UUID,
        category: CaptureCategory,
        assetID: UUID,
        fileExtension: String
    ) throws -> String
    func saveThumbnail(
        data: Data,
        projectID: UUID,
        assetID: UUID,
        fileExtension: String
    ) throws -> String
    func resolveURL(relativePath: String) throws -> URL
    func deleteFile(relativePath: String) throws
    func deleteProjectFiles(projectID: UUID) throws
}

nonisolated protocol ProjectAssetCounting {
    func counts(projectID: UUID) throws -> ProjectAssetCounts
}

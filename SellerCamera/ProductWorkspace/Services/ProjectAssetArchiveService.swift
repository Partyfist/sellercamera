//
//  ProjectAssetArchiveService.swift
//  SellerCamera
//
//  Created by Codex on 2026/6/18.
//

import Foundation

nonisolated struct ProjectPhotoArchiveInput {
    var data: Data
    var capturedAt: Date
    var category: CaptureCategory
    var origin: AssetOrigin
    var width: Int?
    var height: Int?
    var metadata: [String: String]
}

nonisolated struct ProjectAssetArchiveResult {
    var project: ProductProject
    var asset: ProjectAsset
    var counts: ProjectAssetCounts
}

nonisolated final class ProjectAssetArchiveService {
    private let projectService: ProductProjectService
    private let projectRepository: ProductProjectRepository
    private let assetRepository: ProjectAssetRepository
    private let countService: ProjectAssetCounting
    private let fileStore: ProjectFileStoring
    private let thumbnailGenerator: ThumbnailGenerator

    init(
        projectService: ProductProjectService,
        projectRepository: ProductProjectRepository,
        assetRepository: ProjectAssetRepository,
        countService: ProjectAssetCounting,
        fileStore: ProjectFileStoring,
        thumbnailGenerator: ThumbnailGenerator
    ) {
        self.projectService = projectService
        self.projectRepository = projectRepository
        self.assetRepository = assetRepository
        self.countService = countService
        self.fileStore = fileStore
        self.thumbnailGenerator = thumbnailGenerator
    }

    func archivePhoto(_ input: ProjectPhotoArchiveInput) async throws -> ProjectAssetArchiveResult {
        debugLog("asset archive started category=\(input.category.rawValue) origin=\(input.origin.rawValue)")
        var savedRelativePaths: [String] = []

        do {
            var project = try projectService.currentProjectOrCreateDefault(date: input.capturedAt)
            let assetID = UUID()
            let originalExtension = PhotoFileFormatDetector.fileExtension(for: input.data)
            let originalRelativePath = try fileStore.saveOriginalPhoto(
                data: input.data,
                projectID: project.id,
                category: input.category,
                assetID: assetID,
                fileExtension: originalExtension
            )
            savedRelativePaths.append(originalRelativePath)

            let thumbnailRelativePath = await makeThumbnailIfPossible(
                data: input.data,
                projectID: project.id,
                assetID: assetID,
                savedRelativePaths: &savedRelativePaths
            )

            let now = Date()
            let asset = ProjectAsset(
                id: assetID,
                projectID: project.id,
                category: input.category,
                assetType: .photo,
                origin: input.origin,
                relativePath: originalRelativePath,
                thumbnailRelativePath: thumbnailRelativePath,
                createdAt: input.capturedAt,
                updatedAt: now,
                width: input.width,
                height: input.height,
                fileSize: Int64(input.data.count),
                version: 1
            )

            try assetRepository.createAsset(asset)
            debugLog("asset metadata saved project=\(project.id.uuidString) asset=\(asset.id.uuidString)")

            if project.coverAssetID == nil {
                project.coverAssetID = asset.id
                debugLog("project cover assigned project=\(project.id.uuidString) asset=\(asset.id.uuidString)")
            }
            project.updatedAt = now
            try projectRepository.updateProject(project)

            let counts = try countService.counts(projectID: project.id)
            return ProjectAssetArchiveResult(project: project, asset: asset, counts: counts)
        } catch {
            for path in savedRelativePaths {
                try? fileStore.deleteFile(relativePath: path)
            }
            debugLog("asset archive failed error=\(error.localizedDescription)")
            throw error
        }
    }

    private func makeThumbnailIfPossible(
        data: Data,
        projectID: UUID,
        assetID: UUID,
        savedRelativePaths: inout [String]
    ) async -> String? {
        do {
            let thumbnailData = try await thumbnailGenerator.generateThumbnailJPEGData(from: data, maxPixelDimension: 512)
            let thumbnailPath = try fileStore.saveThumbnail(
                data: thumbnailData,
                projectID: projectID,
                assetID: assetID,
                fileExtension: "jpg"
            )
            savedRelativePaths.append(thumbnailPath)
            return thumbnailPath
        } catch {
            debugLog("thumbnail generation failed asset=\(assetID.uuidString) error=\(error.localizedDescription)")
            return nil
        }
    }
}

#if DEBUG
nonisolated private func debugLog(_ message: String) {
    print("[ProductWorkspace] \(message)")
}
#else
nonisolated private func debugLog(_ message: String) {}
#endif

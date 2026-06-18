//
//  ProductWorkspaceFoundationTests.swift
//  SellerCameraTests
//
//  Created by Codex on 2026/6/18.
//

import UIKit
import XCTest
@testable import SellerCamera

final class ProductWorkspaceFoundationTests: XCTestCase {
    private var tempRootURL: URL!
    private var userDefaults: UserDefaults!
    private var userDefaultsSuiteName: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempRootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SellerCameraP1ATests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempRootURL, withIntermediateDirectories: true)
        userDefaultsSuiteName = "SellerCameraP1ATests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: userDefaultsSuiteName)
        userDefaults.removePersistentDomain(forName: userDefaultsSuiteName)
    }

    override func tearDownWithError() throws {
        if let tempRootURL, FileManager.default.fileExists(atPath: tempRootURL.path) {
            try FileManager.default.removeItem(at: tempRootURL)
        }
        if let userDefaultsSuiteName {
            UserDefaults.standard.removePersistentDomain(forName: userDefaultsSuiteName)
        }
        tempRootURL = nil
        userDefaults = nil
        userDefaultsSuiteName = nil
        try super.tearDownWithError()
    }

    func testProjectNameGeneratorUsesSafeDailySequence() throws {
        let generator = DefaultProjectNameGenerator()
        let date = fixedDate()

        XCTAssertEqual(
            generator.generateName(existingNames: [], date: date),
            "商品项目 2026-06-18 001"
        )
        XCTAssertEqual(
            generator.generateName(existingNames: ["商品项目 2026-06-18 001"], date: date),
            "商品项目 2026-06-18 002"
        )
        XCTAssertEqual(
            generator.generateName(existingNames: ["商品项目 2026-06-18 001", "商品项目 2026-06-18 003"], date: date),
            "商品项目 2026-06-18 004"
        )
    }

    func testProjectCreationBecomesCurrentAndArchivedCurrentIsCleared() throws {
        let environment = makeEnvironment()
        let customProject = try environment.projectService.createProject(name: "自定义商品")
        XCTAssertEqual(customProject.name, "自定义商品")
        XCTAssertEqual(environment.currentProjectStore.currentProjectID, customProject.id)

        let restored = try environment.projectService.restoreCurrentProject()
        XCTAssertEqual(restored?.id, customProject.id)

        environment.currentProjectStore.setCurrentProject(UUID())
        XCTAssertNil(try environment.projectService.restoreCurrentProject())
        XCTAssertNil(environment.currentProjectStore.currentProjectID)

        try environment.projectService.setCurrentProject(customProject.id)
        try environment.repository.archiveProject(id: customProject.id)
        let archivedCurrent = try environment.projectService.restoreCurrentProject()
        XCTAssertNil(archivedCurrent)
        XCTAssertNil(environment.currentProjectStore.currentProjectID)
    }

    func testBlankProjectNameUsesAutoName() throws {
        let environment = makeEnvironment()
        let project = try environment.projectService.createProject(name: "   ", date: fixedDate())
        XCTAssertEqual(project.name, "商品项目 2026-06-18 001")
    }

    func testProjectDirectoriesAreRepeatableAndIsolated() throws {
        let environment = makeEnvironment()
        let firstProjectID = UUID()
        let secondProjectID = UUID()

        try environment.fileStore.createProjectDirectories(projectID: firstProjectID)
        try environment.fileStore.createProjectDirectories(projectID: firstProjectID)
        try environment.fileStore.createProjectDirectories(projectID: secondProjectID)

        let firstStandardURL = try environment.fileStore.resolveURL(
            relativePath: "\(firstProjectID.uuidString)/originals/standard"
        )
        let secondDetailURL = try environment.fileStore.resolveURL(
            relativePath: "\(secondProjectID.uuidString)/originals/detail"
        )
        let secondSKUURL = try environment.fileStore.resolveURL(
            relativePath: "\(secondProjectID.uuidString)/originals/sku"
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: firstStandardURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: secondDetailURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: secondSKUURL.path))
        XCTAssertNotEqual(firstStandardURL.path, secondDetailURL.path)
    }

    func testAssetArchiveCreatesMetadataCoverAndCounts() async throws {
        let environment = makeEnvironment()
        let project = try environment.projectService.createProject(name: nil, date: fixedDate())
        let firstInput = makePhotoInput(category: .standard)
        let firstResult = try await environment.archiveService.archivePhoto(firstInput)

        XCTAssertEqual(firstResult.project.id, project.id)
        XCTAssertEqual(firstResult.asset.projectID, project.id)
        XCTAssertEqual(firstResult.asset.category, .standard)
        XCTAssertEqual(firstResult.asset.assetType, .photo)
        XCTAssertEqual(firstResult.asset.mediaType, .photo)
        XCTAssertEqual(firstResult.asset.origin, .camera)
        XCTAssertEqual(firstResult.asset.originalFilename, "test-photo.jpg")
        XCTAssertEqual(firstResult.asset.version, 1)
        XCTAssertEqual(firstResult.counts.standard, 1)
        XCTAssertEqual(firstResult.counts.detail, 0)
        XCTAssertEqual(firstResult.counts.sku, 0)
        XCTAssertEqual(firstResult.counts.video, 0)
        XCTAssertEqual(firstResult.counts.total, 1)

        let savedOriginalURL = try environment.fileStore.resolveURL(relativePath: firstResult.asset.relativePath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: savedOriginalURL.path))
        if let thumbnailPath = firstResult.asset.thumbnailRelativePath {
            let thumbnailURL = try environment.fileStore.resolveURL(relativePath: thumbnailPath)
            XCTAssertTrue(FileManager.default.fileExists(atPath: thumbnailURL.path))
        }

        let projectAfterFirst = try XCTUnwrap(environment.repository.fetchProject(id: project.id))
        XCTAssertEqual(projectAfterFirst.coverAssetID, firstResult.asset.id)

        let detailResult = try await environment.archiveService.archivePhoto(makePhotoInput(category: .detail))
        let projectAfterSecond = try XCTUnwrap(environment.repository.fetchProject(id: project.id))
        XCTAssertEqual(projectAfterSecond.coverAssetID, firstResult.asset.id)
        XCTAssertEqual(detailResult.counts.standard, 1)
        XCTAssertEqual(detailResult.counts.detail, 1)
        XCTAssertEqual(detailResult.counts.sku, 0)
        XCTAssertEqual(detailResult.counts.video, 0)
        XCTAssertEqual(detailResult.counts.total, 2)

        let skuResult = try await environment.archiveService.archivePhoto(makePhotoInput(category: .sku))
        XCTAssertEqual(skuResult.counts.standard, 1)
        XCTAssertEqual(skuResult.counts.detail, 1)
        XCTAssertEqual(skuResult.counts.sku, 1)
        XCTAssertEqual(skuResult.counts.video, 0)
        XCTAssertEqual(skuResult.counts.total, 3)
    }

    func testCreateArchiveAndRestoreIntegration() async throws {
        let environment = makeEnvironment()
        let project = try environment.projectService.createProject(name: nil, date: fixedDate())
        let result = try await environment.archiveService.archivePhoto(makePhotoInput(category: .standard))

        XCTAssertEqual(environment.currentProjectStore.currentProjectID, project.id)
        XCTAssertNotNil(try environment.repository.fetchAsset(id: result.asset.id))
        XCTAssertEqual(try environment.countService.counts(projectID: project.id).total, 1)

        let restartedEnvironment = makeEnvironment()
        let restoredProject = try restartedEnvironment.projectService.restoreCurrentProject()
        XCTAssertEqual(restoredProject?.id, project.id)
        XCTAssertEqual(try restartedEnvironment.countService.counts(projectID: project.id).standard, 1)
        XCTAssertNotNil(try restartedEnvironment.repository.fetchAsset(id: result.asset.id))
    }

    func testProjectSwitchKeepsStatisticsIsolated() async throws {
        let environment = makeEnvironment()
        let firstProject = try environment.projectService.createProject(name: "项目 A", date: fixedDate())
        _ = try await environment.archiveService.archivePhoto(makePhotoInput(category: .standard))
        _ = try await environment.archiveService.archivePhoto(makePhotoInput(category: .detail))

        let secondProject = try environment.projectService.createProject(name: "项目 B", date: fixedDate())
        _ = try await environment.archiveService.archivePhoto(makePhotoInput(category: .sku))
        _ = try await environment.archiveService.archivePhoto(makePhotoInput(category: .sku))

        XCTAssertEqual(try environment.countService.counts(projectID: firstProject.id), ProjectAssetCounts(standard: 1, detail: 1, sku: 0, video: 0))
        XCTAssertEqual(try environment.countService.counts(projectID: secondProject.id), ProjectAssetCounts(standard: 0, detail: 0, sku: 2, video: 0))

        try environment.projectService.setCurrentProject(firstProject.id)
        XCTAssertEqual(try environment.projectService.restoreCurrentProject()?.id, firstProject.id)
    }

    func testLastCurrentProjectAndLastCategoryRestore() throws {
        let environment = makeEnvironment()
        let firstProject = try environment.projectService.createProject(name: "项目 A", date: fixedDate())
        let secondProject = try environment.projectService.createProject(name: "项目 B", date: fixedDate())

        _ = try environment.projectService.updateLastSelectedCaptureCategory(projectID: firstProject.id, category: .sku)
        _ = try environment.projectService.updateLastSelectedCaptureCategory(projectID: secondProject.id, category: .detail)
        try environment.projectService.setCurrentProject(firstProject.id)

        let restartedEnvironment = makeEnvironment()
        let restoredProject = try restartedEnvironment.projectService.restoreCurrentProject()
        XCTAssertEqual(restoredProject?.id, firstProject.id)
        XCTAssertEqual(restoredProject?.lastSelectedCaptureCategory, .sku)
    }

    func testArchiveResolveAndRestoreProject() throws {
        let environment = makeEnvironment()
        let firstProject = try environment.projectService.createProject(name: "项目 A", date: fixedDate())
        let secondProject = try environment.projectService.createProject(name: "项目 B", date: fixedDate())
        try environment.projectService.setCurrentProject(secondProject.id)

        let resolvedCurrent = try environment.projectService.archiveProjectAndResolveCurrent(id: secondProject.id, date: fixedDate())
        XCTAssertEqual(resolvedCurrent.id, firstProject.id)
        XCTAssertEqual(environment.currentProjectStore.currentProjectID, firstProject.id)
        XCTAssertTrue(try XCTUnwrap(environment.repository.fetchProject(id: secondProject.id)).isArchived)

        let restored = try environment.projectService.restoreArchivedProject(id: secondProject.id)
        XCTAssertFalse(restored.isArchived)
        XCTAssertEqual(restored.status, .active)
    }

    func testLegacyWhiteBackgroundCategoryMigratesToSKU() throws {
        let data = Data(#""whiteBackground""#.utf8)
        let category = try JSONDecoder().decode(CaptureCategory.self, from: data)
        XCTAssertEqual(category, .sku)
    }

    func testDefaultProjectIsNotCreatedRepeatedly() throws {
        let environment = makeEnvironment()
        let project = try environment.projectService.currentProjectOrCreateDefault(date: fixedDate())
        XCTAssertEqual(project.name, "商品项目 2026-06-18 001")

        environment.currentProjectStore.setCurrentProject(nil)
        let restoredRecent = try environment.projectService.currentProjectOrCreateDefault(date: fixedDate())
        XCTAssertEqual(restoredRecent.id, project.id)
        XCTAssertEqual(try environment.repository.fetchProjects(includeArchived: false).count, 1)
    }

    func testRenameAndSummariesReflectCounts() async throws {
        let environment = makeEnvironment()
        let project = try environment.projectService.createProject(name: "旧名称", date: fixedDate())
        _ = try await environment.archiveService.archivePhoto(makePhotoInput(category: .standard))
        _ = try await environment.archiveService.archivePhoto(makePhotoInput(category: .sku))

        let renamed = try environment.projectService.renameProject(id: project.id, name: "新名称")
        XCTAssertEqual(renamed.name, "新名称")

        let summary = try XCTUnwrap(environment.projectService.fetchProjectSummaries(includeArchived: false).first)
        XCTAssertEqual(summary.projectName, "新名称")
        XCTAssertEqual(summary.standardCount, 1)
        XCTAssertEqual(summary.skuCount, 1)
        XCTAssertTrue(summary.isCurrent)
    }

    func testP1CLegacyAssetMetadataMigratesToVersionedModel() throws {
        let repository = ProductWorkspaceJSONRepository(
            metadataURL: tempRootURL.appendingPathComponent("ProductWorkspace", isDirectory: true)
                .appendingPathComponent("metadata.json")
        )
        let projectID = UUID()
        let assetID = UUID()
        let timestamp = ISO8601DateFormatter().string(from: fixedDate())
        let metadata = """
        {
          "schemaVersion": 1,
          "projects": [
            {
              "id": "\(projectID.uuidString)",
              "schemaVersion": 1,
              "name": "Legacy",
              "createdAt": "\(timestamp)",
              "updatedAt": "\(timestamp)",
              "status": "active",
              "coverAssetID": null,
              "isArchived": false,
              "sortOrder": 0,
              "lastSelectedCaptureCategory": "standard"
            }
          ],
          "assets": [
            {
              "id": "\(assetID.uuidString)",
              "schemaVersion": 1,
              "projectID": "\(projectID.uuidString)",
              "category": "standard",
              "assetType": "photo",
              "origin": "camera",
              "originalFilename": "legacy.jpg",
              "relativePath": "\(projectID.uuidString)/originals/standard/\(assetID.uuidString).jpg",
              "thumbnailRelativePath": null,
              "createdAt": "\(timestamp)",
              "updatedAt": "\(timestamp)",
              "width": 128,
              "height": 96,
              "fileSize": 2048,
              "isFavorite": true,
              "isDeleted": false,
              "version": 3,
              "parentAssetID": null,
              "skuID": null
            }
          ]
        }
        """
        let metadataURL = repository.metadataURL
        try FileManager.default.createDirectory(
            at: metadataURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(metadata.utf8).write(to: metadataURL)

        let asset = try XCTUnwrap(repository.fetchAsset(id: assetID))
        XCTAssertEqual(asset.schemaVersion, 2)
        XCTAssertEqual(asset.mediaType, .photo)
        XCTAssertEqual(asset.sourceType, .camera)
        XCTAssertEqual(asset.pixelWidth, 128)
        XCTAssertEqual(asset.pixelHeight, 96)
        XCTAssertEqual(asset.fileSizeBytes, 2048)
        XCTAssertEqual(asset.isFavorite, true)
        XCTAssertEqual(asset.isBest, false)
        XCTAssertEqual(asset.deletionState, .active)
        XCTAssertEqual(asset.rootAssetID, assetID)
        XCTAssertEqual(asset.assetRole, .original)
        XCTAssertEqual(asset.processingState, .original)
        XCTAssertEqual(asset.versionNumber, 3)
    }

    func testP1CAssetLibraryFiltersTrashAndCoverFallback() async throws {
        let environment = makeEnvironment()
        let project = try environment.projectService.createProject(name: "资产库", date: fixedDate())
        let standard = try await environment.archiveService.archivePhoto(makePhotoInput(category: .standard)).asset
        let detail = try await environment.archiveService.archivePhoto(makePhotoInput(category: .detail)).asset
        let sku = try await environment.archiveService.archivePhoto(makePhotoInput(category: .sku)).asset
        let video = try await environment.archiveService.archivePhoto(makeVideoInput(targetProjectID: project.id)).asset

        try environment.assetLibraryService.updateFavorite(assetIDs: [detail.id], isFavorite: true)
        try environment.assetLibraryService.updateBest(assetIDs: [sku.id], isBest: true)

        XCTAssertEqual(try environment.assetLibraryService.fetchAssets(projectID: project.id, filter: .all).count, 4)
        XCTAssertEqual(try environment.assetLibraryService.fetchAssets(projectID: project.id, filter: .category(.standard)).map(\.id), [standard.id])
        XCTAssertEqual(try environment.assetLibraryService.fetchAssets(projectID: project.id, filter: .video).map(\.id), [video.id])
        XCTAssertEqual(try environment.assetLibraryService.fetchAssets(projectID: project.id, filter: .favorite).map(\.id), [detail.id])
        XCTAssertEqual(try environment.assetLibraryService.fetchAssets(projectID: project.id, filter: .best).map(\.id), [sku.id])

        try environment.assetLibraryService.setProjectCover(projectID: project.id, assetID: standard.id)
        try environment.assetLibraryService.moveToTrash(assetIDs: [standard.id])
        let projectAfterTrash = try XCTUnwrap(environment.repository.fetchProject(id: project.id))
        XCTAssertEqual(projectAfterTrash.coverAssetID, sku.id)
        XCTAssertEqual(try environment.countService.counts(projectID: project.id), ProjectAssetCounts(standard: 0, detail: 1, sku: 1, video: 1))
        XCTAssertEqual(try environment.assetLibraryService.fetchAssets(projectID: project.id, filter: .trash).map(\.id), [standard.id])

        try environment.assetLibraryService.restoreFromTrash(assetIDs: [standard.id])
        XCTAssertEqual(try environment.countService.counts(projectID: project.id).total, 4)
        XCTAssertEqual(try XCTUnwrap(environment.repository.fetchProject(id: project.id)).coverAssetID, sku.id)
    }

    func testP1CPermanentDeleteRemovesFilesAndBlocksActiveDerivedAssets() async throws {
        let environment = makeEnvironment()
        _ = try environment.projectService.createProject(name: "版本", date: fixedDate())
        let original = try await environment.archiveService.archivePhoto(makePhotoInput(category: .standard)).asset
        let derivedID = UUID()
        let derivedPath = try environment.fileStore.saveOriginalPhoto(
            data: Data("derived".utf8),
            projectID: original.projectID,
            category: .standard,
            assetID: derivedID,
            fileExtension: "jpg"
        )
        let derived = ProjectAsset(
            id: derivedID,
            projectID: original.projectID,
            category: .standard,
            origin: .generated,
            originalFilename: "processed.jpg",
            relativePath: derivedPath,
            thumbnailRelativePath: nil,
            createdAt: fixedDate(),
            updatedAt: fixedDate(),
            width: original.width,
            height: original.height,
            fileSize: original.fileSize,
            version: 2,
            parentAssetID: original.id,
            rootAssetID: original.id,
            assetRole: .processed,
            processingState: .completed
        )
        try environment.repository.createAsset(derived)

        XCTAssertThrowsError(try environment.assetLibraryService.permanentlyDelete(assetIDs: [original.id]))

        try environment.assetLibraryService.moveToTrash(assetIDs: [derived.id])
        _ = try environment.assetLibraryService.permanentlyDelete(assetIDs: [derived.id])
        try environment.assetLibraryService.moveToTrash(assetIDs: [original.id])
        let originalURL = try environment.fileStore.resolveURL(relativePath: original.relativePath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: originalURL.path))
        _ = try environment.assetLibraryService.permanentlyDelete(assetIDs: [original.id])
        XCTAssertNil(try environment.repository.fetchAsset(id: original.id))
        XCTAssertFalse(FileManager.default.fileExists(atPath: originalURL.path))
    }

    @MainActor
    func testP1CImportSessionDedupesAndRoutesVideoToTargetProject() async throws {
        let environment = makeEnvironment()
        let firstProject = try environment.projectService.createProject(name: "项目 A", date: fixedDate())
        let secondProject = try environment.projectService.createProject(name: "项目 B", date: fixedDate())
        let session = ProductAssetLibrarySession(environment: environment)
        await session.load(projectID: secondProject.id)

        let imageData = makePhotoInput(category: .standard).data
        let importItems = [
            ProjectAssetImportItem(
                data: imageData,
                mediaType: .photo,
                originalFilename: "import.jpg",
                fileExtension: "jpg",
                pixelWidth: 64,
                pixelHeight: 48,
                durationSeconds: nil
            ),
            ProjectAssetImportItem(
                data: imageData,
                mediaType: .photo,
                originalFilename: "import.jpg",
                fileExtension: "jpg",
                pixelWidth: 64,
                pixelHeight: 48,
                durationSeconds: nil
            ),
            ProjectAssetImportItem(
                data: Data("fake-movie".utf8),
                mediaType: .video,
                originalFilename: "clip.mov",
                fileExtension: "mov",
                pixelWidth: nil,
                pixelHeight: nil,
                durationSeconds: 1.2
            )
        ]

        let result = await session.importItems(importItems, projectID: secondProject.id, category: .detail)
        XCTAssertEqual(result.requestedCount, 3)
        XCTAssertEqual(result.succeededCount, 2)
        XCTAssertEqual(result.failedCount, 0)
        XCTAssertEqual(try environment.countService.counts(projectID: firstProject.id).total, 0)
        XCTAssertEqual(try environment.countService.counts(projectID: secondProject.id), ProjectAssetCounts(standard: 0, detail: 1, sku: 0, video: 1))

        let importedAssets = try environment.assetLibraryService.fetchAssets(projectID: secondProject.id, filter: .all)
        XCTAssertTrue(importedAssets.allSatisfy { $0.sourceType == .photoLibrary && $0.importedAt != nil })
        XCTAssertEqual(importedAssets.filter { $0.mediaType == .video }.first?.category, .video)
    }

    private func makeEnvironment() -> ProductWorkspaceEnvironment {
        ProductWorkspaceEnvironment(
            rootURL: tempRootURL.appendingPathComponent("Projects", isDirectory: true),
            metadataURL: tempRootURL.appendingPathComponent("ProductWorkspace", isDirectory: true)
                .appendingPathComponent("metadata.json"),
            userDefaults: userDefaults
        )
    }

    private func fixedDate() -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2026
        components.month = 6
        components.day = 18
        components.hour = 12
        return components.date!
    }

    private func makePhotoInput(category: CaptureCategory) -> ProjectPhotoArchiveInput {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 48))
        let image = renderer.image { context in
            UIColor.darkGray.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 64, height: 48))
            UIColor.white.setFill()
            context.fill(CGRect(x: 12, y: 10, width: 40, height: 28))
        }
        return ProjectPhotoArchiveInput(
            data: image.jpegData(compressionQuality: 0.9)!,
            capturedAt: fixedDate(),
            category: category,
            origin: .camera,
            width: 64,
            height: 48,
            metadata: ["test": "true"],
            originalFilename: "test-photo.jpg"
        )
    }

    private func makeVideoInput(targetProjectID: UUID) -> ProjectPhotoArchiveInput {
        ProjectPhotoArchiveInput(
            data: Data("fake-movie".utf8),
            targetProjectID: targetProjectID,
            capturedAt: fixedDate(),
            category: .video,
            origin: .photoLibrary,
            mediaType: .video,
            width: nil,
            height: nil,
            duration: 1.2,
            metadata: ["test": "video"],
            originalFilename: "clip.mov",
            fileExtension: "mov"
        )
    }
}

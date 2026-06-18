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
            "商品 2026-06-18 001"
        )
        XCTAssertEqual(
            generator.generateName(existingNames: ["商品 2026-06-18 001"], date: date),
            "商品 2026-06-18 002"
        )
        XCTAssertEqual(
            generator.generateName(existingNames: ["商品 2026-06-18 001", "商品 2026-06-18 003"], date: date),
            "商品 2026-06-18 004"
        )
    }

    func testProjectCreationCurrentProjectRestoreAndArchiveState() throws {
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
        XCTAssertEqual(archivedCurrent?.id, customProject.id)
        XCTAssertEqual(archivedCurrent?.status, .archived)
        XCTAssertEqual(archivedCurrent?.isArchived, true)
    }

    func testBlankProjectNameUsesAutoName() throws {
        let environment = makeEnvironment()
        let project = try environment.projectService.createProject(name: "   ", date: fixedDate())
        XCTAssertEqual(project.name, "商品 2026-06-18 001")
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
        XCTAssertTrue(FileManager.default.fileExists(atPath: firstStandardURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: secondDetailURL.path))
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
        XCTAssertEqual(firstResult.asset.origin, .camera)
        XCTAssertEqual(firstResult.asset.version, 1)
        XCTAssertEqual(firstResult.counts.standard, 1)
        XCTAssertEqual(firstResult.counts.detail, 0)
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
        XCTAssertEqual(detailResult.counts.video, 0)
        XCTAssertEqual(detailResult.counts.total, 2)
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
            metadata: ["test": "true"]
        )
    }
}

//
//  ProductWorkspaceEnvironment.swift
//  SellerCamera
//
//  Created by Codex on 2026/6/18.
//

import Foundation

nonisolated final class ProductWorkspaceEnvironment {
    static let shared = ProductWorkspaceEnvironment()

    let repository: ProductWorkspaceJSONRepository
    let currentProjectStore: CurrentProjectStore
    let fileStore: ProjectFileStore
    let nameGenerator: ProjectNameGenerating
    let thumbnailGenerator: ThumbnailGenerator
    let projectService: ProductProjectService
    let countService: ProjectAssetCountService
    let archiveService: ProjectAssetArchiveService
    let assetLibraryService: ProjectAssetLibraryService

    init(
        rootURL: URL = ProjectFileStore.defaultRootURL(),
        metadataURL: URL? = nil,
        userDefaults: UserDefaults = .standard
    ) {
        let fileStore = ProjectFileStore(rootURL: rootURL)
        let repository = ProductWorkspaceJSONRepository(
            metadataURL: metadataURL ?? rootURL
                .deletingLastPathComponent()
                .appendingPathComponent("ProductWorkspace", isDirectory: true)
                .appendingPathComponent("metadata.json")
        )
        let currentProjectStore = UserDefaultsCurrentProjectStore(userDefaults: userDefaults)
        let nameGenerator = DefaultProjectNameGenerator()
        let thumbnailGenerator = ThumbnailGenerator()
        let countService = ProjectAssetCountService(assetCounter: repository)
        let projectService = ProductProjectService(
            projectRepository: repository,
            assetRepository: repository,
            assetCounter: repository,
            currentProjectStore: currentProjectStore,
            nameGenerator: nameGenerator,
            fileStore: fileStore
        )
        let archiveService = ProjectAssetArchiveService(
            projectService: projectService,
            projectRepository: repository,
            assetRepository: repository,
            countService: countService,
            fileStore: fileStore,
            thumbnailGenerator: thumbnailGenerator
        )
        let assetLibraryService = ProjectAssetLibraryService(
            projectRepository: repository,
            assetRepository: repository,
            projectService: projectService,
            countService: countService,
            fileStore: fileStore
        )

        self.repository = repository
        self.currentProjectStore = currentProjectStore
        self.fileStore = fileStore
        self.nameGenerator = nameGenerator
        self.thumbnailGenerator = thumbnailGenerator
        self.projectService = projectService
        self.countService = countService
        self.archiveService = archiveService
        self.assetLibraryService = assetLibraryService
    }
}

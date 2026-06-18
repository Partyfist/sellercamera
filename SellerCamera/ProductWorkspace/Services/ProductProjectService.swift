//
//  ProductProjectService.swift
//  SellerCamera
//
//  Created by Codex on 2026/6/18.
//

import Foundation

nonisolated final class ProductProjectService {
    private let projectRepository: ProductProjectRepository
    private let assetRepository: ProjectAssetRepository
    private let assetCounter: ProjectAssetCounting
    private let currentProjectStore: CurrentProjectStore
    private let nameGenerator: ProjectNameGenerating
    private let fileStore: ProjectFileStoring

    init(
        projectRepository: ProductProjectRepository,
        assetRepository: ProjectAssetRepository,
        assetCounter: ProjectAssetCounting,
        currentProjectStore: CurrentProjectStore,
        nameGenerator: ProjectNameGenerating,
        fileStore: ProjectFileStoring
    ) {
        self.projectRepository = projectRepository
        self.assetRepository = assetRepository
        self.assetCounter = assetCounter
        self.currentProjectStore = currentProjectStore
        self.nameGenerator = nameGenerator
        self.fileStore = fileStore
    }

    func createProject(name: String?, date: Date = Date()) throws -> ProductProject {
        let projectName = try resolvedProjectName(name: name, date: date)
        let project = try projectRepository.createProject(name: projectName)
        try fileStore.createProjectDirectories(projectID: project.id)
        currentProjectStore.setCurrentProject(project.id)
        debugLog("project created id=\(project.id.uuidString) name=\(project.name)")
        debugLog("current project changed id=\(project.id.uuidString)")
        return project
    }

    func restoreCurrentProject() throws -> ProductProject? {
        guard let currentProjectID = currentProjectStore.currentProjectID else {
            return nil
        }
        guard let project = try projectRepository.fetchProject(id: currentProjectID) else {
            currentProjectStore.setCurrentProject(nil)
            debugLog("project restored missing id=\(currentProjectID.uuidString), cleared")
            return nil
        }
        guard !project.isArchived else {
            currentProjectStore.setCurrentProject(nil)
            debugLog("project restored archived id=\(currentProjectID.uuidString), cleared")
            return nil
        }
        try fileStore.createProjectDirectories(projectID: project.id)
        debugLog("project restored id=\(project.id.uuidString) name=\(project.name)")
        return project
    }

    func currentProjectOrCreateDefault(date: Date = Date()) throws -> ProductProject {
        if let currentProject = try restoreCurrentProject() {
            return currentProject
        }
        if let recentProject = try mostRecentActiveProject() {
            try setCurrentProject(recentProject.id)
            try fileStore.createProjectDirectories(projectID: recentProject.id)
            debugLog("no current project, restored recent id=\(recentProject.id.uuidString)")
            return recentProject
        }
        let project = try createProject(name: nil, date: date)
        debugLog("no current project, auto-created project=\(project.id.uuidString) name=\(project.name)")
        return project
    }

    func setCurrentProject(_ id: UUID?) throws {
        if let id {
            guard let project = try projectRepository.fetchProject(id: id) else {
                currentProjectStore.setCurrentProject(nil)
                throw ProductWorkspaceError.projectNotFound(id)
            }
            guard !project.isArchived else {
                currentProjectStore.setCurrentProject(nil)
                throw ProductWorkspaceError.currentProjectUnavailable
            }
            try fileStore.createProjectDirectories(projectID: project.id)
        }
        currentProjectStore.setCurrentProject(id)
        debugLog("current project changed id=\(id?.uuidString ?? "nil")")
    }

    func renameProject(id: UUID, name: String) throws -> ProductProject {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ProductWorkspaceError.invalidProjectName
        }
        var projects = try projectRepository.fetchProjects(includeArchived: true)
        guard let index = projects.firstIndex(where: { $0.id == id }) else {
            throw ProductWorkspaceError.projectNotFound(id)
        }
        guard !projects.contains(where: { $0.id != id && $0.name == trimmed }) else {
            throw ProductWorkspaceError.invalidProjectName
        }
        projects[index].name = trimmed
        projects[index].updatedAt = Date()
        try projectRepository.updateProject(projects[index])
        debugLog("project renamed id=\(id.uuidString)")
        return projects[index]
    }

    func updateLastSelectedCaptureCategory(projectID: UUID, category: CaptureCategory) throws -> ProductProject {
        guard var project = try projectRepository.fetchProject(id: projectID) else {
            throw ProductWorkspaceError.projectNotFound(projectID)
        }
        project.lastSelectedCaptureCategory = category
        project.updatedAt = Date()
        try projectRepository.updateProject(project)
        debugLog("project category selected id=\(projectID.uuidString) category=\(category.rawValue)")
        return project
    }

    func archiveProjectAndResolveCurrent(id: UUID, date: Date = Date()) throws -> ProductProject {
        try projectRepository.archiveProject(id: id)
        debugLog("project archived id=\(id.uuidString)")
        if currentProjectStore.currentProjectID == id {
            currentProjectStore.setCurrentProject(nil)
        }
        return try currentProjectOrCreateDefault(date: date)
    }

    func restoreArchivedProject(id: UUID) throws -> ProductProject {
        try projectRepository.restoreProject(id: id)
        guard let project = try projectRepository.fetchProject(id: id) else {
            throw ProductWorkspaceError.projectNotFound(id)
        }
        try fileStore.createProjectDirectories(projectID: project.id)
        debugLog("project restored from archive id=\(id.uuidString)")
        return project
    }

    func setProjectCover(projectID: UUID, assetID: UUID) throws -> ProductProject {
        guard var project = try projectRepository.fetchProject(id: projectID) else {
            throw ProductWorkspaceError.projectNotFound(projectID)
        }
        project.coverAssetID = assetID
        project.updatedAt = Date()
        try projectRepository.updateProject(project)
        debugLog("project cover changed id=\(projectID.uuidString) asset=\(assetID.uuidString)")
        return project
    }

    func fetchProjectSummaries(includeArchived: Bool) throws -> [CurrentProjectSummary] {
        let currentID = currentProjectStore.currentProjectID
        return try projectRepository.fetchProjects(includeArchived: includeArchived)
            .map { project in
                let counts = try assetCounter.counts(projectID: project.id)
                let coverPath = try project.coverAssetID.flatMap { id in
                    try assetRepository.fetchAsset(id: id)?.thumbnailRelativePath
                }
                return CurrentProjectSummary(
                    projectID: project.id,
                    projectName: project.name,
                    coverThumbnailPath: coverPath,
                    counts: counts,
                    updatedAt: project.updatedAt,
                    isCurrent: project.id == currentID,
                    isArchived: project.isArchived
                )
            }
            .sorted { lhs, rhs in
                if lhs.isCurrent != rhs.isCurrent {
                    return lhs.isCurrent
                }
                return lhs.updatedAt > rhs.updatedAt
            }
    }

    private func resolvedProjectName(name: String?, date: Date) throws -> String {
        let trimmed = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty else {
            return trimmed
        }
        let existingNames = try projectRepository.fetchProjects(includeArchived: true).map(\.name)
        return nameGenerator.generateName(existingNames: existingNames, date: date)
    }

    private func mostRecentActiveProject() throws -> ProductProject? {
        try projectRepository.fetchProjects(includeArchived: false)
            .filter { !$0.isArchived }
            .sorted { $0.updatedAt > $1.updatedAt }
            .first
    }
}

#if DEBUG
nonisolated private func debugLog(_ message: String) {
    print("[Project] \(message)")
}
#else
nonisolated private func debugLog(_ message: String) {}
#endif

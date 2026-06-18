//
//  ProductProjectService.swift
//  SellerCamera
//
//  Created by Codex on 2026/6/18.
//

import Foundation

nonisolated final class ProductProjectService {
    private let projectRepository: ProductProjectRepository
    private let currentProjectStore: CurrentProjectStore
    private let nameGenerator: ProjectNameGenerating
    private let fileStore: ProjectFileStoring

    init(
        projectRepository: ProductProjectRepository,
        currentProjectStore: CurrentProjectStore,
        nameGenerator: ProjectNameGenerating,
        fileStore: ProjectFileStoring
    ) {
        self.projectRepository = projectRepository
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
        try fileStore.createProjectDirectories(projectID: project.id)
        debugLog("project restored id=\(project.id.uuidString) name=\(project.name)")
        return project
    }

    func currentProjectOrCreateDefault(date: Date = Date()) throws -> ProductProject {
        if let currentProject = try restoreCurrentProject() {
            return currentProject
        }
        let project = try createProject(name: nil, date: date)
        debugLog("no current project, auto-created project=\(project.id.uuidString) name=\(project.name)")
        return project
    }

    func setCurrentProject(_ id: UUID?) throws {
        if let id, try projectRepository.fetchProject(id: id) == nil {
            currentProjectStore.setCurrentProject(nil)
            throw ProductWorkspaceError.projectNotFound(id)
        }
        currentProjectStore.setCurrentProject(id)
        debugLog("current project changed id=\(id?.uuidString ?? "nil")")
    }

    private func resolvedProjectName(name: String?, date: Date) throws -> String {
        let trimmed = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty else {
            return trimmed
        }
        let existingNames = try projectRepository.fetchProjects(includeArchived: true).map(\.name)
        return nameGenerator.generateName(existingNames: existingNames, date: date)
    }
}

#if DEBUG
nonisolated private func debugLog(_ message: String) {
    print("[ProjectStore] \(message)")
}
#else
nonisolated private func debugLog(_ message: String) {}
#endif

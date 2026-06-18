//
//  ProductWorkspaceSession.swift
//  SellerCamera
//
//  Created by Codex on 2026/6/18.
//

import Combine
import Foundation

@MainActor
final class ProductWorkspaceSession: ObservableObject {
    @Published private(set) var currentProject: ProductProject?
    @Published private(set) var currentProjectSummary: CurrentProjectSummary?
    @Published private(set) var currentCounts: ProjectAssetCounts = .empty
    @Published private(set) var selectedCaptureCategory: CaptureCategory = .standard
    @Published private(set) var projectSummaries: [CurrentProjectSummary] = []
    @Published private(set) var archivedProjectSummaries: [CurrentProjectSummary] = []
    @Published private(set) var currentProjectAssets: [ProjectAsset] = []
    @Published private(set) var allAssets: [ProjectAsset] = []
    @Published private(set) var lastStatusText = "项目未创建"

    let environment: ProductWorkspaceEnvironment

    init(environment: ProductWorkspaceEnvironment = .shared) {
        self.environment = environment
    }

    func restoreCurrentProject() async {
        await loadWorkspaceState(statusOverride: nil)
    }

    func createProject(name: String? = nil) async {
        do {
            let state = try await Task.detached(priority: .utility) { [environment] in
                let project = try environment.projectService.createProject(name: name)
                return try Self.makeState(environment: environment, currentProject: project)
            }.value
            apply(state, statusOverride: "项目已创建：\(state.currentProject.name)")
        } catch {
            lastStatusText = "项目创建失败"
        }
    }

    func selectProject(id: UUID) async {
        do {
            let state = try await Task.detached(priority: .utility) { [environment] in
                try environment.projectService.setCurrentProject(id)
                let project = try environment.projectService.currentProjectOrCreateDefault()
                return try Self.makeState(environment: environment, currentProject: project)
            }.value
            apply(state, statusOverride: "当前项目：\(state.currentProject.name)")
        } catch {
            lastStatusText = "项目切换失败"
        }
    }

    func selectCaptureCategory(_ category: CaptureCategory) async {
        do {
            let state = try await Task.detached(priority: .utility) { [environment] in
                let currentProject = try environment.projectService.currentProjectOrCreateDefault()
                let updatedProject = try environment.projectService.updateLastSelectedCaptureCategory(
                    projectID: currentProject.id,
                    category: category
                )
                debugCategoryLog("selected \(category.rawValue) projectID=\(updatedProject.id.uuidString)")
                return try Self.makeState(environment: environment, currentProject: updatedProject)
            }.value
            apply(state, statusOverride: nil)
        } catch {
            selectedCaptureCategory = category
            lastStatusText = "分类已切换，项目状态稍后同步"
        }
    }

    func renameProject(id: UUID, name: String) async {
        do {
            let state = try await Task.detached(priority: .utility) { [environment] in
                _ = try environment.projectService.renameProject(id: id, name: name)
                let currentProject = try environment.projectService.currentProjectOrCreateDefault()
                return try Self.makeState(environment: environment, currentProject: currentProject)
            }.value
            apply(state, statusOverride: "项目已重命名")
        } catch {
            lastStatusText = "项目重命名失败"
        }
    }

    func archiveProject(id: UUID) async {
        do {
            let state = try await Task.detached(priority: .utility) { [environment] in
                let currentProject = try environment.projectService.archiveProjectAndResolveCurrent(id: id)
                return try Self.makeState(environment: environment, currentProject: currentProject)
            }.value
            apply(state, statusOverride: "项目已归档")
        } catch {
            lastStatusText = "项目归档失败"
        }
    }

    func restoreArchivedProject(id: UUID) async {
        do {
            let state = try await Task.detached(priority: .utility) { [environment] in
                _ = try environment.projectService.restoreArchivedProject(id: id)
                let currentProject = try environment.projectService.currentProjectOrCreateDefault()
                return try Self.makeState(environment: environment, currentProject: currentProject)
            }.value
            apply(state, statusOverride: "项目已恢复")
        } catch {
            lastStatusText = "项目恢复失败"
        }
    }

    func setCover(projectID: UUID, assetID: UUID) async {
        do {
            let state = try await Task.detached(priority: .utility) { [environment] in
                _ = try environment.projectService.setProjectCover(projectID: projectID, assetID: assetID)
                let currentProject = try environment.projectService.currentProjectOrCreateDefault()
                return try Self.makeState(environment: environment, currentProject: currentProject)
            }.value
            apply(state, statusOverride: "封面已更新")
        } catch {
            lastStatusText = "封面更新失败"
        }
    }

    func refreshCurrentProjectState() async {
        await loadWorkspaceState(statusOverride: nil)
    }

    func projectName(for projectID: UUID) -> String {
        if currentProject?.id == projectID {
            return currentProject?.name ?? "当前项目"
        }
        return (projectSummaries + archivedProjectSummaries)
            .first(where: { $0.projectID == projectID })?
            .projectName ?? "未知项目"
    }

    private func loadWorkspaceState(statusOverride: String?) async {
        do {
            let state = try await Task.detached(priority: .utility) { [environment] in
                let project = try environment.projectService.currentProjectOrCreateDefault()
                return try Self.makeState(environment: environment, currentProject: project)
            }.value
            apply(state, statusOverride: statusOverride)
        } catch {
            currentProject = nil
            currentProjectSummary = nil
            currentCounts = .empty
            projectSummaries = []
            archivedProjectSummaries = []
            currentProjectAssets = []
            allAssets = []
            lastStatusText = "项目恢复失败"
        }
    }

    private func apply(_ state: WorkspaceState, statusOverride: String?) {
        currentProject = state.currentProject
        currentProjectSummary = state.currentSummary
        currentCounts = state.currentCounts
        selectedCaptureCategory = state.currentProject.lastSelectedCaptureCategory
        projectSummaries = state.projectSummaries
        archivedProjectSummaries = state.archivedProjectSummaries
        currentProjectAssets = state.currentProjectAssets
        allAssets = state.allAssets
        lastStatusText = statusOverride ?? "当前项目：\(state.currentProject.name) · \(state.currentCounts.total) 张"
    }

    private nonisolated static func makeState(
        environment: ProductWorkspaceEnvironment,
        currentProject: ProductProject
    ) throws -> WorkspaceState {
        let currentCounts = try environment.countService.counts(projectID: currentProject.id)
        let projectSummaries = try environment.projectService.fetchProjectSummaries(includeArchived: false)
        let archivedProjectSummaries = try environment.projectService.fetchProjectSummaries(includeArchived: true)
            .filter(\.isArchived)
        let allAssets = try environment.repository.fetchAssets(includeDeleted: false)
        let currentProjectAssets = allAssets.filter { $0.projectID == currentProject.id }
        let currentSummary = projectSummaries.first(where: { $0.projectID == currentProject.id })
        debugStatsLog(
            "counts updated projectID=\(currentProject.id.uuidString) " +
            "standard=\(currentCounts.standard) detail=\(currentCounts.detail) sku=\(currentCounts.sku) video=\(currentCounts.video)"
        )
        return WorkspaceState(
            currentProject: currentProject,
            currentSummary: currentSummary,
            currentCounts: currentCounts,
            projectSummaries: projectSummaries,
            archivedProjectSummaries: archivedProjectSummaries,
            currentProjectAssets: currentProjectAssets,
            allAssets: allAssets
        )
    }
}

private nonisolated struct WorkspaceState {
    var currentProject: ProductProject
    var currentSummary: CurrentProjectSummary?
    var currentCounts: ProjectAssetCounts
    var projectSummaries: [CurrentProjectSummary]
    var archivedProjectSummaries: [CurrentProjectSummary]
    var currentProjectAssets: [ProjectAsset]
    var allAssets: [ProjectAsset]
}

#if DEBUG
nonisolated private func debugCategoryLog(_ message: String) {
    print("[CaptureCategory] \(message)")
}

nonisolated private func debugStatsLog(_ message: String) {
    print("[ProjectStats] \(message)")
}
#else
nonisolated private func debugCategoryLog(_ message: String) {}
nonisolated private func debugStatsLog(_ message: String) {}
#endif

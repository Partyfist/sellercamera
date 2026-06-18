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
    @Published private(set) var currentCounts: ProjectAssetCounts = .empty
    @Published private(set) var lastStatusText = "项目未创建"

    let environment: ProductWorkspaceEnvironment

    init(environment: ProductWorkspaceEnvironment = .shared) {
        self.environment = environment
    }

    func restoreCurrentProject() async {
        do {
            let state = try await Task.detached(priority: .utility) { [environment] in
                let project = try environment.projectService.restoreCurrentProject()
                let counts = try project.map { try environment.countService.counts(projectID: $0.id) } ?? .empty
                return (project, counts)
            }.value
            currentProject = state.0
            currentCounts = state.1
            lastStatusText = state.0.map { "当前项目：\($0.name) · \(state.1.total) 张" } ?? "项目未创建"
        } catch {
            lastStatusText = "项目恢复失败"
        }
    }

    func createProject(name: String? = nil) async {
        do {
            let state = try await Task.detached(priority: .utility) { [environment] in
                let project = try environment.projectService.createProject(name: name)
                let counts = try environment.countService.counts(projectID: project.id)
                return (project, counts)
            }.value
            currentProject = state.0
            currentCounts = state.1
            lastStatusText = "项目已创建：\(state.0.name)"
        } catch {
            lastStatusText = "项目创建失败"
        }
    }

    func refreshCurrentProjectState() async {
        await restoreCurrentProject()
    }
}

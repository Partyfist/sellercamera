//
//  ProjectFileStore.swift
//  SellerCamera
//
//  Created by Codex on 2026/6/18.
//

import Foundation

nonisolated final class ProjectFileStore: ProjectFileStoring {
    let rootURL: URL

    init(rootURL: URL = ProjectFileStore.defaultRootURL()) {
        self.rootURL = rootURL
    }

    static func defaultRootURL() -> URL {
        let applicationSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return applicationSupportURL
            .appendingPathComponent("SellerCamera", isDirectory: true)
            .appendingPathComponent("Projects", isDirectory: true)
    }

    func createProjectDirectories(projectID: UUID) throws {
        let relativeDirectories = [
            projectRootRelativePath(projectID: projectID),
            "\(projectRootRelativePath(projectID: projectID))/manifest",
            originalDirectoryRelativePath(projectID: projectID, category: .standard),
            originalDirectoryRelativePath(projectID: projectID, category: .detail),
            originalDirectoryRelativePath(projectID: projectID, category: .video),
            "\(projectRootRelativePath(projectID: projectID))/thumbnails",
            "\(projectRootRelativePath(projectID: projectID))/processed",
            "\(projectRootRelativePath(projectID: projectID))/exports"
        ]

        do {
            for relativePath in relativeDirectories {
                try FileManager.default.createDirectory(
                    at: try resolveURL(relativePath: relativePath),
                    withIntermediateDirectories: true
                )
            }
            debugLog("project directories created project=\(projectID.uuidString)")
        } catch {
            throw ProductWorkspaceError.directoryCreationFailed(error.localizedDescription)
        }
    }

    func saveOriginalPhoto(
        data: Data,
        projectID: UUID,
        category: CaptureCategory,
        assetID: UUID,
        fileExtension: String
    ) throws -> String {
        let sanitizedExtension = sanitizedFileExtension(fileExtension)
        let relativePath = "\(originalDirectoryRelativePath(projectID: projectID, category: category))/\(assetID.uuidString).\(sanitizedExtension)"
        try write(data: data, relativePath: relativePath)
        debugLog("asset file saved project=\(projectID.uuidString) asset=\(assetID.uuidString) path=\(relativePath)")
        return relativePath
    }

    func saveThumbnail(
        data: Data,
        projectID: UUID,
        assetID: UUID,
        fileExtension: String
    ) throws -> String {
        let sanitizedExtension = sanitizedFileExtension(fileExtension)
        let relativePath = "\(projectRootRelativePath(projectID: projectID))/thumbnails/\(assetID.uuidString).\(sanitizedExtension)"
        try write(data: data, relativePath: relativePath)
        debugLog("thumbnail generated project=\(projectID.uuidString) asset=\(assetID.uuidString) path=\(relativePath)")
        return relativePath
    }

    func resolveURL(relativePath: String) throws -> URL {
        let cleanPath = relativePath
            .split(separator: "/")
            .filter { !$0.isEmpty && $0 != "." && $0 != ".." }
            .joined(separator: "/")
        guard cleanPath == relativePath || relativePath.hasSuffix("/") == false else {
            throw ProductWorkspaceError.fileWriteFailed(relativePath)
        }
        return rootURL.appendingPathComponent(cleanPath)
    }

    func deleteFile(relativePath: String) throws {
        let url = try resolveURL(relativePath: relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    func deleteProjectFiles(projectID: UUID) throws {
        let url = try resolveURL(relativePath: projectRootRelativePath(projectID: projectID))
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    private func write(data: Data, relativePath: String) throws {
        do {
            let url = try resolveURL(relativePath: relativePath)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: .atomic)
        } catch {
            throw ProductWorkspaceError.fileWriteFailed(relativePath)
        }
    }

    private func projectRootRelativePath(projectID: UUID) -> String {
        projectID.uuidString
    }

    private func originalDirectoryRelativePath(projectID: UUID, category: CaptureCategory) -> String {
        "\(projectRootRelativePath(projectID: projectID))/originals/\(category.rawValue)"
    }

    private func sanitizedFileExtension(_ fileExtension: String) -> String {
        let trimmed = fileExtension
            .trimmingCharacters(in: CharacterSet(charactersIn: ".").union(.whitespacesAndNewlines))
            .lowercased()
        guard trimmed.range(of: #"^[a-z0-9]{2,5}$"#, options: .regularExpression) != nil else {
            return "jpg"
        }
        return trimmed
    }
}

#if DEBUG
nonisolated private func debugLog(_ message: String) {
    print("[ProjectFileStore] \(message)")
}
#else
nonisolated private func debugLog(_ message: String) {}
#endif

//
//  ProductWorkspaceErrors.swift
//  SellerCamera
//
//  Created by Codex on 2026/6/18.
//

import Foundation

nonisolated enum ProductWorkspaceError: LocalizedError, Equatable {
    case invalidProjectName
    case projectNotFound(UUID)
    case currentProjectUnavailable
    case directoryCreationFailed(String)
    case fileWriteFailed(String)
    case metadataSaveFailed(String)
    case assetNotFound(UUID)
    case unsupportedFileFormat
    case metadataLoadFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidProjectName:
            return "项目名称不可为空"
        case .projectNotFound(let id):
            return "项目不存在：\(id.uuidString)"
        case .currentProjectUnavailable:
            return "当前项目不可用"
        case .directoryCreationFailed(let path):
            return "项目目录创建失败：\(path)"
        case .fileWriteFailed(let path):
            return "文件写入失败：\(path)"
        case .metadataSaveFailed(let reason):
            return "元数据保存失败：\(reason)"
        case .assetNotFound(let id):
            return "资产不存在：\(id.uuidString)"
        case .unsupportedFileFormat:
            return "不支持的文件格式"
        case .metadataLoadFailed(let reason):
            return "元数据读取失败：\(reason)"
        }
    }
}

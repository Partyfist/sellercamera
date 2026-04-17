//
//  CapturePhotoLibraryOutputWriter.swift
//  SellerCamera
//
//  Created by Codex on 2026/4/1.
//

import Foundation
import Photos

enum CapturePhotoLibraryOutputWriterError: LocalizedError {
    case permissionDenied
    case permissionRestricted
    case permissionUnknown
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "系统相册权限未开启"
        case .permissionRestricted:
            return "当前设备限制了相册写入"
        case .permissionUnknown:
            return "无法确认相册权限状态"
        case .saveFailed:
            return "保存到系统相册失败"
        }
    }
}

struct CapturePhotoLibraryOutputWriter {
    nonisolated static func exportSingleOriginalResult(_ stillResult: CaptureStillPhotoResult) async throws {
        let authorizationStatus = await resolveAuthorizationStatus()
        switch authorizationStatus {
        case .authorized, .limited:
            break
        case .denied:
            throw CapturePhotoLibraryOutputWriterError.permissionDenied
        case .restricted:
            throw CapturePhotoLibraryOutputWriterError.permissionRestricted
        default:
            throw CapturePhotoLibraryOutputWriterError.permissionUnknown
        }

        try await savePhotoData(stillResult.imageData)
    }

    nonisolated static func exportSingleReadyResult(_ readyResult: CaptureProcessedPhotoResult) async throws {
        let authorizationStatus = await resolveAuthorizationStatus()
        switch authorizationStatus {
        case .authorized, .limited:
            break
        case .denied:
            throw CapturePhotoLibraryOutputWriterError.permissionDenied
        case .restricted:
            throw CapturePhotoLibraryOutputWriterError.permissionRestricted
        default:
            throw CapturePhotoLibraryOutputWriterError.permissionUnknown
        }

        try await savePhotoData(readyResult.imageData)
    }

    private nonisolated static func resolveAuthorizationStatus() async -> PHAuthorizationStatus {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if currentStatus != .notDetermined {
            return currentStatus
        }

        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: status)
            }
        }
    }

    private nonisolated static func savePhotoData(_ imageData: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                let creationRequest = PHAssetCreationRequest.forAsset()
                creationRequest.addResource(with: .photo, data: imageData, options: nil)
            } completionHandler: { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: CapturePhotoLibraryOutputWriterError.saveFailed)
                }
            }
        }
    }
}

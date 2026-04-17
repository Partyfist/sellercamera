//
//  CaptureLatestResultPreview.swift
//  SellerCamera
//
//  Created by Codex on 2026/3/31.
//

import SwiftUI
import UIKit

struct CaptureLatestResultPreview: View {
    let latestResult: CaptureStillPhotoResult?
    let processedResult: CaptureProcessedPhotoResult?
    let isProcessing: Bool
    let isSavingOriginal: Bool
    let isOriginalSaved: Bool
    let originalSaveFailureMessage: String?
    let isSavingProcessed: Bool
    let isProcessedSaved: Bool
    let processedSaveFailureMessage: String?
    let onTapLatest: (() -> Void)?

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var previewImage: UIImage?
    @State private var decodeFailed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("最近结果")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))

                if latestResult != nil {
                    Text(statusBadgeText)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.95))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(statusBadgeColor, in: Capsule())
                }
            }

            Group {
                if latestResult == nil {
                    emptyState
                } else if let previewImage {
                    previewState(image: previewImage)
                } else if decodeFailed {
                    failedState
                } else {
                    loadingState
                }
            }
        }
        .padding(8)
        .frame(width: cardWidth)
        .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            if latestResult != nil, let onTapLatest {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onTapLatest)
            }
        }
        .task(id: latestResult?.id) {
            await refreshPreview()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "photo")
                .font(.system(size: 18))
            Text("未拍摄")
                .font(.caption2)
        }
        .foregroundStyle(.white.opacity(0.72))
        .frame(maxWidth: .infinity, minHeight: 88)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func previewState(image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: previewImageSize, height: previewImageSize)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            if let latestResult {
                VStack(alignment: .leading, spacing: 2) {
                    Text("大小 \(latestResult.byteSizeDisplayText)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .truncationMode(.tail)
                    Text(confirmationHintText)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var loadingState: some View {
        VStack(spacing: 6) {
            ProgressView()
                .tint(.white.opacity(0.9))
            Text("加载中")
                .font(.caption2)
        }
        .foregroundStyle(.white.opacity(0.75))
        .frame(maxWidth: .infinity, minHeight: 88)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var failedState: some View {
        VStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 16))
            Text("缩略图不可用")
                .font(.caption2)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .foregroundStyle(.white.opacity(0.78))
        .frame(maxWidth: .infinity, minHeight: 88)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @MainActor
    private func refreshPreview() async {
        guard let latestResult else {
            previewImage = nil
            decodeFailed = false
            return
        }

        previewImage = nil
        decodeFailed = false

        let imageData = latestResult.imageData
        let decoded = await Task.detached(priority: .userInitiated) {
            UIImage(data: imageData)
        }.value

        guard latestResult.id == self.latestResult?.id else {
            return
        }

        if let decoded {
            previewImage = decoded
        } else {
            decodeFailed = true
        }
    }

    private var cardWidth: CGFloat {
        horizontalSizeClass == .compact ? 100 : 108
    }

    private var previewImageSize: CGFloat {
        horizontalSizeClass == .compact ? 82 : 92
    }

    private var isLatestProcessed: Bool {
        guard let latestResult else { return false }
        return processedResult?.sourceStillPhotoID == latestResult.id
    }

    private var statusBadgeText: String {
        if isProcessing {
            return "白底处理中"
        }
        if isSavingOriginal {
            return "保存中"
        }
        if isSavingProcessed {
            return "白底保存中"
        }
        if isOriginalSaved {
            return "原图已存"
        }
        if isProcessedSaved {
            return "白底已存"
        }
        if originalSaveFailureMessage != nil {
            return "保存失败"
        }
        if processedSaveFailureMessage != nil {
            return "白底保存失败"
        }
        if isLatestProcessed {
            return "白底已生成"
        }
        return "已拍摄"
    }

    private var statusBadgeColor: Color {
        if isProcessing {
            return .orange.opacity(0.42)
        }
        if isSavingOriginal {
            return .blue.opacity(0.42)
        }
        if isSavingProcessed {
            return .blue.opacity(0.42)
        }
        if isOriginalSaved {
            return .green.opacity(0.42)
        }
        if isProcessedSaved {
            return .mint.opacity(0.42)
        }
        if originalSaveFailureMessage != nil {
            return .red.opacity(0.38)
        }
        if processedSaveFailureMessage != nil {
            return .red.opacity(0.38)
        }
        if isLatestProcessed {
            return .blue.opacity(0.42)
        }
        return .orange.opacity(0.36)
    }

    private var confirmationHintText: String {
        if isProcessing {
            return "正在生成白底"
        }
        if isSavingOriginal {
            return "正在保存原图"
        }
        if isSavingProcessed {
            return "正在保存白底图"
        }
        if isOriginalSaved {
            return "原图已保存到系统相册"
        }
        if isProcessedSaved {
            return "白底图已保存到系统相册"
        }
        if originalSaveFailureMessage != nil {
            return "原图保存失败，可重试"
        }
        if processedSaveFailureMessage != nil {
            return "白底图保存失败，可重试"
        }
        if isLatestProcessed {
            if let processedResult {
                return processedResult.qualityHintDisplayText
            }
            return "白底图可直接保存"
        }
        return "点按可保存原图或生成白底"
    }
}

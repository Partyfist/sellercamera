//
//  CaptureLatestResultViewerOverlay.swift
//  SellerCamera
//
//  Created by Codex on 2026/3/31.
//

import SwiftUI
import UIKit

struct CaptureLatestReviewContainerOverlay: View {
    let latestResult: CaptureStillPhotoResult
    let processedResult: CaptureProcessedPhotoResult?
    let isProcessing: Bool
    let processingErrorMessage: String?
    let isSavingOriginal: Bool
    let isOriginalSaved: Bool
    let originalSaveFailureMessage: String?
    let isSavingProcessed: Bool
    let isProcessedSaved: Bool
    let processedSaveFailureMessage: String?
    let onSaveOriginal: () -> Void
    let onGenerateWhiteBackground: () -> Void
    let onSaveWhiteBackground: () -> Void
    let onClose: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var previewImage: UIImage?
    @State private var decodeFailed = false
    @State private var processedPreviewImage: UIImage?
    @State private var processedDecodeFailed = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.58)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

            GeometryReader { proxy in
                let maxContainerHeight = max(320, proxy.size.height - 36)

                VStack(alignment: .leading, spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 10) {
                            CaptureLatestReviewHeader(
                                isLatestProcessed: isLatestProcessed,
                                isProcessing: isProcessing,
                                isSavingOriginal: isSavingOriginal,
                                isOriginalSaved: isOriginalSaved,
                                originalSaveFailureMessage: originalSaveFailureMessage,
                                isSavingProcessed: isSavingProcessed,
                                isProcessedSaved: isProcessedSaved,
                                processedSaveFailureMessage: processedSaveFailureMessage
                            )

                            CaptureLatestReviewImageSection(
                                previewImage: previewImage,
                                decodeFailed: decodeFailed,
                                minHeight: viewerImageMinHeight,
                                maxHeight: viewerImageMaxHeight
                            )

                            CaptureLatestInfoSection(
                                capturedAtText: capturedAtText,
                                resolutionText: resolutionText,
                                byteSizeText: byteSizeText,
                                sourceText: sourceText
                            )

                            CaptureLatestReviewActionArea(
                                isLatestProcessed: isLatestProcessed,
                                isProcessing: isProcessing,
                                isSavingOriginal: isSavingOriginal,
                                isOriginalSaved: isOriginalSaved,
                                originalSaveFailureMessage: originalSaveFailureMessage,
                                isSavingProcessed: isSavingProcessed,
                                isProcessedSaved: isProcessedSaved,
                                processedSaveFailureMessage: processedSaveFailureMessage,
                                processingErrorMessage: processingErrorMessage,
                                onSaveOriginal: onSaveOriginal,
                                onGenerateWhiteBackground: onGenerateWhiteBackground,
                                onSaveWhiteBackground: onSaveWhiteBackground
                            )

                            if shouldShowCompareSection {
                                CaptureLatestCompareSection(
                                    sourceResult: latestResult,
                                    sourcePreviewImage: previewImage,
                                    sourceDecodeFailed: decodeFailed,
                                    processedResult: processedResult,
                                    processedPreviewImage: processedPreviewImage,
                                    processedDecodeFailed: processedDecodeFailed,
                                    isProcessing: isProcessing,
                                    processingErrorMessage: processingErrorMessage
                                )
                            }
                        }
                        .padding(.bottom, 8)
                    }

                    CaptureLatestReviewReturnBar(onClose: onClose)
                        .padding(.top, 4)
                }
                .padding(horizontalSizeClass == .compact ? 12 : 14)
                .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.14), lineWidth: 1)
                }
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity)
                .frame(maxHeight: maxContainerHeight)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: latestResult.id) {
            await refreshLatestPreview()
        }
        .task(id: processedResult?.id) {
            await refreshProcessedPreview()
        }
    }

    private var capturedAtText: String {
        latestResult.capturedAtDisplayText
    }

    private var resolutionText: String {
        latestResult.resolutionDisplayText
    }

    private var byteSizeText: String {
        latestResult.byteSizeDisplayText
    }

    private var sourceText: String {
        latestResult.source.displayText
    }

    private var viewerImageMinHeight: CGFloat {
        horizontalSizeClass == .compact ? 190 : 220
    }

    private var viewerImageMaxHeight: CGFloat {
        horizontalSizeClass == .compact ? 340 : 420
    }

    private var isLatestProcessed: Bool {
        processedResult?.sourceStillPhotoID == latestResult.id
    }

    private var shouldShowCompareSection: Bool {
        isProcessing || isLatestProcessed || processingErrorMessage != nil
    }

    @MainActor
    private func refreshLatestPreview() async {
        previewImage = nil
        decodeFailed = false

        let imageData = latestResult.imageData
        let decoded = await Task.detached(priority: .userInitiated) {
            UIImage(data: imageData)
        }.value

        if let decoded {
            previewImage = decoded
        } else {
            decodeFailed = true
        }
    }

    @MainActor
    private func refreshProcessedPreview() async {
        guard let processedResult else {
            processedPreviewImage = nil
            processedDecodeFailed = false
            return
        }

        processedPreviewImage = nil
        processedDecodeFailed = false

        let imageData = processedResult.imageData
        let decoded = await Task.detached(priority: .userInitiated) {
            UIImage(data: imageData)
        }.value

        guard processedResult.id == self.processedResult?.id else {
            return
        }

        if let decoded {
            processedPreviewImage = decoded
        } else {
            processedDecodeFailed = true
        }
    }
}

private struct CaptureLatestReviewHeader: View {
    let isLatestProcessed: Bool
    let isProcessing: Bool
    let isSavingOriginal: Bool
    let isOriginalSaved: Bool
    let originalSaveFailureMessage: String?
    let isSavingProcessed: Bool
    let isProcessedSaved: Bool
    let processedSaveFailureMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text("最近结果复核")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(statusText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.94))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(statusColor, in: Capsule())
            }

            Text(subtitleText)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
    }

    private var statusText: String {
        if isSavingOriginal {
            return "保存中"
        }
        if isSavingProcessed {
            return "白底保存中"
        }
        if isOriginalSaved {
            return "原图已保存"
        }
        if isProcessedSaved {
            return "白底已保存"
        }
        if originalSaveFailureMessage != nil {
            return "保存失败"
        }
        if processedSaveFailureMessage != nil {
            return "白底保存失败"
        }
        if isProcessing {
            return "白底处理中"
        }
        if isLatestProcessed {
            return "白底已生成"
        }
        return "待处理"
    }

    private var statusColor: Color {
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
        if isProcessing {
            return .orange.opacity(0.42)
        }
        if isLatestProcessed {
            return .blue.opacity(0.42)
        }
        return .orange.opacity(0.36)
    }

    private var subtitleText: String {
        if isSavingOriginal {
            return "正在将当前原图保存到系统相册"
        }
        if isSavingProcessed {
            return "正在将白底图保存到系统相册"
        }
        if isOriginalSaved {
            return "原图已保存，仍可继续生成白底图或返回拍摄"
        }
        if isProcessedSaved {
            return "白底图已保存，仍可返回拍摄继续下一张"
        }
        if let originalSaveFailureMessage {
            return "原图保存失败：\(originalSaveFailureMessage)"
        }
        if let processedSaveFailureMessage {
            return "白底图保存失败：\(processedSaveFailureMessage)"
        }
        if isProcessing {
            return "正在生成白底图，可随时返回拍摄"
        }
        if isLatestProcessed {
            return "白底结果已生成，可复核后继续拍摄"
        }
        return "请选择动作：保存原图、生成白底图或返回拍摄"
    }
}

private struct CaptureLatestReviewImageSection: View {
    let previewImage: UIImage?
    let decodeFailed: Bool
    let minHeight: CGFloat
    let maxHeight: CGFloat

    var body: some View {
        Group {
            if let previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: maxHeight)
                    .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else if decodeFailed {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                    Text("该结果暂不可预览")
                        .font(.caption)
                    Text("可返回拍摄并继续重试")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.64))
                }
                .foregroundStyle(.white.opacity(0.84))
                .frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: maxHeight)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                VStack(spacing: 8) {
                    ProgressView()
                        .tint(.white.opacity(0.92))
                    Text("正在加载最近结果")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.72))
                }
                .frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: maxHeight)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}

private struct CaptureLatestInfoSection: View {
    let capturedAtText: String
    let resolutionText: String
    let byteSizeText: String
    let sourceText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("拍摄信息")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    infoItem(title: "拍摄时间", value: capturedAtText)
                    infoItem(title: "像素尺寸", value: resolutionText)
                    infoItem(title: "文件大小", value: byteSizeText)
                    infoItem(title: "来源", value: sourceText)
                }

                VStack(spacing: 6) {
                    infoItem(title: "拍摄时间", value: capturedAtText)
                    infoItem(title: "像素尺寸", value: resolutionText)
                    infoItem(title: "文件大小", value: byteSizeText)
                    infoItem(title: "来源", value: sourceText)
                }
            }
        }
        .padding(10)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func infoItem(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.64))
            Text(value)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CaptureLatestReviewActionArea: View {
    let isLatestProcessed: Bool
    let isProcessing: Bool
    let isSavingOriginal: Bool
    let isOriginalSaved: Bool
    let originalSaveFailureMessage: String?
    let isSavingProcessed: Bool
    let isProcessedSaved: Bool
    let processedSaveFailureMessage: String?
    let processingErrorMessage: String?
    let onSaveOriginal: () -> Void
    let onGenerateWhiteBackground: () -> Void
    let onSaveWhiteBackground: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("拍后主动作")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    saveOriginalAction(
                        canSave: canSaveOriginal,
                        isSaving: isSavingOriginal,
                        isSaved: isOriginalSaved,
                        failureMessage: originalSaveFailureMessage,
                        onTap: onSaveOriginal
                    )
                    generateWhiteBackgroundAction(
                        canGenerate: canGenerateWhiteBackground,
                        isProcessing: isProcessing,
                        isLatestProcessed: isLatestProcessed,
                        onTap: onGenerateWhiteBackground
                    )
                }

                VStack(spacing: 8) {
                    saveOriginalAction(
                        canSave: canSaveOriginal,
                        isSaving: isSavingOriginal,
                        isSaved: isOriginalSaved,
                        failureMessage: originalSaveFailureMessage,
                        onTap: onSaveOriginal
                    )
                    generateWhiteBackgroundAction(
                        canGenerate: canGenerateWhiteBackground,
                        isProcessing: isProcessing,
                        isLatestProcessed: isLatestProcessed,
                        onTap: onGenerateWhiteBackground
                    )
                }
            }

            saveWhiteBackgroundAction(
                canSave: canSaveWhiteBackground,
                isSaving: isSavingProcessed,
                isSaved: isProcessedSaved,
                failureMessage: processedSaveFailureMessage,
                onTap: onSaveWhiteBackground
            )

            if let processingErrorMessage {
                Text("白底处理失败：\(processingErrorMessage)")
                    .font(.caption2)
                    .foregroundStyle(.red.opacity(0.86))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            Text(actionFooterText)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(10)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var canSaveOriginal: Bool {
        !isSavingOriginal
    }

    private var canGenerateWhiteBackground: Bool {
        !isProcessing
    }

    private var canSaveWhiteBackground: Bool {
        isLatestProcessed && !isProcessing && !isSavingProcessed
    }

    private func saveOriginalAction(
        canSave: Bool,
        isSaving: Bool,
        isSaved: Bool,
        failureMessage: String?,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("保存原图")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(canSave || isSaved ? 0.92 : 0.8))

                    Text(saveTagText(canSave: canSave, isSaving: isSaving, isSaved: isSaved, hasFailure: failureMessage != nil))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.92))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(saveTagColor(canSave: canSave, isSaving: isSaving, isSaved: isSaved, hasFailure: failureMessage != nil), in: Capsule())
                }

                Text(saveDetailText(canSave: canSave, isSaving: isSaving, isSaved: isSaved, failureMessage: failureMessage))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.64))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(canSave || isSaved ? 0.12 : 0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
    }

    private func saveTagText(canSave: Bool, isSaving: Bool, isSaved: Bool, hasFailure: Bool) -> String {
        if isSaving {
            return "保存中"
        }
        if isSaved {
            return "已保存"
        }
        if hasFailure {
            return "失败"
        }
        return canSave ? "可执行" : "稍候"
    }

    private func saveTagColor(canSave: Bool, isSaving: Bool, isSaved: Bool, hasFailure: Bool) -> Color {
        if isSaving {
            return .blue.opacity(0.42)
        }
        if isSaved {
            return .green.opacity(0.42)
        }
        if hasFailure {
            return .red.opacity(0.38)
        }
        return canSave ? .blue.opacity(0.36) : .white.opacity(0.16)
    }

    private func saveDetailText(
        canSave: Bool,
        isSaving: Bool,
        isSaved: Bool,
        failureMessage: String?
    ) -> String {
        if isSaving {
            return "正在将当前原图保存到系统相册"
        }
        if isSaved {
            return "原图已保存，可继续生成白底图或返回拍摄"
        }
        if let failureMessage {
            return "原图保存失败：\(failureMessage)"
        }
        if !canSave {
            return "当前状态暂不可保存原图"
        }
        return "直接保存当前原图，无需额外确认步骤"
    }

    private func generateWhiteBackgroundAction(
        canGenerate: Bool,
        isProcessing: Bool,
        isLatestProcessed: Bool,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(isLatestProcessed ? "重新生成白底图" : "生成白底图")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(canGenerate ? 0.9 : 0.82))

                    Text(processingTagText(canGenerate: canGenerate, isProcessing: isProcessing))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.74))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.white.opacity(0.16), in: Capsule())
                }

                Text(processingDetailText(canGenerate: canGenerate, isProcessing: isProcessing, isLatestProcessed: isLatestProcessed))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(canGenerate ? 0.1 : 0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!canGenerate)
    }

    private func saveWhiteBackgroundAction(
        canSave: Bool,
        isSaving: Bool,
        isSaved: Bool,
        failureMessage: String?,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("保存白底图")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(canSave || isSaving || isSaved ? 0.92 : 0.8))

                        Text(saveWhiteTagText(canSave: canSave, isSaving: isSaving, isSaved: isSaved, hasFailure: failureMessage != nil))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.92))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(saveWhiteTagColor(canSave: canSave, isSaving: isSaving, isSaved: isSaved, hasFailure: failureMessage != nil), in: Capsule())
                    }

                    Text(saveWhiteDetailText(canSave: canSave, isSaving: isSaving, isSaved: isSaved, failureMessage: failureMessage))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.64))
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }

                Spacer(minLength: 8)

                Image(systemName: isSaved ? "square.and.arrow.down.fill" : "square.and.arrow.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(canSave || isSaving || isSaved ? 0.86 : 0.55))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(canSave || isSaving || isSaved ? 0.12 : 0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
    }

    private func saveWhiteTagText(canSave: Bool, isSaving: Bool, isSaved: Bool, hasFailure: Bool) -> String {
        if isSaving {
            return "保存中"
        }
        if isSaved {
            return "已保存"
        }
        if hasFailure {
            return "失败"
        }
        return canSave ? "可执行" : "待生成"
    }

    private func saveWhiteTagColor(canSave: Bool, isSaving: Bool, isSaved: Bool, hasFailure: Bool) -> Color {
        if isSaving {
            return .blue.opacity(0.42)
        }
        if isSaved {
            return .mint.opacity(0.42)
        }
        if hasFailure {
            return .red.opacity(0.38)
        }
        return canSave ? .indigo.opacity(0.36) : .white.opacity(0.16)
    }

    private func saveWhiteDetailText(canSave: Bool, isSaving: Bool, isSaved: Bool, failureMessage: String?) -> String {
        if isSaving {
            return "正在将当前白底结果保存到系统相册"
        }
        if isSaved {
            return "白底图已保存，可返回拍摄继续下一张"
        }
        if let failureMessage {
            return "白底图保存失败：\(failureMessage)"
        }
        if !canSave {
            return "需先生成白底图，再执行保存"
        }
        return "直接保存当前白底结果，无需额外确认步骤"
    }

    private func processingTagText(canGenerate: Bool, isProcessing: Bool) -> String {
        if isProcessing {
            return "生成中"
        }
        return canGenerate ? "可执行" : "稍候"
    }

    private func processingDetailText(canGenerate: Bool, isProcessing: Bool, isLatestProcessed: Bool) -> String {
        if isProcessing {
            return "正在基于当前拍摄原图生成白底图"
        }
        if !canGenerate {
            return "当前状态暂不可发起白底生成"
        }
        if isLatestProcessed {
            return "已生成白底图，可按需再次生成"
        }
        return "直接基于当前原图生成白底图，无需额外确认步骤"
    }

    private var actionFooterText: String {
        if isSavingOriginal {
            return "原图保存中仍可返回拍摄，不阻塞继续拍摄"
        }
        if isSavingProcessed {
            return "白底保存中仍可返回拍摄，不阻塞继续拍摄"
        }
        if isProcessedSaved {
            return "白底图已保存，当前仍可直接返回拍摄"
        }
        if isProcessing {
            return "处理中不会阻塞拍摄，仍可返回拍摄"
        }
        if isLatestProcessed {
            return "白底结果已生成，当前仍可直接返回拍摄"
        }
        return "拍后只保留高频动作：保存原图、生成白底图、返回拍摄"
    }
}

private struct CaptureLatestCompareSection: View {
    let sourceResult: CaptureStillPhotoResult
    let sourcePreviewImage: UIImage?
    let sourceDecodeFailed: Bool
    let processedResult: CaptureProcessedPhotoResult?
    let processedPreviewImage: UIImage?
    let processedDecodeFailed: Bool
    let isProcessing: Bool
    let processingErrorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("处理前后对比")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.74))

            Text("左侧为原图，右侧为白底处理结果")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    sourcePanel
                    processedPanel
                }

                VStack(spacing: 8) {
                    sourcePanel
                    processedPanel
                }
            }
        }
        .padding(10)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var sourcePanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("原图")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))

            Group {
                if let sourcePreviewImage {
                    Image(uiImage: sourcePreviewImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, minHeight: 116, maxHeight: 150)
                        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else if sourceDecodeFailed {
                    Text("原图暂不可预览")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(maxWidth: .infinity, minHeight: 116, maxHeight: 150)
                        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else {
                    ProgressView()
                        .tint(.white.opacity(0.9))
                        .frame(maxWidth: .infinity, minHeight: 116, maxHeight: 150)
                        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }

            Text("\(sourceResult.resolutionDisplayText) · \(sourceResult.byteSizeDisplayText)")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(8)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var processedPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("处理结果")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))

            Group {
                if let processedResult, let processedPreviewImage {
                    Image(uiImage: processedPreviewImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, minHeight: 116, maxHeight: 150)
                        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(processedResult.resolutionDisplayText) · \(processedResult.byteSizeDisplayText)")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.62))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text("质量评估：\(processedResult.qualityLevelDisplayText)")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.56))
                            .lineLimit(1)
                            .minimumScaleFactor(0.84)
                        if let hardCaseHint = processedResult.hardCaseHintDisplayText {
                            Text("难例提示：\(hardCaseHint)")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.52))
                                .lineLimit(1)
                                .minimumScaleFactor(0.84)
                        }
                    }
                } else if processedDecodeFailed {
                    Text("处理结果暂不可预览")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(maxWidth: .infinity, minHeight: 116, maxHeight: 150)
                        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else if isProcessing {
                    VStack(spacing: 8) {
                        ProgressView()
                            .tint(.white.opacity(0.9))
                        Text("处理中")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.68))
                    }
                    .frame(maxWidth: .infinity, minHeight: 116, maxHeight: 150)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else if let processingErrorMessage {
                    Text("处理失败：\(processingErrorMessage)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, minHeight: 116, maxHeight: 150)
                        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else {
                    Text("待生成白底图")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                        .frame(maxWidth: .infinity, minHeight: 116, maxHeight: 150)
                        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .padding(8)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CaptureLatestReviewReturnBar: View {
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("完成复核后可直接返回拍摄")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.65))
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer()

            Button(action: onClose) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.backward")
                        .font(.caption.weight(.semibold))
                    Text("返回拍摄")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.white.opacity(0.14), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 2)
    }
}

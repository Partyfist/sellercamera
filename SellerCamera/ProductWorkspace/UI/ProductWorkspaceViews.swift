//
//  ProductWorkspaceViews.swift
//  SellerCamera
//
//  Created by Codex on 2026/6/18.
//

import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

private enum ProductWorkspaceTab: String, CaseIterable, Identifiable {
    case projects
    case assets

    var id: String { rawValue }

    var title: String {
        switch self {
        case .projects:
            return "项目"
        case .assets:
            return "图片"
        }
    }
}

struct ProductWorkspaceView: View {
    @ObservedObject var session: ProductWorkspaceSession
    let onContinueShooting: () -> Void

    @State private var selectedTab: ProductWorkspaceTab = .projects

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("工作台", selection: $selectedTab) {
                    ForEach(ProductWorkspaceTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Group {
                    switch selectedTab {
                    case .projects:
                        ProductProjectListView(
                            session: session,
                            onContinueShooting: onContinueShooting
                        )
                    case .assets:
                        ProductAssetLibraryView(session: session)
                    }
                }
            }
            .navigationTitle("工作台")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("继续拍摄", action: onContinueShooting)
                }
            }
            .task {
                await session.refreshCurrentProjectState()
            }
        }
    }
}

private struct ProductProjectListView: View {
    @ObservedObject var session: ProductWorkspaceSession
    let onContinueShooting: () -> Void

    @State private var searchText = ""
    @State private var showsArchived = false
    @State private var isCreateSheetPresented = false

    private var visibleSummaries: [CurrentProjectSummary] {
        let source = showsArchived ? session.archivedProjectSummaries : session.projectSummaries
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return source }
        return source.filter { $0.projectName.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        List {
            Section {
                Button {
                    isCreateSheetPresented = true
                } label: {
                    Label("创建商品项目", systemImage: "folder.badge.plus")
                }
            }

            Section {
                Toggle("查看已归档项目", isOn: $showsArchived)
            }

            Section(showsArchived ? "已归档" : "项目") {
                if visibleSummaries.isEmpty {
                    ProductEmptyStateView(
                        title: showsArchived ? "暂无已归档项目" : "暂无项目",
                        systemImage: showsArchived ? "archivebox" : "folder",
                        message: showsArchived ? "归档后的项目会保留图片与 metadata。" : "创建项目后即可按标准、细节、SKU 归档拍摄。"
                    )
                } else {
                    ForEach(visibleSummaries) { summary in
                        NavigationLink {
                            ProductProjectDetailView(
                                session: session,
                                summary: summary,
                                onContinueShooting: onContinueShooting
                            )
                        } label: {
                            ProductProjectCardView(
                                summary: summary,
                                fileStore: session.environment.fileStore
                            )
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            if !summary.isArchived && !summary.isCurrent {
                                Button("设为当前") {
                                    Task {
                                        await session.selectProject(id: summary.projectID)
                                    }
                                }
                                .tint(.green)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if summary.isArchived {
                                Button("恢复") {
                                    Task {
                                        await session.restoreArchivedProject(id: summary.projectID)
                                    }
                                }
                                .tint(.green)
                            } else {
                                Button("归档", role: .destructive) {
                                    Task {
                                        await session.archiveProject(id: summary.projectID)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "搜索项目名称")
        .sheet(isPresented: $isCreateSheetPresented) {
            ProductQuickCreateProjectSheet { name in
                await session.createProject(name: name)
                isCreateSheetPresented = false
            }
            .presentationDetents([.medium])
        }
    }
}

private struct ProductProjectCardView: View {
    let summary: CurrentProjectSummary
    let fileStore: ProjectFileStore

    var body: some View {
        HStack(spacing: 12) {
            ProductWorkspaceThumbnail(
                relativePath: summary.coverThumbnailPath,
                fileStore: fileStore,
                placeholderSymbol: "shippingbox"
            )
            .frame(width: 58, height: 58)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(summary.projectName)
                        .font(.headline)
                        .lineLimit(1)
                    if summary.isCurrent {
                        Text("当前")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.green.opacity(0.14), in: Capsule())
                    }
                    if summary.isArchived {
                        Text("已归档")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.secondary.opacity(0.12), in: Capsule())
                    }
                }
                Text("标准 \(summary.standardCount) · 细节 \(summary.detailCount) · SKU \(summary.skuCount) · 视频 \(summary.videoCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Text(Self.updatedText(summary.updatedAt))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private static func updatedText(_ date: Date) -> String {
        "更新于 " + DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .short)
    }
}

private struct ProductProjectDetailView: View {
    @ObservedObject var session: ProductWorkspaceSession
    let summary: CurrentProjectSummary
    let onContinueShooting: () -> Void

    @State private var isRenameSheetPresented = false

    private var assets: [ProjectAsset] {
        session.allAssets
            .filter { $0.projectID == summary.projectID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    ProductWorkspaceThumbnail(
                        relativePath: latestSummary.coverThumbnailPath,
                        fileStore: session.environment.fileStore,
                        placeholderSymbol: "shippingbox"
                    )
                    .frame(width: 86, height: 86)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        Text(latestSummary.projectName)
                            .font(.title3.weight(.semibold))
                            .lineLimit(2)
                        Text("标准 \(latestSummary.standardCount) · 细节 \(latestSummary.detailCount) · SKU \(latestSummary.skuCount) · 视频 \(latestSummary.videoCount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Text("创建与目录保持 projectID，不随重命名改变。")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 8)
            }

            Section("操作") {
                if !latestSummary.isArchived {
                    Button(latestSummary.isCurrent ? "当前项目" : "设为当前项目") {
                        Task {
                            await session.selectProject(id: latestSummary.projectID)
                        }
                    }
                    .disabled(latestSummary.isCurrent)

                    Button("继续拍摄") {
                        Task {
                            await session.selectProject(id: latestSummary.projectID)
                            onContinueShooting()
                        }
                    }
                } else {
                    Button("恢复项目") {
                        Task {
                            await session.restoreArchivedProject(id: latestSummary.projectID)
                        }
                    }
                }

                Button("重命名") {
                    isRenameSheetPresented = true
                }

                if !latestSummary.isArchived {
                    Button("归档项目", role: .destructive) {
                        Task {
                            await session.archiveProject(id: latestSummary.projectID)
                        }
                    }
                }
            }

            Section("最近图片") {
                if assets.isEmpty {
                    ProductEmptyStateView(
                        title: "暂无图片",
                        systemImage: "photo.on.rectangle",
                        message: "拍摄后会自动出现在这里。"
                    )
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 82), spacing: 10)], spacing: 10) {
                        ForEach(assets.prefix(12)) { asset in
                            ProductAssetTileView(
                                asset: asset,
                                fileStore: session.environment.fileStore
                            )
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .navigationTitle("项目详情")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isRenameSheetPresented) {
            ProductProjectRenameSheet(initialName: latestSummary.projectName) { newName in
                await session.renameProject(id: latestSummary.projectID, name: newName)
                isRenameSheetPresented = false
            }
            .presentationDetents([.medium])
        }
    }

    private var latestSummary: CurrentProjectSummary {
        (session.projectSummaries + session.archivedProjectSummaries)
            .first(where: { $0.projectID == summary.projectID }) ?? summary
    }
}

private enum AssetLibraryFilterOption: String, CaseIterable, Identifiable {
    case all
    case standard
    case detail
    case sku
    case video
    case best
    case favorite
    case trash

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "全部"
        case .standard:
            return "标准"
        case .detail:
            return "细节"
        case .sku:
            return "SKU"
        case .video:
            return "视频"
        case .best:
            return "最佳"
        case .favorite:
            return "收藏"
        case .trash:
            return "回收站"
        }
    }

    var filter: AssetFilter {
        switch self {
        case .all:
            return .all
        case .standard:
            return .category(.standard)
        case .detail:
            return .category(.detail)
        case .sku:
            return .category(.sku)
        case .video:
            return .video
        case .best:
            return .best
        case .favorite:
            return .favorite
        case .trash:
            return .trash
        }
    }
}

private struct ProductAssetLibraryView: View {
    @ObservedObject var session: ProductWorkspaceSession
    @StateObject private var assetSession: ProductAssetLibrarySession

    @State private var filterOption: AssetLibraryFilterOption = .all
    @State private var selectedImportItems: [PhotosPickerItem] = []
    @State private var importProjectID: UUID?
    @State private var importCategory: CaptureCategory = .standard
    @State private var selectedAsset: ProjectAsset?
    @State private var shareURLs: [URL] = []
    @State private var isSharePresented = false
    @State private var isPermanentDeleteConfirmationPresented = false
    @State private var isEmptyTrashConfirmationPresented = false

    init(session: ProductWorkspaceSession) {
        self.session = session
        _assetSession = StateObject(wrappedValue: ProductAssetLibrarySession(environment: session.environment))
    }

    private var currentProjectID: UUID? {
        importProjectID ?? session.currentProject?.id
    }

    private var isTrashFilter: Bool {
        filterOption == .trash
    }

    var body: some View {
        VStack(spacing: 10) {
            headerView
            filterBar
            statusView
            assetGrid
            if assetSession.isSelectionMode {
                selectionToolbar
            }
        }
        .task(id: session.currentProject?.id) {
            importProjectID = session.currentProject?.id
            importCategory = session.selectedCaptureCategory == .video ? .standard : session.selectedCaptureCategory
            await assetSession.load(projectID: currentProjectID)
        }
        .onChange(of: importProjectID) { _ in
            Task {
                await assetSession.load(projectID: currentProjectID)
            }
        }
        .sheet(item: $selectedAsset) { asset in
            ProductAssetPreviewSheet(
                workspaceSession: session,
                assetSession: assetSession,
                asset: asset,
                assets: assetSession.visibleAssets,
                onChanged: {
                    await session.refreshCurrentProjectState()
                    await assetSession.load(projectID: currentProjectID)
                }
            )
            .presentationDetents([.large])
        }
        .sheet(isPresented: $isSharePresented) {
            ActivityView(activityItems: shareURLs)
        }
        .confirmationDialog("永久删除所选资产？", isPresented: $isPermanentDeleteConfirmationPresented, titleVisibility: .visible) {
            Button("永久删除", role: .destructive) {
                Task {
                    await assetSession.permanentlyDeleteSelected()
                    await session.refreshCurrentProjectState()
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作会删除 metadata、原图和缩略图，不能撤销。")
        }
        .confirmationDialog("清空当前项目回收站？", isPresented: $isEmptyTrashConfirmationPresented, titleVisibility: .visible) {
            Button("清空回收站", role: .destructive) {
                Task {
                    await assetSession.emptyTrash()
                    await session.refreshCurrentProjectState()
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("只会永久删除当前项目回收站内的资产。")
        }
        .onChange(of: selectedImportItems) { items in
            guard !items.isEmpty else { return }
            Task {
                await importSelectedItems(items)
            }
        }
    }

    private var headerView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                ProductWorkspaceThumbnail(
                    relativePath: session.currentProjectSummary?.coverThumbnailPath,
                    fileStore: session.environment.fileStore,
                    placeholderSymbol: "shippingbox"
                )
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(session.currentProject?.name ?? "未选择项目")
                        .font(.headline)
                        .lineLimit(1)
                    Text("当前筛选 \(assetSession.visibleAssets.count) 项 · 标准 \(session.currentCounts.standard) · 细节 \(session.currentCounts.detail) · SKU \(session.currentCounts.sku)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Spacer()

                Button(assetSession.isSelectionMode ? "取消" : "选择") {
                    if assetSession.isSelectionMode {
                        assetSession.exitSelectionMode()
                    } else {
                        assetSession.enterSelectionMode()
                    }
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 10) {
                Picker("导入项目", selection: $importProjectID) {
                    ForEach(session.projectSummaries) { summary in
                        Text(summary.projectName).tag(Optional.some(summary.projectID))
                    }
                }
                .pickerStyle(.menu)

                Picker("导入分类", selection: $importCategory) {
                    Text("标准").tag(CaptureCategory.standard)
                    Text("细节").tag(CaptureCategory.detail)
                    Text("SKU").tag(CaptureCategory.sku)
                }
                .pickerStyle(.menu)

                PhotosPicker(
                    selection: $selectedImportItems,
                    maxSelectionCount: 100,
                    matching: .any(of: [.images, .videos]),
                    preferredItemEncoding: .automatic
                ) {
                    Label("导入", systemImage: "square.and.arrow.down")
                }
                .disabled(assetSession.isImporting || importProjectID == nil)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AssetLibraryFilterOption.allCases) { option in
                    Button {
                        filterOption = option
                        Task {
                            await assetSession.setFilter(option.filter)
                        }
                    } label: {
                        Text(option.title)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .foregroundStyle(filterOption == option ? .white : .primary)
                            .background(filterOption == option ? Color.green.opacity(0.78) : Color.secondary.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var statusView: some View {
        if let text = assetSession.importProgressText ?? assetSession.lastStatusText ?? assetSession.lastErrorText {
            Text(text)
                .font(.caption)
                .foregroundStyle(assetSession.lastErrorText == nil ? Color.secondary : Color.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var assetGrid: some View {
        if assetSession.visibleAssets.isEmpty {
            ProductEmptyStateView(
                title: isTrashFilter ? "回收站为空" : "暂无图片",
                systemImage: isTrashFilter ? "trash" : "photo.stack",
                message: isTrashFilter ? "删除到回收站的资产会显示在这里。" : "拍摄或导入成功并写入 metadata 后，图片会按分类出现在这里。"
            )
            .frame(maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(assetSession.visibleAssets) { asset in
                        Button {
                            if assetSession.isSelectionMode {
                                assetSession.toggleSelection(assetID: asset.id)
                            } else {
                                selectedAsset = asset
                            }
                        } label: {
                            ProductAssetTileView(
                                asset: asset,
                                fileStore: session.environment.fileStore,
                                isSelected: assetSession.selectedAssetIDs.contains(asset.id),
                                isCover: session.currentProject?.coverAssetID == asset.id
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("选择") {
                                assetSession.enterSelectionMode(assetID: asset.id)
                            }
                            if asset.mediaType == .photo && asset.deletionState == .active {
                                Button("设为封面") {
                                    Task {
                                        await assetSession.setCover(assetID: asset.id)
                                        await session.refreshCurrentProjectState()
                                    }
                                }
                            }
                            Button(asset.isBest ? "取消最佳" : "标记最佳") {
                                Task {
                                    assetSession.enterSelectionMode(assetID: asset.id)
                                    await assetSession.updateBest(!asset.isBest)
                                    await session.refreshCurrentProjectState()
                                }
                            }
                            Button(asset.deletionState == .trashed ? "恢复" : "删除到回收站", role: asset.deletionState == .trashed ? nil : .destructive) {
                                Task {
                                    assetSession.enterSelectionMode(assetID: asset.id)
                                    if asset.deletionState == .trashed {
                                        await assetSession.restoreSelectedFromTrash()
                                    } else {
                                        await assetSession.moveSelectedToTrash()
                                    }
                                    await session.refreshCurrentProjectState()
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, assetSession.isSelectionMode ? 90 : 18)
            }
        }
    }

    private var selectionToolbar: some View {
        VStack(spacing: 8) {
            HStack {
                Text("已选择 \(assetSession.selectedAssetIDs.count) 项")
                    .font(.caption.weight(.semibold))
                Spacer()
                Button("全选") {
                    assetSession.selectAllVisible()
                }
                Button("取消") {
                    assetSession.exitSelectionMode()
                }
            }

            HStack(spacing: 10) {
                Menu("分类") {
                    Button("标准") { Task { await changeSelectedCategory(.standard) } }
                    Button("细节") { Task { await changeSelectedCategory(.detail) } }
                    Button("SKU") { Task { await changeSelectedCategory(.sku) } }
                }
                Menu("标记") {
                    Button("标记最佳") { Task { await markSelectedBest(true) } }
                    Button("取消最佳") { Task { await markSelectedBest(false) } }
                    Button("收藏") { Task { await markSelectedFavorite(true) } }
                    Button("取消收藏") { Task { await markSelectedFavorite(false) } }
                }
                Button("分享") {
                    shareSelectedAssets()
                }
                if isTrashFilter {
                    Button("恢复") {
                        Task {
                            await assetSession.restoreSelectedFromTrash()
                            await session.refreshCurrentProjectState()
                        }
                    }
                    Button("永久删除", role: .destructive) {
                        isPermanentDeleteConfirmationPresented = true
                    }
                } else {
                    Button("删除", role: .destructive) {
                        Task {
                            await assetSession.moveSelectedToTrash()
                            await session.refreshCurrentProjectState()
                        }
                    }
                }
                if isTrashFilter {
                    Button("清空", role: .destructive) {
                        isEmptyTrashConfirmationPresented = true
                    }
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private func changeSelectedCategory(_ category: CaptureCategory) async {
        await assetSession.updateCategory(category)
        await session.refreshCurrentProjectState()
    }

    private func markSelectedBest(_ isBest: Bool) async {
        await assetSession.updateBest(isBest)
        await session.refreshCurrentProjectState()
    }

    private func markSelectedFavorite(_ isFavorite: Bool) async {
        await assetSession.updateFavorite(isFavorite)
        await session.refreshCurrentProjectState()
    }

    private func shareSelectedAssets() {
        let urls = assetSession.visibleAssets
            .filter { assetSession.selectedAssetIDs.contains($0.id) }
            .compactMap { try? session.environment.fileStore.resolveURL(relativePath: $0.relativePath) }
        guard !urls.isEmpty else { return }
        shareURLs = urls
        isSharePresented = true
    }

    @MainActor
    private func importSelectedItems(_ items: [PhotosPickerItem]) async {
        defer { selectedImportItems = [] }
        guard let projectID = importProjectID else { return }
        var importItems: [ProjectAssetImportItem] = []
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self), !data.isEmpty else {
                continue
            }
            let mediaType = mediaType(for: item)
            let contentType = item.supportedContentTypes.first
            let filename = item.itemIdentifier ?? "import-\(UUID().uuidString)"
            if mediaType == .photo, let image = UIImage(data: data) {
                importItems.append(ProjectAssetImportItem(
                    data: data,
                    mediaType: .photo,
                    originalFilename: filename,
                    fileExtension: contentType?.preferredFilenameExtension,
                    pixelWidth: Int(image.size.width.rounded()),
                    pixelHeight: Int(image.size.height.rounded()),
                    durationSeconds: nil
                ))
            } else {
                importItems.append(ProjectAssetImportItem(
                    data: data,
                    mediaType: .video,
                    originalFilename: filename,
                    fileExtension: contentType?.preferredFilenameExtension ?? "mov",
                    pixelWidth: nil,
                    pixelHeight: nil,
                    durationSeconds: nil
                ))
            }
        }
        _ = await assetSession.importItems(importItems, projectID: projectID, category: importCategory)
        await session.refreshCurrentProjectState()
    }

    private func mediaType(for item: PhotosPickerItem) -> ProjectAssetMediaType {
        item.supportedContentTypes.contains { $0.conforms(to: .movie) } ? .video : .photo
    }
}

private struct ProductAssetTileView: View {
    let asset: ProjectAsset
    let fileStore: ProjectFileStore
    var isSelected = false
    var isCover = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ProductWorkspaceThumbnail(
                relativePath: asset.thumbnailRelativePath ?? asset.relativePath,
                fileStore: fileStore,
                placeholderSymbol: asset.mediaType == .video ? "video" : "photo"
            )
            .aspectRatio(1, contentMode: .fill)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(categoryTitle(asset.category))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.48), in: Capsule())
                        if isCover {
                            Text("封面")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(.green.opacity(0.76), in: Capsule())
                        }
                    }
                    Spacer()
                    VStack(spacing: 4) {
                        if asset.isBest {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(.yellow)
                        }
                        if asset.isFavorite {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.pink)
                        }
                        if asset.mediaType == .video {
                            Text(durationText(asset.durationSeconds))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(.black.opacity(0.5), in: Capsule())
                        }
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    .font(.caption.weight(.bold))
                }
                Spacer()
                if asset.deletionState == .trashed {
                    Text("回收站")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.red.opacity(0.72), in: Capsule())
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(6)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? Color.green : Color.clear, lineWidth: 3)
        )
    }

    private func categoryTitle(_ category: CaptureCategory) -> String {
        switch category {
        case .standard:
            return "标准"
        case .detail:
            return "细节"
        case .sku:
            return "SKU"
        case .video:
            return "视频"
        }
    }

    private func durationText(_ duration: Double?) -> String {
        guard let duration else { return "视频" }
        let seconds = max(Int(duration.rounded()), 0)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

private struct ProductAssetPreviewSheet: View {
    @ObservedObject var workspaceSession: ProductWorkspaceSession
    @ObservedObject var assetSession: ProductAssetLibrarySession
    let asset: ProjectAsset
    let assets: [ProjectAsset]
    let onChanged: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var currentAsset: ProjectAsset
    @State private var zoomScale: CGFloat = 1
    @State private var shareURLs: [URL] = []
    @State private var isSharePresented = false

    init(
        workspaceSession: ProductWorkspaceSession,
        assetSession: ProductAssetLibrarySession,
        asset: ProjectAsset,
        assets: [ProjectAsset],
        onChanged: @escaping () async -> Void
    ) {
        self.workspaceSession = workspaceSession
        self.assetSession = assetSession
        self.asset = asset
        self.assets = assets
        self.onChanged = onChanged
        _currentAsset = State(initialValue: asset)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ZStack {
                        ProductWorkspaceThumbnail(
                            relativePath: currentAsset.relativePath,
                            fileStore: workspaceSession.environment.fileStore,
                            placeholderSymbol: currentAsset.mediaType == .video ? "video" : "photo"
                        )
                        .scaledToFit()
                        .scaleEffect(zoomScale)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .gesture(MagnificationGesture().onChanged { value in
                            zoomScale = min(max(value, 1), 4)
                        })
                        .onTapGesture(count: 2) {
                            zoomScale = zoomScale > 1 ? 1 : 2
                        }
                    }
                    .padding()

                    HStack {
                        Button {
                            move(offset: -1)
                        } label: {
                            Label("上一张", systemImage: "chevron.left")
                        }
                        .disabled(currentIndex <= 0)
                        Spacer()
                        Text("\(currentIndex + 1)/\(max(assets.count, 1))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            move(offset: 1)
                        } label: {
                            Label("下一张", systemImage: "chevron.right")
                        }
                        .disabled(currentIndex >= assets.count - 1)
                    }
                    .padding(.horizontal)

                    assetActions
                    AssetDetailView(
                        workspaceSession: workspaceSession,
                        asset: currentAsset,
                        isProjectCover: workspaceSession.currentProject?.coverAssetID == currentAsset.id
                    )
                }
                .padding(.bottom, 24)
            }
            .navigationTitle("资产")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isSharePresented) {
                ActivityView(activityItems: shareURLs)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var assetActions: some View {
        VStack(spacing: 10) {
            HStack {
                Button("分享") {
                    if let url = try? workspaceSession.environment.fileStore.resolveURL(relativePath: currentAsset.relativePath) {
                        shareURLs = [url]
                        isSharePresented = true
                    }
                }
                Menu("分类") {
                    Button("标准") { Task { await changeCategory(.standard) } }
                    Button("细节") { Task { await changeCategory(.detail) } }
                    Button("SKU") { Task { await changeCategory(.sku) } }
                }
                .disabled(currentAsset.mediaType == .video || currentAsset.deletionState == .trashed)
                Button(currentAsset.isBest ? "取消最佳" : "最佳") {
                    Task { await updateBest(!currentAsset.isBest) }
                }
                Button(currentAsset.isFavorite ? "取消收藏" : "收藏") {
                    Task { await updateFavorite(!currentAsset.isFavorite) }
                }
            }
            .buttonStyle(.bordered)

            HStack {
                Button("设为封面") {
                    Task {
                        await assetSession.setCover(assetID: currentAsset.id)
                        await onChanged()
                    }
                }
                .disabled(currentAsset.mediaType == .video || currentAsset.deletionState == .trashed)

                if currentAsset.deletionState == .trashed {
                    Button("恢复") {
                        Task { await restoreCurrent() }
                    }
                } else {
                    Button("删除到回收站", role: .destructive) {
                        Task { await trashCurrent() }
                    }
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
    }

    private var currentIndex: Int {
        assets.firstIndex(where: { $0.id == currentAsset.id }) ?? 0
    }

    private func move(offset: Int) {
        let nextIndex = currentIndex + offset
        guard assets.indices.contains(nextIndex) else { return }
        currentAsset = assets[nextIndex]
        zoomScale = 1
    }

    private func changeCategory(_ category: CaptureCategory) async {
        assetSession.enterSelectionMode(assetID: currentAsset.id)
        await assetSession.updateCategory(category)
        await onChanged()
        if let updated = assetSession.visibleAssets.first(where: { $0.id == currentAsset.id }) {
            currentAsset = updated
        }
    }

    private func updateBest(_ isBest: Bool) async {
        assetSession.enterSelectionMode(assetID: currentAsset.id)
        await assetSession.updateBest(isBest)
        await onChanged()
        currentAsset.isBest = isBest
    }

    private func updateFavorite(_ isFavorite: Bool) async {
        assetSession.enterSelectionMode(assetID: currentAsset.id)
        await assetSession.updateFavorite(isFavorite)
        await onChanged()
        currentAsset.isFavorite = isFavorite
    }

    private func trashCurrent() async {
        assetSession.enterSelectionMode(assetID: currentAsset.id)
        await assetSession.moveSelectedToTrash()
        await onChanged()
        dismiss()
    }

    private func restoreCurrent() async {
        assetSession.enterSelectionMode(assetID: currentAsset.id)
        await assetSession.restoreSelectedFromTrash()
        await onChanged()
        dismiss()
    }
}

private struct AssetDetailView: View {
    @ObservedObject var workspaceSession: ProductWorkspaceSession
    let asset: ProjectAsset
    let isProjectCover: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("详情")
                .font(.headline)
            detailRow("文件名", asset.originalFilename ?? asset.relativePath.components(separatedBy: "/").last ?? "-")
            detailRow("项目", workspaceSession.projectName(for: asset.projectID))
            detailRow("分类", categoryTitle(asset.category))
            detailRow("来源", asset.sourceType.rawValue)
            detailRow("媒体", asset.mediaType.rawValue)
            detailRow("像素", pixelText)
            detailRow("大小", fileSizeText)
            detailRow("拍摄/导入", DateFormatter.localizedString(from: asset.importedAt ?? asset.createdAt, dateStyle: .short, timeStyle: .short))
            detailRow("创建", DateFormatter.localizedString(from: asset.createdAt, dateStyle: .short, timeStyle: .short))
            detailRow("封面", isProjectCover ? "是" : "否")
            detailRow("最佳", asset.isBest ? "是" : "否")
            detailRow("收藏", asset.isFavorite ? "是" : "否")
            detailRow("资产 ID", String(asset.id.uuidString.prefix(8)))
            #if DEBUG
            Divider()
            detailRow("relativePath", asset.relativePath)
            detailRow("thumbnail", asset.thumbnailRelativePath ?? "-")
            detailRow("schema", "\(asset.schemaVersion)")
            detailRow("parent", asset.parentAssetID?.uuidString ?? "-")
            detailRow("root", asset.rootAssetID?.uuidString ?? "-")
            #endif
        }
        .font(.caption)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var pixelText: String {
        guard let width = asset.pixelWidth, let height = asset.pixelHeight else { return "-" }
        return "\(width) × \(height)"
    }

    private var fileSizeText: String {
        guard let bytes = asset.fileSizeBytes else { return "-" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 82, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func categoryTitle(_ category: CaptureCategory) -> String {
        switch category {
        case .standard:
            return "标准"
        case .detail:
            return "细节"
        case .sku:
            return "SKU"
        case .video:
            return "视频"
        }
    }
}

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private final class ProductWorkspaceThumbnailCache {
    static let shared = ProductWorkspaceThumbnailCache()

    private let cache = NSCache<NSString, UIImage>()

    func image(forKey key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func set(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
}

private struct ProductWorkspaceThumbnail: View {
    let relativePath: String?
    let fileStore: ProjectFileStore
    let placeholderSymbol: String

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.secondary.opacity(0.12))

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: placeholderSymbol)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .clipped()
        .task(id: relativePath) {
            await loadImage()
        }
    }

    @MainActor
    private func loadImage() async {
        guard let relativePath,
              let url = try? fileStore.resolveURL(relativePath: relativePath) else {
            image = nil
            return
        }
        if let cachedImage = ProductWorkspaceThumbnailCache.shared.image(forKey: relativePath) {
            image = cachedImage
            return
        }
        let loaded = await Task.detached(priority: .utility) { () -> UIImage? in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return UIImage(data: data)
        }.value
        if let loaded {
            ProductWorkspaceThumbnailCache.shared.set(loaded, forKey: relativePath)
        }
        image = loaded
    }
}

private struct ProductEmptyStateView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

struct ProductProjectQuickPanel: View {
    @ObservedObject var session: ProductWorkspaceSession
    let onCreateProject: () -> Void
    let onViewAllProjects: () -> Void
    let onSelectProject: (UUID) async -> Void

    var body: some View {
        NavigationStack {
            List {
                if let current = session.currentProjectSummary {
                    Section("当前项目") {
                        ProductProjectCardView(
                            summary: current,
                            fileStore: session.environment.fileStore
                        )
                    }
                }

                Section("最近项目") {
                    ForEach(session.projectSummaries.prefix(5)) { summary in
                        Button {
                            Task {
                                await onSelectProject(summary.projectID)
                            }
                        } label: {
                            ProductProjectCardView(
                                summary: summary,
                                fileStore: session.environment.fileStore
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section {
                    Button(action: onCreateProject) {
                        Label("创建新项目", systemImage: "folder.badge.plus")
                    }
                    Button(action: onViewAllProjects) {
                        Label("查看全部项目", systemImage: "square.grid.2x2")
                    }
                }
            }
            .navigationTitle("项目")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await session.refreshCurrentProjectState()
            }
        }
    }
}

struct ProductQuickCreateProjectSheet: View {
    let onCreate: (String?) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            Form {
                Section("项目名称") {
                    TextField(defaultNameExample, text: $name)
                        .textInputAutocapitalization(.never)
                    Text("留空时自动生成类似“\(defaultNameExample)”的唯一名称。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("创建项目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isCreating ? "创建中…" : "创建") {
                        Task {
                            isCreating = true
                            await onCreate(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : name)
                            isCreating = false
                        }
                    }
                    .disabled(isCreating)
                }
            }
        }
    }

    private var defaultNameExample: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "商品项目 \(formatter.string(from: Date())) 001"
    }
}

private struct ProductProjectRenameSheet: View {
    let initialName: String
    let onSave: (String) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var isSaving = false

    init(initialName: String, onSave: @escaping (String) async -> Void) {
        self.initialName = initialName
        self.onSave = onSave
        _name = State(initialValue: initialName)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("项目名称", text: $name)
            }
            .navigationTitle("重命名项目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "保存中…" : "保存") {
                        Task {
                            isSaving = true
                            await onSave(name)
                            isSaving = false
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
        }
    }
}

struct SellerProfileShellView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("账户") {
                    Label("基础信息", systemImage: "person.crop.circle")
                }
                Section("订阅与服务") {
                    Label("订阅", systemImage: "creditcard")
                    Label("云空间", systemImage: "icloud")
                    Label("AI 使用与费用", systemImage: "sparkles")
                }
                Section("设置") {
                    Label("拍摄与导出", systemImage: "camera.aperture")
                    Label("通知", systemImage: "bell")
                    Label("数据与隐私", systemImage: "lock.shield")
                }
                Section("支持") {
                    Label("帮助与反馈", systemImage: "questionmark.circle")
                    Label("关于 Seller Camera", systemImage: "info.circle")
                }
            }
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

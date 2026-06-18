//
//  ProductWorkspaceViews.swift
//  SellerCamera
//
//  Created by Codex on 2026/6/18.
//

import PhotosUI
import SwiftUI
import UIKit

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

private struct ProductAssetLibraryView: View {
    @ObservedObject var session: ProductWorkspaceSession

    @State private var categoryFilter: CaptureCategory?
    @State private var projectFilterID: UUID?
    @State private var selectedAsset: ProjectAsset?
    @State private var selectedImportPhotoItem: PhotosPickerItem?
    @State private var isImporting = false
    @State private var importStatusText: String?

    private var assets: [ProjectAsset] {
        session.allAssets
            .filter { asset in
                if let categoryFilter, asset.category != categoryFilter {
                    return false
                }
                if let projectFilterID, asset.projectID != projectFilterID {
                    return false
                }
                return true
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 8) {
                Picker("分类", selection: $categoryFilter) {
                    Text("全部").tag(Optional<CaptureCategory>.none)
                    Text("标准").tag(Optional.some(CaptureCategory.standard))
                    Text("细节").tag(Optional.some(CaptureCategory.detail))
                    Text("SKU").tag(Optional.some(CaptureCategory.sku))
                    Text("视频").tag(Optional.some(CaptureCategory.video))
                }
                .pickerStyle(.segmented)

                Picker("项目", selection: $projectFilterID) {
                    Text("全部项目").tag(Optional<UUID>.none)
                    ForEach(session.projectSummaries) { summary in
                        Text(summary.projectName).tag(Optional.some(summary.projectID))
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    PhotosPicker(
                        selection: $selectedImportPhotoItem,
                        matching: .images,
                        preferredItemEncoding: .automatic
                    ) {
                        Label(isImporting ? "导入中…" : "导入图片", systemImage: "square.and.arrow.down")
                    }
                    .disabled(isImporting)

                    if let importStatusText {
                        Text(importStatusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal)

            if assets.isEmpty {
                ProductEmptyStateView(
                    title: "暂无图片",
                    systemImage: "photo.stack",
                    message: "拍摄成功并写入项目 metadata 后，图片会按分类出现在这里。"
                )
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 98), spacing: 10)], spacing: 10) {
                        ForEach(assets) { asset in
                            Button {
                                selectedAsset = asset
                            } label: {
                                ProductAssetTileView(
                                    asset: asset,
                                    fileStore: session.environment.fileStore
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 18)
                }
            }
        }
        .sheet(item: $selectedAsset) { asset in
            ProductAssetPreviewSheet(
                session: session,
                asset: asset
            )
            .presentationDetents([.large])
        }
        .onChange(of: selectedImportPhotoItem) { item in
            guard let item else { return }
            Task {
                await importPhoto(item)
            }
        }
    }

    @MainActor
    private func importPhoto(_ item: PhotosPickerItem) async {
        isImporting = true
        importStatusText = "读取中"
        defer {
            isImporting = false
            selectedImportPhotoItem = nil
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  !data.isEmpty,
                  let image = UIImage(data: data) else {
                importStatusText = "导入失败"
                return
            }
            let category = importCategory
            let input = ProjectPhotoArchiveInput(
                data: data,
                capturedAt: Date(),
                category: category,
                origin: .photoLibrary,
                width: Int(image.size.width.rounded()),
                height: Int(image.size.height.rounded()),
                metadata: ["source": "workspace-import"],
                originalFilename: item.itemIdentifier
            )
            let archiveService = session.environment.archiveService
            let result = try await Task.detached(priority: .utility) {
                try await archiveService.archivePhoto(input)
            }.value
            await session.refreshCurrentProjectState()
            importStatusText = "已导入 \(result.asset.category.rawValue)"
        } catch {
            importStatusText = "导入失败"
        }
    }

    private var importCategory: CaptureCategory {
        if let categoryFilter, categoryFilter != .video {
            return categoryFilter
        }
        if session.selectedCaptureCategory == .video {
            return .standard
        }
        return session.selectedCaptureCategory
    }
}

private struct ProductAssetTileView: View {
    let asset: ProjectAsset
    let fileStore: ProjectFileStore

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ProductWorkspaceThumbnail(
                relativePath: asset.thumbnailRelativePath ?? asset.relativePath,
                fileStore: fileStore,
                placeholderSymbol: asset.category == .video ? "video" : "photo"
            )
            .aspectRatio(1, contentMode: .fill)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text(categoryTitle(asset.category))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.black.opacity(0.46), in: Capsule())
                .padding(6)
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

private struct ProductAssetPreviewSheet: View {
    @ObservedObject var session: ProductWorkspaceSession
    let asset: ProjectAsset

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ProductWorkspaceThumbnail(
                    relativePath: asset.relativePath,
                    fileStore: session.environment.fileStore,
                    placeholderSymbol: "photo"
                )
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .padding()

                VStack(alignment: .leading, spacing: 8) {
                    Text(session.projectName(for: asset.projectID))
                        .font(.headline)
                    Text("\(asset.category.rawValue) · \(DateFormatter.localizedString(from: asset.createdAt, dateStyle: .short, timeStyle: .short))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(asset.relativePath)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                Button {
                    Task {
                        await session.setCover(projectID: asset.projectID, assetID: asset.id)
                        dismiss()
                    }
                } label: {
                    Label("设为项目封面", systemImage: "star.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)

                Spacer(minLength: 0)
            }
            .navigationTitle("图片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
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
        let loaded = await Task.detached(priority: .utility) { () -> UIImage? in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return UIImage(data: data)
        }.value
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

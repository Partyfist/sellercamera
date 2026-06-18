# P1A Product Workspace Foundation 报告

日期：2026-06-18
分支：`feature/product-project-workflow`
基线：`camera-baseline-r77i`

## 1. 改动摘要

P1A 建立商品项目基础闭环：

```text
创建商品项目
→ 自动命名
→ 设为当前项目
→ 拍摄照片
→ 原图写入项目目录
→ 缩略图生成
→ ProjectAsset 入库
→ 统计更新
→ App 重启恢复当前项目与资产
```

本轮只做项目、持久化、文件目录、资产归档、当前项目恢复、统计和文档；未实现完整工作台 UI、我的页面、SKU、AI、云同步、订阅、分享或交易。

## 2. 文件清单

新增 Domain：

- `SellerCamera/ProductWorkspace/Domain/ProductProject.swift`
- `SellerCamera/ProductWorkspace/Domain/ProjectAsset.swift`
- `SellerCamera/ProductWorkspace/Domain/ProjectAssetCounts.swift`
- `SellerCamera/ProductWorkspace/Domain/ProductWorkspaceErrors.swift`
- `SellerCamera/ProductWorkspace/Domain/ProductWorkspaceProtocols.swift`

新增 Persistence：

- `SellerCamera/ProductWorkspace/Persistence/ProductWorkspaceJSONRepository.swift`
- `SellerCamera/ProductWorkspace/Persistence/ProductWorkspaceMapper.swift`
- `SellerCamera/ProductWorkspace/Persistence/CurrentProjectStore.swift`

新增 Storage：

- `SellerCamera/ProductWorkspace/Storage/ProjectFileStore.swift`
- `SellerCamera/ProductWorkspace/Storage/ThumbnailGenerator.swift`
- `SellerCamera/ProductWorkspace/Storage/PhotoFileFormatDetector.swift`

新增 Services：

- `SellerCamera/ProductWorkspace/Services/ProjectNameGenerator.swift`
- `SellerCamera/ProductWorkspace/Services/ProductProjectService.swift`
- `SellerCamera/ProductWorkspace/Services/ProjectAssetArchiveService.swift`
- `SellerCamera/ProductWorkspace/Services/ProjectAssetCountService.swift`
- `SellerCamera/ProductWorkspace/Services/ProductWorkspaceEnvironment.swift`
- `SellerCamera/ProductWorkspace/Services/ProductWorkspaceSession.swift`

相机最小接入：

- `SellerCamera/CaptureLivePreviewView.swift`
- `SellerCamera/CaptureScreen.swift`

测试与工程：

- `SellerCameraTests/ProductWorkspaceFoundationTests.swift`
- `SellerCamera.xcodeproj/project.pbxproj`
- `SellerCamera.xcodeproj/xcshareddata/xcschemes/SellerCamera.xcscheme`

文档：

- `docs/architecture/product_workspace_architecture.md`
- `docs/architecture/product_asset_storage.md`
- `docs/product/pending_product_decisions.md`
- `docs/reports/p1a_product_workspace_foundation.md`
- `README.md`

## 3. 数据模型

`ProductProject`：

- `id`
- `schemaVersion`
- `name`
- `createdAt`
- `updatedAt`
- `status`
- `coverAssetID`
- `isArchived`
- `sortOrder`

`ProjectAsset`：

- `id`
- `schemaVersion`
- `projectID`
- `category`
- `assetType`
- `origin`
- `relativePath`
- `thumbnailRelativePath`
- `createdAt`
- `updatedAt`
- `width`
- `height`
- `duration`
- `fileSize`
- `isFavorite`
- `isDeleted`
- `version`
- `parentAssetID`

`CaptureCategory` 当前为：

- `standard`
- `detail`
- `video`

P1A 实际完整支持 `photo + camera`，其他枚举只作为 schema 预留。

## 4. Repository 与 Storage 结构

Repository：

- `ProductProjectRepository`
- `ProjectAssetRepository`
- `ProjectAssetCounting`
- `ProductWorkspaceJSONRepository`

Storage：

- `ProjectFileStore`
- `ThumbnailGenerator`
- `PhotoFileFormatDetector`

当前 metadata 使用 Application Support 下的 JSON 文件。该实现通过 repository protocol 隔离，Domain 不依赖 UI 和具体持久化实现。

## 5. 项目目录结构

```text
Application Support/
└── SellerCamera/
    ├── ProductWorkspace/
    │   └── metadata.json
    └── Projects/
        └── {projectID}/
            ├── manifest/
            ├── originals/
            │   ├── standard/
            │   ├── detail/
            │   └── video/
            ├── thumbnails/
            ├── processed/
            └── exports/
```

原图文件名使用 `{assetID}.jpg|heic|dng`，数据库只保存相对路径。

## 6. 拍摄资产归档流程

相机接入点：

```text
CaptureCameraRuntime.handleCaptureSuccess
→ archiveCaptureResultToCurrentProject
→ ProjectAssetArchiveService.archivePhoto
```

归档服务流程：

```text
restore current project
→ missing current project 时自动创建默认项目
→ save original photo
→ generate thumbnail
→ create ProjectAsset
→ update project updatedAt
→ coverAssetID nil 时设第一张 photo
→ return counts
```

归档异步执行，不阻塞预览和拍照成功回调。归档失败只显示 Debug / hint 状态，拍照结果仍保留在现有最新照片链路。

## 7. 当前项目恢复逻辑

`CurrentProjectStore` 封装当前项目 ID：

- 创建项目后写入 current project；
- App 启动时 `ProductWorkspaceSession.restoreCurrentProject()` 恢复；
- ID 残留但项目不存在时自动清除；
- 项目归档不自动删除 current project；
- UI 不直接使用 `UserDefaults`。

## 8. 缩略图策略

- 使用 ImageIO 生成；
- 长边 512px；
- JPEG 输出；
- 独立写入 `thumbnails/`；
- 缩略图失败时不阻断原图入库；
- `thumbnailRelativePath` 可为空。

## 9. 测试结果

XCTest：

```text
xcodebuild test \
  -project SellerCamera.xcodeproj \
  -scheme SellerCamera \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' \
  -derivedDataPath /tmp/SellerCameraP1ATest \
  CODE_SIGNING_ALLOWED=NO
```

结果：

```text
Executed 6 tests, with 0 failures
** TEST SUCCEEDED **
```

覆盖：

- 项目自动命名；
- 空白名称自动命名；
- 自定义名称保留；
- 当前项目创建、恢复、缺失清除、归档不删除；
- 项目目录重复创建与隔离；
- 原图与缩略图写入；
- ProjectAsset 元数据；
- 第一张图设封面；
- standard/detail/video/total 统计；
- 创建项目 → 归档 → 文件存在 → metadata 存在 → 统计更新 → 重启恢复。

## 10. Build 结果

Generic iOS build：

```text
xcodebuild \
  -project SellerCamera.xcodeproj \
  -scheme SellerCamera \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/SellerCameraP1ABuild \
  CODE_SIGNING_ALLOWED=NO \
  build
```

结果：

```text
** BUILD SUCCEEDED **
```

已知非新增 warning：

- `CaptureLivePreviewView.swift` 既有 `will never be executed` warning；
- `AppIntents.framework dependency not found` metadata extraction warning。

## 11. 真机验收结果

已执行真机安装 / 启动级验证：

```text
device: iPhone14 pro Max / E7D43088-7946-5FDB-BB14-E38124BB37DB
xcodebuild -destination 'platform=iOS,id=E7D43088-7946-5FDB-BB14-E38124BB37DB' build
** BUILD SUCCEEDED **

xcrun devicectl device install app --device E7D43088-7946-5FDB-BB14-E38124BB37DB ...
App installed: bundleID com.partyfist.SellerCamera

xcrun devicectl device process launch --device E7D43088-7946-5FDB-BB14-E38124BB37DB --terminate-existing --console com.partyfist.SellerCamera
Launched application with com.partyfist.SellerCamera bundle identifier.
```

启动日志确认：

- `Back Triple Camera` 初始化；
- 24mm virtual profile 写入；
- ProductAutoScene / ProductSharpness 日志持续输出；
- 无启动崩溃。

说明：为结束 console 采集，Codex 使用 `SIGINT` 停止 devicectl console，日志中的 `App terminated due to signal 2` 不是 App 自发崩溃。

当前 Codex 未执行手动拍摄动作，因此以下 P1A 真机拍摄归档矩阵仍需用户在设备上补验。

待用户或下一轮真机补验：

1. 打开 Seller Camera；
2. 点击右下角 `项目` 占位入口创建项目；
3. 拍摄一张标准图；
4. 切换到细节并拍摄一张细节图；
5. 查看 Debug 日志 `[ProductWorkspace]` / `[ProjectFileStore]`；
6. 确认标准 1、细节 1；
7. 关闭重启后确认当前项目恢复；
8. 确认相机预览、拍照、镜头、参数、MF、AE-L 无回归。

## 12. 已知限制

- 当前 UI 只有右下角 `项目` 占位入口，非最终工作台。
- 当前 metadata 使用 JSON repository；SwiftData adapter 未实现。
- P1A 不实现项目列表、项目删除、回收站、SKU、商品事实、AI 精修、云同步。
- `whiteBackground` 拍摄意图暂按 `standard` 资产分类归档，避免把 SKU 或白底定稿写入 P1A 数据模型。
- 真机矩阵需在设备上补验。

## 13. 后续任务

建议下一任务：P1B Product Workspace Navigation Shell。

范围应等待 UI 布局确认后再做：

- 顶部项目快捷胶囊；
- 左下角工作台入口；
- 右下角“我的”入口；
- 项目创建轻量弹窗；
- 当前项目封面与数量；
- 最近照片迁移；
- 图册导入入口迁移。

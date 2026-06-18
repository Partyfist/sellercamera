# Product Workspace Architecture

日期：2026-06-19
阶段：P1C Product Asset Library

## 1. 架构目标

Product Workspace 为 Seller Camera 从“单次拍摄工具”进入“商品项目 → 商品事实 → 商品资产 → 精修与分享”的后续阶段提供数据底座。

P1A 建立：

- 商品项目模型；
- 项目资产模型；
- 当前项目恢复；
- 本地元数据持久化；
- 文件系统资产存储；
- 拍摄结果归档；
- 项目资产统计。

P1B 在 P1A 之上建立用户可操作的项目管理闭环：

- 相机顶部项目胶囊；
- 工作台项目列表与图片页；
- “我的”基础页面骨架；
- 项目创建、切换、重命名、归档与恢复；
- 标准 / 细节 / SKU 分类选择与计数；
- 每项目 `lastSelectedCaptureCategory`；
- `CurrentProjectSummary` 供相机 UI 订阅。

P1B 不建立完整 SKU 实体、不建立 AI 精修、不建立云同步、不接入登录/订阅/支付。SKU 仅是 SKU 差异图片的原始采集分类。

P1C 在 P1B 之上补齐商品资产库第一版生命周期：

- 当前项目资产网格与筛选；
- 单张资产查看、详情、分享、分类修改、最佳/收藏、设封面；
- 多选、全选、批量分类、批量最佳/收藏、批量分享、批量删除；
- 系统相册多选导入到目标项目和目标分类；
- 回收站软删除、恢复、永久删除、清空；
- 封面失效自动替换；
- 来源、删除状态、版本关系、处理状态等 metadata 字段预留。

## 2. Domain 与 Persistence 分离

Domain model 位于 `SellerCamera/ProductWorkspace/Domain/`，只使用平台无关类型：

- `String`
- `UUID`
- `Int`
- `Double`
- `Bool`
- `Date`
- `enum`
- `relativePath`

Domain model 不依赖：

- `UIImage`
- `SwiftUI.Image`
- `Color`
- `View`
- `Binding`
- `NavigationPath`

Persistence 位于 `SellerCamera/ProductWorkspace/Persistence/`。当前 P1A 使用 JSON metadata repository 作为最小本地实现，所有调用都通过 repository protocol 进入，不让业务层直接依赖具体持久化记录类型。

SwiftData 可在后续 iOS 实现中替换 JSON repository，但必须继续保持：

- Domain 不导入 SwiftData；
- UI 不直接使用 SwiftData entity；
- repository 负责 entity / domain mapper；
- Android、HarmonyOS 和服务器 schema 仍以 Domain 字段为基准。

## 3. 核心模型关系

```text
ProductProject
└── ProjectAsset[]
    ├── category: standard / detail / sku / video
    ├── mediaType: photo / video
    ├── sourceType: camera / photoLibrary / fileImport / generated / external
    ├── deletionState: active / trashed
    ├── assetRole: original / processed / generated / export
    ├── processingState: original / pending / processing / completed / failed
    ├── parentAssetID / rootAssetID / versionNumber
    └── relativePath: file-system relative path
```

### ProductProject

- `id`: project UUID。
- `schemaVersion`: 当前为 `1`，为 migration 预留。
- `name`: 非空，支持自动命名或用户自定义。
- `createdAt` / `updatedAt`: 创建与更新时间。
- `status`: `active` / `completed` / `archived`。
- `coverAssetID`: 第一张 photo 自动设为封面。
- `isArchived`: 归档字段，归档不等于删除。
- `sortOrder`: 后续项目列表排序预留。
- `lastSelectedCaptureCategory`: 每项目保留上次选择的拍摄分类，切换项目后恢复。

### ProjectAsset

- `id`: asset UUID。
- `schemaVersion`: P1C 资产读取时升级到 `2`。
- `projectID`: 所属项目。
- `category`: `standard` / `detail` / `sku` / `video`。
- `mediaType`: `photo` / `video`，不再通过扩展名判断业务媒体类型；旧 `assetType` metadata 可读取并映射。
- `originalFilename`: 导入或外部来源文件名预留；相机拍摄可为空。
- `sourceType`: P1C 实际使用 `camera` 与 `photoLibrary`；旧 `origin` metadata 可读取并映射。
- `relativePath`: 原图相对路径。
- `thumbnailRelativePath`: 可空；缩略图失败不阻断原图入库。
- `pixelWidth` / `pixelHeight` / `durationSeconds` / `fileSizeBytes`: 基础资产元数据。
- `isFavorite` / `isBest`: 收藏与最佳候选标记，允许多张最佳。
- `deletionState` / `deletedAt`: 软删除和回收站状态。
- `versionNumber`: 原始资产初始为 `1`。
- `parentAssetID` / `rootAssetID`: 后续 processed/export 版本追溯预留，原始资产 `rootAssetID == id`。
- `assetRole`: P1C 新资产默认 `original`。
- `processingState`: P1C 原始资产默认 `original`。
- `skuID`: P2 具体 SKU 实体绑定预留，P1C 不要求填写。

## 4. 当前项目状态

当前项目通过 `CurrentProjectStore` 封装，当前实现为 `UserDefaultsCurrentProjectStore`。

规则：

- 创建项目后自动设为当前项目；
- App 重启后通过 store 恢复；
- 当前项目 ID 残留但项目不存在时自动清除；
- 当前项目若已归档，会清除并切换到最近未归档项目；
- 无当前项目时先复用最近未归档项目，不存在时才创建默认项目；
- UI 不直接读写 `UserDefaults`。

## 5. Repository 与 Service

```text
ProductWorkspaceEnvironment
├── ProductWorkspaceJSONRepository
│   ├── ProductProjectRepository
│   ├── ProjectAssetRepository
│   └── ProjectAssetCounting
├── ProductProjectService
├── ProjectAssetArchiveService
├── ProjectAssetLibraryService
├── ProjectAssetCountService
├── ProjectFileStore
└── ThumbnailGenerator
```

`ProductProjectService` 负责：

- 自动命名；
- 创建项目；
- 创建目录；
- 设置当前项目；
- 恢复当前项目；
- 重命名；
- 归档与恢复；
- 每项目拍摄分类偏好；
- 项目 summary 生成。

`ProjectAssetArchiveService` 负责：

- 无当前项目时自动创建默认项目；
- 支持指定 `targetProjectID`，用于资产库导入时不切换当前项目；
- 保存原图；
- 生成缩略图；
- 写入 `ProjectAsset`；
- 更新项目 `updatedAt`；
- 第一张 photo 设为封面；
- 返回统计结果。

`ProjectAssetLibraryService` 负责：

- 按项目、筛选和排序读取资产；
- 批量修改分类、收藏、最佳；
- 设置项目封面并校验资产属于该项目、为 active photo；
- 删除到回收站、恢复、永久删除、清空回收站；
- 永久删除时同步移除 metadata、原图和缩略图；
- 父资产存在 active 派生版本时阻止永久删除；
- 当前封面进入回收站或永久删除时自动选择新封面。

`ProductWorkspaceSession` 是 SwiftUI 订阅边界，向相机页暴露：

- `currentProjectSummary`
- `currentCounts`
- `selectedCaptureCategory`
- `projectSummaries`
- `archivedProjectSummaries`
- `currentProjectAssets`
- `allAssets`

相机页不扫描目录、不直接解析 metadata，只通过 session/service 更新项目状态；项目切换不触发 AVCaptureSession 重建。

`ProductAssetLibrarySession` 是资产库页面订阅边界，向工作台图片页暴露：

- `selectedFilter`
- `sortOrder`
- `visibleAssets`
- `selectedAssetIDs`
- `isSelectionMode`
- `isImporting`
- `importProgressText`
- `lastStatusText`
- `lastErrorText`

相机主界面只订阅项目 summary 和分类数量，不订阅完整资产列表，避免资产库状态扩散回拍摄页。

## 6. 文件与元数据分离

数据库 / metadata 只保存：

- project 字段；
- asset 字段；
- `relativePath`；
- `thumbnailRelativePath`；
- 基础 metadata。

图片、缩略图、processed、exports 均保存在 Application Support 文件系统，不把大文件写入 metadata。

## 7. Migration 原则

- 每个 Domain model 都有 `schemaVersion`。
- 新字段优先追加并提供默认兼容。
- 旧 `whiteBackground` / `white` / `white_background` 原始分类读取时映射到 `sku`；P1A 未真实生产白底原始分类数据，本轮不做独立 legacy 分类。
- 旧 asset metadata 的 `assetType` 读取时映射到新 `mediaType`。
- 旧 asset metadata 的 `origin` 读取时映射到新 `sourceType`。
- P1C 新增字段缺失时使用安全默认值：`isBest=false`、`deletionState=active`、`rootAssetID=id`、`assetRole=original`、`processingState=original`、`versionNumber=1`。
- 不把 iOS 具体实现类型写入 Domain。
- Android / HarmonyOS 可复用同名 schema 字段。
- SwiftData、SQLite、服务器 API 都只能作为 Persistence adapter。

## 8. P1C 边界

已完成：

- 项目模型；
- 资产模型；
- 自动命名；
- 当前项目恢复；
- 项目列表；
- 图片列表；
- 当前项目胶囊；
- 项目创建 / 切换 / 重命名 / 归档 / 恢复；
- 标准 / 细节 / SKU 分类与计数；
- 资产库筛选；
- 多选与批量操作；
- 系统相册批量导入；
- 回收站与永久删除；
- 项目封面替换；
- 版本关系字段和 active 派生资产保护；
- JSON metadata repository；
- Application Support file store；
- 拍摄资产异步归档；
- 缩略图；
- 统计；
- XCTest 覆盖。

未完成：

- 完整 SKU 实体；
- 商品事实；
- AI 精修；
- 云同步；
- 分享、供货、零售；
- SwiftData adapter。

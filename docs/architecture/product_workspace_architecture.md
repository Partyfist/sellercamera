# Product Workspace Architecture

日期：2026-06-18
阶段：P1A Product Workspace Foundation

## 1. 架构目标

Product Workspace 为 Seller Camera 从“单次拍摄工具”进入“商品项目 → 商品事实 → 商品资产 → 精修与分享”的后续阶段提供数据底座。

P1A 只建立：

- 商品项目模型；
- 项目资产模型；
- 当前项目恢复；
- 本地元数据持久化；
- 文件系统资产存储；
- 拍摄结果归档；
- 项目资产统计。

P1A 不建立完整工作台 UI、不建立“我的”页面、不建立 SKU / 商品事实 / AI 精修 / 云同步。

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
    ├── category: standard / detail / video
    ├── assetType: photo / video / thumbnail / processedImage / export
    ├── origin: camera / photoLibrary / importedFile / generated / externalAI
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

### ProjectAsset

- `id`: asset UUID。
- `schemaVersion`: 当前为 `1`。
- `projectID`: 所属项目。
- `category`: `standard` / `detail` / `video`。
- `assetType`: P1A 实际只完整支持 `photo`。
- `origin`: P1A 拍照归档使用 `camera`；导入路径可标记 `photoLibrary`。
- `relativePath`: 原图相对路径。
- `thumbnailRelativePath`: 可空；缩略图失败不阻断原图入库。
- `width` / `height` / `fileSize`: 基础资产元数据。
- `version`: 初始为 `1`。
- `parentAssetID`: 后续 processed/export 追溯预留。

## 4. 当前项目状态

当前项目通过 `CurrentProjectStore` 封装，当前实现为 `UserDefaultsCurrentProjectStore`。

规则：

- 创建项目后自动设为当前项目；
- App 重启后通过 store 恢复；
- 当前项目 ID 残留但项目不存在时自动清除；
- 归档项目不会被自动删除；
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
├── ProjectAssetCountService
├── ProjectFileStore
└── ThumbnailGenerator
```

`ProductProjectService` 负责：

- 自动命名；
- 创建项目；
- 创建目录；
- 设置当前项目；
- 恢复当前项目。

`ProjectAssetArchiveService` 负责：

- 无当前项目时自动创建默认项目；
- 保存原图；
- 生成缩略图；
- 写入 `ProjectAsset`；
- 更新项目 `updatedAt`；
- 第一张 photo 设为封面；
- 返回统计结果。

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
- 不把 iOS 具体实现类型写入 Domain。
- Android / HarmonyOS 可复用同名 schema 字段。
- SwiftData、SQLite、服务器 API 都只能作为 Persistence adapter。

## 8. P1A 边界

已完成：

- 项目模型；
- 资产模型；
- 自动命名；
- 当前项目恢复；
- JSON metadata repository；
- Application Support file store；
- 拍摄资产异步归档；
- 缩略图；
- 统计；
- XCTest 覆盖。

未完成：

- 完整工作台；
- 项目列表；
- SKU；
- 商品事实；
- AI 精修；
- 云同步；
- 分享、供货、零售；
- SwiftData adapter。

# P1C Product Asset Library 报告

日期：2026-06-19

## 1. 改动摘要

P1C 在 P1A / P1B 的项目与归档基础上，将图片升级为可长期管理的商品资产：

- 资产模型扩展为 `schemaVersion = 2`，新增来源、媒体类型、删除状态、最佳/收藏、文件尺寸、像素尺寸、导入时间、版本关系和处理状态字段。
- 工作台图片页升级为当前项目资产库，支持全部 / 标准 / 细节 / SKU / 视频 / 最佳 / 收藏 / 回收站筛选。
- 单张资产支持大图查看、缩放、左右浏览、详情、分类修改、设封面、最佳、收藏、分享和删除到回收站。
- 批量模式支持多选、全选当前筛选结果、批量分类、批量最佳/收藏、批量分享、批量删除、回收站恢复、永久删除和清空回收站。
- 系统相册导入支持多选图片和视频，导入前选择目标项目与目标分类；视频自动写入 `video` 分类。
- 回收站支持软删除、恢复、永久删除；封面资产失效时自动选择新封面。
- 版本关系仅建立字段和删除保护，不创建真实精修版本。

本轮没有修改相机镜头、连续变焦、AE-L、MF、EV、WB、TINT、ISO、Shutter、比例、像素、RAW、稳定器或拍照主链路。

## 2. 领域模型变化

`ProjectAsset` 保留 P1A / P1B 兼容字段，并新增 P1C 语义：

- `mediaType`: `photo` / `video`，避免通过文件扩展名判断业务类型。
- `sourceType`: `camera` / `photoLibrary` / `fileImport` / `generated` / `external`。
- `importedAt`: 非相机来源导入时间。
- `pixelWidth` / `pixelHeight` / `durationSeconds` / `fileSizeBytes`: 资产基础尺寸信息。
- `isFavorite` / `isBest`: 收藏与最佳候选。
- `deletionState` / `deletedAt`: active / trashed 回收站生命周期。
- `parentAssetID` / `rootAssetID` / `versionNumber`: 版本追溯字段。
- `assetRole` / `processingState`: 后续 processed / generated / export 链路预留。

兼容别名仍保留：

- `assetType`
- `origin`
- `width`
- `height`
- `duration`
- `fileSize`
- `version`

## 3. 旧数据迁移

`ProjectAssetRecord` 支持读取 P1A / P1B 旧 metadata：

- 缺失 `mediaType` 时从旧 `assetType` 映射。
- 缺失 `sourceType` 时从旧 `origin` 映射。
- 缺失 `pixelWidth` / `pixelHeight` / `durationSeconds` / `fileSizeBytes` 时读取旧 `width` / `height` / `duration` / `fileSize`。
- 缺失 `deletionState` 时根据旧 `isDeleted` 映射为 `active` 或 `trashed`。
- 缺失 `rootAssetID` 时使用当前 asset id。
- 缺失 `assetRole` 时默认为 `original`。
- 缺失 `processingState` 时默认为 `original`。
- 缺失 `versionNumber` 时读取旧 `version`，否则默认为 `1`。
- 读取后 asset `schemaVersion` 归一为 `2`。

迁移不复制文件、不修改已有 assetID、不移动原始文件、不丢失分类。

## 4. 资产筛选

P1C 筛选模型：

- `all`
- `category(.standard)`
- `category(.detail)`
- `category(.sku)`
- `video`
- `best`
- `favorite`
- `trash`

默认排序为 `createdAt` descending，预留 `oldest`、`filename` 和 `fileSize`。

默认资产列表、分类筛选、最佳和收藏都只返回 active 资产；回收站筛选只返回 `deletionState == .trashed` 或 legacy `isDeleted == true` 的资产。

## 5. 批量操作

批量操作通过 `ProductAssetLibrarySession` → `ProjectAssetLibraryService` → `ProjectAssetRepository` 执行，UI 不直接写 JSON。

已支持：

- 批量修改分类。
- 批量收藏 / 取消收藏。
- 批量最佳 / 取消最佳。
- 批量分享原文件 URL。
- 批量删除到回收站。
- 回收站批量恢复。
- 回收站批量永久删除。
- 当前项目清空回收站。

视频资产在 repository 层保持 `video` 分类，不参与标准 / 细节 / SKU 分类转换。

## 6. 系统相册导入

导入入口位于工作台图片页顶部：

```text
目标项目 Picker
目标分类 Picker
PhotosPicker 多选导入
```

导入流程：

```text
PhotosPickerItem → Data
→ 同一导入任务内按 filename + size + mediaType 去重
→ ProjectPhotoArchiveInput(targetProjectID:)
→ 复制到 Application Support / Projects
→ photo 生成缩略图
→ video 跳过缩略图并保存 durationSeconds
→ 写入 ProjectAsset metadata
→ 刷新资产库和项目计数
```

单项失败不取消整批；批量结果返回 requested / succeeded / failed。

## 7. 回收站机制

软删除：

```text
deletionState = trashed
isDeleted = true
deletedAt = now
```

软删除后：

- 默认资产列表隐藏。
- 分类统计减少。
- 文件与缩略图保留。
- 回收站可查看。
- 可恢复。

恢复：

```text
deletionState = active
isDeleted = false
deletedAt = nil
```

恢复后原分类、统计和筛选结果恢复。

## 8. 永久删除规则

永久删除执行：

```text
检查 active 派生资产
→ 删除 metadata
→ 删除原图文件
→ 删除缩略图文件
→ 清理或替换封面引用
→ 刷新统计
```

如果父资产仍有 active 派生资产，P1C 阻止永久删除父资产。P1C 尚不创建真实派生版本，但已通过 XCTest 验证该保护策略。

## 9. 项目封面规则

设为封面必须满足：

- asset 属于目标 project。
- asset 为 active。
- asset 未删除。
- `mediaType == photo`。

当前封面进入回收站或永久删除时，自动选择新封面：

```text
最佳标准图
→ 标准图
→ SKU 图
→ 细节图
→ nil
```

恢复旧封面资产后不会自动抢回封面。

## 10. 版本关系预留

原始资产默认：

```text
parentAssetID = nil
rootAssetID = self.id
versionNumber = 1
assetRole = original
processingState = original
```

后续 processed / generated / export 可通过 `parentAssetID` 和 `rootAssetID` 串联版本链。本轮不实现 AI 精修、不生成白底图、不创建真实版本 UI。

## 11. 文件存储规则

P1C 继续使用 P1A 目录结构：

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
            │   ├── sku/
            │   └── video/
            ├── thumbnails/
            ├── processed/
            └── exports/
```

分类以 metadata 为事实源；批量修改分类不移动原始文件目录。永久删除才删除磁盘文件。

## 12. 并发控制

当前 JSON repository 使用 `NSRecursiveLock` 包裹 read / mutate / atomic save，避免拍照归档、批量导入、删除和恢复并发写 metadata 时互相覆盖。

写入规则：

- 以 assetID 为主键操作。
- metadata 编码为 pretty printed + sorted keys。
- 写入使用 `Data.write(..., .atomic)`。
- 归档 metadata 失败时清理本轮写入的原图和缩略图。
- UI 通过 session 重新 load 当前项目筛选结果，不直接维护假增量。

## 13. 性能验证

已完成的工程侧性能保护：

- 网格优先使用 `thumbnailRelativePath`。
- 缩略图读取放在 detached utility task，不阻塞主线程。
- UI 增加轻量 `NSCache` 缓存已解码缩略图。
- metadata 查询不扫描磁盘。
- 批量导入逐项处理，并提供进度文本。

尚未完成 1,000 张资产与 100 张导入的真机压力矩阵，列为后续性能专项。

## 14. 测试结果

### git diff --check

```text
PASS
```

### Generic iOS Build

命令：

```sh
xcodebuild -project SellerCamera.xcodeproj \
  -scheme SellerCamera \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/SellerCameraP1CBuild \
  CODE_SIGNING_ALLOWED=NO \
  clean build
```

结果：

```text
BUILD SUCCEEDED
```

### XCTest

命令：

```sh
xcodebuild test -project SellerCamera.xcodeproj \
  -scheme SellerCamera \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' \
  -derivedDataPath /tmp/SellerCameraP1CTest \
  CODE_SIGNING_ALLOWED=NO
```

结果：

```text
Executed 16 tests, with 0 failures
TEST SUCCEEDED
```

新增 P1C 覆盖：

- 旧资产 metadata 迁移默认值。
- rootAssetID / versionNumber / assetRole / processingState 初始化。
- 全部 / 分类 / 视频 / 最佳 / 收藏 / 回收站筛选。
- 批量 favorite / best / soft delete / restore。
- 删除封面后自动替换，恢复旧封面不抢回。
- 永久删除 metadata 与文件。
- active 派生资产阻止父资产永久删除。
- 批量导入去重、目标项目隔离、视频映射到 video。

## 15. 真机结果

设备：

```text
iPhone14 pro Max
UDID: E7D43088-7946-5FDB-BB14-E38124BB37DB
Model: iPhone 14 Pro Max (iPhone15,3)
State: connected
```

真机 build：

```sh
xcodebuild -project SellerCamera.xcodeproj \
  -scheme SellerCamera \
  -configuration Debug \
  -destination 'platform=iOS,id=E7D43088-7946-5FDB-BB14-E38124BB37DB' \
  -derivedDataPath /tmp/SellerCameraP1CDeviceBuild \
  build
```

结果：

```text
BUILD SUCCEEDED
```

安装：

```sh
xcrun devicectl device install app \
  --device E7D43088-7946-5FDB-BB14-E38124BB37DB \
  /tmp/SellerCameraP1CDeviceBuild/Build/Products/Debug-iphoneos/SellerCamera.app
```

结果：

```text
App installed: com.partyfist.SellerCamera
```

启动：

```sh
xcrun devicectl device process launch \
  --device E7D43088-7946-5FDB-BB14-E38124BB37DB \
  --terminate-existing \
  com.partyfist.SellerCamera
```

结果：

```text
Launched application with com.partyfist.SellerCamera bundle identifier.
PID: 17449
```

手动资产库验收矩阵：

```text
Codex 当前工具可完成真机 build / install / launch / process check，
但无法直接操作用户手中 iPhone 的资产库 UI 完成完整人工矩阵。
以下矩阵需用户补验后才可宣布 P1C 真机验收完全通过。
```

待补验项：

- 标准 20 / 细节 10 / SKU 8 / 视频 2 的筛选数量与滚动。
- 批量标准 5 张改 SKU 后计数同步。
- 批量导入 20 张到当前项目 / 细节。
- 删除 3 张 SKU、恢复 2 张、永久删除 1 张。
- 设置封面 A、删除 A 后自动替换、恢复 A 不抢回。
- 查看器缩放、左右浏览、视频占位/播放能力、详情、分享、分类、最佳/收藏、删除。
- 返回相机后继续拍摄标准 / 细节 / SKU，确认无黑屏、无 session 重建、无参数重置。

## 16. 已知限制

- 完整 SKU 实体、SKU 属性编辑器和 SKU 图片绑定未实现。
- AI 精修、白底图生成、背景生成、图层编辑器未实现。
- 云同步、团队协作、分享链接、账户、订阅支付、供货、零售、店铺、网站、订单未实现。
- 视频 P1C 仅作为资产媒体类型与导入存储接入，未做完整播放器、抽帧封面或视频编辑。
- 1,000 张网格与 100 张批量导入压力测试尚未做真机矩阵。
- 手动资产库验收矩阵尚需用户在 iPhone 14 Pro Max 上补验。

## 17. 后续建议

下一轮建议只做 P1C 补验收口：

1. 用户执行 P1C 手动资产库矩阵。
2. 根据真实问题只做最小修复。
3. 将手动矩阵结果补写到本报告。
4. 再进入 P1D 商品事实或 SKU 实体之前，保持相机冻结基线不动。

## 18. 代码边界声明

P1C 仅新增 Product Workspace 资产库、批量管理、导入、回收站和版本关系基础；未修改冻结拍摄基线和相机 runtime 关键链路。

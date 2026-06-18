# Product Asset Storage

日期：2026-06-19
阶段：P1C Product Asset Library

## 1. 存储原则

- 原始资产永不覆盖。
- 缩略图、processed、export 不替代原图。
- 元数据只保存相对路径和基础字段。
- 数据库 / metadata 不保存图片二进制。
- 文件名使用 asset UUID，不使用项目名或时间戳作为唯一 ID。
- 路径拼接统一由 `ProjectFileStore` 完成。

## 2. Application Support 根目录

P1C 继续使用 Application Support：

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

`ProjectFileStore.createProjectDirectories(projectID:)` 会统一创建上述项目目录。重复创建不报错。

## 3. 原图目录

按 `CaptureCategory` 存储：

```text
{projectID}/originals/standard/{assetID}.jpg|heic|dng
{projectID}/originals/detail/{assetID}.jpg|heic|dng
{projectID}/originals/sku/{assetID}.jpg|heic|dng
{projectID}/originals/video/{assetID}.jpg|heic|dng
```

P1C 支持 `photo + camera`、`photo + photoLibrary`，并为系统相册导入的视频写入 `originals/video`。`sku` 目录代表 SKU 差异图采集分类，不代表完整 SKU 实体管理；`video` 目录代表资产媒体类型为 video，不参与标准 / 细节 / SKU 分类转换。

## 4. 缩略图目录

```text
{projectID}/thumbnails/{assetID}.jpg
```

缩略图策略：

- 长边 512px；
- 保持比例；
- JPEG 独立文件；
- 生成失败不阻断原图归档；
- `thumbnailRelativePath` 可为空。
- 网格优先加载缩略图；
- UI 侧使用轻量 `NSCache` 缓存已解码缩略图；
- 视频 P1C 暂不抽帧，缩略图为空时显示视频占位。

## 5. processed 与 exports

P1C 只创建目录，不写入 processed/export 资产：

```text
{projectID}/processed/
{projectID}/exports/
```

后续精修、白底、导出图必须新建资产或新建文件，不得覆盖 originals。

## 6. 相对路径

`ProjectAsset.relativePath` 示例：

```text
8B1C.../originals/standard/A9F4....jpg
```

`ProjectAsset.thumbnailRelativePath` 示例：

```text
8B1C.../thumbnails/A9F4....jpg
```

业务层调用 `ProjectFileStore.resolveURL(relativePath:)` 获取真实 URL，不直接拼接 Application Support。

## 7. 写入与失败处理

拍摄归档写入顺序：

```text
ensure current project
→ create assetID
→ save original atomically
→ generate thumbnail
→ save thumbnail atomically
→ create metadata
→ update project cover / updatedAt
→ refresh project statistics
```

失败规则：

- 原图写入失败：不创建资产记录。
- 缩略图失败：原图仍可入库，thumbnail path 为空。
- metadata 写入失败：清理本轮已写入的原图和缩略图。
- 归档失败：相机拍照结果仍保留在现有最新照片链路，不崩溃。
- 分类计数只以 metadata 中有效、未删除的 `ProjectAsset` 为准，不通过 UI 扫描磁盘目录增量。

系统相册导入写入顺序：

```text
PhotosPicker 读取 Data
→ 去重同一导入任务内的 filename + size + mediaType
→ 指定 targetProjectID
→ 保存到 Seller Camera 自有 Application Support 目录
→ photo 生成缩略图
→ video 跳过缩略图并保留 durationSeconds
→ 写入 metadata
→ 刷新项目统计和资产库 UI
```

导入失败规则：

- 单项失败不取消整批；
- 批量结果返回 requested / succeeded / failed；
- 同一系统回调内重复项不会重复写入；
- 不长期依赖系统相册原始引用。

## 8. 删除与回收站

P1C 实现资产回收站：

- `ProjectAsset.deletionState == .trashed` 表示软删除；
- `ProjectAsset.isDeleted` 保留为 legacy 兼容字段；
- `deletedAt` 记录删除时间；
- `ProductProject.isArchived` 表示项目归档；
- 软删除不移动或删除原图 / 缩略图；
- 默认资产列表、分类筛选和分类计数只统计 active 资产；
- 回收站筛选只展示 trashed / legacy deleted 资产；
- 恢复后恢复原分类、统计和筛选结果；
- 清空回收站只处理当前项目，不跨项目删除。

永久删除规则：

```text
校验 active 派生资产
→ 移除 asset metadata
→ 删除原图文件
→ 删除缩略图文件
→ 清理封面引用
→ 刷新统计
```

存在 active 派生资产时，父资产永久删除被阻止；用户需先处理派生版本。P1C 不创建真实精修版本，但保留 `parentAssetID`、`rootAssetID`、`versionNumber`、`assetRole` 和 `processingState` 以支持后续版本链。

## 9. 项目封面

设为封面时必须满足：

- 资产属于该项目；
- 资产为 active；
- 资产未删除；
- `mediaType == photo`。

当前封面删除到回收站或永久删除时，自动选择新封面：

```text
最佳标准图
→ 标准图
→ SKU 图
→ 细节图
→ nil
```

恢复旧封面资产不会自动抢回封面，避免覆盖用户在删除期间形成的新选择。

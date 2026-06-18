# Product Asset Storage

日期：2026-06-18
阶段：P1A Product Workspace Foundation

## 1. 存储原则

- 原始资产永不覆盖。
- 缩略图、processed、export 不替代原图。
- 元数据只保存相对路径和基础字段。
- 数据库 / metadata 不保存图片二进制。
- 文件名使用 asset UUID，不使用项目名或时间戳作为唯一 ID。
- 路径拼接统一由 `ProjectFileStore` 完成。

## 2. Application Support 根目录

P1A 使用 Application Support：

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

`ProjectFileStore.createProjectDirectories(projectID:)` 会统一创建上述项目目录。重复创建不报错。

## 3. 原图目录

按 `CaptureCategory` 存储：

```text
{projectID}/originals/standard/{assetID}.jpg|heic|dng
{projectID}/originals/detail/{assetID}.jpg|heic|dng
{projectID}/originals/video/{assetID}.jpg|heic|dng
```

P1A 实际完整支持 `photo + camera`。`video` 目录为 schema 与未来视频资产预留，不代表 P1A 已完成视频功能。

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

## 5. processed 与 exports

P1A 只创建目录，不写入 processed/export 资产：

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

P1A 写入顺序：

```text
ensure current project
→ create assetID
→ save original atomically
→ generate thumbnail
→ save thumbnail atomically
→ create metadata
→ update project cover / updatedAt
```

失败规则：

- 原图写入失败：不创建资产记录。
- 缩略图失败：原图仍可入库，thumbnail path 为空。
- metadata 写入失败：清理本轮已写入的原图和缩略图。
- 归档失败：相机拍照结果仍保留在现有最新照片链路，不崩溃。

## 8. 删除与回收站预留

P1A 不实现项目删除 UI。

预留规则：

- `ProjectAsset.isDeleted` 表示逻辑删除；
- `ProductProject.isArchived` 表示项目归档；
- 未来回收站可先逻辑删除，再由后台回收器清理文件；
- 永久删除必须同时清理 metadata 和项目文件目录。

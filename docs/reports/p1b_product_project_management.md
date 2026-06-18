# P1B Product Project Management 报告

日期：2026-06-18

## 1. 任务定位

P1B 在 P1A Product Workspace Foundation 之上，把商品项目从后台归档对象提升为相机主界面的明确工作上下文。

本轮完成链路：

```text
创建项目
→ 设为当前项目
→ 选择标准 / 细节 / SKU
→ 拍摄
→ 归档到当前项目对应分类
→ 分类数量刷新
→ 工作台查看项目与资产
→ 切换 / 重命名 / 归档 / 恢复项目
```

本轮没有修改镜头、曝光、白平衡、对焦、稳定器、比例、像素、RAW 或拍照底层行为。

## 2. 主界面入口变更

- 左下角入口由“照片”改为“工作台”，图标为 `square.grid.2x2`。
- 右下角入口改为“我的”，图标为 `person.crop.circle`。
- 顶部第一排新增项目胶囊，位于闪光灯 / 比例像素与后摄 / 更多之间的视觉中心。
- 无当前项目时项目胶囊显示“＋ 项目”，点击打开快速创建项目 Sheet。
- 有当前项目时显示项目名称、文件夹图标与 `chevron.down`，点击打开项目快捷面板。

项目切换只更新 Product Workspace 状态和分类计数，不调用相机 session rebuild，不改 lens / parameter / capture format 状态。

## 3. 拍摄分类变更

P1B 将拍摄分类从：

```text
标准 / 细节 / 白底
```

调整为：

```text
标准 / 细节 / SKU
```

对应 Domain：

- `standard`
- `detail`
- `sku`

白底图继续保留为拍后处理 / generated asset 分支，不再作为原始拍摄分类。P1B 的 SKU 只表示 SKU 差异图片采集分类，不表示完整 SKU 实体、SKU 编辑器或 SKU 与图片绑定系统。

## 4. 分类计数来源

分类计数来自 `ProductWorkspaceJSONRepository.counts(projectID:)`，统计有效且未删除的 `ProjectAsset` metadata：

- `standard`
- `detail`
- `sku`
- `video`

相机 UI 通过 `ProductWorkspaceSession.currentCounts` 订阅，不扫描磁盘目录，不根据图片写入成功盲目加数。只有 metadata 写入成功后，归档服务才返回更新后的计数。

## 5. 数据模型与迁移

本轮新增 / 调整：

- `CaptureCategory.sku`
- `ProductAssetCounts.sku`
- `ProductProject.lastSelectedCaptureCategory`
- `ProjectAsset.mediaType`
- `ProjectAsset.originalFilename`
- `ProjectAsset.skuID`
- `CurrentProjectSummary`

兼容策略：

- 旧 `whiteBackground` / `white` / `white_background` 分类读取时映射到 `sku`。
- P1A 未真实生产白底原始采集分类，因此本轮不保留独立 legacy category。
- 旧 metadata 的 `assetType` 读取时映射到新 `mediaType`。
- 项目目录继续使用稳定 `projectID`，重命名不重命名目录。

## 6. 项目管理闭环

已完成：

- 创建项目后自动成为当前项目。
- 无当前项目时优先恢复最近未归档项目，不存在时才创建默认项目。
- 默认项目使用 `商品项目 yyyy-MM-dd 001` 序列，不重复创建。
- 切换项目后分类计数立即切换。
- 每个项目保存 `lastSelectedCaptureCategory`，切换项目后恢复各自上次分类。
- 重命名同步 metadata、项目列表、详情页和顶部项目胶囊。
- 归档项目隐藏于默认项目列表，文件与 metadata 保留。
- 归档当前项目时自动切换到最近未归档项目；若没有则创建默认项目。
- 已归档项目可恢复。

## 7. 工作台与我的页面

工作台首版：

- `项目`：项目列表、搜索、当前项目标记、归档筛选、项目卡片、详情页。
- `图片`：全部 / 标准 / 细节 / SKU / 视频筛选，项目筛选，单张系统相册导入，大图预览，设为封面。

我的页首版只提供静态导航骨架：

- 账户
- 订阅与服务
- 设置
- 支持

本轮未接入登录、支付、订阅、云同步、团队、AI 费用或后端。

## 8. 日志

Debug 日志补充：

- `[Project] project created`
- `[Project] current project changed`
- `[Project] project archived`
- `[CaptureCategory] selected ...`
- `[AssetArchive] archive started`
- `[AssetArchive] archive succeeded`
- `[AssetArchive] archive failed`
- `[ProjectStats] counts updated`

日志包含 `projectID`、`assetID`、`category`、`relativePath`、`duration` 或错误信息，不输出用户商业敏感内容。

## 9. 验证结果

### CLI Build

命令：

```sh
xcodebuild -project SellerCamera.xcodeproj \
  -scheme SellerCamera \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/SellerCameraP1BBuild \
  CODE_SIGNING_ALLOWED=NO \
  build
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
  -derivedDataPath /tmp/SellerCameraP1BTest \
  CODE_SIGNING_ALLOWED=NO
```

结果：

```text
Executed 12 tests, with 0 failures
```

覆盖：

- 创建项目后成为当前项目。
- 自动名称不重复。
- 标准 / 细节 / SKU 统计更新。
- 项目切换后统计隔离。
- 最后当前项目恢复。
- 每项目最后分类恢复。
- 项目归档与恢复。
- 旧白底分类读取迁移到 SKU。
- 默认项目不重复创建。
- 重命名与 summary 计数同步。

### 真机验证

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
  -derivedDataPath /tmp/SellerCameraP1BDeviceBuild \
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
  /tmp/SellerCameraP1BDeviceBuild/Build/Products/Debug-iphoneos/SellerCamera.app
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
PID: 16622
```

Codex 本轮确认 build / install / launch / process created。用户已在 iPhone 14 Pro Max 真机补验 P1B 项目与相机回归矩阵：

- 测试设备：iPhone 14 Pro Max。
- 项目 A / B 创建与切换：通过。
- 标准 / 细节 / SKU 计数：通过。
- 重启恢复：通过。
- 归档恢复：通过。
- 镜头和参数回归：通过。

## 10. 已知限制

- SKU 只是拍摄分类，不含完整 SKU 实体、规格编辑器或 SKU 图片绑定。
- 图片页提供基础筛选、单张系统相册导入与设封面，未实现批量导入、删除或回收站。
- “我的”页是静态骨架，未接入登录、订阅、云空间、AI 费用或支付。
- 工作台视觉为 P1B 首版可操作结构，未做最终视觉精修。
- P1B 真机手动矩阵已补验通过，后续 P1C 将在此基础上扩展资产库生命周期。

## 11. 代码边界声明

本轮仅接入 Product Workspace 项目管理与分类归档 UI，不修改相机底层采集、镜头、参数、稳定器、比例、像素和白底处理主链路。

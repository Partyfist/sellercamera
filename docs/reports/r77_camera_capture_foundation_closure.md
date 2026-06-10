# R77 拍照基础体验收口报告

## 1. 改动摘要

R77 聚焦拍照基础体验，不进入 AI 套图、白底处理或参数系统重构。本轮完成三项最小收口：

- 点击取景区对焦改为即时进入 `focusing` 状态，并在短延迟后根据设备对焦状态收敛到 `focused` 或 `warning`。
- 拍照成功后不再弹出左下快速预览 overlay，用户停留在取景界面继续拍摄；最近照片入口仍由 `latestStillPhotoResult` 更新。
- 像素预设新增“最佳质量”和 RAW 入口；“最佳”不再按固定长边压缩，RAW 入口基于设备能力探测，不支持时禁用，不影响普通拍摄。

## 2. 文件清单

- `SellerCamera/CaptureLivePreviewView.swift`
  - 扩展点击对焦 marker 状态；
  - 增加点击对焦节流、settle / timeout 反馈；
  - 点击对焦时保护 AE-L、AEAF-L、MF、手动 ISO / Shutter；
  - 取消拍后 quick preview overlay；
  - 增加“最佳 / RAW”像素 preset、RAW 能力探测与最佳质量输出策略。
- `SellerCamera/CaptureScreen.swift`
  - 顶部像素菜单接入“最佳 / RAW”；
  - RAW 不支持时灰置；
  - Pixel 参数面板补充最佳 / RAW 文案。
- `docs/reports/r77_camera_capture_foundation_closure.md`
  - 本报告。
- `README.md`
  - 增加 R77 报告索引。

## 3. 点击对焦优化

点击取景区后，UI 立即显示对焦框并进入 `focusing`。对焦写入继续走现有 `applyFocusExposure(...)`，不新增绕过 runtime guard 的独立 AF 路径。

本次对焦状态分层：

- `focusing`：点击后立即显示，表示正在对焦 / 测光。
- `focused`：短延迟后设备不再 `isAdjustingFocus` 时显示。
- `warning`：timeout 后仍未稳定时显示，并提示“增加光线或稍微远离商品”。
- `locked`：AEAF-L 或 MF 阻断时使用。

对焦策略保持低风险：

- 点击时设置 `focusPointOfInterest`；
- 非 AE-L 情况同步设置 `exposurePointOfInterest`；
- 点击 AF 优先使用 `.autoFocus`；
- 支持时关闭 smooth AF，以减少商品近距点击对焦的拖泥带水；
- 增加 0.28s 点击节流，避免连续点击造成状态拥堵；
- 保留 R76 商品清晰度辅助的一次性 AF 路径。

## 4. 手动与锁定保护

点击对焦不会破坏以下语义：

- AEAF-L：点击只提示锁定，不改对焦；
- AE-L：允许更新对焦点，但保持 AE-L；
- MF：点击不抢回 AF；
- 手动 ISO：点击对焦时保留 custom exposure 写入；
- 手动 Shutter：点击对焦时保留 custom shutter 写入；
- ISO + Shutter 全手动：新增 full-manual exposure 保持路径，避免点击对焦把两者重置回 Auto。

## 5. 拍后流程减负

拍照成功后：

- 不再调用 `showQuickPreview(...)`；
- 不再显示“拍后快速预览”overlay；
- 保持取景界面可继续拍摄；
- `latestStillPhotoResult` 仍更新，左下最近照片缩略图继续可用；
- 点击左下最近照片仍进入原 Review / Generate / Save 复核能力；
- 保留轻量 haptic 与“拍摄成功，可继续拍摄”提示。

## 6. 最佳 / RAW 像素预设

新增像素 preset：

- `best`：最佳质量，不按固定长边压缩；仍尊重当前比例 preset 做必要裁切。
- `raw`：RAW 入口，基于 `AVCapturePhotoOutput.availableRawPhotoPixelFormatTypes` 探测能力。

RAW 本轮按低风险策略接入：

- 支持设备显示并允许选择 RAW；
- 不支持设备显示 `RAW（不可用）` 并禁用；
- 选择 RAW 时保留最佳 JPEG/HEIF 预览链路；
- metadata 标记 `capture_raw_requested=true` 与 `capture_raw_file_saved=false`；
- RAW 文件保存完整闭环未在 R77 硬做，避免影响普通拍摄与最近照片预览。

普通像素 preset 保持：

- 800；
- 1200；
- 1600；
- 2400。

## 7. 功能合同保护

本轮没有改动：

- Auto EV / Auto WB 阈值与写入逻辑；
- ISO / Shutter / WB / EV / MF 参数表盘手感；
- Lens zoom 逻辑；
- R76 商品清晰度检测算法；
- 白底处理；
- Review / Compare / Generate / Save；
- 相册导入 / 保存主链路。

## 8. 构建与运行验证

已执行：

```bash
xcodebuild -scheme SellerCamera -project SellerCamera.xcodeproj -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/SellerCameraR77Build CODE_SIGNING_ALLOWED=NO clean build
```

结果：

- `BUILD SUCCEEDED`
- 构建期间仍有既有的嵌套 `SellerCamera/SellerCamera.xcodeproj` 缺少 `project.pbxproj` 提示，但实际根工程 target 构建成功。

真机运行：

- 本轮未执行真机安装 / 实拍验证。
- 点击对焦响应、近距文字清晰度、RAW 能力显示与连续拍摄体验仍需真机复核。

## 9. 风险与后续建议

风险：

- `focused / warning` 目前基于设备 `isAdjustingFocus` 的轻量判断，真机上仍需观察近距商品是否足够准确。
- RAW 本轮是能力探测与入口，不是完整 RAW 文件保存闭环。
- “最佳”仍会按比例 preset 裁切；若后续需要“完全原始未裁切素材”，应单独增加“原始比例/原始像素”合同。

建议下一轮最小任务包：

- R77A：真机验证点击对焦速度、近距文字清晰度、最佳/RAW 入口显示与连续拍摄体验；
- 若 RAW 需求确认优先级高，再单独做 RAW 文件保存闭环，避免和普通拍摄链路耦合。

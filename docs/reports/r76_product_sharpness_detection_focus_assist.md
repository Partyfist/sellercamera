# R76 商品清晰度检测与对焦辅助 1.0 报告

## 1. 改动摘要

- 新增 `ProductSharpnessAnalyzer`，在现有 preview downsample 链路中计算中心 ROI 清晰度指标。
- `CaptureLivePreviewView` 接入 sharpness metrics、连续命中判断、低频 Debug 日志与一次性 AF 辅助。
- `CaptureScreen` 在 MF ruler 打开 / 关闭时通知 runtime 暂停 / 恢复 Focus Assist，避免 MF UI 打开但 runtime 仍为 AF 时被自动辅助抢焦。
- 本轮未新增 video output，未改 Auto EV / Auto WB 阈值，未改 ISO / Shutter / WB / Lens / 白底 / 拍后链路。

## 2. 文件清单

- `SellerCamera/ProductSharpnessAnalyzer.swift`
  - 新增清晰度状态、metrics 结构与中心 ROI 梯度分析逻辑。
- `SellerCamera/CaptureLivePreviewView.swift`
  - 复用 preview frame analysis 输出 sharpness metrics。
  - 新增连续 blurry / sharp 命中、低频提示、一次性 AF 辅助与保护条件。
  - 新增 `[ProductSharpness]` 日志，并扩展 `[ProductAutoScene] Focus(...)` 摘要。
- `SellerCamera/CaptureScreen.swift`
  - 在 MF 模式开关和锁定状态变化时同步 Focus Assist 手动抑制状态。
- `docs/reports/r76_product_sharpness_detection_focus_assist.md`
  - 本轮实现与验证报告。
- `README.md`
  - 增加 R76 报告索引。

## 3. 清晰度检测设计

- 输入：现有 BGRA preview sample buffer 的低频 downsample luma grid。
- 输出：`sharpnessScore`、`edgeDensity`、`confidence`、`state`、`reason`。
- 状态：
  - `sharp`
  - `slightlySoft`
  - `blurry`
  - `lowConfidence`
- 模块职责限定为分析与判断，不直接操作 `AVCaptureDevice`。

## 4. ROI 与指标计算

- ROI：中心约 62% 宽高区域，贴合当前商品通常位于画面中心的第一版假设。
- 指标：
  - 使用 luma 左右 / 上下差分估算边缘梯度。
  - `sharpnessScore` 为 ROI 平均梯度强度。
  - `edgeDensity` 为超过边缘阈值的像素比例。
  - `confidence` 综合 edge density、ROI contrast 与 sharpness score。
- 性能：
  - 复用 EV / WB 已有 downsample 遍历。
  - 不新增 full-resolution 处理。
  - 不在主线程遍历像素。

## 5. blurry / sharp / lowConfidence 判定规则

- `lowConfidence`：
  - 样本不足；
  - 画面过暗；
  - 高光 / clipped 面积过高；
  - 中心 ROI 纹理过低；
  - confidence 低于阈值。
- `sharp`：
  - sharpness score 与 edge density 均达到较高阈值。
- `slightlySoft`：
  - 指标处于中间区间。
- `blurry`：
  - confidence 足够但 sharpness score / edge density 低。
- 连续命中：
  - 连续 3 次 blurry 后才提示或尝试辅助 AF。
  - 连续 3 次 sharp 后确认清晰并结束当前 blur episode。
  - lowConfidence 不触发 AF。

## 6. 一次性 AF 辅助策略

- 触发条件：
  - 连续 blurry 命中；
  - confidence 足够；
  - 当前不在 MF；
  - 当前不在 AE-L / AEAF-L；
  - 当前不在拍摄、切镜头、倒计时、连拍或复核受限状态；
  - 距离用户点击对焦 / 手动 MF 足够久；
  - 距离上一次商品 Focus Assist 超过 7 秒；
  - 当前 blur episode 尚未触发过辅助 AF。
- AF 入口：
  - 复用现有 `applyFocusExposure(...)`，以中心点 `(0.5, 0.5)` 做一次轻量 AF。
  - 新增内部 source：`productAutoFocus`，用于区分提示文案。
- 连续触发保护：
  - 一个 blur episode 只触发一次。
  - 如果仍模糊，继续轻提示，不反复抽焦。

## 7. 手动 MF / 点击对焦 / LOCK 保护

- MF：
  - MF ruler 打开时 runtime 进入 Focus Assist manual suppression。
  - 用户拖动 MF 会刷新 manual cooldown，并清空 blurry hit。
  - MF 状态下只检测清晰度，不触发 AF。
- 点击对焦：
  - 用户点击 / 长按预览会刷新 focus cooldown。
  - cooldown 内不触发商品 Focus Assist。
- AE-L / AEAF-L：
  - `isExposureLocked` 或 `isFocusExposureLocked` 时不触发 AF。
- 拍摄中 / 切镜头：
  - 复用 `isPreviewInteractionTemporarilyRestricted` 与 `isSwitchingCamera` 保护。

## 8. 与 Auto EV / Auto WB 的共存关系

- Auto EV：
  - 未改 EV optimizer、阈值、写入路径或手动接管逻辑。
- Auto WB：
  - 未改 WB optimizer、Kelvin 写入路径或手动接管逻辑。
- Preview analysis：
  - EV / WB / Focus metrics 共用同一次 downsample。
  - 不新增第二条 `AVCaptureVideoDataOutput`。
- 状态隔离：
  - Focus Assist 不改 ISO / Shutter / WB / Lens。
  - Focus Assist 不改白底或拍后流程。

## 9. UI 状态与 Debug 日志

- UI：
  - 清晰时不打扰。
  - 略虚时只更新内部状态。
  - 连续明显虚焦时复用现有 `captureHintText` 显示：`商品可能未对焦，建议重新对焦`。
  - 正在辅助时显示：`已辅助对焦，继续观察商品清晰度`。
- Debug：
  - 新增 `[ProductSharpness] score=... edge=... conf=... state=... reason=... blurHit=... sharpHit=... autoAF=... cooldown=...`
  - 扩展 `[ProductAutoScene] Focus(state=..., score=..., edge=..., conf=..., reason=...)`
  - 日志节流为约 1 秒一次。

## 10. 性能与线程处理

- 清晰度计算在 `videoAnalysisQueue` 上完成。
- 主线程只接收 metrics、更新状态与必要提示。
- 未新增 video output。
- 未增加全分辨率图像处理。
- AF 辅助最多一次 / blur episode，避免频繁 lockForConfiguration。

## 11. 构建与运行验证

- `git status`：执行，工作区包含 R76 预期改动。
- `xcodebuild`：通过。
  - 命令：`xcodebuild -scheme SellerCamera -project SellerCamera.xcodeproj -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/SellerCameraR76Build CODE_SIGNING_ALLOWED=NO clean build`
  - 结果：`BUILD SUCCEEDED`
- 真机构建：通过。
  - 设备：iPhone 14 Pro Max（`E7D43088-7946-5FDB-BB14-E38124BB37DB`）
  - 命令：`xcodebuild -scheme SellerCamera -project SellerCamera.xcodeproj -configuration Debug -destination 'id=E7D43088-7946-5FDB-BB14-E38124BB37DB' -derivedDataPath /tmp/SellerCameraR76DeviceBuild build`
  - 结果：`BUILD SUCCEEDED`
- 真机安装 / 启动：通过。
  - 安装：`xcrun devicectl device install app --device E7D43088-7946-5FDB-BB14-E38124BB37DB /tmp/SellerCameraR76DeviceBuild/Build/Products/Debug-iphoneos/SellerCamera.app`
  - 启动：`xcrun devicectl device process launch --device E7D43088-7946-5FDB-BB14-E38124BB37DB com.partyfist.SellerCamera`
- 真机场景验证：未完成清晰 / 虚焦样本观察；当前 `devicectl` 不提供直接日志流子命令，本轮未采集到 `[ProductSharpness]` 日志。仍需在 Xcode console 或设备日志中复核 `[ProductSharpness]`、虚焦提示、一次性 AF cooldown、MF / 点击对焦 / LOCK 保护。

## 12. 风险与后续建议

- 第一版使用中心 ROI，不具备主体识别能力；边缘商品或偏离中心的商品可能需要后续结合构图框 / 主体区域改进。
- 清晰度阈值为保守初版，需要真机固定样本校准。
- 低纹理商品会进入 lowConfidence，避免乱报虚焦，但也可能降低提示覆盖率。
- 后续最小增量建议：R76A 固定样本真机阈值校准，覆盖清晰商品、故意虚焦、纯白背景、低纹理商品和反光商品。

# R77F ProductAutoScene 真机指标校准与自动拍摄策略收口报告

## 1. 改动摘要

R77F 在 R77E 采样可信度修复基础上，完成了一轮真机构建、安装、启动和低频日志复核。日志确认 ProductAutoScene 的有效帧已经从“长期假黑”恢复为真实 preview frame 指标：有效帧为 `32BGRA 1720x1290`，中心 ROI 有 `1296` 个有效采样点，Auto EV / Auto WB / Sharpness 均能得到非零指标。

本轮没有调整 Auto EV / Auto WB / Sharpness 业务阈值，只做两个采样与诊断层小修：

- 将 ProductAutoScene session warmup 窗口从 0.6s 收口为常量 `1.2s`，吞掉启动后的残余黑帧。
- 增加 near-black probe guard：前 2 个近黑分析帧先跳过；若持续近黑，则作为真实暗场放行给 `tooDark` / `darkSceneLift` 判断。
- 将 Auto WB 不可用状态拆分为 `系统Auto` 与 `设备Gains`，便于区分“没有白点”和“当前设备/虚拟镜头不支持 custom gains 写入”。

## 2. 文件清单

- `SellerCamera/CaptureLivePreviewView.swift`
  - 新增 `productAutoSceneSessionWarmupInterval`。
  - 新增 near-black probe streak guard。
  - 细化 Auto WB availability 日志状态。
- `docs/reports/r77f_product_auto_scene_metrics_calibration.md`
  - 新增本报告。
- `README.md`
  - 增加 R77F 报告索引。

## 3. 真机验证环境

- 设备：iPhone 14 Pro Max
- 设备标识：`E7D43088-7946-5FDB-BB14-E38124BB37DB`
- 构建：Debug / iPhoneOS / 真机签名构建
- 安装：通过 `xcrun devicectl device install app`
- 启动：通过 `xcrun devicectl device process launch --console`
- 说明：CLI 可完成构建、安装、启动和日志采集；无法替代真人手势完成 zoom ruler 拖动、点击对焦与 macro fallback 场景，因此这些交互项保留为真机人工待复核。

## 4. R77E 后现状复核

R77E 后真机有效帧日志示例：

- `[ProductAutoSceneFrame] format=32BGRA rawFormat=1111970369 width=1720 height=1290 planes=0 bytesPerRow=6912`
- `[ProductAutoSceneROI] normalized=x:0.20,y:0.20,w:0.60,h:0.60 pixel=x:344,y:258,w:1032,h:774 valid=1296 skipped=0 sampled=1296`

这说明当前分析数据来自真实 `AVCaptureVideoDataOutput` sample buffer，ROI 尺寸有效，采样点不为 0。R77E 的 BGRA 解析路径在当前设备上生效。

## 5. 正常亮场指标复核

启动后有效日志中，Auto EV 不再长期维持假黑值：

- `mean=0.276...0.343`
- `shadow=0.360...0.628`
- `highlight=0.000...0.002`
- `clipped=0.000...0.001`

ProductSharpness 也恢复为非零且可用：

- `score=16.75...26.30`
- `edge=0.576...0.715`
- `state=sharp`
- `reason=sharpEdges`

结论：正常 preview frame 指标已恢复可信；不再表现为长期 `mean≈0.005 / shadow=1.000 / score=0`。

## 6. 白底 / WB 指标复核

日志中 Auto WB 已能获得非零 near-white 与 RGB/Y：

- `whiteCount=131...312`
- `whiteRatio=0.101...0.241`
- `R=0.640...0.766`
- `G=0.632...0.727`
- `B=0.583...0.643`
- `Y=0.630...0.730`
- `confidence=0.63...1.00`

这说明 R77E 后 WB metrics 数据源已可信，不是 RGB/Y 全 0。

当前真机日志同时显示：

- `status=商品 WB 不可用 · 设备Gains`

因此本轮判断为：WB 采样有效，但当前 active device / virtual multi-camera path 对 custom device gains 写入不可用或被系统能力限制。本轮不绕过该能力边界。

## 7. zoom / lens unstable guard 验收

本轮 CLI 启动日志确认 session warmup guard 生效：

- `[ProductAutoSceneFrameGuard] skipped reason=sessionWarmup ...`

R77F 后启动阶段会跳过 warmup 帧，并且 near-black probe 会额外跳过前两个近黑分析帧。由于 CLI 无法进行焦段按钮点击、ruler 拖动或 switch-over 人工手势，本轮未完成以下实操日志复核：

- 24mm -> 48mm -> 77mm 按钮切换期间的 guard。
- lens ruler 拖动期间的 guard。
- switch-over 区间 guard。

这些需要在真机上人工操作并观察 `[ProductAutoSceneFrameGuard] reason=unstableLensState:*`。

## 8. macro fallback 验收

本轮 CLI 无法替代用户近距点击对焦，因此未实操 macro fallback。代码路径保持 R77E 设计：

- `lastCloseFocusFallbackAt` 后 0.6s 内 ProductAutoScene 跳过分析。
- fallback 期间不会向 Auto EV / Auto WB / Sharpness 传入假黑指标。

待真机人工复核：

- 近距包装文字点击对焦触发 fallback 时是否输出 `[CaptureLensMacroFallback]`。
- fallback 期间是否出现 `reason=unstableLensState:macroFallback`。
- fallback 完成后 Sharpness 是否恢复为非零指标。

## 9. 本次最小修复

### 9.1 session warmup 收口

将 warmup 从硬编码 `0.6s` 调整为常量：

- `productAutoSceneSessionWarmupInterval = 1.2s`

原因：R77F 首次真机日志显示，0.6s 后仍可能出现一帧残余黑帧，并触发 `darkSceneLift`。

### 9.2 near-black probe guard

新增规则：

- 若 `meanLuma < 0.015`
- 且 `shadowRatio > 0.985`
- 且 `highlightRatio == 0`
- 且 `clippedRatio == 0`
- 且 `nearWhiteRatio == 0`

则判定为 near-black probe frame。前 2 个连续 near-black frame 跳过；若持续近黑，则放行给真实暗场逻辑。

这可以区分启动/过渡黑帧与真实 `tooDark`，避免用业务阈值掩盖采样问题。

### 9.3 WB 不可用诊断细化

Auto WB 不可用现在区分：

- `商品 WB 不可用 · 系统Auto`
- `商品 WB 不可用 · 设备Gains`

本轮真机日志显示为 `设备Gains`，说明 WB metrics 有效，但 custom gains 写入能力不可用。

## 10. Debug 日志复核

本轮确认以下日志可用于定位：

- `[ProductAutoSceneFrameGuard]`
- `[ProductAutoSceneFrame]`
- `[ProductAutoSceneROI]`
- `[ProductAutoExposure]`
- `[ProductAutoWB]`
- `[ProductSharpness]`
- `[CaptureLensZoom]`

当前日志频率保持约 1s 摘要输出，不做更高频刷屏。

## 11. 影响范围

本轮未改变：

- Auto EV 阈值与写入策略。
- Auto WB near-white / warm / cool 阈值。
- Sharpness 判定阈值与 AF 辅助策略。
- 参数入口。
- zoom ruler 手感。
- 稳定器设置。
- 拍照、最近照片、白底与拍后流程。

## 12. 构建与运行验证

- `git status`：执行前为 `main...origin/main [ahead 14]`。
- 真机设备发现：`xcrun devicectl list devices` 检测到 iPhone 14 Pro Max connected。
- 真机构建：`xcodebuild -scheme SellerCamera -project SellerCamera.xcodeproj -configuration Debug -destination 'id=E7D43088-7946-5FDB-BB14-E38124BB37DB' -derivedDataPath /tmp/SellerCameraR77FDeviceBuild build`
  - 结果：`BUILD SUCCEEDED`
- 真机安装：`xcrun devicectl device install app ...`
  - 结果：安装成功，bundleID `com.partyfist.SellerCamera`
- 真机启动日志：`xcrun devicectl device process launch --console --timeout ...`
  - 结果：成功捕获 ProductAutoScene / EV / WB / Sharpness 日志。
  - 命令以 timeout 结束，因为 App 正常常驻前台，不代表 App 崩溃。
- generic iOS 构建：`xcodebuild -scheme SellerCamera -project SellerCamera.xcodeproj -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/SellerCameraR77FBuild CODE_SIGNING_ALLOWED=NO clean build`
  - 结果：`BUILD SUCCEEDED`

## 13. 风险与后续建议

- 需要人工真机完成四类场景：正常亮场、白底、zoom 切换、近距 macro fallback。
- 当前 active virtual camera path 下 Auto WB custom gains 写入显示不可用；后续如需恢复 Auto WB 写入，需要单独调查虚拟多摄与 `isLockingWhiteBalanceWithCustomDeviceGainsSupported` 的关系，不能在 R77F 中绕过。
- EV 当前在偏暗场景仍会进入 `darkSceneLift`，但这是有效 frame 下的业务判断，不属于假黑采样问题。本轮不调阈值。

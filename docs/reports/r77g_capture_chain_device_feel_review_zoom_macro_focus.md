# R77G 拍摄链路真机手感复核报告

## 1. 改动摘要

R77G 对 R77F 之后的拍摄链路进行真机可执行范围内的复核，重点覆盖 ProductAutoScene 指标是否保持可信、virtual multi-camera 启动链路、稳定器配置、zoom / macro / focus 相关日志入口与当前 tuning 参数。

本轮没有做新功能，也没有在缺少人工手势日志的情况下盲目调整 zoom / macro / stabilizer 参数。CLI 已完成真机构建、安装、启动与日志采集；焦段按钮点击、lens ruler 拖动、近距点击对焦、稳定器三档拍照响应属于必须手持设备操作的项目，本轮记录为人工真机待复核项。

## 2. 文件清单

- `docs/reports/r77g_capture_chain_device_feel_review_zoom_macro_focus.md`
  - 新增 R77G 真机手感复核报告。
- `README.md`
  - 增加 R77G 报告索引。

本轮未修改业务代码。

## 3. 真机验证环境

- 设备：iPhone 14 Pro Max
- 设备标识：`E7D43088-7946-5FDB-BB14-E38124BB37DB`
- 状态：connected
- 构建方式：Debug / iPhoneOS / 真机签名构建
- 安装方式：`xcrun devicectl device install app`
- 启动方式：`xcrun devicectl device process launch --console`

已确认：

- 真机构建通过。
- 真机安装成功。
- 真机启动成功。
- 控制台可采集 `[CaptureLensDevice]`、`[CaptureLensZoom]`、`[CaptureStabilizer]`、`[ProductAutoSceneFrameGuard]`、`[ProductAutoScene]`、`[ProductAutoExposure]`、`[ProductAutoWB]`、`[ProductSharpness]`。

## 4. 焦段按钮复核

CLI 启动阶段确认当前后置设备策略为：

- activeDevice：Back Triple Camera
- deviceType：`AVCaptureDeviceTypeBuiltInTripleCamera`
- virtualSwitchOver：`[2.00, 6.00]`
- minZoom：`1.00`
- maxZoom：`189.00`
- 默认 UI 焦段：24mm

启动时可见：

- `[CaptureLensZoom] reason=semanticFocal:24mm ... target=1.00 actual=1.00 ramped=false`

未完成项：

- 24 -> 48
- 48 -> 77
- 77 -> 24
- 24 -> 13

原因：CLI 无法直接替代用户在真机上点击取景页焦段按钮。需要人工手持设备执行，观察是否有黑屏、跳变、卡顿和明显重置对焦。

本轮未调整 `lensZoomRampRate`，当前值保持：

- `lensZoomRampRate = 7.0`

## 5. Lens ruler 拖动复核

当前 lens ruler tuning：

- `tickSpacing = 34`
- `normalSensitivity = 3.0`
- `fineSensitivity = 0.90`
- `ultraFineSensitivity = 0.38`
- `pointsPerZoomCommon = 96`
- `pointsPerZoomHigh = 172`
- `smoothingPreviousWeight = 0.34`
- `dragSnapThreshold = 0.016`
- `settleSnapThreshold = 0.075`
- `emitDelta = 0.005`
- `maxInertiaDelta = 38`
- `inertiaScale = 0.22`
- device write interval：`1 / 30s`

当前 runtime 策略：

- 焦段按钮：继续使用 ramp。
- ruler 拖动：使用节流后的直接 `videoZoomFactor` 写入。
- switch-over 附近：使用 hysteresis 保护。

未完成人工复核：

- 慢拖 24 -> 48。
- 普通拖 24 -> 77。
- 快拖 13 -> 77。
- 松手靠近 48 / 77 锚点 settle。

本轮未调整 sensitivity / smoothing / inertia，因为没有人工拖动日志证明偏慢、过快或卡顿。

## 6. Switch-over hysteresis 复核

当前 switch-over guard：

- `lensRulerSwitchOverHysteresis = 0.022`
- virtual switch-over factors：`[2.00, 6.00]`

CLI 启动只确认设备公开的 switch-over 区间存在，未能覆盖人工在 1x / 2x / 3x 附近反复拖动。

待人工复核：

- 2x 附近是否被卡住。
- 2x 附近是否来回跳。
- 3x 附近是否正常跨越。

本轮未调整 hysteresis。若后续真机显示“卡住”，建议收紧到 `0.015...0.018`；若显示“来回跳”，建议略增到 `0.026...0.030`，但必须基于日志而非猜测。

## 7. 近距 macro fallback 复核

当前 macro fallback 保护：

- MF 下不触发。
- AEAF-L / AE-L 下不触发。
- 手动 77mm 下不触发。
- 拍摄受限或切镜中不触发。
- cooldown：`5.0s`
- fallback target：virtual / ultra wide 可用时回到稳定 `1.0x`
- fallback delay：`0.22s`

R77F 已确认 ProductSharpness 在有效画面下不再长期 `score=0`，可为近距清晰度判断提供可信指标。

未完成人工复核：

- 包装文字近距点击对焦。
- 触发 `[CaptureLensMacroFallback]` 后是否改善文字 / 边缘清晰度。
- fallback 期间是否输出 `[ProductAutoSceneFrameGuard] reason=unstableLensState:macroFallback`。

本轮未调整 close-focus timeout 或 fallback 条件，因为缺少近距点击对焦样本。

## 8. 稳定器三档复核

当前稳定器设置：

- 关闭：`off`，拍照前等待 `0ms`
- 标准：`auto`，拍照前最多等待 `200ms`
- 增强：`cinematic` 优先，拍照前最多等待 `450ms`

真机启动日志确认：

- video stabilization supported
- requested standard mode
- connection 接受 stabilization 配置

未完成人工复核：

- 标准档是否明显拖慢拍摄。
- 增强档是否等待过长。
- 刚拖动 zoom 后拍照是否更稳。

本轮未将增强档从 450ms 收到 300-350ms，因为缺少拍照响应实测。

## 9. ProductAutoScene 回归复核

R77F 真机日志已确认 ProductAutoScene 不再长期假黑：

- 有效 frame：`32BGRA 1720x1290`
- ROI：中心 60%，`valid=1296`
- AutoExposure：`mean` 恢复到约 `0.23...0.34`，不再长期 `0.005`
- AutoWB：`whiteCount / RGB / Y` 非零
- ProductSharpness：`score / edge` 非零，状态可达 `sharp`

R77G 未改 ProductAutoScene 代码，因此不回退 R77F 修复。

## 10. 本轮 tuning 决策

本轮没有调整 tuning 参数。

原因：

- 已完成真机构建、安装、启动和静态日志采集。
- 未获得人工手势日志，无法判断 zoom ruler 是偏慢、过快、卡住还是 switch-over 抖动。
- 按 AGENTS.md 的低风险原则，不用猜测改手感参数。

保留当前参数，待人工复核后再做 R77G-1 或 R77H 小包微调。

## 11. 构建与运行验证

已执行：

- `git status --short --branch`
  - 当前分支：`main...origin/main [ahead 15]`
- `xcrun devicectl list devices`
  - 检测到 iPhone 14 Pro Max connected。
- 真机构建：
  - `xcodebuild -scheme SellerCamera -project SellerCamera.xcodeproj -configuration Debug -destination 'id=E7D43088-7946-5FDB-BB14-E38124BB37DB' -derivedDataPath /tmp/SellerCameraR77FDeviceBuild build`
  - 结果：`BUILD SUCCEEDED`
- 真机安装：
  - `xcrun devicectl device install app --device E7D43088-7946-5FDB-BB14-E38124BB37DB ...`
  - 结果：安装成功。
- 真机启动：
  - `xcrun devicectl device process launch --console --timeout ... com.partyfist.SellerCamera`
  - 结果：启动成功并捕获日志；命令 timeout 是因为 App 常驻前台。
- Generic iOS clean build：
  - `xcodebuild -scheme SellerCamera -project SellerCamera.xcodeproj -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/SellerCameraR77GBuild CODE_SIGNING_ALLOWED=NO clean build`
  - 结果：`BUILD SUCCEEDED`

## 12. 风险与后续建议

人工真机待复核项：

- 13 / 24 / 48 / 77mm 焦段按钮切换。
- lens ruler 慢拖、普通拖、快拖。
- 2x / 3x switch-over 附近来回拖动。
- 近距包装文字点击对焦与 macro fallback。
- 稳定器关闭 / 标准 / 增强拍照响应。

建议下一步只做一个小包：

- 如果真机确认 zoom ruler 偏慢：只调 `CaptureZoomDialView.Tuning.pointsPerZoomCommon / normalSensitivity / smoothingPreviousWeight`。
- 如果 switch-over 卡住：只收紧 `lensRulerSwitchOverHysteresis`。
- 如果增强稳定器响应慢：只将增强等待从 `450ms` 收到 `300...350ms`。

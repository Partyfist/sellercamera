# R77D 参数调节回归修复与焦段 ruler 速度校准报告

## 1. 改动摘要

R77D 针对 R77C 后真机反馈的两个问题做最小收口：

- 修复 lens zoom 面板活跃时底部参数栏被整体隐藏并禁止 hit testing 的交互回归。
- 参数点击时强制退出 lens zoom active state，避免 lens zoom ruler 与 EV / WB / TINT / ISO / Shutter 参数面板互相拦截。
- 增加 Debug-only `[CaptureParameterTap]`、`[CaptureParameterRuler]`、`[CaptureParameterGuard]` 日志，定位参数入口、ruler 写入与 guard 拦截原因。
- 提高焦段 ruler normal 拖动灵敏度，缩短 24mm 到 48mm / 77mm 的拖动距离。
- 降低拖动中 smoothing 滞后，缩窄拖动中锚点吸附阈值，保留松手 settle。
- 收紧 virtual switch-over hysteresis，降低临界点保护对正常跨越 1x / 2x / 3x 的阻力。

本轮未改镜头 virtual multi-camera 选择策略，未改稳定器设置，未改 R77 / R77A / R77B 的拍照、点击对焦、实时参数显示、最近照片入口或最佳 / RAW 入口。

## 2. 文件清单

- `SellerCamera/CaptureScreen.swift`
  - 修复底部参数栏 hit testing 与 lens zoom active state 隔离。
  - 增加参数点击、参数 ruler、参数 guard Debug 日志。
  - 集中焦段 ruler tuning 参数并加快 normal 拖动。
  - 调整 zoom smoothing、snap、inertia 与 haptic 阈值。
- `SellerCamera/CaptureLivePreviewView.swift`
  - 收紧 lens ruler switch-over hysteresis。
- `README.md`
  - 增加 R77D 报告索引。

## 3. 回归原因判断

R77C 中 `isBottomOverlayControlPresented` 同时包含：

- `isBottomParameterPanelExpanded`
- `isLensZoomControlPresented`

底部基础控制区使用该状态控制：

- `.opacity(isBottomOverlayControlPresented ? 0 : 1)`
- `.allowsHitTesting(!isBottomOverlayControlPresented)`

因此当用户点击焦段按钮进入 `.lensZoom` 后，底部 EV / WB / TINT / ISO / Shutter 参数栏会被整体透明并禁止命中。焦段 ruler 的 active state 若未及时解除，用户会感觉除残留 active panel 外的参数无法点击或无法进入对应调节面板。

R77D 将底部参数栏的隐藏与禁点条件收口为仅在 `isBottomParameterPanelExpanded` 时生效。lens zoom panel 活跃时，底部参数入口仍保持可触达；选择任何参数时，`handleBottomParameterSelection` 会将 `activeControlTarget = .none`，明确退出 lens zoom。

## 4. 参数入口与 ruler 修复

本轮修复后：

- EV / WB / TINT / ISO / Shutter 点击路径统一进入 `handleBottomParameterSelection`。
- 选择参数时会关闭更多面板、关闭 MF ruler、退出 lens zoom active state。
- 参数 disabled 时输出 `[CaptureParameterGuard]` 并显示对应 hint。
- 参数 ruler 每次 step 后输出 `[CaptureParameterRuler]`，记录 kind、input、formatted value 与 applied 结果。
- WB / TINT / ISO / Shutter 的不可调 guard 额外输出拦截原因。

这次没有改各参数 runtime 写入路径，仍使用已有：

- `setWhiteBalanceDialValue`
- `setWhiteBalanceTintDialValue`
- `setISODialValue`
- `setShutterDialValue`
- `setExposureBiasDialValue`

## 5. lens zoom 状态隔离

R77D 没有新增大状态机，只做最小隔离：

- lens zoom active 不再禁止底部参数栏命中。
- 参数选择时主动清掉 `activeControlTarget`。
- zoom ruler smoothing、hysteresis、settle、inertia 只存在于 `CaptureZoomDialView` 和 lens runtime path，不作用于参数 ruler。
- 通用参数 ruler 继续使用 `CaptureHorizontalParameterRuler` 的已有 step / inertia / pending 逻辑。

## 6. 焦段 ruler 速度校准

R77C 的焦段 ruler 已连续，但 normal 拖动偏慢。R77D 调整为：

- normal sensitivity：`2.2` → `3.0`
- fine sensitivity：`0.75` → `0.90`
- ultraFine sensitivity：`0.35` → `0.38`
- common points per zoom：`132pt` → `96pt`
- high zoom points per zoom：`210pt` → `172pt`
- smoothing previous weight：`0.58` → `0.34`
- drag snap threshold：`0.026` → `0.016`
- drag snap weight：`0.46` → `0.25`
- emit delta：`0.006` → `0.005`
- inertia max delta：`56pt` → `38pt`
- inertia scale：`0.28` → `0.22`

结果目标：

- 24mm 到 48mm / 77mm 的同距拖动覆盖更广。
- 画面响应更跟手。
- 拖动中锚点吸附不再强拉住手指。
- 松手后仍可轻量 settle 到 0.5x / 1x / 2x / 3x。
- 不回退为离散 step 或每 tick ramp。

## 7. switch-over hysteresis 校准

R77C 的 switch-over hysteresis 为 `0.035`，R77D 收紧为 `0.022`。

目的：

- 保留虚拟多摄 switch-over 临界区保护。
- 降低 hysteresis 对正常跨越 1x / 2x / 3x 的阻力。
- 避免 1.99x / 2.01x 一类来回写入导致设备内部组成镜头频繁切换。

Debug 日志继续输出：

- `[CaptureLensZoom] switchOverHysteresis=true`
- requested zoom
- held zoom
- switch factor

焦段 ruler 拖动还会输出：

- `[CaptureLensZoomRuler] dragDelta`
- sensitivity
- rawZoom
- smoothedZoom
- emittedZoom

## 8. R77 / R77A / R77B / R77C 回归保护

本轮未改：

- R77 取消拍后快速预览。
- 左下最近照片入口。
- 最佳 / RAW 像素入口。
- R77A WB / ISO / Shutter / TINT 实时显示。
- R77A 点击对焦状态机和四角对焦框。
- R77B virtual multi-camera 优先策略。
- 焦段按钮 ramp 行为。
- 近距 fallback。
- R77C 稳定器设置与持久化。
- 拍照保存、白底处理、Review / Compare / Save。

## 9. 构建与运行验证

已执行：

```bash
xcodebuild -scheme SellerCamera -project SellerCamera.xcodeproj -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/SellerCameraR77DBuild CODE_SIGNING_ALLOWED=NO clean build
```

结果：

- `BUILD SUCCEEDED`

真机验证：

- 本轮未执行真机安装与交互实测。
- 需要真机重点复核五参数入口点击、WB / TINT / ISO / Shutter 实际拖动写入、焦段 ruler 24mm → 48mm / 77mm 的同距覆盖提升、switch-over 临界区是否仍平稳。

## 10. 风险与后续建议

风险：

- lens zoom panel 活跃时底部参数栏重新可触达，真机上需确认视觉层叠不会造成误触；若误触明显，下一轮可只做小范围 layout spacing。
- 焦段 ruler normal 已明显提速，若真机感觉过快，可只调 `Tuning.normalSensitivity` 或 `Tuning.pointsPerZoomCommon`，不要回退 direct zoom 架构。
- switch-over hysteresis 收窄后保护更轻，需在多摄真机日志中确认不会重新出现临界点跳动。

建议：

- R77E 只做真机参数交互验收：五参数逐项点击、拖动、Auto/Reset、lens zoom 后再调参数。
- 焦段手感若仍偏慢，优先继续调 `pointsPerZoomCommon`，不要恢复离散 step。

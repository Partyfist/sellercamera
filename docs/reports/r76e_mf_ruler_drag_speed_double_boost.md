# R76E MF Ruler 拖动速度三次加速报告

## 1. 改动摘要

- 基于 R76D 真机反馈，将 MF normal 拖动速度在 R76D 基础上再提升约 1 倍。
- MF normal 灵敏度从 3.0x 提升到 6.0x，让同样滑动距离覆盖更大的 lensPosition 范围。
- MF fine / ultraFine 从 0.50x / 0.20x 收紧到 0.42x / 0.16x，继续保留精修能力。
- 未修改 MF tick spacing、dragStepThreshold、0.005 step、默认居中、中心 50 / 双线去重、轻量 inertia、haptic 节流或 runtime 写入语义。
- 未修改 Shutter / S、Auto EV、Auto WB、ProductSharpness、ISO、EV、WB、Lens、拍照、白底或拍后流程。

## 2. 文件清单

- `SellerCamera/CaptureScreen.swift`
  - 调整 `CaptureManualFocusRulerPanel.scrubSensitivity(for:)` 的 normal / fine / ultraFine 灵敏度。
- `README.md`
  - 增加 R76E 报告索引。
- `docs/reports/r76e_mf_ruler_drag_speed_double_boost.md`
  - 新增本轮报告。

## 3. 真机反馈问题

R76D 后 MF normal 已从 2.2x 提升到 3.0x，并将 `dragStepThreshold` 从 18pt 降到 15pt，但真机反馈仍要求“划动速度需较现在增加一倍”。这说明 R76D 的方向正确，但 normal 粗调模式仍不够快，用户从近焦到远焦仍需要较长拖动。

## 4. R76D MF 参数基线

```text
tickSpacing: 10pt
dragStepThreshold: 15pt
normal: 3.0x
fine: 0.50x
ultraFine: 0.20x
step: 0.005
inertia: very light, max 2 step
```

## 5. MF normal 约 2 倍加速方案

R76E 调整：

```text
normal: 3.0x -> 6.0x
```

在当前实现中，drag translation 通过 `effectiveThreshold = dragStepThreshold / sensitivity` 转换为 step。因此 normal 从 3.0x 提升到 6.0x 后，同样手指位移理论上会跨过约 2 倍 step，满足本轮“较 R76D 再增加一倍”的目标。

## 6. dragStepThreshold / tickSpacing 保留或调整

```text
dragStepThreshold: 15pt -> 15pt
tickSpacing: 10pt -> 10pt
```

本轮优先通过 normal multiplier 达到目标，不继续降低 threshold，也不压缩 tick spacing。这样可以避免视觉密度、中心去重和细调手感被同时扰动。

## 7. fine / ultraFine 精修保留情况

```text
fine: 0.50x -> 0.42x
ultraFine: 0.20x -> 0.16x
```

normal 变为真正粗调后，fine / ultraFine 独立收紧，用于保留上拉微调的精准控制。上拉 40pt / 90pt 的模式切换逻辑未修改。

## 8. inertia / haptic 保留情况

- MF inertia 未改，仍为 very light，最多 2 个 step。
- haptic 未改，继续按 `mf-selectedIndex-step` 签名与 0.09s 间隔节流。
- 未新增连续震动或飞轮式惯性。

## 9. 中心 50 / 双线去重保留情况

- selected tick / selected value 附近 tick 线隐藏逻辑未改。
- 中心附近 major label 隐藏逻辑未改。
- 当前值仍由上方 `MF xx` bubble 唯一表达。
- 本轮没有恢复中心重复 `50` 或双中心线。

## 10. 状态保护

- MF 默认居中逻辑未改。
- 打开 MF ruler 不主动写入 0.5。
- `setManualFocusLensPosition(_:)` runtime 写入路径未改。
- LOCK / disabled guard 未改。
- restore AF / Focus Assist 相关逻辑未改。

## 11. 构建与运行验证

- `git status`：执行，变更仅包含 `CaptureScreen.swift`、`README.md` 与本报告。
- `xcodebuild -scheme SellerCamera -project SellerCamera.xcodeproj -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/SellerCameraR76EBuild CODE_SIGNING_ALLOWED=NO clean build`：通过，`BUILD SUCCEEDED`。
- 真机运行：本轮未声明完成真机手感验收；需要重点复核 normal 是否约为 R76D 的 2 倍、fine / ultraFine 是否仍可控、haptic 是否不过密、MF 是否无明显对焦抖动。

## 12. 风险与后续建议

- normal 6.0x 是按真机反馈做的明显加速，可能让普通拖动更接近快速粗调；若真机认为过快，应优先回调到 5.0x 或 5.5x，而不是改 tick spacing。
- fine / ultraFine 已收紧，但真机仍需确认上拉微调是否足够精确。
- 本轮不改 runtime 写入节流；如 normal 加速后出现对焦抖动，下一步应优先处理写入节流，而不是回退 UI 响应速度。

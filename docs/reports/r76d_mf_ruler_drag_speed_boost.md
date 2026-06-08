# R76D MF Ruler 拖动速度二次加速报告

## 1. 改动摘要

- 基于 R76C 真机反馈，对 MF ruler normal 拖动做二次加速。
- MF `dragStepThreshold` 从 18pt 降到 15pt，让更短手指位移即可跨过 0.005 step。
- MF normal 灵敏度从 2.2x 提升到 3.0x，让同距滑动覆盖更大 lensPosition 范围。
- MF fine / ultraFine 从 0.56x / 0.24x 收紧到 0.50x / 0.20x，继续保留精修能力。
- 未修改 MF tick spacing、0.005 step、默认居中、中心 50 / 双线去重、轻量惯性、haptic 节流或 runtime 写入语义。

## 2. 文件清单

- `SellerCamera/CaptureScreen.swift`
  - 调整 `CaptureManualFocusRulerPanel` 的 MF 拖动阈值和 scrub sensitivity。
- `README.md`
  - 增加 R76D 报告索引。
- `docs/reports/r76d_mf_ruler_drag_speed_boost.md`
  - 新增本轮报告。

## 3. 真机反馈问题

R76C 后 MF 视觉去重、中心双线清理和基础阻尼方向保留，但真机反馈仍认为 MF normal 模式划动偏慢。同样手指滑动距离下，lensPosition 覆盖范围仍不足，用户需要较长拖动才能从近焦到远焦或完成粗调。

## 4. R76C MF 参数基线

R76C 基线：

```text
tickSpacing: 10pt
dragStepThreshold: 18pt
normal: 2.2x
fine: 0.56x
ultraFine: 0.24x
step: 0.005
inertia: very light, max 2 step
```

## 5. MF normal 拖动速度调整

R76D 调整：

```text
normal: 2.2x -> 3.0x
```

normal 继续承担快速粗调职责。配合 `dragStepThreshold` 降低后，相同手指位移会跨过更多 0.005 step，解决“划动吃力”的主反馈。

## 6. dragStepThreshold / tickSpacing 调整

```text
dragStepThreshold: 18pt -> 15pt
tickSpacing: 10pt -> 10pt
```

本轮没有继续压缩 tick spacing，避免同时放大视觉密度和拖动速度造成失控。速度提升只来自拖动映射层，不改变 MF 视觉去重和 0.005 数据粒度。

## 7. fine / ultraFine 保留情况

```text
fine: 0.56x -> 0.50x
ultraFine: 0.24x -> 0.20x
```

normal 加速后，fine / ultraFine 略收紧，用于保留精修落点能力。上拉 40pt / 90pt 的模式切换逻辑未修改。

## 8. inertia / haptic 保留情况

- MF inertia 未改，仍为轻量延续，最多 2 个 step。
- haptic 仍按 `mf-selectedIndex-step` 签名和 0.09s 间隔节流。
- 未新增任何高频震动逻辑。

## 9. 中心 50 / 双线去重保留情况

- selected tick / selected value 附近 tick 线隐藏逻辑未改。
- 中心附近主刻度 label 隐藏逻辑未改。
- 当前值仍由上方 `MF xx` bubble 表达。
- 未恢复中心重复 `50`，未恢复双中心线。

## 10. 状态保护

- MF 默认居中逻辑未改，非 manual 且无 pending 时仍以 0.5 作为 UI 锚点。
- 打开 MF ruler 不主动写入 0.5。
- `setManualFocusLensPosition(_:)` 写入路径未改。
- LOCK / disabled guard 未改。
- restore AF / Focus Assist 相关逻辑未改。

## 11. 构建与运行验证

- `git status`：执行，变更仅包含 `CaptureScreen.swift`、`README.md` 与本报告。
- `xcodebuild -scheme SellerCamera -project SellerCamera.xcodeproj -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/SellerCameraR76DBuild CODE_SIGNING_ALLOWED=NO clean build`：通过，`BUILD SUCCEEDED`。
- 真机运行：本轮未声明完成真机手感验收；需要重点复核 normal 是否明显更快、fine / ultraFine 是否仍可精准、haptic 是否不过密。

## 12. 风险与后续建议

- normal 3.0x 与 15pt threshold 会明显提升覆盖范围；若真机认为过快，应优先微降 normal 到 2.7x 左右，而不是回退 R76C 视觉去重。
- 本轮未改 tickSpacing，因此如果后续仍感觉视觉和拖动不匹配，可单独评估 10pt -> 8pt，但不建议与本轮同时叠加。
- 真机仍需复核 MF 拖动是否造成对焦抖动；若抖动明显，优先增加 runtime 写入节流，而不是降低 UI 响应。

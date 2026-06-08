# R76F MF 同距参数覆盖范围修复报告

## 1. 改动摘要

- 复查 MF ruler 从手指 translation 到 lensPosition 写入的完整映射链路。
- 定位 R76E 后真实瓶颈：normal 6.0x 已生效，但每次更新仍被硬夹到 1 step，且 cooldown 未到时会提前消费位移，导致“滑了很多但 lensPosition 变化小”。
- 将 MF normal 从 6.0x 提升到 8.0x。
- 将 `dragStepThreshold` 从 15pt 降到 10pt。
- normal 每次更新最多允许 12 step；fine 最多 2 step；ultraFine 最多 1 step。
- cooldown 未到时不再消费 drag offset；边界 / 写入失败时仍消费当前位移，防止边界 residual 回归。
- 增加 Debug-only `[ManualFocusRuler]` 映射摘要日志，输出 translation、mode、sensitivity、threshold、raw/applied step、lensBefore/lensAfter、delta、clamped。
- 保留 MF 0.005 step、默认居中、中心 50 / 双线去重、打开不写入 0.5、restore AF、LOCK / disabled 保护。

## 2. 文件清单

- `SellerCamera/CaptureScreen.swift`
  - 调整 MF drag mapping、step cap、cooldown offset consumption 和 Debug-only 映射日志。
- `README.md`
  - 增加 R76F 报告索引。
- `docs/reports/r76f_mf_ruler_same_distance_range_fix.md`
  - 新增本轮报告。

## 3. 真机反馈问题

用户澄清本轮目标不是“动画更快”或“惯性更强”，而是相同手指滑动距离下，实际 lensPosition 变化范围要明显更大。R76E 虽然把 normal 提升到 6.0x，但真机仍需要多次拖动才能完成粗调，说明真实 value mapping 仍被其它环节限制。

## 4. R76E MF 参数基线

```text
tickSpacing: 10pt
dragStepThreshold: 15pt
normal: 6.0x
fine: 0.42x
ultraFine: 0.16x
step: 0.005
inertia: very light, max 2 step
```

## 5. MF drag translation 到 lensPosition 映射复查

R76E 前链路：

```text
finger translation
-> delta = translationWidth - lastDragStepTranslation
-> sensitivity = scrubSensitivity(verticalTranslation)
-> effectiveThreshold = dragStepThreshold / sensitivity
-> rawStepCount = delta / effectiveThreshold
-> lastDragStepTranslation += rawStepCount * effectiveThreshold
-> cooldown guard
-> clampedStepCount = clamp(-rawStepCount, -1...1)
-> stepManualFocusRuler(by:)
-> targetIndex = currentIndex + clampedStepCount
-> lensPosition = values[targetIndex]
-> setManualFocusLensPosition(lensPosition)
```

其中 normal 6.0x 会降低 `effectiveThreshold`，但随后仍会被两个机制削弱：step cap 只允许 1 step，cooldown 前提前消费 offset。

## 6. 真实瓶颈定位

本轮定位到两个具体瓶颈：

1. `clampedStepCount = max(-1, min(1, -rawStepCount))`
   - 即使 raw step 很大，每次有效更新也最多只写 0.005 lensPosition。
2. cooldown 前先执行 `lastDragStepTranslation += rawStepCount * effectiveThreshold`
   - 当 drag 事件频率高于 0.12s cooldown 时，大量手指位移会被消费但不产生 runtime write。

这两个点叠加后，会造成用户同距拖动覆盖范围显著低于 sensitivity 理论值。

## 7. normal 同距覆盖范围调整

R76F 调整：

```text
normal: 6.0x -> 8.0x
dragStepThreshold: 15pt -> 10pt
normal maxStepPerUpdate: 1 -> 12
```

理论映射：

```text
R76E effectiveThreshold = 15 / 6.0 = 2.5pt per raw step
R76F effectiveThreshold = 10 / 8.0 = 1.25pt per raw step
```

在不考虑 cap 的情况下，100pt drag 的 raw step 会从约 40 step 增加到约 80 step；R76F 同时把 normal 每次可应用 step 提升到 12，并保留 residual，使持续拖动可以把更多位移转成 lensPosition。

## 8. step cap / threshold / offset consumption 调整

- normal：max step per update = 12。
- fine：max step per update = 2。
- ultraFine：max step per update = 1。
- cooldown 未到时不消费 `lastDragStepTranslation`，让位移保留到下一次可写时转换为 step。
- onStep 失败时消费当前 raw movement，保持边界可反向回退，避免 residual 回归。
- tickSpacing 保持 10pt，避免再次扰动视觉密度和中心去重。

## 9. fine / ultraFine 精修保留情况

```text
fine: 0.42x -> 0.40x
ultraFine: 0.16x -> 0.16x
```

fine / ultraFine 没有跟随 normal 放大。fine 只允许 2 step/update，ultraFine 只允许 1 step/update，继续承担精修落点。

## 10. haptic / inertia 保留情况

- inertia 未改，仍为 very light，最多 2 step。
- haptic 未改，继续按 `mf-selectedIndex-step` 签名和 0.09s 间隔节流。
- normal 单次 step 增大后，每次有效更新仍只触发一次 haptic，不按每个 0.005 step 连续震动。

## 11. 中心 50 / 双线去重保留情况

- selected tick / selected value 附近 tick 线隐藏逻辑未改。
- 中心附近 major label 隐藏逻辑未改。
- 当前值仍由上方 `MF xx` bubble 唯一表达。
- 本轮未恢复中心重复 `50` 或双中心线。

## 12. 状态保护

- MF 默认居中逻辑未改。
- 打开 MF ruler 不主动写入 0.5。
- `setManualFocusLensPosition(_:)` runtime 写入路径未改。
- LOCK / disabled guard 未改。
- restore AF / Focus Assist 相关逻辑未改。

## 13. 构建与运行验证

- `git status`：执行，变更仅包含 `CaptureScreen.swift`、`README.md` 与本报告。
- `xcodebuild -scheme SellerCamera -project SellerCamera.xcodeproj -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/SellerCameraR76FBuild CODE_SIGNING_ALLOWED=NO clean build`：通过，`BUILD SUCCEEDED`。
- 真机运行：本轮未声明完成真机手感验收；需要重点复核 `[ManualFocusRuler]` 日志中的 translation 与 lensPosition delta，以及 normal 是否能更快完成粗调。

## 14. 风险与后续建议

- normal max step 提升到 12 后，MF 粗调会明显更强；若真机出现对焦抖动，优先增加 MF runtime 写入节流或将 cap 降到 8，而不是继续调高 multiplier。
- cooldown 不再吞位移后，快速拖动的最终 lensPosition 覆盖会更接近真实手指距离；需真机确认边界反向回退仍自然。
- Debug 日志只在 DEBUG 输出；如真机日志过多，可下一轮改为 drag ended 汇总。

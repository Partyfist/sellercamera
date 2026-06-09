# R76G MF Ruler 真机手感稳定性收口报告

## 1. 改动摘要

- 保留 R76F 的同距覆盖修复，不继续提高 MF normal 速度。
- 将 MF ruler 调参集中到 `ManualFocusRulerTuning`，便于真机验收后快速调整 cap。
- 为 MF ruler runtime 写入增加独立 0.04s throttle，避免快速拖动时高频 `setManualFocusLensPosition` 写入导致真机对焦抖动。
- 将 MF step 结果从 Bool 改为 `applied / throttled / rejected`，让 UI 能区分 throttle 与边界失败。
- cooldown 未到、runtime throttle 未到时不消费 drag offset，避免 R76E 类“滑动被吃掉”回归。
- 边界 / duplicate / guard rejected 时仍消费当前位移，保持边界反向回退手感。
- 增强 Debug-only `[ManualFocusRuler]` 日志字段，用于真机判断 mapping、cap、throttle、cooldown 与 offset consumption。

## 2. 文件清单

- `SellerCamera/CaptureScreen.swift`
  - 新增 `ManualFocusRulerTuning` 与 `ManualFocusRulerStepResult`。
  - 集中 MF normal / fine / ultraFine sensitivity、step cap、tick spacing、drag threshold、lens step、write interval。
  - 增加 MF runtime write throttle 状态与写入保护。
  - 增强 Debug-only MF drag mapping 日志。
- `README.md`
  - 增加 R76G 报告索引。
- `docs/reports/r76g_mf_ruler_stability_closure.md`
  - 新增本轮报告。

## 3. MF 写入节流实现说明

新增：

```text
ManualFocusRulerTuning.writeMinInterval = 0.04s
lastManualFocusRuntimeWriteAt
```

`stepManualFocusRuler(by:)` 在调用 `setManualFocusLensPosition(_:)` 前检查距离上次写入的时间：

- `writeAge >= 0.04s`：允许写入，更新 pending / last dispatched / runtime write timestamp，返回 `.applied`。
- `writeAge < 0.04s`：不写 runtime，返回 `.throttled(lastWriteAge:)`。

Panel 收到 `.throttled` 后不会更新 `lastDragStepTranslation`，因此用户输入不会被吃掉；下一次 drag update 会用累计位移重新计算最新目标。

## 4. normal cap 保护说明

R76F cap 保留但集中化：

```text
normalMaxStepPerUpdate = 12
fineMaxStepPerUpdate = 2
ultraFineMaxStepPerUpdate = 1
```

本轮不直接降到 8，先保留 R76F 的粗调覆盖能力。若真机出现明显跳焦 / 抖动，下一步优先把 `normalMaxStepPerUpdate` 从 12 降到 8，而不是继续改 multiplier。

## 5. Debug 日志字段说明

`[ManualFocusRuler]` Debug-only 日志现在包含：

```text
mode
translation
delta
effectiveThreshold
rawStepCount
appliedStepDelta
cap
lensBefore
lensAfter
lensDelta
writeAllowed
throttled
cooldownAllowed
consumedOffset
clamped
lastWriteAge
```

这些字段用于判断：

- 当前手指 translation 是否持续增加；
- raw step 是否被 cap；
- runtime write throttle 是否拦截；
- lensPosition 是否真实变化；
- cooldown / throttle 未到时是否错误消费 offset。

## 6. 与 R76F 的区别

R76F 重点是修“同距滑动覆盖不足”：

- normal 8.0x；
- threshold 10pt；
- normal cap 12；
- cooldown 未到不消费 offset。

R76G 重点是稳定性收口：

- 不继续加速；
- 增加 runtime write throttle；
- 集中 tuning 配置；
- 扩展日志字段；
- 明确 throttle 不消费 offset。

## 7. 影响范围

- MF：仅改 ruler mapping 周边、写入节流与日志。
- Shutter / S：未改。
- ISO / EV / WB / Lens：未改。
- Auto EV / Auto WB / ProductSharpness / Focus Assist：未改。
- 拍照 / 白底 / 拍后：未改。

## 8. 构建结果

- `git status`：执行，变更仅包含 `CaptureScreen.swift`、`README.md` 与本报告。
- `xcodebuild -scheme SellerCamera -project SellerCamera.xcodeproj -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/SellerCameraR76GBuild CODE_SIGNING_ALLOWED=NO clean build`：通过，`BUILD SUCCEEDED`。

## 9. 真机运行结果

本轮未声明已完成真机手感验收。真机需重点观察：

- normal 快速拖动是否不再明显抽动；
- `[ManualFocusRuler] appliedStepDelta` 是否不长期卡在 ±1；
- 是否经常打满 ±12；
- throttle 时 `consumedOffset=false`；
- fine / ultraFine 是否仍可精修；
- haptic 是否不过密；
- restore AF / LOCK / Focus Assist 是否不被影响。

## 10. 风险与下一步建议

- 如果真机日志显示 normal 经常打满 ±12 且画面跳变明显，优先将 `normalMaxStepPerUpdate` 降到 8。
- 如果 throttle 后仍有抖动，可将 `writeMinInterval` 从 0.04s 调到 0.05s。
- 如果 fine / ultraFine 变迟钝，应只调整 fine / ultraFine sensitivity 或 cap，不要改 normal 粗调链路。

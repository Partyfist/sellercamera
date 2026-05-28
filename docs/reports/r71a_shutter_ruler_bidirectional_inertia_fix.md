# R71A Shutter Ruler Bidirectional Inertia Fix

## 1. 改动摘要

本包只修 Shutter ruler 交互层，不改 AVFoundation 曝光写入主链路。

- 修复 Shutter 拖拽中 runtime readback 抢回 UI selected 的风险。
- 将 Shutter 的 pending / committed / runtimeConfirmed tick 语义拆开记录。
- 收紧 duplicated tick guard，仅在非拖拽、无 pending、目标 tick 与 committed tick 完全一致时跳过。
- 将 Shutter ruler tick spacing 从通用 24pt 缩小到 18pt，同屏显示更多刻度。
- 为 Shutter ruler 增加基于 predictedEndTranslation 的轻量惯性 final step。
- 增强 Debug 日志，覆盖 drag / inertia / readback / duplicate skip 关键字段。

## 2. 文件清单

- `SellerCamera/CaptureBottomParameterBar.swift`
  - 为 horizontal ruler item 增加 `tickSpacing` 与 `supportsInertia`。
  - 为 ruler panel 增加 drag state 回调。
  - 为 Shutter ruler 增加惯性 final step 与 Shutter gesture debug 日志。

- `SellerCamera/CaptureScreen.swift`
  - 增加 Shutter ruler 交互态、committed tick / duration 状态。
  - Shutter readback 在拖拽中只记录，不清 pending、不抢 selected。
  - duplicated guard 改为 committed + non-dragging + no-pending 才生效。
  - Shutter spacing 单独下调为 18pt。

- `docs/reports/r71a_shutter_ruler_bidirectional_inertia_fix.md`
  - 本报告。

- `docs/reports/r71a_shutter_ruler_bidirectional_inertia_fix.json`
  - 机器可读验证摘要。

- `README.md`
  - 增加 R71A 报告索引。

## 3. 双向拖拽修复说明

R71A 不改 Shutter duration 写入路径，而是在 UI 交互层保证双向目标 tick 能继续推进：

- 拖拽中以 `pendingShutterWheelDurationSeconds` 作为 selected 优先来源。
- runtime readback 到达时，如果 `isShutterRulerInteracting == true`，只输出 readback 日志，不清 pending。
- 反向拖拽时 `stepShutterWheel(by:)` 继续按当前 pending/runtime 最近 tick 计算目标，不让 committed tick 阻断方向变化。
- boundary skip 日志增加 previous / target / clamped index，便于确认是否方向被 clamp。

## 4. selected / pending / committed 分离说明

当前页面层语义如下：

- selected：由 `horizontalRulerSelectedIndex` 根据 pending 优先计算，pending 不存在时才回落 runtime。
- pending：`pendingShutterWheelDurationSeconds` + `lastDispatchedShutterTickIndex` 表示已发起但未确认写入。
- committed：`committedShutterDurationSeconds` + `committedShutterTickIndex` 表示 runtime readback 确认后的最近 tick。
- runtimeConfirmed：`currentManualShutterDurationSeconds` readback 后临时映射到最近 tick，仅在非拖拽时用于确认 pending。

这样拖拽中 selected 不会被 readback 抢回；readback 只在用户松手后收口 pending。

## 5. duplicated guard 修复说明

R70 后重复判重仍可能误伤反向拖动。本包将 skip 条件限制为同时满足：

- 当前不是 auto takeover 强写。
- 没有 pending shutter write。
- 当前不处于 Shutter ruler dragging。
- target tick 等于 committed tick。
- target duration 与 committed duration 差值小于 identity epsilon。

拖拽中、惯性 final step 中、pending 覆盖中均不走 duplicate skip。

## 6. 刻度间距优化说明

Shutter ruler 使用独立 `tickSpacing = 18pt`，其它参数仍保留 24pt。

这样不改变 R70 的 tick 生成与 activeFormat 全范围策略，只增加同屏可见刻度数量，让 1/30、1/60、1/125、1/250 等常用区移动更连续。

## 7. 惯性滑动实现说明

在 Shutter ruler 的 `DragGesture.onEnded` 中读取 `predictedEndTranslation.width`：

- 慢速拖动不触发惯性。
- 快速滑动按 predicted delta 计算最多 5 tick 的 final inertia step。
- 惯性通过现有 `onWheelStep` 只提交一次 final step，避免逐 tick 写入风暴。
- Debug 下输出 `[CaptureShutterInertia]`，包含 direction、previous index、step、边界与 writeReason。

本包没有新增复杂动画引擎，保持低风险。

## 8. 写入节流说明

本包没有改 Shutter AVFoundation 写入主链路，也没有改 R66 safe clamp。

写入层保护来自：

- 通用 ruler step cooldown：Shutter 从 0.16s 调整为 0.12s。
- 惯性只在拖拽结束后提交一次 final step。
- duplicate guard 只过滤真正 committed 重复目标。
- pending 可被新的拖拽目标覆盖，避免旧 pending 锁住方向。

## 9. 验证结果

- `xcodebuild -scheme SellerCamera -project SellerCamera.xcodeproj -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/SellerCameraDerivedData CODE_SIGNING_ALLOWED=NO clean build`
  - 结果：通过，`BUILD SUCCEEDED`。

- `python3 -m json.tool docs/reports/r71a_shutter_ruler_bidirectional_inertia_fix.json`
  - 结果：通过。

- 真机：
  - 本轮未在真机运行。需要继续验证 1/30 ↔ 1/250 双向拖拽、快速滑动惯性与 readback 不抢 selected。

## 10. 风险与后续建议

- 当前惯性是轻量 final step，不是连续物理滚动；如果真机仍觉得惯性不足，下一包可只调 predicted delta 到 step 的映射强度。
- 本包不改 exposure write 主链路；如果真机出现写入延迟，优先看日志中的 `pendingTickIndex / committedTickIndex / runtimeConfirmedTickIndex`，不要先改 runtime。
- 需要真机确认快速来回拖动时不会出现写入风暴或 haptic 过密。

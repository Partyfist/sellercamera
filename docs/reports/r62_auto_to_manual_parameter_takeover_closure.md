# R62 AUTO → MANUAL 参数接管收口

## 1. 改动摘要

本包修复 AUTO 状态下第一次横向拖动可能被吞掉的问题，重点收口 WB / ISO / Shutter / EV 从 AUTO 到 MANUAL 的接管时机。

本次没有新增参数功能，没有改 UI 布局，没有改镜头 zoom、Focus、白底或拍后流程。

## 2. 文件清单

- `SellerCamera/CaptureScreen.swift`
  - 新增轻量 `manualTakeoverTargetIndex(...)` helper。
  - 调整 EV / WB / ISO / Shutter 第一次 drag 的 AUTO takeover 写入路径。
  - 调整 pending manual 状态下的参数 mode 显示，避免 UI 仍显示 AUTO。
- `docs/reports/r62_auto_to_manual_parameter_takeover_closure.md`
  - 本报告。
- `docs/reports/r62_auto_to_manual_parameter_takeover_closure.json`
  - 结构化报告。
- `README.md`
  - 新增 R62 报告索引。

## 3. AUTO takeover 问题原因判断

R61 已修复 drag residual 和边界 consume，但 AUTO 状态仍存在另一类问题：第一次 drag 如果命中边界或目标值与当前自动读数等价，旧逻辑会在 duplicate / boundary guard 处直接 `return false`。

结果是：

- runtime 没有收到 manual 写入。
- pending manual state 没有建立。
- UI 仍按 AUTO 渲染。
- 用户感知为“第一次滑动无效，需要反向滑一下”。

## 4. takeover 时机修复说明

新增 `manualTakeoverTargetIndex(...)`：

- 正常情况下仍按当前 tick + direction 取目标。
- 如果 AUTO 状态下第一步指向边界，允许返回当前边界 tick，并标记 `forceWrite`。
- `forceWrite` 会绕过 duplicate guard，派发一次 manual 写入。

这样第一次有效 drag 会同时完成：

- 建立 pending manual value。
- 派发 runtime manual 写入。
- 让 UI 脱离 AUTO。
- 让当前 drag 直接生效。

## 5. UI / runtime 同步说明

参数 state 现在在 pending manual 写入期间优先显示为 manual：

- `pendingWhiteBalanceWheelValue != nil` 时 WB 视为 manual。
- `pendingISOWheelValue != nil` 时 ISO 视为 manual。
- `pendingShutterWheelDurationSeconds != nil` 时 Shutter 视为 manual。
- `pendingExposureBiasWheelValue != nil` 时 EV 视为 manual。

WB / ISO / Shutter 的 AUTO 控件在 pending 期间允许恢复 AUTO，避免 UI 已显示 manual 但 AUTO 按钮不可用。

## 6. 覆盖参数列表

- EV：覆盖 exposure bias AUTO mode。
- WB：覆盖 AUTO → Kelvin manual takeover。
- TINT：无 AUTO 合同，本包未改主逻辑；继续通过现有 tint 写入从 WB Auto 进入手动白平衡组合。
- ISO：覆盖 AUTO → manual ISO takeover。
- Shutter：覆盖 AUTO → manual shutter takeover。
- MF：非 AUTO 参数，本包未改 MF drag / runtime 逻辑。

## 7. drag consumption 保护说明

本包没有改 R61 的横向 drag consumption 逻辑：

- 边界 movement 仍会被 consume。
- direction change 仍会重置 cooldown baseline。
- `CaptureHorizontalParameterRuler` 的 residual 修复未回退。
- MF ruler 的 R60/R61 手感逻辑未修改。

## 8. 功能合同保护说明

- EV 合同未改：RESET 回 0.0。
- WB 合同未改：AUTO 恢复自动白平衡，manual Kelvin 保留 TINT。
- TINT 合同未改：RESET，不是 AUTO。
- ISO 合同未改：AUTO 恢复自动 ISO。
- Shutter 合同未改：ISO Auto 时可调，ISO 非 Auto 时 LOCK。
- Focus 不回到底部五参数栏。
- 镜头 zoom、白底、拍后流程未修改。

## 9. 构建结果

- JSON：`python3 -m json.tool docs/reports/r62_auto_to_manual_parameter_takeover_closure.json` 通过。
- xcodebuild：通过。

## 10. 真机验证结果

本包当前未执行真机验证。

仍需真机重点确认：

- WB 在 AUTO 下第一次右滑是否立即进入 manual。
- WB 不再需要先左滑一次。
- ISO / Shutter 从 AUTO 第一次 drag 是否直接 takeover。
- TINT 与 MF 未受影响。
- R61 边界 residual 修复未回退。

## 11. 风险与后续建议

风险：

- 如果设备在 AUTO 状态下上报的 runtime 值长期停在能力边界，第一次 outward drag 会写入当前边界 tick 以完成 manual takeover，视觉变化可能较小，但状态会明确进入 manual。

下一步建议：

- R63 做真机专项复验：WB AUTO 首滑、ISO/Shutter AUTO 首滑、R61 边界行为、MF ruler 不回退。

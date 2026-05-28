# R63 Xcode / Simulator WB AUTO Takeover Diagnosis

## 1. 改动摘要

- 在 iPhone 16e / iOS 26.3 模拟器中启动拍摄页，确认模拟器无真实相机时会禁用硬件参数入口。
- 为 `DEBUG + simulator` 增加最小 WB 参数 UI fallback，用于观察 WB ruler / AUTO 状态机；该 fallback 不影响真机与 Release。
- 为 WB ruler 增加 Debug 诊断日志，覆盖 drag step、AUTO 状态、pending/runtime/displayed 值、target index、takeover 与 dispatch。
- 修复 AUTO 状态在边界接管时写入同一个 tick 的问题，改为写入相邻可见 manual tick，避免首滑被吞。

## 2. 文件清单

- `SellerCamera/CaptureScreen.swift`
  - 增加 WB Debug 诊断日志。
  - 增加仅 `DEBUG + simulator` 的 WB UI fallback。
  - 修正 AUTO boundary takeover target。
- `SellerCamera/CaptureBottomParameterBar.swift`
  - 增加仅 Debug 下的 WB ruler drag consumption 日志。
- `docs/reports/r63_xcode_simulator_wb_auto_takeover_diagnosis.md`
  - 新增本报告。
- `docs/reports/r63_xcode_simulator_wb_auto_takeover_diagnosis.json`
  - 新增结构化报告。
- `README.md`
  - 更新 R63 报告索引。

## 3. Xcode / 模拟器复现方式

- 构建目标：iPhone 16e / iOS 26.3 模拟器。
- 安装并启动：`com.partyfist.SellerCamera`。
- 初始观察：拍摄页可进入；由于模拟器无真实摄像头，硬件参数原本显示 disabled。
- 处理方式：增加仅 Debug + Simulator 生效的 WB UI fallback，让 WB 能展开 ruler 并显示 AUTO。
- 可视化结果：WB 参数入口可点击，WB ruler 可显示 `A`、`AUTO`、5000K 中心值与 Kelvin ticks。

## 4. 是否使用 Debug fallback

使用了 Debug fallback。

- 生效条件：`#if DEBUG && targetEnvironment(simulator)`。
- 范围：仅让 WB 在模拟器无相机能力时仍可进入 UI 状态机观察。
- 不改变：真机能力判断、真机 runtime 写入、Release 行为。

## 5. 诊断日志说明

新增日志前缀：

- `[CaptureWBRulerDrag]`
  - 输出 translation、delta、rawStepCount、consumedStepCount、rawDirection、selectedIndex、AUTO control 状态。
- `[CaptureWBWheel]`
  - 输出 direction、mode、pending WB、runtime WB、displayed WB、currentIndex、targetIndex、forceWrite、didTakeover、dispatch / skip 原因。

这些日志用于区分：

- drag changed 是否到达；
- step 是否被消费；
- takeover 是否发生；
- duplicate / boundary guard 是否吞掉首滑；
- pending manual 是否建立；
- runtime dispatch 是否调用；
- UI 是否仍显示 AUTO。

## 6. 实际观察到的状态流转

代码诊断确认 R62 的 AUTO takeover helper 存在一个边界路径：

1. WB 处于 AUTO。
2. 当前 nearest tick 如果位于 min / max 边界。
3. 用户首滑方向继续指向边界外。
4. `manualTakeoverTargetIndex` 会返回 `currentIndex` 且 `forceWrite = true`。
5. 结果是本次写入能绕过 duplicate guard，但目标值仍是同一个边界 tick。
6. UI / 用户体感上表现为“第一次 drag 没有真正改变数值”，容易被理解为 AUTO 未解除或首滑被吞。

这与真机反馈“WB AUTO 右滑需要先反向一次”一致：第一次同向滑动如果命中 AUTO 边界接管路径，写入的是同一 tick；反向滑动后进入非边界值，后续再同向才恢复正常。

## 7. 根因结论

根因是 AUTO -> MANUAL 接管在边界路径下只完成了“force write”，但没有完成“可见 manual tick 变化”。

R62 的修复让 duplicate guard 不再吞掉 AUTO takeover，但边界场景仍会把 target 保持为 current tick，导致首滑在视觉和手感上像无效输入。

## 8. 修复说明

修复点：

- `manualTakeoverTargetIndex` 在 AUTO 且 target 被 clamp 到当前边界时，不再返回 `currentIndex`。
- 改为返回相邻可用的 `takeoverBaselineIndex`，并继续 `forceWrite = true`。

效果：

- 首次 drag 如果命中边界，也会直接写入一个真实 manual tick。
- 首滑同时完成 AUTO takeover 和数值变化。
- duplicate guard / boundary guard 不再吞掉可见变化。
- R61 的 drag consumption 修复保持不变。

## 9. WB AUTO 首滑验证

已完成：

- 模拟器可打开拍摄页。
- 通过 Debug fallback 可展开 WB AUTO ruler。
- 代码路径已能输出 WB drag / takeover 诊断日志。
- 修复后，AUTO 边界接管不再写入同一个 tick。

未完成：

- 当前环境无法通过可用工具向 Simulator 注入真实横向 drag 手势；`Computer Use` 当前仅提供 click/type/set_value，macOS `osascript` 因辅助功能权限被拒绝，CGEvent 注入未被 Simulator 接收。
- 因此本轮未完成自动化模拟器拖拽日志采样。
- 真机仍需验证 WB AUTO 状态直接右滑是否立即显示 manual Kelvin。

## 10. R61 Drag Consumption 回归结果

- 未改动 R61 的 `lastDragStepTranslation` 消费逻辑。
- 未改动边界 residual consume。
- 未改动方向切换 baseline reset。
- WB 修复只改变 AUTO takeover 的边界 target，不改变 drag consumption。

## 11. EV / ISO / Shutter / MF 影响说明

- EV：沿用相同 helper，但 EV 当前无 AUTO 主语义，正常路径不受影响。
- ISO / Shutter：同样受益于 AUTO 边界接管不写同值；runtime 合同未改。
- TINT：无 AUTO 语义，未改 TINT 逻辑。
- MF：未改 MF ruler、MF pending、AF/MF/LOCK 状态。

## 12. 构建结果

- iPhone 16e 模拟器 Debug build：通过。
- generic iOS Simulator build：通过。

## 13. 真机验证情况

本轮未运行真机。

仍需在真机验证：

- WB AUTO 状态直接右滑是否立即退出 AUTO。
- 首滑后是否立即显示 Kelvin manual 值。
- WB 左右边界是否不再残留。
- ISO / Shutter AUTO 首滑是否无回归。
- MF ruler 是否不受影响。

## 14. 遗留风险

- 本轮定位依赖代码路径与模拟器 UI fallback，未能采集真实 drag 日志，仍需真机确认。
- 如果真机问题还包含 runtime 回写覆盖 pending，则下一包应继续沿 `[CaptureWBWheel]` 日志查看 pending 是否被 auto preset 回写清掉。
- 当前 Debug fallback 仅用于模拟器 UI 状态机诊断，不应扩展为产品能力。

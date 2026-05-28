# R49 五参数贴合式刻度交互与 TINT 修复报告

日期：2026-05-23

## 1. 背景

本轮处理 R47 / R48 后的真机视觉与交互反馈：五参数入口仍有明显底色和外框，整体像表格卡片；点击参数后入口不应移动；刻度应贴合 active 参数下方展开；TINT 横向滑动反馈为不可调；点击参数控制区外部应能关闭当前展开层。

本包不进入 Focus，不改白底、拍后、镜头底层路径，也不改变 EV / WB / TINT / ISO / Shutter 的 runtime 写入合同。

## 2. 五参数入口去底色去外框

- 去掉 `CaptureBottomParameterBar` 常态入口外层的大背景、material、外框描边和阴影。
- 去掉非 active 参数项的完整卡片边框，非 active 仅保留图标、参数名、当前值和透明度层级。
- active 参数改为轻量强调：青绿色图标/文字、轻薄圆角底、底部短指示线和非常轻的 glow。
- 五参数入口行仍保持等宽布局，点击后不通过放大 active item 改变其它参数位置。

## 3. 贴合式刻度展开

- 展开层不再给整条参数入口套大卡片背景；只有横向 ruler 自身保留低位深色控制条。
- 在 active 参数下方加入小型强调色锚点，使横向刻度尺与当前参数形成视觉关联。
- 参数控制台外层切换使用 opacity，避免入口行跳动；ruler 内容使用从顶部移入 + 淡入的轻动画，模拟从 active 参数下方展开。
- 当前值浮窗、中心指针、主/次刻度和 AUTO / RESET / LOCK 胶囊继续沿用 R44-R48 的横向 ruler 主线。

## 4. TINT 无法调整根因与修复

根因定位为 UI tick 与 runtime 写入量化不一致：

- `CaptureCameraRuntime.whiteBalanceTintDialStep` 为 `5`。
- R43 以后 UI tick 曾在常用区提供 `2` 为步进的 TINT 值。
- 用户滑到 `M2 / G2` 等值时，runtime 会按 5-step 量化回 `0` 或相邻 5-step 值，真机体感上表现为 TINT 调不动或刚动就回弹。

本轮修复：

- `tintWheelValues()` 改为 runtime 可确认的 `5` 步进 tick：`-50 ... 0 ... +50`。
- current runtime tint 追加到 tick 列表前也按 runtime step 重新量化，避免历史非 5-step 状态继续进入 ruler。
- 未改 `setWhiteBalanceTintDialValue(_:)`、`resetWhiteBalanceTint()` 或白平衡组合写入逻辑。

保留合同：

- TINT 仍是 RESET，不是 AUTO。
- TINT RESET 仍调用 `resetWhiteBalanceTint()`，不触发 `applyWhiteBalanceAuto()`。
- TINT 调节仍保留当前 WB Kelvin。
- WB AUTO 后仍清 TINT 为 0。

## 5. 点击外部关闭

新增统一的 `dismissInlineControls()`：

- 点击取景区关闭当前参数 / 镜头展开层。
- 点击顶部状态区关闭当前展开层。
- 点击拍摄意图切换区关闭当前展开层。
- 点击参数项内部不关闭：active 参数再次点击会收起；点击其它参数会切换 active 并显示对应刻度。
- 横向 ruler 拖动和 AUTO / RESET / LOCK 操作不触发关闭。

当前点击取景区仍保留原有点击对焦桥接；本轮只在同一路径上补充关闭 inline controls，不改变对焦 runtime。

## 6. 触觉与顺滑度

- 保留横向 ruler 的 tick 成功变化后轻触觉反馈。
- 保留 RESET / AUTO 单次轻反馈。
- LOCK / disabled / 同值 / 边界未成功变化不触发写入，也不重复触发反馈。
- 未引入 heavy feedback。

## 7. 修改文件

- `CaptureBottomParameterBar.swift`
  - 去除五参数入口外部底色与外框。
  - 调整 active / non-active 视觉层级。
  - 增加 active 参数下方锚点。
  - 调整 ruler 展开动效与背景层级。
- `CaptureScreen.swift`
  - 新增参数选择与外部关闭 helper。
  - 调整参数展开切换逻辑。
  - 修复 TINT tick 与 runtime 5-step 量化不一致问题。
  - 在顶部、取景区、意图切换区接入外部点击关闭。
- `README.md`
  - 增加本轮 R49 报告索引。

## 8. 验证

- `xcodebuild -project /Users/sungning/Projects/SellerCamera/SellerCamera.xcodeproj -scheme SellerCamera -configuration Debug -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO build`
  - 结果：通过。
- `python3 -m json.tool docs/reports/r49_parameter_inline_ruler_interaction_and_tint_fix.json`
  - 结果：通过。

真机未在本轮自动运行，因此以下仍需人工确认：

- 五参数底色和外框在真机上是否已经足够轻。
- 刻度是否符合“从 active 参数下方展开”的主观预期。
- TINT 真机色偏是否随横向滑动稳定变化。
- 触觉反馈是否足够轻、不扰人。

## 9. 边界

本轮没有：

- 新增 Tone / Style / 滤镜 / 调色盘。
- 让 Focus 回到底部五参数。
- 修改 EV / WB / TINT / ISO / Shutter runtime 写入路径。
- 修改镜头 zoom 底层路径。
- 修改白底图处理、拍后 Review / Save / Generate 流程。
- 删除或重接旧大参数面板。

## 10. 遗留风险

- 本轮修复了 TINT “UI tick 无法被 runtime 确认”的主要原因，但 TINT 色彩方向仍需要真机色彩验证。
- 外部点击关闭已覆盖取景区、顶部状态区和意图切换区；如果后续发现某个底部空白区域未关闭，可继续补一个透明 hit layer，但本轮未扩大底部控制结构。
- 现有 R49 编号已被独立 Focus 前置报告使用过；本轮按任务书新增独立文件名，未覆盖已有 Focus 报告。

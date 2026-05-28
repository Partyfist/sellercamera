# R61 参数横向滚轮边界残留修复 + Drag Consumption 收口报告

## 1. 改动摘要

R61 针对真机反馈的“WB 向右滑动到边界后，需要先反向滑一下才能继续响应”问题，修复横向 ruler 的 drag consumption 残留。

本包完成：

- 修复五参数横向 ruler 的边界 residual。
- 修复 MF ruler 的边界 residual。
- cooldown 或边界未产生真实参数变化时，也会消费本段 drag baseline。
- 方向变化时清理 step cooldown，让反向拖动立即响应。
- 手势结束时清空方向状态。

本包没有新增参数功能，没有改 runtime 写入合同，没有改白底、拍后、镜头 zoom 或 Focus 新功能。

## 2. 文件清单

- `SellerCamera/CaptureBottomParameterBar.swift`
  - 修复 EV / WB / TINT / ISO / Shutter 共用横向 ruler 的 drag consumption。
- `SellerCamera/CaptureScreen.swift`
  - 修复 MF ruler 的 drag consumption。
- `README.md`
  - 新增 R61 报告索引。
- `docs/reports/r61_parameter_drag_boundary_consumption_closure.md`
  - 本报告。
- `docs/reports/r61_parameter_drag_boundary_consumption_closure.json`
  - 结构化记录。

## 3. 问题原因判断

当前横向 ruler 使用：

```swift
translationWidth - lastDragStepTranslation
```

来计算本次应消费的 step。

问题点在于：

- 当手势已经达到边界时，`onWheelStep` 会返回 `false`。
- 当 cooldown 尚未到期时，原逻辑直接 return。
- 这两类情况下，如果没有消费当前 translation baseline，旧 residual 会留在后续事件里。
- 用户反向拖动时会先抵消 residual，表现为“必须先反滑一下”。

真机反馈中的 WB 右滑卡住符合这一类 residual 问题。

## 4. drag residual 修复说明

修复后逻辑：

1. 先计算 `rawStepCount`。
2. 记录本次拖动方向。
3. 将本次达到阈值的 movement 先消费到 `lastDragStepTranslation`。
4. 再判断 cooldown。
5. 再尝试写入参数。

关键原则：

```text
即使 cooldown 或边界导致本次没有真实值变化，也要消费已达到阈值的拖动距离。
```

这样用户继续向边界方向拖动不会累积 residual，反向拖动也不需要先抵消旧输入。

## 5. 边界 reset 说明

当参数已经位于 min / max，用户继续向边界方向拖动：

- 不重复写入同一个边界值。
- 不重复触觉反馈。
- 会消费当前 movement baseline。
- 不把这段 movement 留给后续反向拖动抵消。

这使边界表现更接近“柔性吸附”，而不是输入卡死。

## 6. 方向切换说明

新增最小方向记录：

- 五参数 ruler：`lastRulerDragDirection`
- MF ruler：`lastDragDirection`

当方向变化时：

- 清理 step cooldown。
- 保留当前 baseline 消费策略。
- 让反向第一档可以立即响应。

手势结束时：

- 清空 `lastDragStepTranslation`。
- 清空方向状态。

## 7. 覆盖参数列表

本次覆盖：

- EV
- WB
- TINT
- ISO
- Shutter
- MF ruler

五参数共用 `CaptureHorizontalParameterRuler`，因此 WB 修复不会成为单点补丁。

## 8. MF ruler 保护说明

R60 的 MF 手感目标保持：

- `0.025` tick。
- `40pt` trigger。
- `0.12s` cooldown。
- 单次 consume 最多 1 档。
- `0.0 = 近`，`1.0 = 远`。

本包只修 consumption 状态，不改 MF 写入路径：

```swift
cameraRuntime.setManualFocusLensPosition(_:)
```

也不改 AF 恢复路径：

```swift
cameraRuntime.restoreAutofocusMode()
```

## 9. 功能合同保护说明

未改动：

- EV / WB / TINT / ISO / Shutter runtime 合同。
- TINT RESET 合同。
- WB / TINT 组合合同。
- ISO / Shutter LOCK 合同。
- MF / AF / LOCK 状态合同。
- 镜头 zoom runtime。
- 点击对焦。
- 长按 AE/AF Lock。
- 双指缩放。
- 白底 pipeline。
- 拍后流程。

## 10. 构建结果

已运行：

```bash
xcodebuild -project /Users/sungning/Projects/SellerCamera/SellerCamera.xcodeproj -scheme SellerCamera -configuration Debug -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO build
```

结果：通过。

同时验证 R61 JSON 可解析。

## 11. 真机验证结果

本轮未运行真机。

仍需真机复测：

- WB 到右边界后继续右滑，再立刻左滑是否立即响应。
- WB 反向后再右滑是否无需“先抵消”。
- EV / TINT / ISO / Shutter 边界是否同样稳定。
- MF ruler 到 0% / 100% 后反向是否立即响应。
- 快速连续拖动是否不异常跳档。

## 12. 风险与后续建议

- 本包修复的是输入 consumption 基础状态，真机手感仍需复测确认。
- Lens zoom ruler 不是本包要求覆盖范围，未做跟随修改；如后续出现同类反馈，可单独处理。
- 下一包建议只做 R61 真机边界复验与必要阈值微调，不新增功能。

# R60 Focus 真机闭环收口 + MF 手感微调 + 状态表达清理报告

## 1. 本包实现范围

R60 基于 R59 的真机反馈进行最小收口，不新增 Focus 大功能，不改变五参数、镜头、更多面板、白底或拍后流程。

已完成：

- 保留 R59 的独立低位 MF ruler。
- 保留 `MF` 单按钮进入 / 退出模式。
- 保留 `setManualFocusLensPosition(_:)` 写入闭环。
- 保留 `restoreAutofocusMode()` 恢复 AF。
- 确认并修正显示语义：`0.0 = 近`，`1.0 = 远`。
- 将 MF ruler 档位从 `0.05` 细化为 `0.025`。
- 将 MF ruler 拖动阈值从 `34pt` 提高到 `40pt`。
- 将 MF ruler step 冷却从 `0.10s` 提高到 `0.12s`。
- MF 进入提示补充“左近右远”。

本包没有做：

- 没有新增对焦峰值。
- 没有新增放大镜。
- 没有新增 AI 对焦辅助。
- 没有把 Focus 放回底部五参数栏。
- 没有重构相机 runtime。
- 没有改 EV / WB / TINT / ISO / Shutter 合同。

## 2. Focus 真机闭环结论

用户已反馈 R59 MF 真机验证正常。

R60 在此基础上只做最小代码收口：

- MF 仍是明确状态入口，不是瞬时按钮。
- 收起 ruler 不退出 MF。
- 退出 MF 必须再次点击 `MF`。
- LOCK 优先级仍高于 MF。
- MF 模式下点击取景区仍不会偷偷触发 AF tap focus。
- AF 恢复仍走 `restoreAutofocusMode()`。

## 3. MF 手感微调

R59 的 MF ruler 为 `0.05` 步进。R60 调整为：

```text
range: 0.0 ... 1.0
step: 0.025
```

拖动阻尼调整：

```text
drag threshold: 40pt
step cooldown: 0.12s
max step per trigger: 1
```

目的：

- 让 MF 微调更细。
- 减少轻滑时过快跳档。
- 保持真实 tick 变化才写入 runtime。
- 保持同值去重、边界去重和轻触觉反馈。

## 4. 状态表达清理

R60 修正了 runtime 的手动对焦区间文案：

```text
0.0 ... 0.34 = 近距
0.34 ... 0.67 = 中距
0.67 ... 1.0 = 远距
```

这与 MF ruler 的左右语义保持一致：

```text
左 = 近
右 = 远
```

进入 MF 后提示文案调整为：

```text
MF 模式已开启，左近右远，拖动刻度微调对焦
```

## 5. 与现有模块关系

本包只涉及：

- `CaptureScreen.swift`
- `CaptureLivePreviewView.swift`

页面层负责：

- ruler 档位密度。
- 拖动阈值。
- 状态提示。

runtime 继续负责：

- `setManualFocusLensPosition(_:)`
- `restoreAutofocusMode()`
- `currentManualFocusPosition`
- `focusControlMode`
- `isFocusExposureLocked`

## 6. 功能合同保护

未改动：

- `EV / WB / TINT / ISO / S` 五参数结构。
- EV 写入与 RESET。
- WB / TINT 组合合同。
- TINT RESET 合同。
- ISO / Shutter LOCK 合同。
- 镜头切换与 zoom runtime。
- 点击对焦。
- 长按 AE/AF Lock。
- 双指缩放。
- 右上角更多面板持久交互。
- 白底处理。
- 拍后流程。

## 7. 构建验证

已运行：

```bash
xcodebuild -project /Users/sungning/Projects/SellerCamera/SellerCamera.xcodeproj -scheme SellerCamera -configuration Debug -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO build
```

结果：通过。

同时验证 R60 JSON 可解析。

## 8. 真机验证情况

本轮未再次运行真机。

已知外部反馈：

- R59 MF 真机验证正常。

仍需真机确认：

- R60 的 `0.025` 档位是否更利于微调。
- `40pt / 0.12s` 阻尼是否足够稳。
- “左近右远”提示是否清楚。
- 低位 ruler 是否仍不遮挡商品主体。

## 9. 遗留风险

- 不同镜头的 lensPosition 体感可能不完全一致，后续可按真机反馈微调阈值或 tick 密度。
- 当前没有对焦峰值和放大镜，MF 精确确认仍依赖用户观察实时预览。
- MF 模式下 tap focus 被保护性消费，这符合防误触策略，但仍需持续观察用户是否理解。

## 10. 下一步建议

下一包建议：

第 61 包：Focus 真机复验 + MF 低位 ruler 小屏 / 镜头差异最小修正。

只做：

- 真机验证不同焦段下 MF 手感。
- 微调 MF ruler 阈值或 tick 密度。
- 检查 LOCK / AF / MF 状态显示。
- 不新增对焦峰值、放大镜或 AI 辅助。

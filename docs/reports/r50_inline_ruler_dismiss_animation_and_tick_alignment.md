# R50 五参数贴合式刻度层真机修正报告

日期：2026-05-24

## 1. 背景

R49 的“轻量参数入口 + active 参数下方贴合展开横向刻度”方向已经通过真机反馈确认有效。本轮只针对 R49 后的三个细节问题做最小修正：

- 点击取景区时参数刻度层未关闭。
- 从上到下展开动画仍不够优雅。
- 中心指针过长，且与当前 tick 存在视觉偏移。

本轮不新增 Focus，不改白底、拍后、镜头底层，也不改变 EV / WB / TINT / ISO / Shutter 的 runtime 写入合同。

## 2. 点击取景区关闭修复

根因是 R49 的关闭逻辑挂在 SwiftUI 外层 `.onTapGesture`，但真实预览点击由 `CameraPreviewLayerView` 内部 UIKit `UITapGestureRecognizer` 处理，外层 tap 在真机上并不稳定触发。

本轮修复方式：

- `CaptureLivePreviewView` 新增 `onTapPreviewBeforeFocus` 钩子。
- 预览 tap 进入 `cameraRuntime.handlePreviewTap(...)` 之前先询问外层是否需要消费本次点击。
- 当五参数刻度层或镜头 inline control 已展开时：
  - 先调用 `dismissInlineControls()`。
  - 返回 `true` 消费本次点击。
  - 本次点击不继续执行对焦 / 测光。
- 当没有 inline control 展开时：
  - 返回 `false`。
  - 继续执行原有点击对焦 / 测光。

采用策略：

```text
参数层展开时，第一次点击取景区只关闭参数层；
参数层关闭后，再点击取景区才执行正常点击对焦 / 测光。
```

这样避免用户退出调参时误改对焦点。

## 3. 展开动画优化

- 保持五参数入口固定，不通过 active 放大或位移影响布局。
- ruler 内容从 active 参数下方锚点处以 `top move + opacity + top scale` 方式展开。
- 动画时长调整为 `0.20s`，更接近轻量控制层自然落下的感觉。
- 收起时使用 `opacity + top scale`，避免整个底部区域闪烁。
- active 参数切换时，新 ruler 从新 active 参数下方出现，参数入口不跳动。

## 4. 中心指针与 tick 对齐

R49 中 horizontal ruler 的 selected tick offset 少了半个 tick 宽度，导致当前 tick 的中心会偏离中心指针约半格。

本轮修复：

- tick 内容 offset 从：

```swift
centerX - selectedIndex * tickSpacing
```

调整为：

```swift
centerX - selectedIndex * tickSpacing - tickSpacing / 2
```

原因：每个 tick item 的视觉中心在该 item 宽度的中点，吸附到中心指针时必须扣除半个 tick 宽度。

修复后：

- 静止时当前 selected tick 位于中心指针下方。
- 吸附后当前 tick 与中心指针对齐。
- 当前值浮窗继续固定在中心指针上方。

## 5. 指针与刻度视觉优化

中心指针：

- 竖线高度从约 `41pt` 缩短到约 `30pt`。
- 三角从 `9x6pt` 调整为 `8x5pt`。
- 指针固定定位在 ruler 中心，不再依赖默认 ZStack 居中后 offset。
- 颜色继续使用 Seller Camera 主强调色。

刻度：

- selected 主线高度从约 `25pt` 降至 `21pt`。
- major tick 从约 `19pt` 降至 `16pt`。
- minor tick 从约 `11pt` 降至 `9pt`。
- 非选中刻度透明度进一步降低。
- 标签字号略收，标签宽度从 `50pt` 收到 `46pt`。

整体目标是让刻度尺更轻、更克制，不再像开发调试控件。

## 6. TINT 保护

R49 的 TINT 修复保持不变：

- TINT tick 仍按 runtime 可确认的 5-step 生成。
- TINT 正值显示 `Mxx`。
- TINT 负值显示 `Gxx`。
- TINT RESET 仍只归零色偏。
- TINT 调节仍保留当前 WB Kelvin。
- TINT 不触发 WB AUTO。

## 7. 修改文件

- `CaptureScreen.swift`
  - 新增 `dismissInlineControlsForPreviewTapIfNeeded()`。
  - 将预览点击关闭逻辑传入 `CapturePreviewContainer`。
  - 明确调参态取景点击先关闭并消费本次 tap。
- `CaptureLivePreviewView.swift`
  - 新增 `onTapPreviewBeforeFocus`。
  - 在 UIKit 预览 tap 进入对焦前执行关闭判断。
- `CaptureBottomParameterBar.swift`
  - 优化 ruler 展开 / 收起 transition。
  - 修复 selected tick 与中心指针对齐。
  - 缩短中心指针。
  - 收敛主/次刻度高度、透明度和标签尺寸。
- `README.md`
  - 增加 R50 报告索引。

## 8. 验证

- `xcodebuild -project /Users/sungning/Projects/SellerCamera/SellerCamera.xcodeproj -scheme SellerCamera -configuration Debug -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO build`
  - 结果：通过。
- `python3 -m json.tool docs/reports/r50_inline_ruler_dismiss_animation_and_tick_alignment.json`
  - 结果：通过。

真机未在本轮自动运行，因此仍需人工确认：

- 点击取景区是否在真机上稳定关闭参数层。
- 第一次点击关闭参数层是否符合预期，不造成误对焦。
- 展开动画是否足够顺。
- 指针与 tick 是否在真机视觉上完全对齐。
- TINT 真机调节是否仍稳定。

## 9. 边界

本轮没有：

- 新增 Focus 控件。
- 让 Focus 回到底部五参数栏。
- 修改 EV / WB / TINT / ISO / Shutter runtime 写入路径。
- 修改镜头 zoom 底层路径。
- 修改白底图处理 pipeline。
- 修改拍后 Review / Save / Generate 流程。
- 回退五参数去底色、去外框、去表格感方向。

## 10. 遗留风险

- 本轮修正了点击取景区关闭的代码路径，但真机触摸层级仍需要再次人工确认。
- 指针与 tick 几何中心已修正，视觉上是否还需 1-2pt 微调需要真机截图判断。
- Ruler 标签密度未重新设计；如某些参数仍显拥挤，可后续只做标签采样优化。

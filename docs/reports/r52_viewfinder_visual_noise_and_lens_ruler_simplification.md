# R52 取景区视觉噪音与镜头刻度精简报告

日期：2026-05-24

## 1. 背景

R51 已修复镜头焦段 ruler 的 pending zoom、selected tick、offset、吸附和重叠问题。真机反馈进一步指出当前拍摄页仍有几处视觉噪音：

- 取景区左上角仍显示 `EV +0.00` 类状态，干扰取景主体。
- 取景区外部白色线条较明显，画面像被 UI 容器框住。
- 镜头调节面板仍有标题、外框和内部容器边框，焦段刻度看起来偏重。

本轮只做视觉减法，不改 runtime、不改五参数合同、不改镜头底层、不改白底和拍后流程。

## 2. 取景区 EV 状态移除

处理方式：

- 移除 `CapturePreviewContainer` 中挂在 preview topLeading 的 `CaptureRuntimeBadge`。
- 删除已不再使用的 `CaptureRuntimeBadge` 私有 View。

影响范围：

- 仅移除取景区内冗余 EV 状态显示。
- 底部 `EV` 参数入口的当前值显示不变。
- EV runtime 写入、RESET、pending 回写逻辑不变。
- AE / AEAF 锁定逻辑未修改；本轮没有调整底层对焦或曝光状态。

## 3. 取景区外框线移除 / 弱化

处理方式：

- 删除 `CapturePreviewContainer` 对 `workspaceRect` 额外绘制的白色边框 stroke。
- 将 `CaptureAspectRatioGuideOverlay` 内部比例参考线从明显白线弱化为极低透明度线：

```swift
.stroke(.white.opacity(0.07), lineWidth: 0.6)
```

这样仍保留极弱比例边界感，但不再用亮线框住取景画面。

## 4. 镜头调节面板精简

处理方式：

- 移除镜头调节面板顶部标题，例如 `13mm · 镜内缩放`。
- 移除镜头调节外层明显 stroke。
- 移除 `CaptureZoomDialView` 内层刻度容器 stroke。
- 收紧镜头 panel 高度和 padding。
- 保留轻量暗色衬底，但不再做强卡片边框。

保留元素：

- 当前值浮窗，例如 `1.0x`。
- 中心指针。
- 横向主 / 次刻度。
- sampled major tick label。
- R51 的 pending zoom、selected tick、drag offset、吸附和 runtime 回写收口。

## 5. 交互保护

本轮没有改变镜头交互路径：

- 横向拖动镜头刻度仍调用现有 `cameraRuntime.setLensZoomDialValue(_)`。
- pending zoom 显示仍优先于 runtime zoom。
- 滑动结束后仍吸附到最近 tick。
- 双指缩放路径未改。
- 点击取景区关闭 inline controls 的策略未改。
- 镜头调节与五参数调节互斥未改。

## 6. 五参数保护

本轮没有改动五参数控制台：

- `EV / WB / TINT / ISO / S` 结构不变。
- TINT 仍是 RESET，不是 AUTO。
- WB 调节仍保留 TINT。
- TINT 调节仍保留 WB Kelvin。
- WB AUTO 后 TINT 仍回 0。
- ISO 非 Auto 时 Shutter LOCK 合同未改。
- Focus 没有回到底部五参数栏。

## 7. 修改文件

- `CaptureScreen.swift`
  - 移除取景区 EV runtime badge。
  - 删除不再使用的 `CaptureRuntimeBadge`。
  - 删除 preview workspace 外框 stroke。
  - 精简镜头 zoom panel 标题、外框和内部容器边框。

- `CaptureLivePreviewView.swift`
  - 弱化比例参考线，降低取景区亮线干扰。

- `README.md`
  - 增加 R52 报告索引。

## 8. 验证

- `xcodebuild -project /Users/sungning/Projects/SellerCamera/SellerCamera.xcodeproj -scheme SellerCamera -configuration Debug -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO build`
  - 结果：通过。

- `python3 -m json.tool /Users/sungning/Projects/SellerCamera/docs/reports/r52_viewfinder_visual_noise_and_lens_ruler_simplification.json`
  - 结果：通过。

真机未在本轮自动运行，因此仍需人工确认：

- 取景区左上角 EV 状态是否已从真机画面消失。
- preview 外框是否足够弱，不再形成明显白框。
- 镜头刻度是否只保留必要刻度、浮窗和指针。
- 镜头横向调节、双指缩放和点击取景区关闭是否在真机上继续稳定。

## 9. 边界

本轮没有：

- 修改 EV / WB / TINT / ISO / Shutter runtime 写入路径。
- 修改 WB / TINT 组合写入合同。
- 修改 TINT RESET 合同。
- 修改 ISO / Shutter LOCK 合同。
- 修改镜头底层 zoom 系统。
- 修改点击对焦或长按 AE/AF Lock。
- 修改白底图处理 pipeline。
- 修改拍后 Review / Save / Generate 流程。
- 新增 Focus 控件或让 Focus 回到底部五参数栏。

## 10. 遗留风险

- 比例参考线仍保留 7% 白色透明度；如真机上仍觉得有框感，下一轮可进一步降到 0 或仅在构图辅助开启时显示。
- 镜头刻度的暗色衬底仍保留，用于保证刻度可读性；是否还需要更轻，需要真机截图判断。
- 本轮未做真机自动运行，视觉减法结果仍需真实设备确认。

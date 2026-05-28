# R48 拍摄页参数控制台代码清理收口

日期：2026-05-23  
任务：第 28 包：拍摄页参数控制台代码清理收口 —— 删除无用残留、合并重复样式、降低维护风险

## 1. 清理背景

R36-R47 连续完成了底部五参数从 `FOCUS / EV / WB / ISO / S` 到 `EV / WB / TINT / ISO / S` 的结构调整、TINT RESET 合同、横向精密刻度尺、底部覆盖式控制层、镜头同风格调节与视觉统一。多轮方向切换后，拍摄页代码中存在旧竖向滚轮、旧 PARAMS 面板、Focus 五参数分支、TINT AUTO 旧语义和过渡样式残留的维护风险。

本包只做低风险代码清理，不新增功能，不改变 runtime 写入合同，不改变白底或拍后流程。

## 2. 核查范围

已核查：

- `SellerCamera/CaptureScreen.swift`
  - 五参数 active 状态、tick 生成、横向刻度尺映射、底部覆盖层、镜头调节、Focus 残留、旧 PARAMS overlay、旧竖向滚轮状态与 handler。
- `SellerCamera/CaptureBottomParameterBar.swift`
  - 横向刻度尺正式主线、旧短竖向滚轮组件、AUTO / RESET / LOCK 胶囊、当前值浮窗、五参数 glyph 与去格子化样式。
- `SellerCamera/CaptureProfessionalParameterPanel.swift`
  - 旧大参数面板 UI、旧 panel style、仍被当前状态模型复用的参数类型与状态结构。
- `SellerCamera/CaptureLivePreviewView.swift`
  - 仅做残留搜索，不修改；保留双指缩放、点击对焦、长按 AE/AF Lock 与 runtime 能力。
- `README.md`
  - 补充 R48 索引，不删除历史报告。

## 3. 删除与收口内容

### 旧竖向滚轮残留

已从 `CaptureBottomParameterBar.swift` 删除：

- `CaptureWheelDisplayTick`
- `CaptureCompactParameterWheelItem`
- `CaptureCompactParameterWheelPanel`
- `CaptureCompactVerticalWheelColumn`

已从 `CaptureScreen.swift` 删除对应旧链路：

- `compactWheelItems`
- `compactWheelItem(for:)`
- `compactWheelTicks(for:)`
- `wheelTicks(...)`
- `focusWheelTicks`
- `exposureCompensationWheelTicks`
- `whiteBalanceWheelTicks`
- `isoWheelTicks`
- `tintWheelTicks`
- `shutterWheelTicks`

当前正式调节主线只保留横向精密刻度尺。

### Focus 五参数残留

已删除 Focus 作为底部滚轮参数时使用的旧状态与 handler：

- `pendingFocusWheelPosition`
- `pendingFocusUpdatedAt`
- `lastDispatchedFocusPosition`
- `focusPendingTimeout`
- `stepFocusWheel(by:)`
- `applyFocusAutoFromWheel()`
- `focusWheelPositions()`
- `nearestFocusWheelPosition(...)`
- `logFocusWheel(...)`

保留 Focus runtime 与状态读取能力，用于后续独立 Focus 系统；Focus 不回到底部五参数栏。

### 旧 PARAMS / 大参数面板残留

已删除当前拍摄页不再接入的旧 overlay 与旧面板 UI：

- `CaptureFloatingParameterOverlay`
- `CaptureFloatingLensZoomOverlay`
- `CaptureProfessionalParameterEntryBar`
- `CaptureProfessionalParameterPanelContainer`
- `CaptureProfessionalDialPanel`
- `CaptureProfessionalLinearPanel`
- `CaptureProfessionalPlaceholderPanel`
- `CaptureProfessionalPanelHeader`
- `CaptureDialScaleControl`
- `CaptureLinearScaleControl`

已删除旧面板 handler：

- `handlePanelDialChange`
- `handlePanelAuto`
- `handlePanelReset`

旧 PARAMS 面板未重新接入正式主线。

### TINT AUTO 残留

通过删除旧面板 auto handler 与旧 UI 分支，移除了 TINT 通过旧 PARAMS 路径误走 Auto 的残留风险。当前正式合同保持：

- TINT = RESET，不是 AUTO。
- TINT RESET 只归零色偏。
- WB AUTO 后 TINT 回 0。
- WB 调节保留 TINT。
- TINT 调节保留 WB Kelvin。

### 命名和样式收口

- 将旧 `compactWheelDragThreshold` / `compactWheelMaximumStepCount` 命名收口为 `rulerDragThreshold` / `rulerMaximumStepCount`，避免横向刻度尺继续携带竖向滚轮语义。
- 删除旧 `CaptureProfessionalParameterPanelStyle` 与 `panelStyle` 字段；横向控制台不再依赖旧面板样式选择。
- 通过删除旧面板 UI，移除了旧面板内重复的颜色、尺寸、滑条、刻度和 header 样式实现。
- 未引入复杂主题系统；现有横向控制台样式继续集中在当前组件的私有 style 常量中。

## 4. 保留代码与原因

- 保留 `CaptureProfessionalParameterKind / Mode / State`：当前横向刻度尺、底部参数行和 `CaptureScreen.parameterState(for:)` 仍复用这些轻量状态结构。
- 保留 `parameterState(for: .focus)` 及 Focus 状态显示 helper：Focus 已从底部五参数入口移出，但该状态可作为后续独立 Focus 系统前置数据，不接入当前五参数主线。
- 保留 gated by `#if DEBUG` 的 EV / WB / TINT / ISO / Shutter 低频日志：这些日志用于 runtime 写入、pending 回收和真机问题定位，未在 Release 下输出。
- 保留历史 Rxx 报告：本包只更新索引，不删除历史文档。

## 5. 功能合同保护

本包未改动：

- 五参数结构：`EV / WB / TINT / ISO / S`。
- EV 写入路径与 RESET 合同。
- WB AUTO 合同。
- WB 调节保留 TINT。
- TINT RESET 合同。
- TINT 调节保留 WB Kelvin。
- ISO AUTO 合同。
- ISO 非 Auto 时 Shutter LOCK 合同。
- Shutter AUTO 合同。
- 镜头焦段能力判断、镜头切换与 zoom 写入路径。
- 双指缩放。
- 点击对焦与长按 AE/AF Lock。
- 白底处理链路。
- 拍后 Review / Save / Generate 流程。
- 横向精密刻度尺控制台。
- 底部覆盖式控制层。
- 拍摄按钮 / 最近 / 图册入口。

## 6. 构建验证

执行：

```bash
xcodebuild -project /Users/sungning/Projects/SellerCamera/SellerCamera.xcodeproj -scheme SellerCamera -configuration Debug -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO build
```

结果：通过，`BUILD SUCCEEDED`。

备注：构建日志仍出现历史嵌套工程路径警告：

```text
Project /Users/sungning/Projects/SellerCamera/SellerCamera/SellerCamera.xcodeproj cannot be opened because it is missing its project.pbxproj file.
```

该警告不阻断当前 target 构建。

## 7. 真机验证

未执行真机安装与交互验证。本包为代码清理包，当前已完成 simulator generic build 验证；仍建议下一轮如进入独立 Focus 前，在真机上快速确认：

- 五参数仍正常显示与展开。
- 横向控制台仍可调 EV / WB / TINT / ISO / S。
- 镜头调节仍可展开。
- 双指缩放、点击对焦、长按 AE/AF Lock 不回归。
- 拍摄按钮与拍后流程不回归。

## 8. 遗留风险

- `CaptureProfessionalParameterState` 仍保留部分旧面板时代字段，例如 hint、dial labels、dial range；其中一部分仍可服务横向刻度尺 fallback 和未来 Focus 前置，不在本包继续收缩，避免过度清理。
- EV / WB / TINT / ISO / Shutter DEBUG 日志仍保留，后续如真机链路稳定后可另包降噪。
- `CaptureScreen.swift` 仍承担较多页面装配与状态路由职责；本包未做架构拆分，避免扩大风险。

## 9. 下一步建议

建议下一包进入独立 Focus 对焦系统 UI 方案与接入前置，明确 Focus 从底部栏移出后的 AF / MF / LOCK 独立入口，不影响当前 `EV / WB / TINT / ISO / S` 参数控制台。

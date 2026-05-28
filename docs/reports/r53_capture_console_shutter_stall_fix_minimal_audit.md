# R53 Shutter 调参后交互卡顿修复与最小性能体检报告

日期：2026-05-24

## 1. 背景

真机反馈指出：横向调节 `S / Shutter` 后，取景画面确实发生变化，说明 Shutter runtime 写入已经生效；但随后点击 `EV / WB / TINT / ISO / S` 其它参数入口无反应，表现为交互被阻塞或短时间卡顿。

本轮只处理该交互稳定性问题和最小性能体检，不新增 Focus，不改白底图处理，不改拍后流程，不改变五参数功能合同。

## 2. 问题定位

本轮重点核查了：

- `CaptureHorizontalParameterRulerPanel` 的 panel 级 drag 状态。
- `CaptureHorizontalParameterRuler` 的横向拖动状态释放。
- `CaptureScreen` 中底部 overlay 展开 / 收起、active 参数切换和 Shutter pending 收口。
- `CaptureCameraRuntime.setShutterDialValue(_:)` 到 `applyShutterPreset(.custom)` 的写入路径。

定位结论：

- Shutter 写入路径本身已经走现有 runtime，且 `lockForConfiguration` 在 `sessionQueue` 中执行，不是直接在 SwiftUI 主线程内锁配置。
- Shutter 每次 tick 变化会触发相机配置写入，比 EV / WB / TINT / ISO 更重；原横向 ruler 对所有参数使用统一 `0.08s` step 冷却，Shutter 在快速拖动时仍可能过密触发写入。
- 横向 ruler 的 `isDragInProgress` / panel 的 `isRulerDragging` 主要依赖 `DragGesture.onEnded` 释放；如果 Shutter runtime 回写导致 active item / view 重建或手势中断，存在父层 drag 状态残留风险。
- panel 级下滑关闭逻辑会参考 `isRulerDragging` 和最近拖动时间。如果 drag 状态残留，可能造成后续交互判断不稳定。

因此本轮采用最小修复：强化 drag 状态释放，并单独降低 Shutter step 触发频率。

## 3. 修复措施

### 3.1 ruler drag 状态强制释放

在 `CaptureHorizontalParameterRuler` 中新增统一结束方法：

- 手势正常结束时释放 `isDragInProgress`。
- 视图消失时也释放 `isDragInProgress`，并通知父层 `onDragStateChange(false)`。
- 清空 `lastDragStepTranslation` 和 `dragOffset`，避免下次参数切换沿用旧拖动累计。

这样即使 Shutter 写入导致 SwiftUI 重建 ruler，也不会把父层长期留在 dragging 状态。

### 3.2 panel drag 状态切参 / 消失清理

在 `CaptureHorizontalParameterRulerPanel` 中增加：

- active 参数变化时重置 `isRulerDragging`。
- panel 消失时重置 `isRulerDragging`。
- 参数入口点击前先释放 panel drag tracking，再交给 `CaptureScreen` 切换 active。

这样 Shutter 调参后点击 `EV / WB / TINT / ISO` 不会被旧 drag 状态影响。

### 3.3 Shutter 专用 step 冷却

横向 ruler 保留其它参数 `0.08s` step 冷却，但对 Shutter 单独提升为 `0.16s`：

- 降低 Shutter 高频写入 AVCaptureDevice 配置的概率。
- 保持 tick 变化才写入、同值不重复写入、边界不重复写入的既有逻辑。
- 不改变 Shutter runtime 写入合同，不改变 Shutter 档位和显示语义。

## 4. 五参数体检结果

- `EV`：tick、RESET、pending 收口和 runtime 写入路径未改。
- `WB`：Kelvin、AUTO、WB 调节保留 TINT 的合同未改。
- `TINT`：仍为 RESET，不是 AUTO；G / M 显示和 `setWhiteBalanceTintDialValue(_:)` 路由未改。
- `ISO`：AUTO、manual ISO、ISO 非 Auto 时 Shutter LOCK 合同未改。
- `Shutter`：AUTO、manual shutter、ISO Auto 时可调、ISO 非 Auto 时 LOCK 合同未改；本轮只加更保守 UI step 冷却和 drag 状态释放。

## 5. Overlay / Hit-test / Gesture 体检结果

已核查：

- 底部常态 action bar 在参数或镜头 overlay 展开时使用 `.allowsHitTesting(false)`，不会与 overlay 同时抢点击。
- 参数 overlay 展开时仍由 `CaptureHorizontalParameterRulerPanel` 承担参数入口点击和横向 ruler 拖动。
- active 参数切换不触发 runtime 写入。
- 点击取景区关闭 inline controls 的路径未改。
- 镜头调节与五参数调节互斥逻辑未改。

本轮未发现需要重写 overlay 层级的证据，因此没有做大范围 zIndex / hit-test 重构。

## 6. 性能收口

本轮只做最小性能收口：

- Shutter 横向 ruler step 冷却从通用 `0.08s` 提升到 `0.16s`。
- 保留 tick 变化才写入的 UI 层去重。
- 保留 `stepShutterWheel(by:)` 中 pending / lastDispatched / boundary 去重。
- 保留 runtime 在 `sessionQueue` 中执行相机配置写入。

未做：

- 未重构 camera runtime。
- 未把 runtime 写入改为新的队列系统。
- 未移除真实 Shutter 写入。

## 7. 修改文件

- `SellerCamera/CaptureBottomParameterBar.swift`
  - 增加 horizontal ruler 视图消失时的 drag 状态释放。
  - 增加 panel active 参数变化 / panel 消失时的 dragging 状态清理。
  - 参数入口点击前释放 panel drag tracking。
  - 对 Shutter 使用更保守的 `0.16s` ruler step cooldown。

- `README.md`
  - 增加 R53 报告索引。

- `docs/reports/r53_capture_console_shutter_stall_fix_minimal_audit.md`
  - 本报告。

- `docs/reports/r53_capture_console_shutter_stall_fix_minimal_audit.json`
  - 本轮结构化记录。

## 8. 验证

- `xcodebuild -project /Users/sungning/Projects/SellerCamera/SellerCamera.xcodeproj -scheme SellerCamera -configuration Debug -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO build`
  - 结果：通过。

- `python3 -m json.tool /Users/sungning/Projects/SellerCamera/docs/reports/r53_capture_console_shutter_stall_fix_minimal_audit.json`
  - 结果：通过。

真机仍需验证：

- Shutter 调参后 `EV / WB / TINT / ISO / S` 是否全部可点击展开。
- Shutter 调参后点击取景区是否仍可关闭 inline controls。
- Shutter 调参时是否仍能真实改变预览。
- 是否还有 1 秒以上不可响应或隐藏层挡点击。

## 9. 边界

本轮没有：

- 新增 Focus，或让 Focus 回到底部五参数栏。
- 修改 EV / WB / TINT / ISO / Shutter 产品合同。
- 修改 WB / TINT 组合写入合同。
- 修改 TINT RESET 合同。
- 修改 ISO / Shutter LOCK 合同。
- 修改镜头底层 zoom 系统。
- 修改点击对焦或长按 AE/AF Lock。
- 修改白底图处理 pipeline。
- 修改拍后 Review / Save / Generate 流程。
- 做大规模 UI 改版或 CaptureScreen 重构。

## 10. 遗留风险

- 本轮修复基于代码路径和最小构建验证，无法替代真机触控验证。
- 如果真机上仍出现卡顿，需要继续观察 Shutter 写入频率、runtime 回写节奏和是否存在设备级 `AVCaptureDevice` 配置延迟。
- 当前仅对 Shutter 做更保守 step 冷却；如其它重参数后续出现类似问题，可按相同模式逐项收口。

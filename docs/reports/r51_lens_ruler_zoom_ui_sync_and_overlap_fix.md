# R51 镜头焦段调节 UI 同步与重叠修复报告

日期：2026-05-24

## 1. 背景

R50 后五参数贴合式刻度层已经完成点击取景区关闭、展开动效和指针对齐修正。真机反馈进一步指出镜头焦段调节仍存在独立问题：

- 横向滑动镜头调节时，真实 zoom 已经变化。
- 镜头调节 UI 没有同步变化，看起来刻度不动。
- 当前值浮窗、中心指针、刻度标签有重叠。

这说明镜头 runtime 写入路径基本可用，本轮只修镜头 ruler 的 selected value、pending display、offset、吸附和防重叠，不改镜头底层系统，也不改 EV / WB / TINT / ISO / Shutter 合同。

## 2. 根因

镜头调节旧实现采用“手势位置直接映射 zoom progress”的方式：

- 拖动时直接根据手指位置调用 `setLensZoomDialValue(_)`。
- UI 没有本地 pending zoom，因此 runtime 回写前当前值浮窗可能仍显示旧值。
- 刻度内容是静态 progress 布局，没有基于 selected tick 的 offset 模型，拖动时视觉上缺少“刻度随手移动”的反馈。
- selected tick 没有统一吸附到固定中心指针下方。
- 当前值、标题和 tick label 的垂直层级过近，容易形成重叠。

因此问题不是 zoom runtime 不可用，而是 lens ruler UI 状态模型没有和五参数横向 ruler 的反馈标准对齐。

## 3. 本轮修复

### 3.1 Pending zoom 显示

`CaptureLensZoomControlPanel` 新增本地 pending 状态：

- `pendingLensZoomValue`
- `lastDispatchedLensZoomValue`
- `lastLensZoomPendingAt`

显示优先级调整为：

```text
pendingLensZoomValue
> cameraRuntime.lensZoomDialValue
```

用户横向拖动后，当前值浮窗立即显示 pending zoom，不再等待 runtime 回写。

### 3.2 Selected tick 与 offset

镜头 tick 现在由当前 lens range 和 display zoom 生成：

- 按当前 `cameraRuntime.lensZoomDialRange` 裁剪。
- 自动加入 lower / upper / current display value。
- 去重排序。
- 根据 display zoom 计算最近 tick index。

`CaptureZoomDialView` 改为 selected tick + drag offset 模型：

```swift
centerX - CGFloat(selectedIndex) * tickSpacing - tickSpacing / 2 + dragOffset
```

这样静止和吸附后，selected tick 的视觉中心会回到固定中心指针下方。

### 3.3 拖动反馈与吸附

镜头 ruler 拖动时：

- `dragOffset` 跟随手指横向位移。
- 超过阈值后按离散 tick step 写入目标 zoom。
- 写入成功后更新 pending zoom。
- 同一 zoom 不重复写入。
- 滑动结束后 `dragOffset` 归零，刻度吸附回 selected tick。
- 触觉反馈只在真实 step 生效时触发。

### 3.4 Runtime 回写收口

当 `cameraRuntime.lensZoomDialValue` 接近 pending zoom 时：

- 清除 pending。
- 清除 last dispatched。
- UI 回到 runtime confirmed value。

如果 runtime 回写超过合理时间仍未接近 pending，本轮会清除 pending，避免 UI 长时间挂在过期目标值。

切换镜头 profile 时也会清除 pending，避免上一镜头的 zoom 目标污染下一镜头 UI。

## 4. 双指缩放同步策略

本轮不改双指缩放 runtime。

当没有 lens pending zoom 时，镜头调节面板读取 `cameraRuntime.lensZoomDialValue`。因此双指缩放改变 zoom 后：

- 当前值浮窗会使用 runtime zoom。
- tick 列表会自动插入当前 zoom。
- selected tick 会重新计算到当前 zoom 最近位置。

如果双指缩放产生连续 zoom 且不在离散 tick 上，UI 会把该值加入 tick 列表用于显示和对齐，不会为了 UI tick 强行改写 runtime zoom。

## 5. 重叠修复

为避免当前值浮窗、指针和 tick label 重叠，本轮做了以下收口：

- 顶部右侧重复 current zoom 文案移除，只保留左侧标题。
- 中心浮窗只显示简短 zoom 值，例如 `1.0x`。
- 主刻度 label 只显示 sampled major tick。
- 次刻度不显示文字。
- 中心指针沿用 R50 的短指针风格。
- 当前值浮窗位于刻度上方，tick label 位于刻度下方。
- `tickSpacing`、label frame、panel padding 重新收敛，避免极端值挤压。

## 6. 修改文件

- `CaptureScreen.swift`
  - 修复 `CaptureLensZoomControlPanel` 的 pending zoom、selected tick、runtime 回写收口。
  - 重写 `CaptureZoomDialView` 为 selected tick + drag offset 的镜头 ruler。
  - 优化镜头 ruler 的 value badge、中心指针、tick label 密度和吸附逻辑。

- `README.md`
  - 增加 R51 报告索引。

## 7. 验证

- `xcodebuild -project /Users/sungning/Projects/SellerCamera/SellerCamera.xcodeproj -scheme SellerCamera -configuration Debug -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO build`
  - 结果：通过。

- `python3 -m json.tool /Users/sungning/Projects/SellerCamera/docs/reports/r51_lens_ruler_zoom_ui_sync_and_overlap_fix.json`
  - 结果：通过。

真机未在本轮自动运行，因此以下项仍需人工确认：

- 镜头横向滑动时，UI 是否在真机上明显跟随 zoom。
- 刻度移动是否足够顺滑。
- 当前值浮窗、中心指针、tick label 是否仍有 1-2pt 级别重叠。
- 双指缩放后 lens overlay 是否稳定显示最新 zoom。

## 8. 边界

本轮没有：

- 修改 EV / WB / TINT / ISO / Shutter runtime 写入合同。
- 修改 WB / TINT 组合写入合同。
- 修改 TINT RESET 合同。
- 修改 ISO / Shutter LOCK 合同。
- 修改镜头底层 zoom 系统。
- 修改点击对焦或长按 AE/AF Lock。
- 修改白底图处理 pipeline。
- 修改拍后 Review / Save / Generate 流程。
- 新增 Focus 控件或让 Focus 回到底部五参数栏。

## 9. 遗留风险

- 真机 UI 跟随和防重叠仍需人工截图确认。
- 本轮采用离散 tick ruler；双指缩放产生连续 zoom 时会插入临时当前值用于显示，后续如果需要更强的连续 zoom 手感，可单独做镜头调节手感包。
- 极端设备 zoom range 很大时，major label 采样仍可能需要按真实设备再做一次密度微调。

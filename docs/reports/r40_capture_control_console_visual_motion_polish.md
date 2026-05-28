# R40 拍摄页专业控制台视觉质感 + 动效手感打磨报告

## 1. 本包定位

- 包类型：UI 视觉与动效打磨包。
- 范围：仅优化底部五参数控制台的视觉层级、active 状态、滚轮刻度、控制按钮语义和展开/收起动画。
- 边界：不改 runtime 写入合同，不改白底链路，不改拍后流程，不新增 Focus 控件。

## 2. 视觉打磨范围

1. 底部五参数栏背景：
   - 从单层黑色半透明提升为深色渐变 + material + 双层细描边；
   - 增加克制阴影，强化专业相机控制台的悬浮层级；
   - 保持原高度，不扩大为大控制台。
2. 参数项 active 状态：
   - active 项增加轻填充、描边和微弱 glow；
   - 当前值继续使用 `monospacedDigit()`，减少数值变化时的左右跳动；
   - 数值变化增加轻微 opacity/scale 过渡。
3. 展开面板：
   - 背景改为更有层次的深色渐变 + thin material；
   - 保持面板高度与五列结构，不改变拍摄按钮可见性。

## 3. 滚轮刻度样式变化

- 中心值增加轻微描边背景和 active scale；
- 相邻刻度进一步弱化透明度；
- active 列中心线和当前值更清楚；
- 未改变滚轮数据源、写入触发或参数合同。

## 4. AUTO / RESET / LOCK 样式变化

1. AUTO 开启态：
   - 当参数值为 `A` 时，按钮使用更明确的强调色填充。
2. AUTO 关闭态：
   - 保持弱填充，可点击恢复 Auto。
3. RESET：
   - 保持动作按钮语义，不表现为开启/关闭开关。
4. LOCK：
   - 禁用态弱化显示，不触发写入，不抢主视觉。

## 5. 动效打磨范围

1. 展开/收起：
   - 增加 0.18s `easeOut` 动画；
   - 展开从底部上浮并淡入，收起向下淡出。
2. 参数切换：
   - active 切换使用 0.14-0.16s 轻动画；
   - 当前值变化使用轻微 opacity/scale 过渡。
3. 触觉反馈：
   - 保持现有轻触觉策略；
   - 未引入 heavy feedback，也未增加高频反馈。

## 6. 功能合同保护

本包未改变以下合同：

- 底部五参数仍为 `EV / WB / TINT / ISO / S`；
- Focus 不回到底部栏；
- TINT 仍为 `RESET`，不是 `AUTO`；
- WB 调节保留 TINT，TINT 调节保留 WB Kelvin；
- WB AUTO 后 TINT 回 0；
- ISO 非 Auto 时 Shutter LOCK；
- EV/WB/TINT/ISO/Shutter 写入路径未改。

## 7. 修改文件

- `SellerCamera/CaptureBottomParameterBar.swift`
- `SellerCamera/CaptureScreen.swift`
- `README.md`
- `docs/reports/r40_capture_control_console_visual_motion_polish.md`
- `docs/reports/r40_capture_control_console_visual_motion_polish.json`

## 8. 验证结果

- 已执行 iOS Simulator Debug 构建：
  - `xcodebuild -project /Users/sungning/Projects/SellerCamera/SellerCamera.xcodeproj -scheme SellerCamera -configuration Debug -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO build`
- 结果：通过（见本轮回报）。
- 真机视觉与动效体感：本轮未在当前会话内完成真机安装/人工观察，仍需后续用真实设备确认。

## 9. 遗留风险

1. 视觉质感已在代码层打磨，但“是否足够高级/顺手”仍需真机主观确认。
2. 小屏拥挤度需要在具体设备上继续看一眼，尤其是 `TINT` 与 Shutter 长值。
3. 下一包应进入独立 Focus 对焦系统方案，不应回头扩展五参数功能。


# R47 底部控制台视觉统一收口

日期：2026-05-23  
任务：第 27 包：底部控制台视觉统一收口 —— 去除五参数外框格线 + 镜头焦距调节样式对齐 + 底部动作区继续下移

## 1. 背景

R46 已完成底部动作区缩小、参数展开覆盖底部动作区、镜头焦段同风格低位调节入口与构建验证。但真机截图反馈显示：

- 五参数栏仍有明显外框与竖向格线，视觉像表格。
- 镜头焦段调节与五参数横向刻度尺仍像两套控件。
- 拍摄按钮、最近、图册整体还可以继续下移，贴近专业相机低位操作结构。

本包只做 UI 视觉统一与底部低位化修正，不改相机 runtime、参数写入、白底处理、拍后流程或镜头底层逻辑。

## 2. 本包完成内容

### 五参数去格子化

- 移除 `EV / WB / TINT / ISO / S` 常态入口之间的强竖向分隔线。
- 弱化五参数栏外层描边与内层描边透明度。
- 保留一体化深色圆角控制条背景。
- 保留 active 参数的青绿色轻描边、轻填充与 glow。
- 非 active 参数不再呈现独立格子边框；手动/锁定状态只保留极弱描边提示。

目标是让五参数栏从“表格式五格控件”收口成“一体化专业参数 deck”。

### 镜头焦段入口样式统一

- 将镜头焦段入口的 selected 状态从普通 `Color.teal` 胶囊改为与五参数一致的 Seller Camera 青绿色强调色。
- 非 selected 焦段去掉强边框，仅保留极弱背景和描边。
- selected 焦段保留轻填充、轻描边与 subtle glow。
- 保持设备能力驱动的焦段显示，不写死 `13mm / 24mm / 48mm / 77mm`。
- 保持点击焦段切换 / 点击当前焦段展开镜头调节的既有行为。

### 镜头调节面板向五参数横向刻度尺看齐

`CaptureZoomDialView` 从普通进度胶囊滑条调整为低位横向刻度尺语言：

- 增加当前值浮窗：`镜内 1.0x` 等。
- 增加固定中心指针。
- 增加主刻度与次刻度层级。
- 使用与五参数控制台一致的深色控制条、细描边、青绿色 active 视觉。
- 横向拖动仍调用既有 `cameraRuntime.setLensZoomDialValue(_:)`。
- 双指缩放路径未改，仍由 `CaptureLivePreviewView` 的现有手势驱动 runtime zoom。

本包没有新增镜头 runtime，也没有重写镜头切换系统。

### 底部动作区继续下移

- 将底部控制 deck 高度从 `154pt` 微收至 `150pt`。
- 将 deck 底部 padding 从 `10pt` 收至 `4pt`。
- 拍摄按钮、最近、图册常态整体更贴近底部安全区上方。
- 保留 R46 的覆盖策略：参数或镜头调节展开时，底部动作区被控制层覆盖/隐藏，收起后恢复。

## 3. 功能合同保护

本包未改动：

- EV 写入路径与 RESET 合同。
- WB AUTO 合同。
- WB 调节保留 TINT。
- TINT RESET 合同。
- TINT 调节保留 WB Kelvin。
- ISO AUTO 合同。
- ISO 非 Auto 时 Shutter LOCK 合同。
- Shutter AUTO 合同。
- 五参数结构 `EV / WB / TINT / ISO / S`。
- Focus 不回到底部五参数栏。
- 镜头焦段能力判断与底层切换逻辑。
- 双指缩放路径。
- 点击对焦与长按 AE/AF Lock。
- 白底处理链路。
- 拍后 Review / Save / Generate 流程。

## 4. 修改文件

- `SellerCamera/CaptureBottomParameterBar.swift`
  - 五参数栏去格子化。
  - 弱化外框 / 内框描边。
  - 移除强竖向分隔线。
  - 弱化非 active 手动态描边。
- `SellerCamera/CaptureScreen.swift`
  - 底部 deck 继续下移。
  - 镜头焦段入口视觉与五参数 active 语言对齐。
  - 镜头 zoom 调节从胶囊滑条改为横向刻度尺式视觉。
  - 新增镜头刻度中心指针形状。
- `README.md`
  - 新增 R47 报告索引。

## 5. 构建验证

执行：

```bash
xcodebuild -project /Users/sungning/Projects/SellerCamera/SellerCamera.xcodeproj -scheme SellerCamera -configuration Debug -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO build
```

结果：通过。

备注：构建日志仍出现历史嵌套工程路径警告：

```text
Project /Users/sungning/Projects/SellerCamera/SellerCamera/SellerCamera.xcodeproj cannot be opened because it is missing its project.pbxproj file.
```

该警告不阻断当前 target 构建，最终 `BUILD SUCCEEDED`。

## 6. 真机验证

未执行真机安装与交互验证。

仍需真机确认：

- 五参数外框格线是否已显著弱化到不再像表格。
- 镜头调节面板是否与五参数横向刻度尺形成同一视觉语言。
- 底部动作区继续下移后是否仍避开 Home indicator。
- 双指缩放、镜头调节、点击对焦、长按 AE/AF Lock 是否在真实设备上全部不回归。

## 7. 遗留风险

- 镜头调节已视觉上对齐五参数横向刻度尺，但仍是镜头专用轻量组件，不是完全复用五参数 tick renderer。
- 本包仅做 simulator build 验证，没有真机截图确认。
- 底部下移幅度保持保守，后续如果真机仍偏高，需要结合具体设备截图继续微调 safe-area padding。

## 8. 下一步建议

建议下一包进入独立 Focus 对焦系统 UI 方案与接入前置，明确 Focus 从底部栏移出后的 AF / MF / LOCK 独立入口，不回退到五参数栏。

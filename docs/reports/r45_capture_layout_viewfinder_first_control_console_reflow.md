# R45 拍摄页取景主体优先布局收口

日期：2026-05-23  
任务：第 25 包：拍摄页空间结构重排 —— 参数控制低位收纳，不侵占取景主体

## 1. 背景

R44 已将底部五参数展开区升级为 Seller Camera 原创横向精密刻度尺控制台，但真机/视觉反馈指出：控制台虽然更专业，空间结构仍然偏重，展开后会挤占取景主体。

本包只处理垂直空间结构，不新增参数能力，不改变 runtime 写入合同，不改白底与拍后流程。

## 2. 本包目标

本包目标是让拍摄页重新回到“取景主体优先”：

- 参数控制区低位收纳。
- 横向刻度尺保持低矮、紧凑。
- 当前值浮窗留在控制条内部。
- 镜头焦段入口和拍摄按钮继续清楚可用。
- 小屏上减少控制区对取景区域的挤占。

## 3. 布局调整

### 底部五参数常驻栏

- 常驻栏高度从 62pt 收紧到 56pt。
- 图标和值字号略微收紧。
- 横向 padding 略减。
- 保留 EV / WB / TINT / ISO / S 五参数结构。

### 横向刻度尺展开控制台

- 展开面板高度从 178pt 收紧到 150pt。
- 面板内部垂直间距从 8pt 收紧到 6pt。
- 面板上下 padding 从 9pt 收紧到 6pt。
- 参数入口行高度从 48pt 收紧到 42pt。
- 横向刻度尺行高度从 82pt 收紧到 68pt。

这些调整让展开状态少挤占 28pt 垂直空间，同时保留横向刻度尺、当前值浮窗、中心指针和右侧胶囊控件。

### 当前值浮窗

- 当前值浮窗位置从更高处下收，保持在横向刻度尺控制条内部。
- 浮窗字体、padding 轻微收缩。
- 目标是避免数值牌漂浮到商品主体取景区域。

### 胶囊控件

- AUTO / RESET / LOCK 胶囊宽度从 68pt 收紧到 60pt。
- 胶囊高度从 30pt 收紧到 28pt。
- 保留状态语义，不改变行为：
  - WB / ISO / Shutter：AUTO。
  - EV / TINT：RESET。
  - Shutter locked：LOCK。

### 页面垂直间距

- 意图切换条与参数区之间的 padding 收紧。
- 参数区与拍摄按钮之间的 padding 收紧。
- 拍摄按钮底部安全区仍保留，不通过挤压拍摄按钮换取空间。

## 4. 取景主体保护

本包没有将参数面板改为覆盖式大浮层，而是继续将控制台放在底部布局流中，并降低其高度。这样参数展开时：

- 不遮挡商品主体。
- 不覆盖镜头焦段入口。
- 不覆盖拍摄按钮。
- 不改变点击取景区收起逻辑。
- 不改变横向滑动调参逻辑。

## 5. 小屏适配

本包采用低风险紧凑化策略：

- 收紧参数入口行高度。
- 收紧横向刻度尺高度。
- 减少主/次刻度标签字号和标签高度。
- 缩小当前值浮窗。
- 缩小右侧胶囊控件。

没有隐藏任何参数，也没有扩大为大控制面板。

## 6. 功能合同保护

本包未改动：

- EV 写入路径与 RESET 合同。
- WB AUTO 合同。
- WB 调节保留 TINT。
- TINT RESET 合同。
- TINT 调节保留 WB Kelvin。
- ISO AUTO 合同。
- ISO 非 Auto 时 Shutter LOCK 合同。
- Shutter AUTO 合同。
- Focus 不回到底部五参数栏。
- 点击对焦与长按 AE/AF Lock。
- 白底处理链路。
- 拍后 Review / Save / Generate 流程。
- 镜头切换系统。

## 7. 修改文件

- `SellerCamera/CaptureBottomParameterBar.swift`
  - 压缩常驻五参数栏高度。
  - 压缩横向刻度尺展开面板高度。
  - 压缩当前值浮窗、刻度尺、胶囊控件尺寸。
- `SellerCamera/CaptureScreen.swift`
  - 收紧意图切换、参数区和拍摄按钮之间的垂直间距。
- `README.md`
  - 新增 R45 报告索引。

## 8. 构建验证

执行：

```bash
xcodebuild -project /Users/sungning/Projects/SellerCamera/SellerCamera.xcodeproj -scheme SellerCamera -configuration Debug -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO build
```

结果：通过。

备注：构建日志仍出现历史嵌套工程路径警告：

```text
Project /Users/sungning/Projects/SellerCamera/SellerCamera/SellerCamera.xcodeproj cannot be opened because it is missing its project.pbxproj file.
```

该警告不阻断实际 target 构建，最终 `BUILD SUCCEEDED`。

## 9. 真机验证

本包尚未完成真机安装与截图验证。

需要后续真机确认：

- 参数展开后是否明显少占取景主体。
- 当前值浮窗是否完全避开商品主体。
- 镜头焦段入口是否仍清楚。
- 拍摄按钮是否仍清楚可点。
- 小屏上是否仍有拥挤或遮挡。

## 10. 遗留风险

- 本包通过压缩控制区解决空间问题，但未做真机截图复核，仍需要在实际设备上确认观感。
- 横向刻度尺标签变小后，小屏可读性需要真机验证。
- 如仍觉得取景区被挤占，下一步应优先进一步下沉或条件化折叠控制台，而不是扩大控制面板。

## 11. 下一步建议

下一包可以进入独立 Focus 对焦系统 UI 方案与接入前置，但建议先用真机截图确认 R45 低位收纳后的空间结构是否达标。

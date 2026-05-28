# R44 Seller Camera 原创控制台与横向刻度尺

日期：2026-05-23  
任务：第 24 包：Seller Camera 拍摄页原创专业设计系统 + 五参数横向刻度尺控制台

## 1. 背景

R43 后，底部五参数保持为：

```text
EV / WB / TINT / ISO / S
```

飓风相机公开 UI 调研得到的可借鉴原则是：低位调参、不离开拍摄页、当前值浮窗、横向刻度表达、AUTO 状态强表达、active 参数明确高亮。

本包不复制飓风相机图标、素材或品牌样式，只将这些原则转化为 Seller Camera 自己的专业商品拍摄控制台。

## 2. 本包完成内容

### 原创视觉系统

- 建立了新的拍摄控制台视觉 token：
  - 深色半透明控制台背景。
  - 青绿色主强调色。
  - 琥珀色用于 RESET 动作按钮。
  - 低透明白色细描边。
  - monospaced digit 用于参数值与刻度。
- 继续保持暗色、克制、专业相机仪表感。

### 原创五参数图标

在底部参数入口中加入 Seller Camera 自绘参数 glyph：

- `EV`：半明半暗圆 + `+/-`，表达曝光补偿。
- `WB`：分割圆 + 中轴，表达冷暖平衡。
- `TINT`：双向微调滑杆，表达绿/品红偏移。
- `ISO`：感光芯片 + ISO 字样。
- `S`：简化快门叶片。

这些图标由 SwiftUI 基础形状组合，不使用第三方素材，也不复制竞品图标。

### 横向刻度尺控制台

展开状态从五列短竖轮改为：

```text
五参数入口行
当前 active 参数的横向精密刻度尺
右侧 AUTO / RESET / LOCK 胶囊控制区
```

同一时间只显示当前 active 参数的横向刻度尺。

### 当前值浮窗与中心指针

- active 参数的当前值显示为中心浮动值牌。
- 中心指针固定在刻度尺中间。
- 刻度内容横向移动，最近中心指针的 tick 作为目标值。
- pending 值仍通过既有 `bottomParameterValueText` 优先显示。

### AUTO / RESET / LOCK 胶囊控制区

- `WB / ISO / Shutter AUTO`：胶囊状态控件，开启态高亮，关闭态弱化。
- `EV / TINT RESET`：琥珀色动作胶囊，不表现为开关。
- `Shutter LOCK`：灰色禁用胶囊，不触发写入。

## 3. 交互实现

- 横向拖动刻度尺调用既有 `onWheelStep(kind, step)`。
- 写入仍走既有：
  - EV：`stepExposureCompensationWheel`
  - WB：`stepWhiteBalanceWheel`
  - TINT：`stepTintWheel`
  - ISO：`stepISOWheel`
  - Shutter：`stepShutterWheel`
- AUTO / RESET 仍走既有 `onControlTap` 路由。
- 切换 active 参数只切换 UI，不触发写入。
- LOCK / disabled 状态不触发写入。
- 同值去重、边界保护、pending 收口仍由既有 Screen 层逻辑负责。

## 4. Tick 映射

本包复用 R43 后的 tick 生成结果：

- EV：1/3 EV。
- WB：常用 Kelvin 精细 tick。
- TINT：常用区 step 2、极端区 step 5。
- ISO：摄影常用 1/3 stop tick。
- Shutter：精细化快门 tick。

横向刻度尺只负责展示和手势，不重新定义参数合同。

## 5. 功能合同保护

本包未改动：

- EV 写入路径与 RESET 合同。
- WB AUTO 合同。
- WB 调节保留 TINT。
- TINT RESET 合同。
- TINT 调节保留 WB Kelvin。
- ISO AUTO 合同。
- ISO 非 Auto 时 Shutter LOCK 合同。
- Shutter AUTO 合同。
- Focus 独立于底部五参数栏的方向。
- 白底处理链路。
- 拍后 Review / Save / Generate 流程。
- 镜头切换系统。

## 6. 修改文件

- `SellerCamera/CaptureBottomParameterBar.swift`
  - 新增原创参数 glyph。
  - 新增 `CaptureHorizontalParameterRulerPanel`。
  - 新增 `CaptureHorizontalParameterRuler`。
  - 新增当前值浮窗、中心指针、主/次刻度、右侧胶囊控制。
- `SellerCamera/CaptureScreen.swift`
  - 新增 `CaptureHorizontalParameterRulerItem` 映射。
  - 将展开区接入横向刻度尺面板。
  - 继续复用原有 tick 生成与写入路由。
- `README.md`
  - 新增 R44 报告索引。

## 7. 构建验证

执行：

```bash
xcodebuild -project /Users/sungning/Projects/SellerCamera/SellerCamera.xcodeproj -scheme SellerCamera -configuration Debug -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO build
```

结果：通过。

备注：构建日志仍出现历史路径警告：

```text
Project /Users/sungning/Projects/SellerCamera/SellerCamera/SellerCamera.xcodeproj cannot be opened because it is missing its project.pbxproj file.
```

该警告不阻断实际 target 构建，最终 `BUILD SUCCEEDED`。

## 8. 真机验证

未执行真机安装与交互验证。

因此本包只确认：

- Swift 编译通过。
- UI 结构已接入。
- Runtime 写入合同未在代码层改动。

尚未确认：

- 横向刻度尺真机手感。
- 当前值浮窗在真机尺寸下的精确观感。
- AUTO / RESET / LOCK 胶囊的真机可读性。
- 横向拖动是否仍需进一步阻尼微调。

## 9. 遗留风险

- 横向刻度尺从竖向手势切换为横向手势，真机上需要验证是否比旧短竖轮更顺手。
- tick 较多的 WB / TINT / Shutter 需要真机确认标签密度是否仍然清晰。
- 当前值浮窗和右侧胶囊在小屏上需要截图复核。

## 10. 下一步建议

下一包不要急着进入 Focus，实现前建议先做一轮真机 UI 交互复核：

1. 横向刻度尺滑动方向与吸附手感。
2. 当前值浮窗清晰度。
3. AUTO / RESET / LOCK 胶囊状态辨识。
4. 小屏布局。
5. 拍摄按钮与拍后流程回归。

# R46 底部操作层覆盖式重构与镜头调节接入

日期：2026-05-23  
任务：第 26 包：底部操作层重构 —— 缩小拍摄按钮/最近/图册，参数控制覆盖底部操作区，并为镜头焦段加入同风格调节

## 1. 背景

R44/R45 已经完成 Seller Camera 原创五参数横向刻度尺与低位压缩，但真机截图反馈指出：底部拍摄按钮、最近、图册仍偏大，参数展开仍以占位布局挤压取景主体。

本包转为低位覆盖式结构：

- 常态：五参数入口 + 小型拍摄动作区。
- 参数态：不透明参数控制层覆盖底部动作区。
- 镜头态：不透明镜头缩放控制层覆盖底部动作区。

## 2. 本包完成内容

### 底部动作区缩小

- 拍摄按钮视觉尺寸缩小：
  - 外白圆从 78pt 收至 70pt。
  - 内圈从 62pt 收至 56pt。
  - 外辅助圈从 88pt 收至 80pt。
  - 点击 frame 从 98pt 收至 86pt。
- 最近入口和图册入口从大卡片收缩为 64pt × 58pt 的低位入口。
- 底部动作区高度从 112pt 收至 86pt。

视觉尺寸变小，但保留独立按钮和可点击热区，不改变拍摄、最近结果、图册预留入口的行为。

### 底部固定 deck

新增底部固定高度控制 deck：

- 常态下显示五参数入口 + 小型拍摄动作区。
- 展开五参数或镜头调节时，覆盖该 deck，而不是把 preview 继续向上挤。
- 覆盖态隐藏底部动作按钮，避免拍摄按钮和刻度尺视觉混杂。
- 点击取景区会收起当前底部控制层。

### 参数覆盖层

五参数横向刻度尺继续保留 R44/R45 方向，但从“额外占位”改为覆盖底部动作区：

- `EV / WB / TINT / ISO / S` 入口仍在控制层内。
- 横向刻度尺仍调用既有 `onWheelStep`。
- `AUTO / RESET / LOCK` 胶囊仍在控制层内。
- 控制台背景提高到高不透明深色，遮住底部动作区，避免视觉重叠。

### 镜头焦段同风格调节

镜头焦段入口继续保持设备能力驱动的 `13mm / 24mm / 48mm / 77mm` 等显示。

本包调整为：

- 点击当前焦段：切换镜头调节面板开/关。
- 点击非当前焦段：先切换焦段，再进入镜头调节面板。
- 镜头调节面板复用现有 `CaptureLensZoomControlPanel` 与 `CaptureZoomDialView`。
- 镜头调节面板改为与五参数控制层同样的低位深色不透明样式。
- 镜头缩放仍调用既有 `cameraRuntime.setLensZoomDialValue(_:)`。

### 双指缩放保护

本包没有修改 `CaptureLivePreviewView` 中的双指缩放实现。

现有双指缩放仍走：

```text
MagnificationGesture -> cameraRuntime.setLensZoomMultiplier(...)
```

镜头调节 UI 读取 `cameraRuntime.lensZoomDialValue`，因此双指缩放和镜头面板共享同一 runtime zoom 状态，不新建并行镜头系统。

## 3. 手势互斥策略

本包保持单一低位控制层：

- 点击五参数：打开参数覆盖层，并关闭镜头调节。
- 点击镜头焦段：打开镜头调节覆盖层，并关闭五参数展开。
- 点击取景区：关闭参数覆盖层或镜头调节层。
- 参数横向滑动只在参数覆盖层内生效。
- 镜头横向滑动只在镜头调节层内生效。

这样避免参数控制、镜头控制和拍摄按钮在底部同时抢手势。

## 4. 功能合同保护

本包未改动：

- EV 写入路径与 RESET 合同。
- WB AUTO 合同。
- WB 调节保留 TINT。
- TINT RESET 合同。
- TINT 调节保留 WB Kelvin。
- ISO AUTO 合同。
- ISO 非 Auto 时 Shutter LOCK 合同。
- Shutter AUTO 合同。
- 镜头底层切换与 zoom runtime。
- 双指缩放 runtime。
- Focus 独立于底部五参数栏的方向。
- 白底处理链路。
- 拍后 Review / Save / Generate 流程。

## 5. 修改文件

- `SellerCamera/CaptureScreen.swift`
  - 新增底部固定 deck。
  - 将参数展开改为覆盖底部动作区。
  - 将镜头缩放面板接入底部覆盖层。
  - 缩小拍摄按钮、最近、图册入口。
  - 调整镜头焦段点击后进入镜头调节。
- `SellerCamera/CaptureBottomParameterBar.swift`
  - 提高横向参数控制层背景不透明度。
- `README.md`
  - 新增 R46 报告索引。

## 6. 构建验证

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

## 7. 真机验证

未执行真机安装与交互验证。

仍需真机确认：

- 拍摄按钮 / 最近 / 图册尺寸是否符合预期。
- 参数覆盖层是否确实不再明显挤压取景主体。
- 镜头调节面板是否足够顺手。
- 双指缩放与镜头面板显示是否同步。
- 横向调参是否误触底部动作区。

## 8. 遗留风险

- 镜头调节 UI 复用现有缩放条，已经低位同风格化，但还不是完全等同五参数横向刻度尺的主/次刻度系统。
- 展开态隐藏拍摄按钮，符合本包“覆盖底部动作区”策略；如后续希望展开时仍拍摄，需要单独设计小型快门入口。
- 未做真机截图，底部 deck 高度与安全区仍需设备确认。

## 9. 下一步建议

建议先做一次真机截图和手势验证，确认 R46 空间策略成立；之后再进入第 27 包独立 Focus 对焦系统 UI 方案与接入前置。

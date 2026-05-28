# R49 独立 Focus 对焦系统 UI 方案与接入前置

日期：2026-05-23  
任务：第 29 包：独立 Focus 对焦系统 UI 方案与接入前置

## 1. 本包定位

当前底部五参数正式主线为：

```text
EV / WB / TINT / ISO / S
```

Focus 已从底部五参数栏移出，不再作为参数控制台的一项。本包只做 Focus 独立系统前置核查与方案收口，不新增 Focus UI，不接入新的 Manual Focus ruler，不改变点击对焦、长按 AE/AF Lock、五参数 runtime、镜头 zoom、白底或拍后流程。

## 2. 当前 Focus runtime 能力核查

### 状态与能力

`CaptureCameraRuntime` 当前已有 Focus 相关状态：

- `CaptureFocusControlMode`
  - `.auto` -> `AF`
  - `.manual` -> `MF`
- `isManualFocusSupported`
- `focusControlMode`
- `currentManualFocusPosition`
- `focusMarker`
- `isFocusExposureLocked`
- `isExposureLocked`
- `lastAppliedManualFocusPosition`

设备能力读取路径：

- `updateFocusCapabilityState(with:)`
  - 读取 `device.isLockingFocusWithCustomLensPositionSupported`
  - 读取 `device.lensPosition`
  - 初始化 `focusControlMode = .auto`

当前已经具备手动对焦能力判断与 lens position 回写，不需要下一包重建 runtime 能力。

### Manual Focus 写入

当前手动 Focus 写入函数：

```swift
setManualFocusLensPosition(_ requestedLensPosition: Float)
```

实际写入路径：

- guard `isManualFocusSupported`
- guard `!isFocusExposureLocked`
- guard `!isPreviewInteractionTemporarilyRestricted`
- session queue 中读取当前 `AVCaptureDevice`
- guard `device.isLockingFocusWithCustomLensPositionSupported`
- clamp 到 `0...1`
- `quantizedManualFocusPosition(_:)`
- `device.lockForConfiguration()`
- `device.setFocusModeLocked(lensPosition: quantized)`
- 主线程回写：
  - `currentManualFocusPosition`
  - `lastAppliedManualFocusPosition`
  - `focusControlMode = .manual`
  - `captureHintText = "MF ..."`

结论：下一包如做 MF 写入，不应新增并行 runtime；应复用该函数。

### Autofocus 恢复

当前 AF 恢复函数：

```swift
restoreAutofocusMode()
```

实际路径：

- guard `!isPreviewInteractionTemporarilyRestricted`
- session queue 中锁设备
- 优先设置 `.continuousAutoFocus`
- 否则设置 `.autoFocus`
- 读取 `device.lensPosition`
- 主线程回写：
  - `focusControlMode = .auto`
  - `currentManualFocusPosition`
  - `lastAppliedManualFocusPosition`
  - `captureHintText = "已切回 AF"`

结论：Focus AUTO / AF 恢复应复用该函数。

## 3. 点击对焦路径

入口链路：

```text
CameraPreviewLayerView.handleTap(_:)
-> onTapPreview(devicePoint, normalizedPoint)
-> CaptureLivePreviewView
-> cameraRuntime.handlePreviewTap(devicePoint:normalizedPoint:)
```

`handlePreviewTap(...)` 当前行为：

1. 如果预览交互受限，显示限制提示并返回。
2. 如果 `isFocusExposureLocked == true`：
   - 不改对焦。
   - 显示“当前 AE/AF 已锁定，长按可解锁”。
   - 显示 locked focus marker。
3. 如果 `focusControlMode == .manual`：
   - 不退出 MF。
   - 不改对焦。
   - 显示“MF 生效，点按不改对焦”或“MF + AE-L 生效，点按不改对焦”。
   - 显示 locked focus marker。
4. 默认 AF 状态：
   - 设置 auto focus marker。
   - 调用 `applyFocusExposure(lockAfterFocus: false, source: .tap)`。

`applyFocusExposure(..., lockAfterFocus: false)` 当前会：

- 设置 focus point of interest。
- 设置 focus mode 为 `.autoFocus` 或 `.continuousAutoFocus`。
- 设置 exposure point of interest，除非需要保留 AE-L。
- 保留部分手动 ISO / Shutter 策略。
- 更新 lens position、ISO、Shutter、EV 等 runtime 回写。
- `focusControlMode = .auto`。
- 显示“已设置对焦与测光点”。

结论：

- 当前点击对焦同时服务对焦与测光。
- 当前点击对焦在 MF 下不会退出 MF。
- 下一包如果引入 Focus UI，不应改变该行为；如果未来要“点击画面退出 MF”，必须单独开包明确产品合同。

## 4. 长按 AE/AF Lock 路径

入口链路：

```text
CameraPreviewLayerView.handleLongPress(_:)
-> onLongPressPreview(devicePoint, normalizedPoint)
-> CaptureLivePreviewView
-> cameraRuntime.handlePreviewLongPress(devicePoint:normalizedPoint:)
```

`CameraPreviewLayerView` 中长按配置：

- `UILongPressGestureRecognizer`
- `minimumPressDuration = 0.6`
- `allowableMovement = 8`
- 只在 `.began` 时触发。

`handlePreviewLongPress(...)` 当前行为：

1. 预览交互受限时返回。
2. 如果 `focusControlMode == .manual`：
   - 不进入 AE/AF Lock。
   - 显示“MF 模式下不可进入 AE/AF 锁定，先切回 AF”。
   - 显示 locked marker。
3. 如果当前已 `isFocusExposureLocked`：
   - 调用 `clearFocusExposureLockState()`。
   - 显示 unlocked marker。
   - 调用 `applyFocusExposure(lockAfterFocus: false, source: .unlockByLongPress)` 重新对焦测光。
4. 默认状态：
   - 显示 locked marker。
   - 调用 `applyFocusExposure(lockAfterFocus: true, source: .longPress)`。

`applyFocusExposure(..., lockAfterFocus: true)` 当前会：

- 设置 focus point。
- 如果支持 `.locked`，设置 `device.focusMode = .locked`。
- 设置 exposure point。
- 如果支持 `.locked`，设置 `device.exposureMode = .locked`。
- 主线程回写：
  - `isFocusExposureLocked = true`
  - `isExposureLocked = true`
  - `focusControlMode = .auto`
  - `selectedISOPreset = .auto`
  - `selectedShutterPreset = .auto`
  - focus marker locked
  - “AE/AF 已锁定，长按可解锁”

解锁路径 `clearFocusExposureLockState()` 会：

- 清 `isFocusExposureLocked / isExposureLocked`
- 尝试恢复 continuous AF / AF
- 尝试恢复 continuous AE
- 回写 EV / ISO / Shutter / lens position
- `selectedISOPreset = .auto`
- `selectedShutterPreset = .auto`
- `focusControlMode = .auto`

结论：

- 当前长按是 AE/AF 联合锁定，不是单独 AF Lock。
- 当前 MF 状态下禁止进入 AE/AF Lock。
- 下一包 Focus UI 必须尊重该合同，不应让 MF 与 AE/AF Lock 同时展开。

## 5. 当前 CaptureScreen 关系

### 五参数栏

`primaryParameterKinds` 当前为：

```swift
[.exposureCompensation, .whiteBalance, .tint, .iso, .shutter]
```

结论：Focus 已不在底部五参数栏。

### 保留的 Focus 状态

`parameterState(for: .focus)` 仍保留，当前用于状态建模前置，不接入 `primaryParameterKinds`。

建议保留到下一包，因为独立 Focus 状态胶囊可以复用：

- `focusEntryValueText(mode:)`
- `focusHintText(for:)`
- `cameraRuntime.focusControlMode`
- `cameraRuntime.isFocusExposureLocked`
- `cameraRuntime.currentManualFocusPosition`

### 当前底部控制互斥

当前 `CaptureActiveControlTarget`：

```swift
case none
case lensZoom
```

当前已有互斥：

- 点击五参数：`activeControlTarget = .none`，展开参数 ruler。
- 点击 lens：`activeControlTarget = .lensZoom`，收起五参数 ruler。
- 点击取景区：如果参数或 lens overlay 展开，则收起。

结论：下一包可最小扩展为：

```swift
case focus
```

或新增独立 Focus 展开状态，但推荐复用现有互斥模型，避免底部参数、镜头调节、Focus 面板同时堆叠。

## 6. Focus 产品语义方案

正式语义：

```text
LOCK > MF > AF
```

### AF

自动对焦状态。默认状态，点击取景区可执行对焦 / 测光。

显示建议：

- `AF`
- 或 `自动对焦`

### MF

Manual Focus。用户通过后续独立 Focus UI 主动进入手动对焦。当前 runtime 已有 `setManualFocusLensPosition(_:)`。

显示建议：

- `MF`
- 可附带距离感文本：`近 / 中 / 远` 或百分比。

### LOCK

当前应表示 AE/AF Lock，而不是单独 Focus Lock。由长按取景区进入，长按再次解锁。

显示建议：

- `AE/AF-L`
- 或 `锁定`

### 不可用

部分设备 / 镜头不支持 custom lens position 时，MF 不可用。

显示建议：

- `AF`
- MF 入口弱化或显示 `--`
- 不阻断点击对焦。

## 7. 独立 Focus UI 候选方案

### 方案 A：取景区边缘小型 Focus 状态胶囊

位置：取景区左上或左下边缘，贴边，不挡商品主体。

内容：

- `AF / MF / AE/AF-L`
- 可带小型 focus glyph。
- 点击后展开 Focus 小面板骨架。

优点：

- Focus 与取景主体强相关。
- 不占用底部五参数栏。
- 状态持续可见。
- 与当前 `CaptureRuntimeBadge` / focus marker 逻辑容易协调。

风险：

- 需要避开商品主体、焦段入口和现有 runtime badge。
- 小屏上要控制尺寸。

### 方案 B：顶部工具胶囊增加 Focus 状态入口

位置：顶部工具行。

优点：

- 不占用底部空间。
- 状态信息放顶部较自然。

风险：

- 离取景主体和手动调焦动作较远。
- 顶部工具区已有 flash / AE-L / grid / timer 等，继续塞 Focus 可能拥挤。
- 不利于后续 MF 微调手感。

### 方案 C：点击对焦框后出现 Focus 小浮层

位置：对焦框附近或取景区边缘，短暂出现。

优点：

- 上下文强。
- 对焦反馈自然。

风险：

- 与商品主体和点击位置冲突概率高。
- 实现复杂度高。
- 不适合作为第一版常驻入口。

## 8. 推荐方案

推荐：方案 A 为主，方案 C 作为后续增强。

第一阶段建议做：

- 在取景区边缘新增小型 Focus 状态胶囊。
- 常态显示 `AF / MF / AE/AF-L`。
- 胶囊点击只展开一个小型 Focus 面板骨架。
- 不接入新的 MF ruler。
- 不改变点击对焦和长按锁定行为。

不推荐方案 B 作为主方案，因为它离取景动作太远，且顶部工具行已经承担多项低频状态。

## 9. 手势与互斥边界

### 与五参数控制台

- 五参数仍为 `EV / WB / TINT / ISO / S`。
- Focus 不进入五参数栏。
- Focus 面板展开时，应收起五参数 ruler。
- 五参数 ruler 展开时，Focus 状态胶囊可以继续显示，但不应展开 MF 面板。
- Focus runtime 不影响 EV / WB / TINT / ISO / Shutter runtime 合同。

### 与镜头调节

- Focus 面板和 lens zoom 面板不能同时展开。
- 进入 Focus 面板，应收起 lens zoom。
- 进入 lens zoom，应收起 Focus 面板。
- Focus 调节只影响 focus / lensPosition。
- Lens 调节只影响 zoom。
- 不共用 runtime 写入路径。

### 与双指缩放

- 双指缩放仍属于取景区 zoom 手势。
- Focus 状态胶囊不应覆盖主要双指缩放区域。
- 后续 MF 微调建议使用底部或边缘小控制条，不与双指缩放使用同一种双指手势。
- 如果 Focus 面板展开，双指缩放仍应可在取景主体上继续使用。

### 与点击对焦

当前 `CapturePreviewContainer` 的外层 tap 会在参数 / lens overlay 展开时收起 overlay；同时 `CaptureLivePreviewView` 内部也有 tap bridge 到 runtime 点击对焦。

下一包不建议改变该合同。若 Focus 面板展开，建议：

- 点击取景区先收起 Focus 面板。
- 是否同时执行点击对焦，保持当前页面既有 tap 行为，不在下一包改动。
- 后续如果要“点击取景区只收起不对焦”，应单独开包处理。

### 与长按 AE/AF Lock

- 长按取景区继续由 `handlePreviewLongPress(...)` 处理。
- Focus 状态胶囊不应覆盖长按主要区域。
- MF 状态下当前禁止进入 AE/AF Lock，下一包不改变。
- AE/AF Lock 状态优先于 MF / AF 显示。

## 10. 下一包最小实现建议

建议下一包：

```text
第 30 包：独立 Focus 状态入口 + AF / MF / LOCK 最小 UI 骨架
```

只做：

1. 新增取景区边缘 Focus 状态胶囊。
2. 显示 `AF / MF / AE/AF-L`。
3. 点击 Focus 胶囊展开一个小型 Focus 面板骨架。
4. 面板只显示 AF / MF / LOCK 三段结构或状态说明。
5. 复用 `activeControlTarget` 或等价状态，让 Focus 面板与五参数 / lens zoom 互斥。
6. 不接入新的 Manual Focus ruler。
7. 不改变 `setManualFocusLensPosition(_:)`。
8. 不改变 `restoreAutofocusMode()`。
9. 不改变点击对焦。
10. 不改变长按 AE/AF Lock。

最小验收：

- Focus 胶囊状态准确。
- Focus 不回到底部五参数栏。
- 展开 Focus 面板时，五参数 / lens panel 收起。
- 点击对焦与长按锁定不回归。
- xcodebuild 通过。

## 11. 功能合同保护

本包未改动 Swift 运行行为。已保护：

- 五参数结构仍为 `EV / WB / TINT / ISO / S`。
- Focus 不回到底部五参数栏。
- TINT 是 RESET，不是 AUTO。
- WB 调节保留 TINT。
- TINT 调节保留 WB Kelvin。
- WB AUTO 后 TINT 回 0。
- TINT RESET 只归零色偏。
- ISO 非 Auto 时 Shutter LOCK。
- ISO AUTO 后 Shutter 恢复可调。
- EV / WB / TINT / ISO / Shutter runtime 写入路径未改。
- 镜头焦段显示仍由设备能力驱动。
- 镜头切换与 zoom runtime 未改。
- 双指缩放未改。
- 点击对焦未改。
- 长按 AE/AF Lock 未改。
- 白底链路未改。
- 拍后流程未改。
- 横向参数控制台未改。
- 底部覆盖式控制层未改。

## 12. 构建验证

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

## 13. 遗留风险

- 当前 `CaptureScreen` 仍保留 `parameterState(for: .focus)`，但不接入五参数；下一包应决定是否把它提炼成独立 Focus 状态源，避免长期挂在 parameter state 中。
- 当前点击取景区收起 overlay 与点击对焦可能同时发生，这是既有行为；下一包不应贸然改变。
- 当前 MF 状态下点击取景区不退出 MF，长按不进入 AE/AF Lock；这是当前 runtime 合同，若要调整需单独决策。
- Focus 胶囊放置需要真机截图确认，避免遮挡商品主体或镜头焦段入口。

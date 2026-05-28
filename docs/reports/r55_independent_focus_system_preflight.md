# R55 独立 Focus 对焦系统 UI 方案与接入前置报告

日期：2026-05-24

## 1. 背景

Seller Camera 当前拍摄页底部正式参数已经收口为 `EV / WB / TINT / ISO / S`。Focus 已从底部五参数栏移出，后续应作为独立对焦系统设计，而不是重新混入底部参数控制台。

本轮只做 Focus 接入前置核查与方案收口：

- 不新增正式 Focus UI。
- 不新增 Manual Focus 横向 ruler。
- 不接入新的 MF 写入。
- 不改变点击对焦、长按 AE/AF Lock、双指缩放。
- 不改变 EV / WB / TINT / ISO / Shutter / 镜头 / 更多面板合同。
- 不改白底、拍后流程。

## 2. 代码路径核查

### 2.1 Focus runtime 能力

当前 Focus 底层能力集中在 `CaptureLivePreviewView.swift` 的 `CaptureCameraRuntime` 中。

已存在能力：

- `focusControlMode: CaptureFocusControlMode`
  - 当前枚举为 `.auto` / `.manual`。
  - 显示短文案为 `AF` / `MF`。
- `currentManualFocusPosition: Float`
  - 当前手动对焦位置回写状态。
- `isManualFocusSupported`
  - 由设备能力 `isLockingFocusWithCustomLensPositionSupported` 决定。
- `focusMarker`
  - 用于点击对焦 / 锁定 / 解锁的取景区反馈点。
- `isFocusExposureLocked`
  - 当前 AE/AF Lock 状态。
- `isExposureLocked`
  - 当前 AE-L 状态。

底层能力判断：

- `updateFocusCapabilityState(with:)`
  - 读取 `device.isLockingFocusWithCustomLensPositionSupported`。
  - 读取并量化 `device.lensPosition`。
  - 将 `focusControlMode` 初始化为 `.auto`。

## 3. 点击对焦路径

当前点击取景区路径：

1. `CaptureLivePreviewView`
2. `CameraPreviewLayerView`
3. `PreviewContainerUIView.handleTap(_:)`
4. `onTapPreview?(devicePoint, normalizedPoint)`
5. `CaptureLivePreviewView` 中先执行 `onTapPreviewBeforeFocus`
6. 如未被 overlay 关闭逻辑消费，调用 `cameraRuntime.handlePreviewTap(...)`
7. `handlePreviewTap(...)` 再调用 `applyFocusExposure(..., lockAfterFocus: false, source: .tap)`

当前点击行为：

- 正常 AF 状态下：设置 `focusPointOfInterest` 与 `exposurePointOfInterest`，并尝试 `autoFocus` / `continuousAutoExposure`。
- AE/AF 已锁定时：不改对焦点，仅提示当前已锁定。
- MF 模式下：不改对焦点，提示当前 MF 生效。
- 如果五参数 / 镜头 / 更多面板已展开，当前策略倾向为第一次点击取景区先关闭面板，不同次执行对焦。

结论：

- 点击对焦路径完整，且已与 overlay 关闭机制解耦。
- 下一包 Focus UI 骨架不应改变此路径。

## 4. 长按 AE/AF Lock 路径

当前长按路径：

1. `PreviewContainerUIView.handleLongPress(_:)`
2. `onLongPressPreview?(devicePoint, normalizedPoint)`
3. `cameraRuntime.handlePreviewLongPress(...)`
4. `applyFocusExposure(..., lockAfterFocus: true, source: .longPress)`

当前长按行为：

- AF 状态下：尝试锁定 Focus 与 Exposure，成功后 `isFocusExposureLocked = true`，`isExposureLocked = true`。
- 已锁定状态下再次长按：执行 `clearFocusExposureLockState()`，并重新对焦测光。
- MF 模式下：不进入 AE/AF Lock，提示需先切回 AF。

结论：

- 当前实现是 AE/AF 一起锁定，不是只锁 AF。
- LOCK 状态应该作为独立 Focus 系统的最高优先级状态显示。
- 下一包不应改变长按锁定 / 解锁行为。

## 5. Manual Focus 与 Autofocus 能力

### 5.1 Manual Focus 写入

已存在函数：

- `setManualFocusLensPosition(_ requestedLensPosition: Float)`

当前行为：

- 先检查 `isManualFocusSupported`。
- AE/AF Lock 状态下拒绝写入。
- 预览交互临时受限时拒绝写入。
- 使用 `device.isLockingFocusWithCustomLensPositionSupported` 做二次能力判断。
- 将传入值 clamp 到 `0...1`。
- 使用 `quantizedManualFocusPosition(_:)` 量化。
- 调用 `device.setFocusModeLocked(lensPosition: quantized)`。
- 成功后设置：
  - `currentManualFocusPosition = quantized`
  - `lastAppliedManualFocusPosition = quantized`
  - `focusControlMode = .manual`
  - hint 显示 `MF ...`

### 5.2 恢复 Autofocus

已存在函数：

- `restoreAutofocusMode()`

当前行为：

- 优先切回 `.continuousAutoFocus`。
- 不支持时尝试 `.autoFocus`。
- 读取 `device.lensPosition` 并量化回写。
- 成功后设置：
  - `focusControlMode = .auto`
  - `currentManualFocusPosition`
  - `lastAppliedManualFocusPosition`
  - hint 显示 `已切回 AF`

### 5.3 状态回写

当前已回写：

- `focusControlMode`
- `currentManualFocusPosition`
- `lastAppliedManualFocusPosition`
- `isManualFocusSupported`
- `isFocusExposureLocked`
- `isExposureLocked`
- `focusMarker`

当前未形成独立 UI 状态：

- 独立 Focus 面板是否展开。
- Focus 胶囊是否常驻。
- LOCK / MF / AF 的独立显示组件。

结论：

- 手动 Focus 底层能力已存在，但本包不接 UI、不新增写入。
- 下一包可以先只做状态胶囊和骨架面板，不需要立即接 MF ruler。

## 6. 当前底部五参数与 Focus 残留

`CaptureScreen.swift` 当前底部主线：

- `primaryParameterKinds = [.exposureCompensation, .whiteBalance, .tint, .iso, .shutter]`

结论：

- Focus 已不在底部五参数入口。
- `CaptureBottomParameterBar.swift` 的 glyph / ruler 当前只覆盖 EV / WB / TINT / ISO / Shutter。
- `parameterState(for: .focus)` 仍存在，但当前不进入底部主线；可作为后续独立 Focus 状态映射参考，不应在下一包直接删除。

## 7. Focus 产品语义

建议正式语义：

### AF

自动对焦状态。

使用场景：

- 默认状态。
- 用户未手动调焦。
- 用户未进入 AE/AF Lock。

建议显示：

- `AF`
- 或 `自动对焦`

### Tap Focus

点击取景区对焦 / 测光。

使用场景：

- 用户点击商品主体。
- 当前未被 overlay 首次点击关闭逻辑消费。
- 当前未处于 MF 或 AE/AF Lock 阻止状态。

建议显示：

- 对焦框。
- 轻量对焦动画。
- 可短暂提示“已设置对焦与测光点”。

### MF

Manual Focus，手动对焦状态。

使用场景：

- 用户后续通过独立 Focus 系统进入手动对焦。
- 适用于近距离商品、小物件、包装文字、反光边缘等需要微调的场景。

建议显示：

- `MF`
- 可附带当前位置百分比或近 / 中 / 远语义，但第一版骨架不必实现调节。

### LOCK

AE/AF Lock 或对焦 / 曝光锁定状态。

使用场景：

- 用户长按取景区锁定。

建议显示：

- `AE/AF-L`
- 或 `LOCK`

### 状态优先级

建议优先级：

```text
LOCK > MF > AF
```

原因：

- LOCK 是用户显式锁定，优先级最高。
- MF 是用户显式手动调焦，优先级高于默认 AF。
- AF 是默认状态。

## 8. 独立 Focus UI 候选方案

### 方案 A：取景区边缘小型 Focus 状态胶囊

位置：

- 取景区左下或右下边缘。
- 避开主体中心。

优点：

- 与取景主体强相关。
- 不占用底部五参数栏。
- AF / MF / LOCK 状态可常驻可见。
- 后续可点击展开 Focus 小面板。

风险：

- 小屏和商品主体靠边时可能遮挡，需要谨慎定位。

### 方案 B：顶部工具区 Focus 状态入口

位置：

- 顶部工具区，与更多、AE-L 状态并列。

优点：

- 不占用取景下方和底部参数区域。
- 适合状态展示。

风险：

- 离拇指操作区较远。
- MF 微调时操作路径不够顺。

### 方案 C：点击对焦框后出现上下文 Focus 小浮层

位置：

- 对焦框附近。

优点：

- 上下文最强。
- 用户能直观看到 Focus 与当前对焦点关联。

风险：

- 对焦点位置不固定，容易遮挡商品主体。
- UI 适配复杂，不适合作为第一版。

### 方案 D：底部低位 Focus 面板，但不进入五参数栏

位置：

- 由 Focus 状态胶囊触发。
- 使用独立底部低位控制层。

优点：

- 后续 MF 微调可继承当前低位控制台手感。
- 适合拇指操作。

风险：

- 必须与五参数 ruler、镜头 zoom ruler、更多面板严格互斥。

### 推荐方案

推荐 `A + D`：

1. 常态在取景区边缘显示小型 Focus 状态胶囊。
2. 胶囊仅显示 `AF / MF / LOCK`，不进入底部五参数。
3. 点击胶囊后，底部低位展开独立 Focus 小面板骨架。
4. 后续 Manual Focus ruler 另包接入。

不推荐第一版直接采用方案 C：

- 对焦点位置不固定，容易遮挡商品主体。
- 上下文浮层复杂度高，风险超过当前“最小骨架”目标。

## 9. 与现有控制系统的边界

### 9.1 与五参数控制台

规则：

- 五参数仍为 `EV / WB / TINT / ISO / S`。
- Focus 不进入五参数。
- 打开 Focus 面板时，关闭五参数 inline controls。
- 打开五参数 inline controls 时，关闭 Focus 面板。
- Focus MF 后续如使用 ruler，也必须是独立 Focus 面板，不复用五参数入口。

### 9.2 与镜头 zoom ruler

规则：

- Focus 面板与镜头 zoom ruler 互斥。
- 打开 Focus 面板时，关闭镜头 zoom ruler。
- 打开镜头 zoom ruler 时，关闭 Focus 面板。
- 镜头调节只写 zoom。
- Focus 调节只写 lensPosition / focus。
- 双指缩放继续走镜头 zoom，不与 Focus MF 混淆。

### 9.3 与更多面板

规则：

- 打开 Focus 面板时，关闭更多面板。
- 打开更多面板时，关闭 Focus 面板。
- 更多面板内部操作保持打开的 R54 合同不变。
- Focus 状态胶囊在更多面板打开时建议弱化或保持可见但不可展开，避免叠层冲突。

### 9.4 与取景手势

单指点击：

- 默认用于点击对焦 / 测光。
- 如果五参数、镜头、更多或 Focus 面板打开，第一次点击优先关闭当前控制层。
- 下一次点击再执行对焦，保持 R50 / R54 的“先关闭，不同次对焦”倾向。

长按：

- 继续用于 AE/AF Lock / 解锁。
- Focus UI 不应拦截长按取景。
- LOCK 状态应反映到 Focus 胶囊。

双指缩放：

- 继续用于镜头 zoom。
- Focus 面板不应破坏双指缩放。
- 后续 MF 调节应避免使用双指手势。

## 10. 下一包最小实现建议

建议下一包：

**第 36 包：独立 Focus 状态胶囊 + AF / MF / LOCK 最小 UI 骨架**

只做：

1. 新增取景区边缘 Focus 状态胶囊。
2. 胶囊显示 `AF / MF / LOCK`。
3. 状态来自现有 `focusControlMode`、`isFocusExposureLocked`、`isExposureLocked` 映射。
4. 点击 Focus 胶囊可展开独立小型 Focus 面板骨架。
5. 面板只展示 AF / MF / LOCK 结构。
6. 打开 Focus 面板时关闭五参数 / 镜头 / 更多。
7. 点击取景区关闭 Focus 面板。
8. 不接 Manual Focus ruler。
9. 不写入新的 Focus runtime。
10. 不改变点击对焦与长按锁定。

下一包不要做：

- 不新增 MF 横向 ruler。
- 不接新的 lensPosition 写入。
- 不改变点击对焦路径。
- 不改变长按 AE/AF Lock。
- 不让 Focus 回到底部五参数栏。

最小验收：

- Focus 胶囊能显示 AF / LOCK。
- 当前 MF 状态可显示 MF，但不触发新写入。
- 面板互斥规则正确。
- 五参数、镜头、更多面板不回归。
- xcodebuild 通过。

## 11. 本轮修改文件

- `docs/reports/r55_independent_focus_system_preflight.md`
  - 本报告。
- `docs/reports/r55_independent_focus_system_preflight.json`
  - 本轮结构化记录。
- `README.md`
  - 新增 R55 报告索引。

本轮未修改 Swift 行为代码。

## 12. 构建验证

已执行：

```bash
xcodebuild -project /Users/sungning/Projects/SellerCamera/SellerCamera.xcodeproj -scheme SellerCamera -configuration Debug -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO build
```

结果：通过。

已执行 JSON 解析：

```bash
python3 -m json.tool /Users/sungning/Projects/SellerCamera/docs/reports/r55_independent_focus_system_preflight.json
```

结果：通过。

本轮未运行真机；因为本包只做前置核查和文档落地，没有新增 Swift 行为。

## 13. 风险与限制

- Focus 底层 MF 写入能力存在，但尚未通过本轮新增 UI 真机验证。
- 当前 `parameterState(for: .focus)` 仍存在历史状态映射，可作为下一包 Focus 胶囊状态来源参考，但不应重新接回五参数栏。
- AE/AF Lock 与手动 Focus 的关系已经有保护逻辑：MF 模式下不进入 AE/AF Lock，LOCK 下不允许 MF 写入。下一包 UI 需要忠实反映该合同。
- Focus 胶囊位置需要真机确认是否遮挡商品主体，尤其是小屏、商品靠边和竖向构图场景。

## 14. 边界确认

本轮没有：

- 新增 Focus UI。
- 新增 Manual Focus ruler。
- 接入新的 MF 写入。
- 改变点击对焦。
- 改变长按 AE/AF Lock。
- 改变五参数合同。
- 改变镜头 zoom runtime。
- 改变更多面板持久交互。
- 改变白底或拍后流程。

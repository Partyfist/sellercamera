# R64 Full Code State Audit and Parameter Simplification

## 1. 改动摘要

- 对拍摄页参数系统做了状态流体检，重点核查 `EV / WB / TINT / ISO / S`、pending、runtime 回写、AUTO/MANUAL 接管、MF/AF/LOCK、镜头 zoom 与 Debug fallback。
- 修复了 runtime `.auto` 回写会在手动 pending 尚未确认时清空 pending 的冲突，避免 WB 首次手动接管被旧 AUTO 状态覆盖。
- 保留 R61 的 drag consumption 修复、R62/R63 的首滑接管与 Debug 诊断路径；本包没有新增功能、没有改 UI 主布局、没有改 runtime 方法签名。

## 2. 文件清单

- `SellerCamera/CaptureScreen.swift`
  - 审查并收口 WB / ISO / Shutter preset AUTO 回写与 pending manual 的优先级。
  - 增加 Debug-only 日志说明 runtime AUTO echo 被 pending manual 接管忽略。
- `docs/reports/r64_full_code_state_audit_parameter_simplification.md`
  - 新增本报告。
- `docs/reports/r64_full_code_state_audit_parameter_simplification.json`
  - 新增结构化报告。
- `README.md`
  - 更新 R64 报告索引。

## 3. 全代码体检范围

- `CaptureScreen.swift`
  - 拍摄页主状态、底部五参数、inline ruler、lens ruler、MF ruler、更多面板、pending timeout、runtime onChange 回写。
- `CaptureBottomParameterBar.swift`
  - 横向 ruler drag consumption、边界 consume、方向切换、Debug WB drag 日志、五参数点击区域。
- `CaptureLivePreviewView.swift`
  - WB / ISO / Shutter / Focus runtime 写入路径、点击对焦、长按 AE/AF Lock、双指缩放、白平衡手动写入异步回写。
- `CaptureProfessionalParameterPanel.swift`
  - 旧参数类型保留情况与正式五参数主线隔离情况。
- 白底与拍后入口
  - 本包未改白底处理、Review / Save / Generate 相关链路。

## 4. 当前状态系统问题列表

### 必要状态

- runtime 状态：`selectedWhiteBalancePreset`、`currentWhiteBalanceTemperature`、`selectedISOPreset`、`currentManualISOValue`、`selectedShutterPreset`、`currentManualShutterDurationSeconds`、`focusControlMode`、`currentManualFocusPosition`。
- UI pending 状态：各参数的 `pending...WheelValue`、`pending...UpdatedAt`、`lastDispatched...`。
- overlay 状态：五参数 inline、lens zoom、MF ruler、更多面板互斥状态。
- Debug fallback：仅 `DEBUG + simulator` 的 WB UI fallback，用于无相机模拟器观察状态机。

### 重复状态

- 参数值存在 runtime current 与 local pending 两套来源，这是必要重复，但必须明确优先级。
- AUTO/MANUAL 状态同时由 runtime preset 与 pending manual 推导，必须让 pending manual 在用户接管期间优先。
- R61/R62/R63 后存在 drag consume、manual takeover、Debug log 三组辅助逻辑，功能不同，当前不直接冲突。

### 冲突状态

- WB / ISO / Shutter 的 `.onChange(selected...Preset)` 之前在 preset 变为 `.auto` 时无条件清 pending。
- runtime 写入是异步的，手动写入确认前可能仍收到旧 `.auto` preset 或 AUTO 回声，导致 UI/pending 被打回 AUTO。
- 对 WB 最明显，因为 `setWhiteBalanceDialValue` 需要在 session queue 中设置 gains，`selectedWhiteBalancePreset = .custom` 只在主线程回写阶段确认。

### 临时补丁

- R63 的 `[CaptureWBWheel]` 与 `[CaptureWBRulerDrag]` 日志仍保留，均为 Debug-only，用于继续真机定位 WB 首滑。
- R63 的 simulator fallback 仅在 `DEBUG && targetEnvironment(simulator)` 生效，不污染真机与 Release。

## 5. R61 / R62 / R63 补丁审查结论

### 保留

- R61 drag consumption：边界向外拖动时 consume movement，方向切换重建 baseline，仍是必要基础修复。
- R62/R63 manual takeover：首个有效 drag 同时完成 manual 接管与参数变化，仍保留。
- R63 Debug 诊断：真机问题尚未完全闭环，Debug-only 日志继续有价值。

### 合并

- 本包没有新增大型 helper，也没有把 R61/R62/R63 重新包装为新框架。
- 本包将 AUTO 回写处理统一为同一条原则：pending manual 存在时，不允许 runtime AUTO echo 清 pending。

### 删除

- 本包没有删除 Swift 代码。审查结论是当前最危险点不是无引用代码，而是回写优先级错误；先做最小行为修复。

### 风险

- `manualTakeoverTargetIndex` 仍包含 `forceWrite` 语义，虽可解释但复杂度偏高；本包为避免扩大改动未重写。
- WB 真机首滑仍需要真实设备复验，确认 runtime AUTO echo 不再覆盖 pending。

## 6. WB 首滑根因结论

R64 体检确认，R63 解决了边界同 tick 写入问题，但未覆盖另一条状态覆盖路径：

1. 用户在 WB AUTO 状态下首滑。
2. `stepWhiteBalanceWheel` 建立 manual target 和 `pendingWhiteBalanceWheelValue`。
3. `cameraRuntime.setWhiteBalanceDialValue` 异步写入白平衡 gains。
4. runtime 在确认 `.custom` 前仍可能发布或保持 `.auto`。
5. 原代码看到 `.auto` 就无条件清掉 WB pending，并清掉 Tint pending。
6. UI 显示优先级失去 pending manual 后回到 runtime AUTO，因此用户看到首滑没有稳定解除 AUTO。

这就是 R63 后仍可能需要“先反向滑一下”的真实结构性原因：pending manual 与 runtime AUTO 回写的优先级反了。

## 7. 精简与修复说明

本包采用最小修复：

- WB：当 `selectedWhiteBalancePreset == .auto` 且 `pendingWhiteBalanceWheelValue != nil` 时，视为 runtime AUTO echo，保留 pending manual，不清 Tint pending。
- ISO：当 `selectedISOPreset == .auto` 且 `pendingISOWheelValue != nil` 时，保留 pending manual。
- Shutter：当 `selectedShutterPreset == .auto` 且 `pendingShutterWheelDurationSeconds != nil` 时，保留 pending manual。
- 显式 AUTO 按钮路径不受影响，因为 `apply...AutoFromWheel()` 会先主动清 pending，再调用 runtime AUTO；此时 `.auto` 回写仍会按正常 AUTO 逻辑收口。

## 8. 参数状态优先级说明

本包明确参数显示和状态优先级：

1. 用户拖动产生的 pending manual value。
2. 已确认的 manual runtime value。
3. runtime current value。
4. runtime AUTO fallback display。
5. default preset value。

具体影响：

- pending manual 存在时，AUTO badge / 参数 mode 不应被 runtime `.auto` 回声盖回。
- pending 超时或 runtime 确认后再清理 pending。
- 显式 AUTO 操作仍能立即恢复 AUTO。

## 9. AUTO -> MANUAL 接管规则说明

统一规则：

- 第一次有效 drag 必须建立 pending manual。
- 即使 runtime 尚未确认，UI 也应立即进入 manual 表达。
- duplicate guard / boundary guard 不得吞掉 AUTO takeover。
- runtime `.auto` 回写不得覆盖 in-flight manual pending。
- 只有 runtime manual 确认、pending 超时、显式 AUTO、LOCK/disabled 等明确事件可以清 pending。

覆盖参数：

- WB：本包重点修复。
- ISO：同步保护，避免相同 async preset echo 风险。
- Shutter：同步保护，避免相同 async preset echo 风险。
- EV：无 AUTO 主语义，未改。
- TINT：RESET 语义，不存在 AUTO takeover，未改。
- MF：不是 AUTO 参数，未改 MF 主逻辑。

## 10. Debug / Simulator Fallback 隔离说明

- Debug fallback 仅在 `#if DEBUG && targetEnvironment(simulator)` 下生效。
- 作用范围仅为无真实相机模拟器中的 WB UI 状态机观察。
- Release 与真机能力判断不受影响。
- Debug logs 使用 `#if DEBUG` 包裹，不进入 Release 行为。

## 11. 功能合同保护说明

- EV：合同未改，RESET 未改。
- WB：runtime 写入方法未改；AUTO 显式恢复未改；手动 pending 优先级修复。
- TINT：仍为 RESET，不是 AUTO；WB AUTO 清 Tint 的显式路径未改。
- ISO：AUTO / MANUAL 合同未改；pending 优先级保护。
- Shutter：AUTO / LOCK 合同未改；pending 优先级保护。
- Focus / MF：未改 MF ruler、AF restore、LOCK 保护。
- Lens zoom：未改焦段显示、镜头切换、zoom runtime。
- 白底 / 拍后：未改白底 pipeline、Review / Compare / Save / Generate。

## 12. 构建结果

- `xcodebuild -project /Users/sungning/Projects/SellerCamera/SellerCamera.xcodeproj -scheme SellerCamera -configuration Debug -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO build`：通过。
- 构建期间 Xcode 仍输出已有 `IDEFileReferenceDebug` 工程引用警告，但最终 `BUILD SUCCEEDED`。

## 13. 真机验证结果

- 本轮未运行真机。
- 仍需真机重点验证：
  - WB AUTO 状态直接右滑是否立即进入 manual。
  - 首滑后 AUTO badge 是否消失且 Kelvin pending 保持。
  - runtime 回写后 UI 是否不再回 AUTO。
  - ISO / Shutter AUTO 首滑是否无回归。
  - MF ruler、镜头 zoom、拍照、白底与拍后流程是否无回归。

## 14. 风险与后续建议

- 最大风险：若真机仍失败，下一步应读取 `[CaptureWBWheel]` 真机日志，确认 pending 是否被 timeout、runtime current mismatch 或别的 onChange 清理。
- 建议下一包不再扩大修复面，先用真机日志验证 R64 的 pending/manual 优先级是否命中。
- `manualTakeoverTargetIndex` 的 `forceWrite` 分支未来可以在稳定后做一次小型命名/语义清理，但当前不建议马上重写。

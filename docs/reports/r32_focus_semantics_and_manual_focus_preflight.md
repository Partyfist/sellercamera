# R32 Focus 参数语义设计与手动 Focus 接入前置方案报告

## 1. 本包定位

- 包类型：前置方案包（核查 + 语义收口），非真实写入包。
- 范围：仅覆盖 Focus 与点击对焦、长按 AE/AF Lock、底部参数栏语义的关系梳理。
- 边界：不接入 Focus 真实滚轮写入，不改变现有点击对焦/长按锁定行为，不改 EV/WB/ISO/Shutter。

---

## 2. 核查结论（代码证据）

### 2.1 点击画面对焦路径

- 入口：`CaptureCameraRuntime.handlePreviewTap(devicePoint:normalizedPoint:)`
- 关键行为：
  - `isFocusExposureLocked == true`：直接提示“AE/AF 已锁定”，不执行重对焦。
  - `focusControlMode == .manual`：提示“MF 生效，点按不改对焦”，不执行重对焦。
  - 其余情况：调用 `applyFocusExposure(... lockAfterFocus: false, source: .tap)`。
- 对焦与测光：同一条 `applyFocusExposure` 中同时处理 focus point 和 exposure point（设备支持时）。
- 点击是否解除 AE/AF Lock：不会；锁定状态下点击被拦截。
- 点击是否受状态限制：受 `isSwitchingCamera / countdown / burst / quickPreview` 限制。

### 2.2 长按 AE/AF Lock 路径

- 入口：`CaptureCameraRuntime.handlePreviewLongPress(devicePoint:normalizedPoint:)`
- 关键行为：
  - `focusControlMode == .manual`：拦截，提示先切回 AF。
  - 当前已锁定：`clearFocusExposureLockState()`，随后重新走一次 `applyFocusExposure(... lockAfterFocus: false, source: .unlockByLongPress)`。
  - 当前未锁定：走 `applyFocusExposure(... lockAfterFocus: true, source: .longPress)`。
- 当前锁定语义：AE/AF 一起锁（`isFocusExposureLocked = true`，`isExposureLocked = true`）。
- 再次长按：可解锁（现有行为）。
- 解锁后状态：回到 AF/Auto（`clearFocusExposureLockState()` 内设回 `continuousAutoFocus` + `continuousAutoExposure`）。

### 2.3 Focus 手动能力现状

- 已有手动写入函数：`setManualFocusLensPosition(_:)`。
- 已有恢复 AF 函数：`restoreAutofocusMode()`。
- 已有状态：
  - `isManualFocusSupported`
  - `focusControlMode`（`.auto / .manual`）
  - `currentManualFocusPosition`
  - `lastAppliedManualFocusPosition`
  - `isFocusExposureLocked`
- 能力探测：`updateFocusCapabilityState(with:)` 中使用 `device.isLockingFocusWithCustomLensPositionSupported`。
- 写入方式：`device.setFocusModeLocked(lensPosition:)`（需 `lockForConfiguration`）。

### 2.4 当前底部 Focus 语义映射

- `CaptureScreen.parameterState(for: .focus)`：
  - `isFocusExposureLocked == true` -> `mode = .locked` -> 显示 `L`
  - `focusControlMode == .manual` -> `mode = .manual` -> 显示 `M`
  - `isManualFocusSupported == true` -> `mode = .auto` -> 显示 `A`
  - 否则 `mode = .disabled` -> `--`
- 当前 Focus 列是“状态展示 + 预留交互”，未接入短滚轮真实写入。

---

## 3. 必答问题逐项回答

### 3.1 点击画面对焦

1. 入口函数：`handlePreviewTap(...)`。  
2. 是否同时做 Focus/Exposure：是（`applyFocusExposure(lockAfterFocus: false)` 内同设 focus/exposure point）。  
3. 点击后 Focus 显示：正常路径回到 `A`；manual/locked 被拦截时保持原状态。  
4. 点击是否解除 AE/AF Lock：否。  
5. 是否受限制：是，受切镜头/倒计时/连拍/quick preview 限制。  
6. 后续手动 Focus 接入后，点击是否应退出 `M`：**建议不退出**（沿用当前“MF 生效时点按不改对焦”），避免误触打断手动对焦。

### 3.2 长按 AE/AF Lock

1. 入口函数：`handlePreviewLongPress(...)`。  
2. 是 AE/AF 一起锁还是单锁：当前是一起锁。  
3. 锁定后 Focus 显示：应为 `L`（当前已是该行为）。  
4. 锁定后点击画面：被禁止并提示。  
5. 再次长按：解锁（当前已支持）。  
6. 解锁后 Focus 状态：回 Auto（AF）。  
7. 锁定后 Focus 滚轮是否禁用：**应禁用**（与现有参数锁定合同一致）。

### 3.3 手动 Focus 可行性

1. 是否已有手动写入函数：有，`setManualFocusLensPosition(_:)`。  
2. 是否已有 lensPosition 读写：有。  
3. 是否已有设备能力判断：有，`isLockingFocusWithCustomLensPositionSupported`。  
4. 若缺少能力是否要新增：当前主干不缺“最小可用能力”。  
5. 是否需要 `lockForConfiguration`：需要（当前实现已使用）。  
6. 部分镜头/设备不可用可能性：有（当前已有降级标记 `isManualFocusSupported=false`）。  
7. 不可用时 UI 显示建议：保持 `--`（沿用现有 `mode = .disabled` 显示）。

### 3.4 Focus 状态语义（R32 建议定稿）

- `A`：自动对焦（AF）  
- `M`：手动对焦（MF）  
- `L`：AE/AF 锁定态  
- `--`：设备不支持手动 Focus 或状态不可用

补充约束：
- `M` 与 `L` 互斥；
- `L` 优先级高于 `M`；
- `M` 下点击对焦不改焦点（维持当前合同）；
- `L` 下 Focus 滚轮禁用。

---

## 4. 下一包（Focus 真实接入）实施边界与改动点

## 4.1 建议改动文件（最小集合）

1. `SellerCamera/CaptureScreen.swift`
   - 为 `.focus` 增加 `stepFocusWheel(by:)`
   - 为 `.focus` 增加 `applyFocusAutoFromWheel()` 路由
   - Focus tick 生成从静态占位改为基于 `currentManualFocusPosition` 的相邻档展示
2. `SellerCamera/CaptureBottomParameterBar.swift`
   - 复用现有短滚轮交互，不新增大面板
   - Focus 列只在 `isAdjustable` 时允许拖动
3. `SellerCamera/CaptureLivePreviewView.swift`
   - 优先复用 `setManualFocusLensPosition(_:)` / `restoreAutofocusMode()`
   - 不改 `handlePreviewTap` / `handlePreviewLongPress` 主合同

### 4.2 下一包必须遵守的优先级

1. `L`（AE/AF 锁定）> `M`（手动）> `A`（自动）  
2. 点击画面对焦不应覆盖 `M`。  
3. Focus AUTO 仅恢复 AF（调用 `restoreAutofocusMode()`），不应隐式改 AE-L/AEAF-L 合同。  
4. 不因 Focus 接入触发 EV/WB/ISO/Shutter 状态重置。

---

## 5. 风险点与规避建议

1. 风险：将 Focus AUTO 错做成“全量解锁”导致 AE-L 被意外清掉。  
   - 规避：Focus AUTO 仅调用 `restoreAutofocusMode()`，不调用 `clearFocusExposureLockState()`。

2. 风险：手动 Focus 与点击对焦互相抢状态。  
   - 规避：保持现有“MF 下点击不改对焦”合同。

3. 风险：锁定态下滚轮仍可动，造成“看起来可调但不生效”。  
   - 规避：锁定态直接禁用 Focus 滚轮和 Focus AUTO 控件。

4. 风险：Focus 接入时误改曝光链，连带影响 ISO/Shutter。  
   - 规避：下一包仅触达 Focus 路由，不触达 ISO/Shutter 合同。

---

## 6. 本包结论

1. Focus 的核心运行路径（点击/长按/手动写入/恢复 AF）在当前代码中已具备最小接入条件。  
2. 当前缺口不是底层能力，而是“滚轮交互接入 + 语义落位”的工程收口。  
3. 可进入下一包：`Focus 短竖向滚轮交互化 + Auto / Manual Focus 写入接入`，并按本报告边界执行。  

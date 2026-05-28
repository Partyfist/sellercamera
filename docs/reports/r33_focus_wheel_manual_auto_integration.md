# R33 Focus 短竖向滚轮交互化 + Auto / Manual Focus 写入接入报告

## 1. 本包定位

- 包类型：最小增量功能接入包（Focus）。
- 范围：仅接入 Focus 短滚轮交互、Manual 写入、AUTO 恢复 AF。
- 边界：不改点击对焦主合同、不改长按 AE/AF Lock 合同、不改 EV/WB/ISO/Shutter、不改白底与拍后链路。

---

## 2. 本包实现摘要

1. Focus 列由静态占位升级为可交互短滚轮：
   - 支持上下滑切档；
   - 仅在 `isAdjustable` 时可滑动（锁定态/不可用态禁用）。
2. Focus Manual 写入接入：
   - 滚轮档位变化触发 `setManualFocusLensPosition(_:)`；
   - 沿用 runtime 现有写入路径与设备能力判断。
3. Focus AUTO 接入：
   - Focus 列下方 `AUTO` 触发 `restoreAutofocusMode()`；
   - 不触发 AE/AF 解锁重置逻辑（保持既有合同）。
4. Focus 状态与显示：
   - 沿用 `L > M > A > --`；
   - 锁定态按钮显示 `LOCK` 并禁用；
   - 滚轮中心在 `A` 时显示 `A`，`M` 时显示手动百分比，`L` 时显示 `L`。

---

## 3. 关键实现路径

## 3.1 `CaptureScreen.swift`

- 新增 Focus 交互状态：
  - `pendingFocusWheelPosition`
  - `pendingFocusUpdatedAt`
  - `lastDispatchedFocusPosition`
- 面板路由接入：
  - `onWheelStep(.focus)` -> `stepFocusWheel(by:)`
  - `onControlTap(.focus)` -> `applyFocusAutoFromWheel()`
- 新增 Focus wheel 逻辑：
  - `focusWheelTicks()`
  - `focusWheelPositions()`
  - `nearestFocusWheelPosition(...)`
  - `stepFocusWheel(by:)`
  - `applyFocusAutoFromWheel()`
- pending 收口：
  - 监听 `currentManualFocusPosition` 回写确认；
  - 监听 `focusControlMode == .auto` 清空 pending；
  - 超时清理 pending，避免 UI 悬挂。

## 3.2 `CaptureBottomParameterBar.swift`

- 无功能结构重写。
- 通过既有 `isWheelInteractive` / `controlTitle == LOCK` 禁用机制承接 Focus 锁定态。

## 3.3 Runtime 复用说明

- Manual：`CaptureCameraRuntime.setManualFocusLensPosition(_:)`
- Auto：`CaptureCameraRuntime.restoreAutofocusMode()`
- 未新增并行 Focus 写入通道。

---

## 4. 交互合同确认（本包后）

1. `A`（Auto）：
   - Focus 可进入滚轮；
   - 滑动后转入 `M`。
2. `M`（Manual）：
   - 滚轮继续可调；
   - 点击 Focus 的 `AUTO` 回 `A`。
3. `L`（Locked）：
   - Focus 滚轮禁用；
   - Focus 控制按钮显示 `LOCK`；
   - 不允许通过 Focus 列改写对焦。
4. 点击画面对焦（既有）：
   - `M` 下仍保持“点按不改焦点”；
   - `L` 下仍保持“提示解锁后再改”。

---

## 5. 风险与边界

## 5.1 已规避

- 未动 AE/AF Lock 主流程；
- 未引入 ISO/Shutter 联动改造；
- 未改拍摄后链路和白底链路。

## 5.2 当前遗留

- 真机主观手感（焦点转移体感、不同设备镜头响应）尚需补一次人工验证闭环；
- Focus 百分比显示是工程化近似语义，不等同光学景深教学语义。

---

## 6. 验证结果

1. 构建验证（必做）：
   - 命令：`xcodebuild -project /Users/sungning/Projects/SellerCamera/SellerCamera.xcodeproj -scheme SellerCamera -configuration Debug -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO build`
   - 结果：`BUILD SUCCEEDED`
2. 运行时验证：
   - 本包未在当前 CLI 会话完成真机人工滑动验证；
   - 需在下一轮或专项真机轮补齐“手感与视觉”确认。

---

## 7. 结论

R33 已在不扩散到无关链路的前提下完成 Focus 最小真实接入：

1. Focus 短滚轮可交互；
2. Manual 写入可走既有 runtime；
3. AUTO 可恢复 AF；
4. 锁定态清晰禁用；
5. 与 EV/WB/ISO/Shutter 现有合同保持兼容。

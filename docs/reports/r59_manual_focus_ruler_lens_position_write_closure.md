# R59 Manual Focus 低位微调 ruler 接入报告

## 1. 本包实现范围

本包在 R58 的 `AE-L + 焦段 + MF` 取景控制组基础上，为 `MF` 模式接入独立低位 Manual Focus ruler，并完成最小 lensPosition 写入闭环。

已完成：

- 点击 `MF` 进入 MF 模式并显示低位 MF ruler。
- MF ruler 独立显示在取景区低位，不进入底部五参数栏。
- MF ruler 范围为 `0.0 ... 1.0`，步进 `0.05`。
- 当前值显示为 `MF 0 ... MF 100`。
- 左右语义显示为 `近 / 远`。
- 拖动 MF ruler 时调用现有 `cameraRuntime.setManualFocusLensPosition(_:)`。
- 再次点击 `MF` 退出 MF，并调用现有 `cameraRuntime.restoreAutofocusMode()`。
- 新增 `pendingManualFocusPosition` 回写、超时、去重、边界保护。
- LOCK 状态下 MF 禁用，不显示可调 ruler，不写入 lensPosition。

本包没有做：

- 没有把 Focus 加回底部五参数栏。
- 没有恢复独立 AF 胶囊。
- 没有恢复 AF / MF / LOCK 大面板主入口。
- 没有新增对焦峰值、放大镜、景深提示或 AI 对焦辅助。
- 没有改 EV / WB / TINT / ISO / Shutter 合同。
- 没有改镜头 zoom runtime、白底 pipeline 或拍后流程。

## 2. MF ruler UI

MF ruler 由 `CaptureManualFocusRulerPanel` 承担。

视觉结构：

- 深色低位横向 ruler。
- 中心短指针。
- 当前值浮窗。
- 主刻度：`0 / 25 / 50 / 75 / 100`。
- 次刻度：每 `0.05` 一档。
- 左侧语义：`近`。
- 右侧语义：`远`。

显示位置：

- 位于取景区内、焦段控制组下方的低位区域。
- 不进入 `EV / WB / TINT / ISO / S` 五参数栏。
- 不替换底部五参数。

显示条件：

- 用户点击 `MF` 进入 MF 模式。
- 当前不是 `AE/AF Lock`。
- 当前设备支持手动对焦。
- 五参数 inline controls、镜头 zoom ruler、更多面板未展开。

## 3. lensPosition 写入路径

MF ruler 的真实写入路径为：

```swift
cameraRuntime.setManualFocusLensPosition(targetPosition)
```

写入保护：

- 仅在 `isManualFocusModeActive == true` 时写入。
- 仅在 `cameraRuntime.isManualFocusSupported == true` 时写入。
- 仅在 `cameraRuntime.isFocusExposureLocked == false` 时写入。
- 目标值裁剪到 `0.0 ... 1.0`。
- 同值不重复写入。
- 边界不重复写入。
- 只有 tick 真实变化时写入。

## 4. pending / 回写 / 超时策略

新增状态：

- `pendingManualFocusPosition`
- `pendingManualFocusUpdatedAt`
- `lastDispatchedManualFocusPosition`
- `manualFocusPendingTimeout = 1.4s`

收口规则：

- UI 显示优先使用 `pendingManualFocusPosition`。
- runtime `currentManualFocusPosition` 与 pending 差值 `<= 0.02` 时清除 pending。
- pending 超过 `1.4s` 未确认时清除，回落到 runtime 当前值。
- 切换回 AF 时清除 pending。
- 进入 LOCK 时清除 pending。

## 5. AF 恢复路径

退出 MF 仍通过再次点击 `MF` 胶囊完成。

退出时调用：

```swift
cameraRuntime.restoreAutofocusMode()
```

同时：

- 清除 `pendingManualFocusPosition`。
- 关闭 MF ruler。
- 清除本地 MF 模式状态。
- MF 胶囊取消高亮。

AF 恢复不影响：

- EV / WB / TINT / ISO / Shutter。
- 镜头 zoom。
- 更多面板设置。
- 白底和拍后流程。

## 6. LOCK 下禁用策略

`cameraRuntime.isFocusExposureLocked == true` 时：

- MF 胶囊进入弱化禁用态。
- 点击 MF 不进入 MF。
- 不显示 MF ruler。
- 不调用 `setManualFocusLensPosition(_:)`。
- 不调用 `restoreAutofocusMode()`。
- 提示用户长按画面解除锁定后再调焦。

如果 MF 模式下进入 LOCK：

- 本地 MF 模式退出。
- MF ruler 关闭。
- pending 清理。

## 7. 互斥关系

打开 MF ruler 时：

- 关闭五参数 inline controls。
- 关闭镜头 zoom ruler。
- 关闭更多面板。

打开五参数、镜头或更多时：

- 收起 MF ruler。
- 保持 MF 模式，直到用户再次点击 `MF` 退出。

点击取景区时：

- 如果 MF ruler 正在显示，先收起 ruler。
- 如果 MF 模式仍处于开启状态，不同次触发 AF tap focus，避免自动对焦覆盖手动状态。

## 8. 手势保护

本包未改变：

- 点击取景区对焦路径。
- 长按 AE/AF Lock 路径。
- 双指缩放路径。

MF 模式下点击取景区会被现有 preview tap 钩子消费，防止 AF tap focus 覆盖手动对焦模式。

## 9. 修改文件

- `SellerCamera/CaptureScreen.swift`
  - 新增 MF ruler 显示状态、pending 状态、写入函数和低位 ruler UI。
  - 将 MF 模式与五参数、镜头、更多面板互斥收口。
  - 保持 R58 的 `AE-L + 焦段 + MF` 控制组。
- `README.md`
  - 新增 R59 报告索引。
- `docs/reports/r59_manual_focus_ruler_lens_position_write_closure.md`
  - 本报告。
- `docs/reports/r59_manual_focus_ruler_lens_position_write_closure.json`
  - 结构化验证记录。

## 10. 构建验证

已运行：

```bash
xcodebuild -project /Users/sungning/Projects/SellerCamera/SellerCamera.xcodeproj -scheme SellerCamera -configuration Debug -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO build
```

结果：通过。

同时验证 R59 JSON 可解析。

## 11. 真机验证情况

本轮未运行真机。

仍需真机确认：

- MF ruler 是否可打开。
- 拖动 MF ruler 是否真实改变焦点。
- 再次点击 MF 是否恢复 AF。
- LOCK 下 MF 是否禁用清楚。
- 点击取景区、长按 AE/AF Lock、双指缩放是否体感无回归。
- 低位 ruler 是否遮挡商品主体。

## 12. 遗留风险

- MF 的 `0.0 = 近 / 1.0 = 远` 显示语义需真机确认是否符合当前镜头体感。
- 目前 MF tick 为 `0.05` 步进，若真机觉得太粗或太敏感，下一包应只做手感微调。
- MF 模式下点击取景区不执行 AF tap focus，这符合“避免 AF 覆盖 MF”的策略，但需真机确认是否直观。

## 13. 下一步建议

下一包建议做：

第 40 包：Focus 真机闭环验证 + MF 手感 / 状态显示最小修正。

重点只验证和最小修：

- MF 写入是否真实改变焦点。
- AF 恢复是否稳定。
- LOCK 下禁用是否清楚。
- MF ruler 位置和灵敏度是否需要微调。
- 点击对焦、长按锁定、双指缩放是否无回归。

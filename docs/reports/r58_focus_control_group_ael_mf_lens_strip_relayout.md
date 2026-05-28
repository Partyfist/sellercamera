# R58 Focus 控制组 AE-L / MF 焦段两侧重构报告

## 1. 本包实现范围

本包根据新的产品方向，将 Focus 入口从 R56 / R57 的独立 AF / MF / LOCK 胶囊面板，重构为焦段控制组两侧的轻量胶囊：

```text
AE-L   13mm   24mm   48mm   77mm   MF
```

本包完成：

- 焦段控制组左侧新增 `AE-L` 胶囊。
- 焦段控制组右侧新增 `MF` 胶囊。
- 停用并移除独立 Focus 状态胶囊主入口。
- 停用并移除独立 AF / MF / LOCK Focus 面板主入口。
- `MF` 使用单按钮切换：点击进入 MF 模式，再次点击恢复 AF。
- `MF` 退出时调用现有 `cameraRuntime.restoreAutofocusMode()`。
- LOCK 状态下 `MF` 禁用并给出提示。
- 打开 `MF` 模式时关闭五参数 inline controls、镜头 zoom ruler、更多面板。

本包没有接入 Manual Focus ruler，没有新增 `setManualFocusLensPosition(_:)` 写入，没有改变点击对焦、长按 AE/AF Lock、双指缩放、白底和拍后流程。

## 2. 为什么调整 Focus 方向

此前 R56 / R57 的独立 Focus 胶囊和 AF / MF / LOCK 面板已经验证了状态语义，但产品方向进一步收口为：

- AF 是默认状态，不需要长期作为一个主按钮。
- 用户主动需要的是 `MF` 入口。
- AE-L / MF 与焦段控制同属取景现场控制，应放在焦段组两侧。
- 底部五参数继续只承担画面参数：`EV / WB / TINT / ISO / S`。

因此本包把 Focus 从“独立状态面板”收敛为“取景控制组的一枚 MF 模式开关”。

## 3. AE-L / MF 与焦段组布局

修改后的 `CaptureLensControlStrip` 结构：

- 左侧：`AE-L`
- 中间：设备能力驱动的焦段按钮
- 右侧：`MF`

焦段按钮仍使用 `cameraRuntime.availableSemanticFocalCapabilities`，没有写死所有设备都有 `13mm / 24mm / 48mm / 77mm`。

视觉策略：

- `AE-L`、焦段按钮、`MF` 使用统一胶囊高度、圆角、描边和暗色透明背景。
- 当前焦段继续使用青绿色 active 高亮。
- `AE-L` 锁定态使用琥珀色轻高亮。
- `MF` 激活态使用蓝色轻高亮。
- LOCK 或设备不支持手动对焦时，`MF` 显示弱化禁用态。

## 4. 独立 AF 胶囊和 Focus 面板处理

本包从 UI 主线移除了：

- `CaptureFocusStatusCapsule`
- `CaptureFocusStatusPanel`
- `CaptureFocusStatusPresentation`
- Focus 面板显示 state
- Focus 面板路由 handler

这样拍摄页不会同时出现独立 AF 胶囊和焦段组 `MF` 胶囊，避免双入口混乱。

## 5. MF 单按钮切换 AF / MF

`MF` 胶囊行为：

- 默认 AF 状态下，`MF` 普通态。
- 点击 `MF` 后进入本地 MF 模式，高亮 `MF` 胶囊。
- 再次点击 `MF` 后退出 MF，并调用：

```swift
cameraRuntime.restoreAutofocusMode()
```

本包没有调用：

```swift
cameraRuntime.setManualFocusLensPosition(_:)
```

因此本包只完成 MF 模式入口与 AF 恢复，不做真实 lensPosition 微调闭环。

## 6. LOCK 下 MF 禁用策略

LOCK 优先级继续最高。

规则：

- `cameraRuntime.isFocusExposureLocked == true` 时，`MF` 胶囊弱化。
- LOCK 下点击 `MF` 不进入 MF。
- LOCK 下不调用 `restoreAutofocusMode()`。
- LOCK 下不调用任何 manual focus 写入。
- 提示用户长按画面解除 AE/AF Lock 后再进入 MF。

## 7. 与五参数 / 镜头 / 更多的互斥关系

互斥规则：

- 点击 `MF` 进入模式时，关闭五参数 inline controls。
- 点击 `MF` 进入模式时，关闭镜头 zoom ruler。
- 点击 `MF` 进入模式时，关闭右上角更多面板。
- 点击五参数时，不退出 MF 模式，但会按现有规则关闭镜头 / 更多并打开参数控制。
- 点击焦段时，焦段切换与 zoom ruler 逻辑保持原样；MF 模式状态不强制退出。
- 打开更多面板时，MF 模式状态保持，但无额外 MF 面板需要关闭。

## 8. 与点击对焦 / 长按锁定 / 双指缩放关系

本包未改 `CaptureLivePreviewView` 的点击、长按、缩放实现。

策略：

- AF 状态下，点击取景区仍执行原有点击对焦 / 测光。
- MF 模式下，点击取景区会被当前 `onTapPreviewBeforeFocus` 钩子消费并提示需要点击 `MF` 退出后再点按对焦，避免 AF tap focus 覆盖 MF 模式。
- 长按取景区仍执行现有 AE/AF Lock。
- 进入 LOCK 时，MF 本地模式会自动关闭。
- 双指缩放仍用于 zoom，不受 MF 胶囊影响。

## 9. 是否改动 runtime 合同

本包未改：

- EV 写入路径。
- WB / TINT 组合写入合同。
- TINT RESET 合同。
- ISO / Shutter LOCK 合同。
- 镜头 zoom runtime。
- 点击对焦 runtime。
- 长按 AE/AF Lock runtime。
- 白底图处理 pipeline。
- 拍后 Review / Save / Generate 流程。

本包唯一 Focus runtime 调用是退出 MF 时复用现有 `restoreAutofocusMode()`。

## 10. 修改文件

- `SellerCamera/CaptureScreen.swift`
  - 移除独立 Focus 胶囊 / 面板主入口。
  - 移除上一版 MF ruler UI 与 pending 写入主线。
  - 在 `CaptureLensControlStrip` 中接入 `AE-L` 与 `MF` 胶囊。
  - 新增 `MF` 单按钮本地模式切换与 AF 恢复路由。

- `README.md`
  - 更新 R58 报告索引。

- `docs/reports/r58_focus_control_group_ael_mf_lens_strip_relayout.md`
  - 本报告。

- `docs/reports/r58_focus_control_group_ael_mf_lens_strip_relayout.json`
  - 结构化记录。

## 11. 构建验证

已运行：

```bash
xcodebuild -project /Users/sungning/Projects/SellerCamera/SellerCamera.xcodeproj -scheme SellerCamera -configuration Debug -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO build
```

结果：`BUILD SUCCEEDED`

同时验证 R58 JSON 可解析。

## 12. 真机验证情况

本轮未运行真机。

仍需真机确认：

- `AE-L / 焦段 / MF` 控制组位置是否不遮挡商品主体。
- 小屏下焦段组是否拥挤。
- `MF` 进入 / 退出是否符合预期。
- 退出 MF 是否恢复 AF。
- 点击对焦、长按 AE/AF Lock、双指缩放是否无回归。

## 13. 遗留风险

- 本包只做 MF 模式入口，不做真实 lensPosition 微调；下一包若要手动对焦闭环，仍需单独接入低位 MF ruler。
- `AE-L` 目前复用现有曝光锁定入口，未拆分新的 AE-L runtime 合同。
- MF 模式下点击取景区被消费以避免 AF 覆盖，这个策略需要真机确认是否符合手感。

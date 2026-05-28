# R57 Focus 面板交互语义与 MF 微调前置报告

日期：2026-05-24

## 1. 本包实现范围

本包在 R56 独立 Focus 状态胶囊基础上，完善 Focus 面板内 `AF / MF / LOCK` 三项的交互语义表达。

本包只做 UI 语义和下一包前置方案：

- 不把 Focus 加回底部五参数栏。
- 不新增 Manual Focus ruler。
- 不新增 `setManualFocusLensPosition(_:)` 调用。
- 不改变 `restoreAutofocusMode()` 行为。
- 不改变点击对焦、长按 AE/AF Lock、双指缩放。

## 2. AF / MF / LOCK 交互语义

### AF

语义：自动对焦。

显示规则：

- 当前为 AF 时，AF 行显示 `当前`。
- 当前为 MF 时，AF 行显示 `恢复`，表达后续可作为恢复自动对焦入口。
- 当前为 LOCK 时，AF 行显示 `禁用`，表达锁定状态下不应直接恢复。

后续真实接入建议：

- 点击 AF 时调用 `cameraRuntime.restoreAutofocusMode()`。
- 如果当前处于 AE/AF Lock，应先要求用户长按取景区解除锁定，不在 AF 行直接强制改 runtime。

### MF

语义：手动对焦。

显示规则：

- 当前为 MF 时，MF 行显示 `当前`。
- 当前为 AF 且设备支持手动对焦时，MF 行显示 `微调`，表达下一包的手动微调入口。
- 当前为 LOCK 时，MF 行显示 `禁用`。
- 当前镜头不支持手动对焦时，MF 行显示 `不可用`。

后续真实接入建议：

- 点击 MF 后进入独立低位 Focus 微调面板。
- 不进入底部五参数栏。
- 不与五参数 inline controls 或镜头 zoom ruler 同时展开。

### LOCK

语义：AE/AF Lock。

显示规则：

- 当前为 LOCK 时，LOCK 行显示 `当前`。
- 非 LOCK 时，LOCK 行显示 `长按触发`。

LOCK 行是状态说明，不作为普通开关。本包不新增点击 LOCK 进入锁定的行为。

## 3. 当前状态高亮规则

Focus 状态优先级继续保持：

```text
LOCK > MF > AF
```

状态来源：

- `LOCK`：`cameraRuntime.isFocusExposureLocked`
- `MF`：`cameraRuntime.focusControlMode == .manual`
- `AF`：以上条件都不满足时的保守默认

视觉规则：

- 当前状态使用对应 accent 描边和轻填充。
- 后续可操作入口使用轻强调状态标签。
- LOCK 下不可用项使用低透明度禁用态。
- AE-L only 不映射为 Focus LOCK。

## 4. LOCK 下 MF 禁用规则

当前包明确：

- `isFocusExposureLocked == true` 时，Focus 面板和胶囊显示 LOCK。
- LOCK 下 MF 行禁用，显示 `锁定中不可微调`。
- LOCK 下 AF 行也不直接提供 runtime 恢复动作。
- 解锁路径仍通过原有长按取景区逻辑完成。

原因：

- LOCK 是用户明确锁定 AE/AF 的状态。
- 直接从面板中切 AF 或 MF 容易破坏现有长按锁定语义。
- 下一包如要增加解锁入口，应单独定义，不在本包实现。

## 5. AF 恢复自动对焦后续方案

下一包或后续真实接入时，AF 行可以成为恢复自动对焦入口。

建议行为：

1. 如果当前为 MF 且未 LOCK，点击 AF。
2. 调用 `cameraRuntime.restoreAutofocusMode()`。
3. 清理 MF pending 状态。
4. Focus 胶囊显示 AF。
5. 不影响 EV / WB / TINT / ISO / Shutter。

LOCK 状态下不建议直接调用 AF 恢复。应提示或要求先长按解除锁定。

## 6. MF 微调后续接入方案

下一包建议为独立 Focus 低位微调，而不是回到底部五参数。

建议入口：

- 点击 Focus 面板的 MF 行。

建议 UI：

- 使用独立低位 Focus 面板。
- 面板可复用五参数 / 镜头的横向 ruler 视觉语言。
- 左侧语义：`Near / 近`
- 右侧语义：`Far / 远`
- 当前值显示：`MF 35`、`MF 0.35` 或 `35%`

建议写入路径：

- `cameraRuntime.setManualFocusLensPosition(_:)`

建议 pending / 回写：

- `pendingManualFocusPosition`
- 使用 `currentManualFocusPosition` 回写确认。
- 同值去重。
- 边界去重。
- 超时回收。
- tick 变化轻触觉反馈。

建议节流：

- 只在 tick 变化时写入。
- 避免每一帧拖动都调用 runtime。
- LOCK 或 unsupported 时不写入。

## 7. 与五参数 / 镜头 / 更多互斥

当前互斥规则保持：

- 打开 Focus 面板时，关闭五参数 inline controls。
- 打开 Focus 面板时，关闭镜头 zoom ruler。
- 打开 Focus 面板时，关闭更多面板。
- 打开五参数、镜头调节或更多面板时，关闭 Focus 面板。
- 点击取景区时关闭 Focus 面板。

Focus 胶囊可以继续作为状态展示存在，但 Focus 面板不与其它低位控制层同时展开。

## 8. 与点击对焦 / 长按锁定 / 双指缩放关系

本包未改 `CaptureLivePreviewView`。

保持：

- 点击取景区仍执行原有点击对焦 / 测光。
- Focus 面板打开时，第一次点击取景区只关闭面板，不同次对焦。
- 长按取景区仍执行原有 AE/AF Lock。
- 双指缩放仍执行原有 lens zoom。

## 9. 修改文件

- `SellerCamera/CaptureScreen.swift`
  - 强化 Focus 面板三态行的 selected / disabled / future-entry 语义。
  - 增加 AF / MF / LOCK 行内状态标签。
  - 保持面板为只读骨架，不接 runtime 写入。

- `README.md`
  - 增加 R57 报告索引。

- `docs/reports/r57_focus_panel_interaction_semantics_and_mf_preflight.md`
  - 本报告。

- `docs/reports/r57_focus_panel_interaction_semantics_and_mf_preflight.json`
  - 本轮结构化记录。

## 10. 构建验证

已执行：

```bash
xcodebuild -project /Users/sungning/Projects/SellerCamera/SellerCamera.xcodeproj -scheme SellerCamera -configuration Debug -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO build
```

结果：通过。

已执行：

```bash
python3 -m json.tool /Users/sungning/Projects/SellerCamera/docs/reports/r57_focus_panel_interaction_semantics_and_mf_preflight.json
```

结果：通过。

## 11. 真机验证情况

本轮尚未运行真机。

仍需真机确认：

- AF / MF / LOCK 三态是否一眼可读。
- LOCK 下 MF 禁用是否清楚。
- Focus 胶囊与面板是否仍不遮挡商品主体。
- 点击对焦和长按锁定是否未回归。

## 12. 遗留风险

- 本包仍是语义骨架，未接真实 MF 微调。
- 下一包接入 MF ruler 前，需再次确认 LOCK 状态下的禁用与解锁路径。
- AF 恢复自动对焦入口未来接入时，需要避免破坏 AE/AF Lock 语义。

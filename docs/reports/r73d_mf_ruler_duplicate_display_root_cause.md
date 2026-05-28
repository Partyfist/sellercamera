# R73D MF Ruler 重复显示真因定位与最小修复报告

## 1. 改动摘要

R73D 对 MF ruler 重复显示做代码级来源排查，并在 R73C 基础上补上遗漏场景：

- R73C 已隐藏 selected tick label，但 MF `0.005` 密刻度后，当前值附近的相邻 major tick 仍可能显示 `50`，在真机上看起来像中央重复读数。
- R73C 已过滤 `MF ` 前缀 hint，但 MF 相关提示并不都只能依赖该前缀判断，仍需按 MF ruler 打开态做更稳的过滤。

本包只做 MF 显示层最小修复，不改 MF runtime、默认居中、0.005 step、normal/fine/ultraFine、轻量惯性、haptic 或其它参数主链路。

## 2. 文件清单

- `SellerCamera/CaptureScreen.swift`
  - 增加 MF tick label 的“中心附近去重”判断。
  - 扩展 MF ruler 打开态下的 MF hint 过滤条件。

- `docs/reports/r73d_mf_ruler_duplicate_display_root_cause.md`
  - 新增本报告。

- `README.md`
  - 增加 R73D 报告索引。

## 3. 真机反馈问题

真机反馈需要查明 MF ruler 中重复的 `50 / 50%` 具体来源，而不是继续凭截图猜测。

此前截图观察到：

- 上方 bubble：`MF 50`
- 中央附近：`50`
- 背景隐约：`50%`

## 4. MF 显示来源排查

### 4.1 当前值 bubble 来源

来源：

- `SellerCamera/CaptureScreen.swift`
- `CaptureManualFocusRulerPanel.valueBadge`
- 文案来自 `currentValueText`
- 上游为 `formattedManualFocusRulerValue(manualFocusDisplayPosition)`

职责：

- 作为 MF ruler 当前值主读数。
- 显示格式为 `MF 50`。

结论：

- 这是应该保留的唯一主读数。

### 4.2 tick label 来源

来源：

- `SellerCamera/CaptureScreen.swift`
- `CaptureManualFocusRulerPanel.focusRulerTicks`
- `focusTickLabel(_:)`
- `isMajorTick(_:)`

职责：

- 显示主刻度标签：`0 / 25 / 50 / 75 / 100`。

R73C 处理情况：

- R73C 将 selected tick 的文字隐藏。

R73C 遗漏点：

- MF ruler 使用 `0.005` 密刻度后，如果 selected value 不是精确 `0.500`，`0.500` 对应的 major tick 可能是 selected tick 附近的相邻 tick，而不是 selected tick 本身。
- 该相邻 major tick 仍会显示 `50`，在中心指针附近形成“第二个 50”。

R73D 修复：

- 不只隐藏 selected tick。
- 同时隐藏 selected index 附近 ±4 tick，或 value 与 selected value 差值小于约 `0.0201` 的 major label。
- 非中心区域的 `0 / 25 / 75 / 100` 等主刻度标签继续保留。

### 4.3 hint / overlay 来源

来源：

- `SellerCamera/CaptureLivePreviewView.swift`
- `setManualFocusLensPosition(_:)` 成功后设置 `captureHintText = "MF \(manualFocusDisplayText)"`
- `manualFocusDisplayText` 包含 `manualFocusPercentText`，例如 `中距 · 50%`
- `SellerCamera/CaptureScreen.swift`
- `CapturePreviewContainer` 通过 `CaptureAssistHintSlot` 渲染 `captureHintText`

职责：

- 显示拍摄辅助提示。

R73C 处理情况：

- R73C 在 MF ruler 打开态下过滤 `MF ` 前缀 hint。

R73D 修复：

- 扩展过滤逻辑：只要 MF ruler 打开，过滤 `MF` 前缀、`手动对焦`、`MF 模式`、`MF 生效` 相关 hint。
- 这样避免 MF 百分比提示在 ruler 背后形成 `50%` 残影。

### 4.4 bottom bar / lens strip 来源

排查结果：

- 底部五参数栏当前不包含 Focus / MF。
- 焦段控制组 MF 胶囊只显示固定 `MF`，不显示 `50` 或 `50%`。
- Lens strip 本身不是重复百分比来源。

### 4.5 其它可能来源

排查结果：

- `CaptureBottomParameterBar` 的 tick label 属于 EV / WB / TINT / ISO / Shutter，不渲染 MF。
- `CaptureProfessionalParameterPanel` 不是当前 MF 低位 ruler 主路径。
- `manualFocusDisplayText` 还用于旧 Focus parameter state 文案，但 Focus 不在底部五参数主线中，当前 MF ruler 重复显示主要不是这里触发。

## 5. 具体原因结论

`MF 50` 来源：

- `CaptureManualFocusRulerPanel.valueBadge`
- 这是正确主读数，应保留。

第二个 `50` 来源：

- MF ruler 的 major tick label。
- R73C 隐藏了 selected tick，但未覆盖“selected 附近的相邻 major tick”。
- 在 MF `0.005` 密刻度下，当前值接近 0.5 时，`50` 标签可能仍位于中心附近。

背景 `50%` 来源：

- `CaptureLivePreviewView.manualFocusPercentText`
- 通过 `captureHintText = "MF \(manualFocusDisplayText)"` 进入 `CaptureAssistHintSlot`。
- R73C 只按 `MF ` 前缀过滤，R73D 改为 MF ruler 打开态下按 MF 相关 hint 统一过滤。

## 6. 最小修复方案

本次只做两处最小修复：

1. `CaptureManualFocusRulerPanel` 增加 `shouldShowFocusTickLabel(index:value:)`
   - 只显示 major tick。
   - 隐藏 selected tick 附近 ±4 tick。
   - 隐藏 value 与 selected value 相差 `<= 0.0201` 的 label。
   - 不隐藏远离中心的主刻度标签。

2. `CapturePreviewContainer.isManualFocusHint(_:)` 扩展判断
   - MF ruler 打开时过滤 MF 前缀与手动对焦相关 hint。
   - 避免背景辅助提示显示 `50%`。

## 7. R73B / R73C 手感保留情况

未改：

- MF 默认视觉居中。
- MF `0.005` step。
- MF normal `2.0x`。
- fine / ultraFine 上拉微调。
- MF very light inertia。
- haptic 节流。
- LOCK / disabled 阻断。
- `setManualFocusLensPosition(_:)` 调用路径。

WB / ISO / Shutter / EV / Lens 主链路未改。

## 8. 验证结果

已执行：

```bash
xcodebuild -scheme SellerCamera -project SellerCamera.xcodeproj -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/SellerCameraR73DBuild CODE_SIGNING_ALLOWED=NO clean build
```

结果：`BUILD SUCCEEDED`

构建过程中仍出现项目既有 nested project reference 警告：

- `SellerCamera/SellerCamera.xcodeproj` 缺少 `project.pbxproj`

该警告未阻塞根工程构建，本包未修改该历史引用。

真机待复核：

- MF ruler 打开时只显示一个当前主读数。
- 中央附近不再出现相邻 major tick 的 `50`。
- 背景不再出现 `50%` 辅助提示残影。
- MF 默认居中、密刻度、微调、惯性不回退。

## 9. 风险与真机待复核项

本次隐藏中心附近 major label 后，中心区域更干净，但需要真机确认：

- 中心附近无 label 后，用户是否仍能通过指针和 value badge 获得足够定位感。
- `0 / 25 / 75 / 100` 等远离中心的主刻度标签是否仍提供足够区间感。
- MF hint 过滤是否不会误伤其它重要拍摄提示。

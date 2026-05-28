# R73C MF Ruler 重复数值显示清理报告

## 1. 改动摘要

R73C 针对真机反馈“MF ruler 中出现两个 50，并有背景 50% 残影”做最小视觉去重补丁。

本次只调整 MF ruler 的显示条件：

- 保留上方当前值气泡 `MF 50` 作为唯一主读数。
- 隐藏中央 selected tick 的重复数值标签。
- MF ruler 打开时隐藏 `captureHintText` 中的 `MF ... 50%` 背景提示。

未改 MF runtime 写入、未改 R73B 的 `0.005` step、默认居中、normal/fine/ultraFine、轻量惯性或 haptic 节流。

## 2. 文件清单

- `SellerCamera/CaptureScreen.swift`
  - MF selected tick label 去重。
  - MF ruler 打开时隐藏 MF hint，避免背景 `50%` 残影。

- `docs/reports/r73c_mf_ruler_duplicate_value_cleanup.md`
  - 新增本报告。

- `README.md`
  - 增加 R73C 报告索引。

## 3. 真机反馈问题

真机截图显示 MF ruler 打开后同时出现：

1. 上方当前值气泡：`MF 50`
2. 中央 selected tick 标签：`50`
3. 背景提示残影：类似 `50%`

这三者表达同一个当前对焦位置，造成重复读数和视觉噪音。

## 4. 重复显示原因

当前 MF ruler 的 tick 规则会对 `0 / 25 / 50 / 75 / 100` 显示主刻度标签。

R73B 将默认视觉值设为 `0.5`，因此 selected tick 刚好落在主刻度 `50` 上；同时上方 value badge 也显示 `MF 50`。

背景残影来自 `setManualFocusLensPosition(_:)` 成功后写入的 `captureHintText`，例如 `MF 中距 · 50%`。在 MF ruler 打开期间，该 hint 仍会被 `CaptureAssistHintSlot` 渲染，位置接近 ruler，形成残影。

## 5. 当前值唯一化方案

采用单一主读数策略：

- 当前值只由上方 value badge 显示。
- 文案继续使用现有 `MF 50` 格式。
- 不改底部栏或 MF 胶囊状态。
- 不改 `formattedManualFocusRulerValue(_:)`。

这样用户只需要看一个主读数，中心指针负责定位，刻度线负责表达位置。

## 6. 中央 tick 标签去重

MF tick label 规则调整为：

- major tick 可显示标签。
- selected tick 不显示标签。
- 非 selected 的 `0 / 25 / 75 / 100` 等主刻度仍可显示。

实现上使用 `isMajor && !isSelected` 控制 label 文案，保持刻度线与 selected 指针不变，不影响拖动、haptic、惯性或 `0.005` tick 密度。

## 7. 背景残影清理

`CapturePreviewContainer` 中新增 MF hint 过滤：

- 当 `isManualFocusRulerPresented == true`
- 且 `captureHintText` 以 `MF ` 开头
- 不渲染该 hint

这只影响 MF ruler 打开态的重复背景提示。Lens 切换 transient hint 和其它非 MF hint 的逻辑保持不变。

## 8. R73B 手感保留情况

本包未改以下内容：

- MF `0.005` step。
- MF 默认视觉居中。
- MF 打开不写入 `0.5`。
- MF normal `2.0x`。
- fine / ultraFine 上拉微调。
- MF very light inertia。
- haptic 节流。
- LOCK / disabled 阻断。
- `setManualFocusLensPosition(_:)` 调用路径。

WB / ISO / Shutter / EV / Lens 的主链路未改。

## 9. 构建与运行验证

已执行：

```bash
xcodebuild -scheme SellerCamera -project SellerCamera.xcodeproj -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/SellerCameraR73CBuild CODE_SIGNING_ALLOWED=NO clean build
```

结果：`BUILD SUCCEEDED`

构建过程中仍出现项目既有 nested project reference 警告：

- `SellerCamera/SellerCamera.xcodeproj` 缺少 `project.pbxproj`

该警告未阻塞根工程构建，本包未修改该历史引用。

真机待复核：

- MF ruler 打开时是否只剩一个 `MF 50` 主读数。
- 中央指针下方是否不再显示重复 `50`。
- 背景是否不再出现 `50%` 残影。
- MF 默认居中、密刻度、微调、惯性是否不回退。

## 10. 风险与真机待复核项

本包属于视觉条件隐藏，风险较低。

仍需真机确认：

- selected tick 隐藏文字后，MF ruler 的定位感是否仍清楚。
- MF hint 被隐藏后，用户是否仍能通过 value badge 理解当前值。
- 非 selected 主刻度标签是否足够表达区间位置。

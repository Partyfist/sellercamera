# R73A 参数表盘拖动灵敏度加速修复报告

## 1. 改动摘要

R73A 针对真机反馈“参数表盘拖动太慢、相同滑动距离覆盖范围太窄”做最小补丁。改动只作用于 drag translation 到 tick step 的映射倍率，不改变视觉 tickSpacing、不改变 tick 生成、不改变 runtime 写入主链路、不改变 Auto / Manual / Lock 语义。

本轮让普通拖动更快，同时保留 R73 的上拉慢速微调、方向切换 cooldown 重置、边界位移消费与 haptic 节流。

## 2. 文件清单

- `SellerCamera/CaptureBottomParameterBar.swift`
  - 调整五参数通用横向 ruler 的 normal / fine / ultraFine 灵敏度倍率。
- `SellerCamera/CaptureScreen.swift`
  - 调整 Lens zoom 独立 ruler 的 normal / fine / ultraFine 灵敏度倍率。
  - 调整 Manual Focus ruler 的 normal / fine / ultraFine 灵敏度倍率。
- `docs/reports/r73a_parameter_ruler_drag_sensitivity_acceleration.md`
  - 新增 R73A 修复报告。
- `README.md`
  - 增加 R73A 报告索引。

## 3. 问题原因

R73 将 Lens / MF 与五参数表盘的微调、haptic、边界消费规则收口后，普通模式仍沿用较保守的 1.0x 映射；fine / ultraFine 又进一步降低灵敏度。真机上表现为默认拖动效率不足，用户需要较长距离才能跨过足够参数范围。

这不是刻度密度问题，也不是 runtime 写入范围问题，而是普通拖动的位移到 step 映射过慢。

## 4. 灵敏度调整方案

本轮采用局部 `scrubSensitivity` 调整，不改变视觉间距：

- 五参数通用 ruler：normal `1.8x`，fine `0.75x`，ultraFine `0.35x`。
- Lens zoom ruler：normal `2.2x`，fine `0.75x`，ultraFine `0.35x`。
- MF ruler：normal `2.0x`，fine `0.70x`，ultraFine `0.35x`。

这些倍率通过降低等效 step threshold 提升普通拖动速度；上拉后仍提高等效 threshold，实现低速微调。

## 5. 参数影响范围

- Lens：普通拖动覆盖倍率范围更大，仍使用 0.1x tick 与现有 zoom 写入路径。
- MF：普通拖动从近到远效率提高，仍保持上拉慢速微调与 `setManualFocusLensPosition(_:)` 路径。
- WB：通用 ruler normal 加速后，同样滑动距离可跨过更多 50K tick；AUTO takeover、RESET、pending manual 未改。
- ISO：通用 ruler normal 加速后，可更快跨越合法 ISO tick；R66 safe clamp 未改。
- Shutter：通用 ruler normal 加速后可更快跨越快门 tick；R69/R70/R71A 的全范围、锚点、惯性与写入节流未改。
- EV：通用 ruler normal 加速后调节更快；EV 的半自动 LOCK 与 runtime 写入保护未改。

## 6. 慢速微调保留情况

普通拖动和微调仍按手指相对轨道的垂直位移分层：

- normal：手指贴近轨道，快速覆盖范围。
- fine：上拉超过 40pt，进入较慢精调。
- ultraFine：上拉超过 90pt，进入更慢精修。

进入和退出 fine / ultraFine 不重置参数，不改变当前值，不改变 Auto / Manual 状态。

## 7. Haptic 与边界保护

R73 的 haptic 节流规则保持：

- 五参数通用 ruler 继续按参数、selected index、step 签名和时间节流。
- Lens / MF 继续按 selected index、step 签名和时间节流。
- LOCK / disabled 时仍由 `isEnabled` / `isAvailable` guard 阻断。
- 边界与 cooldown 位移仍先消费，避免加速后重新出现 residual 或反向卡住。

## 8. 构建验证

已执行：

```bash
xcodebuild -scheme SellerCamera -project SellerCamera.xcodeproj -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/SellerCameraR73ABuild CODE_SIGNING_ALLOWED=NO clean build
```

结果：`BUILD SUCCEEDED`。

备注：构建开始阶段仍有历史嵌套工程引用警告，路径为 `SellerCamera/SellerCamera.xcodeproj` 且缺少 `project.pbxproj`；根工程 `SellerCamera.xcodeproj` 构建成功。

## 9. 真机待复核项

本轮 Codex 环境不直接声明真机已验证。建议真机重点复核：

- Lens 普通拖动是否明显更快，fine / ultraFine 是否仍能微调。
- MF 从近到远是否不再拖不动，对焦是否无明显抖动。
- WB / ISO / Shutter / EV 是否更顺手但不过飞。
- Haptic 是否仍克制。
- 边界是否仍能自然回退。
- Shutter 惯性是否没有因 normal 加速变得失控。

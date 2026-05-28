# R73E MF Ruler 刻度间距减半与拖动覆盖增强报告

## 1. 改动摘要

R73E 针对真机反馈“MF 刻度间距缩小一半，并让同距拖动覆盖更广”做最小补丁。

本包只调整 MF ruler：

- MF 视觉 `tickSpacing` 从 `28pt` 缩小到 `14pt`。
- MF drag step threshold 从 `40pt` 缩小到 `20pt`。
- 保留 MF `0.005` step。
- 保留 MF 默认居中。
- 保留 R73D 当前值去重与 MF hint 过滤。
- 保留 normal / fine / ultraFine、very light inertia、haptic 节流与 LOCK 保护。

未改 MF runtime 写入方法，未改 WB / ISO / Shutter / EV / Lens 主链路。

## 2. 文件清单

- `SellerCamera/CaptureScreen.swift`
  - MF ruler `tickSpacing` 减半。
  - MF drag step threshold 减半。
  - MF 中心附近 label hide range 扩大，防止密刻度下重复 `50` 回归。

- `docs/reports/r73e_mf_ruler_tick_spacing_halved_and_drag_range.md`
  - 新增本报告。

- `README.md`
  - 增加 R73E 报告索引。

## 3. 真机反馈问题

真机反馈指出 MF ruler 需要：

- 刻度间距缩小一半。
- 同样手指滑动距离下，参数调整范围更广。

这说明 R73D 的 MF 手感仍偏“视觉间距大、覆盖范围偏慢”，需要让 normal 拖动承担更强的粗调效率。

## 4. MF tick spacing 调整

调整前：

- `tickSpacing = 28`

调整后：

- `tickSpacing = 14`

效果：

- 同样宽度下可见 tick 数量约翻倍。
- MF ruler 视觉更密，更接近专业细密滚轮。
- 未改变 MF `values` 生成，仍为 `0.0...1.0`，step `0.005`。

## 5. drag mapping 与 tick spacing 关系

代码排查发现，当前 MF drag mapping 并不是直接用 `translation / tickSpacing`，而是使用独立 step threshold：

- R73D：`threshold = 40`
- R73E：`dragStepThreshold = 20`

如果只改 `tickSpacing`，视觉会变密，但同距拖动覆盖范围不会变广。为满足 R73E 产品目标，本包同步将 MF drag threshold 减半。

效果：

- normal 模式下，同样滑动距离可跨越约 2 倍 MF tick。
- fine / ultraFine 仍通过上拉降低灵敏度。
- 不改 runtime 写入语义。

## 6. normal / fine / ultraFine 调整

本包未改 R73A 的 sensitivity multiplier：

- normal：`2.0`
- fine：`0.70`
- ultraFine：`0.35`

实际覆盖增强来自 `dragStepThreshold` 减半，而不是提高 multiplier。

这保留了 R73A 的分层语义：

- normal 用于快速覆盖。
- fine 用于中速微调。
- ultraFine 用于精细落点。

## 7. R73D 去重逻辑保留情况

R73D 的当前值唯一化继续保留：

- 上方 bubble 仍是唯一主读数，例如 `MF 50`。
- selected tick 不显示文字。
- MF ruler 打开态过滤 MF hint，避免背景 `50%`。

由于 tick spacing 减半后中心附近可见 tick 增多，本包扩大了中心附近 label hide range：

- index 从 `±4` 扩大到 `±8`
- value 距离从 `<= 0.0201` 扩大到 `<= 0.0401`

这样可以防止 `50` 作为相邻 major label 重新贴近中心出现。

## 8. MF 手感保留情况

保留：

- MF `0.005` step。
- MF 默认视觉居中。
- 打开 MF 不写入 `0.5`。
- normal / fine / ultraFine。
- very light inertia。
- haptic 节流。
- clamp / 边界回退。
- LOCK / disabled 阻断。
- `setManualFocusLensPosition(_:)` 路径。

未触碰：

- WB / ISO / Shutter / EV / Lens。
- 白底处理。
- 拍后 Review / Compare / Save。

## 9. 构建与运行验证

已执行：

```bash
xcodebuild -scheme SellerCamera -project SellerCamera.xcodeproj -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/SellerCameraR73EBuild CODE_SIGNING_ALLOWED=NO clean build
```

结果：`BUILD SUCCEEDED`

真机待复核：

- MF 刻度间距是否约减半。
- 同屏可见 tick 是否明显更多。
- 同距拖动 MF 参数覆盖是否更广。
- normal 是否更快但不失控。
- fine / ultraFine 是否仍可精准。
- 中央是否不再出现第二个 `50`。
- 背景是否没有 `50%`。

## 10. 风险与真机待复核项

本包让 MF normal 覆盖范围明显增强，需真机确认：

- normal 是否过快。
- fine / ultraFine 是否足以承担精准落点。
- haptic 是否因为 step 更快而过密。
- MF 对焦是否出现抖动。

如果真机反馈 normal 过快，建议下一包仅微调 MF `normal` 或 `dragStepThreshold`，不要回退 `tickSpacing` 减半方向。

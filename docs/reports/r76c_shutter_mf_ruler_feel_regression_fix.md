# R76C S / MF 参数表盘手感回归修复报告

## 1. 改动摘要

- 将 Shutter ruler 主 tick 从 1/8-stop log 密集序列收口为商品拍摄常用固定锚点序列。
- 保留 Shutter activeFormat 最慢 / 最快端点、当前值与 pending 值，runtime 写入仍走既有 clamp / sanitize 链路。
- 将 Shutter 单次普通拖动最大步进从 1 档提高到 2 档，降低常用快门区拖动“走不远”的感觉。
- 清理 MF ruler 中心重复视觉：当前 selected tick 不再绘制刻度线，中心附近主刻度标签继续隐藏，避免主读数下方重复 `50` 和中心双线。
- 微调 MF ruler 阻尼：tick spacing 从 14pt 调整到 10pt，normal 从 2.0x 调整为 2.2x，fine / ultraFine 降低为 0.56x / 0.24x，保留精准微调层级。
- 保留 MF 0.005 step、默认居中、轻量惯性、haptic 节流、LOCK / disabled 保护。

## 2. 文件清单

- `SellerCamera/CaptureScreen.swift`
  - 新增 Shutter 固定锚点分母 / duration helper。
  - 调整 Shutter tick 生成、major tick 标记和最大拖动步进。
  - 调整 MF ruler tick spacing、拖动灵敏度、惯性步进和中心 tick / label 去重。
- `README.md`
  - 增加 R76C 报告索引。
- `docs/reports/r76c_shutter_mf_ruler_feel_regression_fix.md`
  - 新增本轮修复报告。

## 3. Shutter / S 当前问题判断

R70-R71A 后 Shutter 写入与 activeFormat 安全链路已经稳定，但 R76C 前的 ruler 仍使用 1/8-stop log 序列生成大量中间 tick，再混入常用快门锚点。真机手感上会出现：

- 常用档位之间 tick 过多，普通拖动同距覆盖范围偏窄；
- `1/30...1/250` 常用商品拍摄区不够容易跨档；
- 固定摄影语义锚点被大量中间值稀释；
- 表盘更像连续技术值列表，不像固定快门档位滚轮。

因此本轮不改 runtime 写入，而是把交互主序列收口为固定锚点。

## 4. Shutter 固定锚点序列

本轮主锚点：

```text
1/30
1/50
1/60
1/96
1/100
1/120
1/125
1/200
1/240
1/250
1/500
1/1000
1/2000
1/4000
1/8000
```

实现策略：

- 使用 `activeFormat` 读取到的 `minimumShutterDurationSeconds` / `maximumShutterDurationSeconds` 作为真实边界。
- 只保留落在当前 activeFormat 范围内的固定锚点。
- 始终加入 activeFormat 最慢 / 最快端点，避免丢失完整能力范围。
- 加入当前 runtime / manual / pending duration，避免 readback 或 pending 值在 UI 中丢失。
- 最终统一 clamp、deduplicate、按 duration 从慢到快排序。

## 5. Shutter 拖动与边界保护

- Shutter 普通拖动 `maximumStepCount` 从 1 提升为 2，允许一次输入跨过更多固定锚点。
- 既有 duplicated tick guard、pending/committed 分离、active dragging 判断未修改。
- 既有 R66/R69 自定义曝光写入安全 clamp 未修改。
- activeFormat 之外的 anchor 不会进入最终 tick；runtime 仍以当前设备能力范围做最终保护。

## 6. MF 重复显示与中心双线清理

R76C 前 MF 仍可能在中心位置同时看到：

- 上方当前值 bubble：`MF 50`
- selected tick 的中心刻度线；
- selected / 0.5 附近 major label：`50`

本轮处理：

- selected tick 或与 selected value 相差不超过 `0.0051` 的 tick 不再绘制刻度线。
- 中心附近 label 隐藏范围扩大到 ±10 tick 或 value ±0.0501。
- 保留上方当前值 bubble 作为唯一主读数。
- 不隐藏所有主刻度；远离中心的 `0 / 25 / 50 / 75 / 100` 仍可作为空间参照。

## 7. MF 拖动阻尼优化

- MF `tickSpacing`：14pt → 10pt。
- MF `dragStepThreshold`：20pt → 18pt。
- MF normal：2.0x → 2.2x。
- MF fine：0.70x → 0.56x。
- MF ultraFine：0.35x → 0.24x。
- MF inertia：仍为 very light，但允许最终最多 2 个 0.005 step，避免死停又避免飞轮感。

这些调整让 normal 同距覆盖更广，fine / ultraFine 继续承担精确落点，不改 `setManualFocusLensPosition(_:)` 写入语义。

## 8. 影响范围

- Shutter：仅改 ruler tick 生成与交互步进，不改曝光写入、ISO 联动、EV Lock 语义。
- MF：仅改 ruler 视觉去重与手感参数，不改 runtime 写入、AF / MF / LOCK 语义。
- Auto EV / Auto WB / ProductSharpness：未修改。
- WB / ISO / EV / Lens：未修改主链路。
- 拍照、白底、拍后：未修改。

## 9. 构建与运行验证

- `git status`：执行，变更仅包含 `CaptureScreen.swift`、`README.md` 与本报告。
- `xcodebuild -scheme SellerCamera -project SellerCamera.xcodeproj -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/SellerCameraR76CBuild CODE_SIGNING_ALLOWED=NO clean build`：通过，`BUILD SUCCEEDED`。
- 真机运行：本轮未声明完成真机手滑验收；需要在真机上重点复核 S 常用档位跨档、MF 中心唯一读数、MF normal / fine / ultraFine 手感。

## 10. 风险与真机待复核项

- Shutter 从 log 密集序列收口到固定锚点后，常用档位会更好停靠，但极端端点附近的非锚点连续细调减少；这是本轮为了固定档位手感做的取舍。
- activeFormat 最慢 / 最快端点仍会出现在 tick 列表里；如果真机认为极端端点干扰常用档位，可下一轮只在边界附近弱化标签。
- MF tick spacing 与 normal 灵敏度都提高后，normal 更快；如真机仍觉得 MF 过快，可仅小幅下调 normal，不回退中心去重。
- MF center tick line 被隐藏后，中心定位完全由蓝色指针承担；需真机确认视觉足够清楚。

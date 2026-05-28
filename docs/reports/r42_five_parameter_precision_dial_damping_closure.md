# R42 五参数滚轮精密阻尼二次收口报告

## 1. 本包定位

- 包类型：五参数滚轮精密阻尼二次收口包。
- 范围：仅调整 `EV / WB / TINT / ISO / S` 的拖动阈值、单次最大跨档和档位触发节奏。
- 边界：不改任何相机 runtime 写入路径，不改白底链路，不改拍后流程，不新增 Focus 控件。

## 2. 本轮阻尼修正

R41 已完成 per-parameter sensitivity，但真机反馈仍然偏快。本轮继续收口为“精密微调”：

| 参数 | R42 触发阈值 | R42 单次最大跨档 | 说明 |
| --- | ---: | ---: | --- |
| EV | 42pt | 1 档 | 亮暗变化明显，优先慢和稳 |
| WB | 40pt | 2 档 | 允许明确大滑最多 2 档，但取消 3 档 |
| TINT | 44pt | 1 档 | 色偏微调，避免过敏 |
| ISO | 40pt | 2 档 | 常用 1/3 stop 档位，明确大滑最多 2 档 |
| S / Shutter | 44pt | 1 档 | 快门变化敏感，优先停得住 |

## 3. 取消 3 档跨越

- 本包取消所有参数的一次手势 3 档跨越。
- EV / TINT / Shutter 收敛为最多 1 档。
- WB / ISO 仅在明确大幅拖动时最多 2 档。
- active 参数切换不触发写入。

## 4. 累计拖动与触发节奏

当前滚轮仍沿用“消耗 translation”的累计机制：

1. `lastDragStepTranslation` 记录已消耗位移。
2. 触发后只扣除已应用档位对应阈值。
3. 手势结束时清空累计。
4. 边界、重复值、LOCK、disabled 不触发反馈。

本轮新增 0.08s 的单列档位触发冷却：

- 避免同一次拖动事件流中连续过密写入；
- 不改变写入路径；
- 不增加复杂物理惯性或横向刻度尺。

## 5. 档位列表

本包优先修正阻尼，没有继续扩展档位列表：

- EV：保持 `-2.0 ... +2.0` 1/3 EV；
- WB：保持 R41 `2800K ... 8000K` 常用 Kelvin 列表；
- TINT：保持 `-50 ... +50` step `5`；
- ISO：保持 R41 常用 1/3 stop ISO 列表；
- Shutter：保持 R39/R41 快门常用 1/3 stop 列表。

所有参数继续按设备能力裁剪。

## 6. 触觉反馈

- 仍只在真实档位变化成功后触发。
- 跨 2 档时只触发一次反馈。
- 边界、重复值、LOCK、disabled 不触发滚轮档位反馈。
- RESET / AUTO 仍保持一次轻反馈。
- 未引入 heavy feedback。

## 7. 功能合同保护

本包未改变以下合同：

- 底部五参数仍为 `EV / WB / TINT / ISO / S`；
- Focus 不回到底部五参数栏；
- TINT 是 `RESET`，不是 `AUTO`；
- WB 调节保留 TINT；
- TINT 调节保留 WB Kelvin；
- WB AUTO 后 TINT 回 0；
- TINT RESET 只归零色偏；
- ISO 非 Auto 时 Shutter LOCK；
- ISO AUTO 后 Shutter 恢复可调；
- EV / WB / TINT / ISO / Shutter 的 runtime 写入路径未改。

## 8. 修改文件

- `SellerCamera/CaptureBottomParameterBar.swift`
- `SellerCamera/CaptureScreen.swift`
- `README.md`
- `docs/reports/r42_five_parameter_precision_dial_damping_closure.md`
- `docs/reports/r42_five_parameter_precision_dial_damping_closure.json`

## 9. 验证结果

- 已执行 iOS Simulator Debug 构建：
  - `xcodebuild -project /Users/sungning/Projects/SellerCamera/SellerCamera.xcodeproj -scheme SellerCamera -configuration Debug -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO build`
- 结果：通过。
- 真机手感：当前会话内未执行真机安装与人工滑动验证，需后续确认“是否明显比 R41 更慢、哪个参数仍然最快”。

## 10. 遗留风险

1. 阻尼已在代码层二次收口，但真实手感仍必须靠真机确认。
2. 0.08s 冷却是保守节奏控制，如真机仍偏快，可继续提高到 0.10s 或统一最大 1 档。
3. 本包未做独立 Focus 对焦系统，也未触碰白底、拍后或镜头切换链路。

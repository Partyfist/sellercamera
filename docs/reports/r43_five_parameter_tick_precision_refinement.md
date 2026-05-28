# R43 五参数档位精细化二次收口报告

## 1. 本包定位

- 包类型：五参数档位精细化包。
- 范围：仅细化 `EV / WB / TINT / ISO / S` 的可选档位，重点提升常用区可调精度。
- 边界：保留 R42 慢速阻尼，不改 runtime 写入合同，不改白底链路，不改拍后流程，不让 Focus 回到底部五参数栏。

## 2. EV 档位

- EV 保持 `-2.0 ... +2.0` 的 1/3 EV 标准档位。
- 本包未改 EV 档位，原因是 1/3 EV 已是专业曝光补偿常用精度，继续细到 0.1 EV 会增加操作复杂度和写入密度。
- EV RESET 仍回 `0.0`。

## 3. WB 档位调整

WB 是本包重点之一。

- 2800K / 3000K / 3200K 保持较粗入口；
- `3200K ... 6500K` 常用区改为 100K 步进；
- 6500K 以上保留较粗档位：6700K / 7000K / 7500K / 8000K；
- 继续按设备 white balance 能力裁剪，并保留当前 runtime Kelvin。

当前优先档位：

`2800K, 3000K, 3200K, 3300K, 3400K, 3500K, 3600K, 3700K, 3800K, 3900K, 4000K, 4100K, 4200K, 4300K, 4400K, 4500K, 4600K, 4700K, 4800K, 4900K, 5000K, 5100K, 5200K, 5300K, 5400K, 5500K, 5600K, 5700K, 5800K, 5900K, 6000K, 6100K, 6200K, 6300K, 6400K, 6500K, 6700K, 7000K, 7500K, 8000K`

## 4. TINT 档位调整

TINT 从 R42 的 step 5 改为中心常用区更细：

- 极端区：`-50 ... -30` 和 `30 ... 50` 使用 5 step；
- 常用微调区：`-30 ... +30` 使用 2 step；
- 继续保留 `0`；
- 继续使用 `Gxx / 0 / Mxx` 显示语义；
- TINT RESET 仍只归零色偏，不触发 WB AUTO。

## 5. ISO 档位调整

ISO 保持摄影常用 1/3 stop 思路，并补齐高 ISO 档位：

`25, 32, 40, 50, 64, 80, 100, 125, 160, 200, 250, 320, 400, 500, 640, 800, 1000, 1250, 1600, 2000, 2500, 3200, 4000, 5000, 6400`

- 继续按设备 `minISO / maxISO` 裁剪；
- 继续保留当前 runtime ISO / manual ISO；
- ISO AUTO 和 ISO / Shutter LOCK 合同未改。

## 6. Shutter 档位调整

Shutter 保持常用 1/3 stop 档位，并补齐：

- 高速端：`1/8000, 1/6400, 1/5000`；
- 低速端细档：`1/13, 1/5, 1/3`；
- 常用商品拍摄区 `1/30 ... 1/500` 继续保持密集档位；
- 继续按设备 `minExposureDuration / maxExposureDuration` 裁剪。

## 7. R42 阻尼保护

本包未回退 R42 阻尼：

| 参数 | 阈值 | 最大跨档 |
| --- | ---: | ---: |
| EV | 42pt | 1 档 |
| WB | 40pt | 2 档 |
| TINT | 44pt | 1 档 |
| ISO | 40pt | 2 档 |
| S / Shutter | 44pt | 1 档 |

继续保留：

- 取消 3 档跨越；
- 累计位移消耗机制；
- 0.08s step 冷却；
- 边界、重复值、LOCK / disabled 不反馈；
- RESET / AUTO 一次轻反馈。

## 8. 功能合同保护

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

## 9. 修改文件

- `SellerCamera/CaptureScreen.swift`
- `README.md`
- `docs/reports/r43_five_parameter_tick_precision_refinement.md`
- `docs/reports/r43_five_parameter_tick_precision_refinement.json`

## 10. 验证结果

- 已执行 iOS Simulator Debug 构建：
  - `xcodebuild -project /Users/sungning/Projects/SellerCamera/SellerCamera.xcodeproj -scheme SellerCamera -configuration Debug -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO build`
- 结果：通过。
- 真机档位手感：当前会话内未执行真机安装与人工滑动验证，仍需在真实设备上确认 WB / TINT / ISO / Shutter 是否更容易精调。

## 11. 遗留风险

1. 档位更细后，真实手感是否“刚好”仍需真机确认。
2. 如果 WB 常用区 100K 在真机上仍太细或太慢，可只针对 WB 做小幅阈值调整，不应回退整体阻尼。
3. 本包未做独立 Focus 对焦系统，也未触碰白底、拍后或镜头切换链路。

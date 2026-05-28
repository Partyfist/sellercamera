# R41 五参数滚轮阻尼与常用区精度修正报告

## 1. 本包定位

- 包类型：五参数滚轮手感修正包。
- 范围：仅调整 `EV / WB / TINT / ISO / S` 的滚轮阻尼、单次最大跨档与常用区档位密度。
- 边界：不改变任何相机 runtime 写入路径，不改白底链路，不改拍后流程，不让 Focus 回到底部五参数栏。

## 2. 滚轮阻尼修正

本包将上一阶段的全局滚轮手感改为按参数配置：

| 参数 | 触发阈值 | 单次最大跨档 | 目的 |
| --- | ---: | ---: | --- |
| EV | 28pt | 2 档 | 保持 1/3 EV 精度，同时降低误跨档 |
| WB | 26pt | 3 档 | Kelvin 档位较多，允许中等滑动但仍受控 |
| TINT | 30pt | 2 档 | 色偏微调更稳，避免过敏 |
| ISO | 26pt | 3 档 | 1/3 stop 常用档位可连续选择 |
| S / Shutter | 28pt | 2 档 | 快门常用区更容易停住 |

拖动方向、AUTO / RESET / LOCK 行为和写入路由均保持不变。

## 3. 档位调整

### EV

- 继续使用 `-2.0 ... +2.0` 的 1/3 EV 档位。
- 未改为更粗步进。
- 按设备 exposure bias 能力裁剪。

### WB

- 增补常用 Kelvin 档位：
  - `2800K`
  - `6200K`
- 当前档位覆盖：
  - `2800K, 3000K, 3200K, 3400K, 3600K, 3800K, 4000K, 4200K, 4400K, 4600K, 4800K, 5000K, 5200K, 5400K, 5600K, 5800K, 6000K, 6200K, 6500K, 7000K, 7500K, 8000K`
- 继续按设备白平衡范围裁剪，并保留当前 runtime Kelvin。

### TINT

- 收口到 `-50 ... +50`。
- 固定步进 `5`。
- 保留设备能力裁剪、当前 runtime tint 与 `0`。
- 继续使用 `Gxx / 0 / Mxx` 显示语义。

### ISO

- 从按设备范围连续 log 生成改为明确的常用 1/3 stop 档位：
  - `25, 32, 40, 50, 64, 80, 100, 125, 160, 200, 250, 320, 400, 500, 640, 800, 1000, 1250, 1600, 2000, 2500, 3200`
- 继续按设备 `minISO / maxISO` 裁剪，并保留当前 runtime ISO / manual ISO。

### Shutter

- 保持 R39 已形成的 1/3 stop 常见快门档位：
  - `1/4000 ... 1"`，包含 `1/30 ... 1/500` 商品拍摄常用区。
- 继续按设备 `minExposureDuration / maxExposureDuration` 裁剪，并保留当前 runtime shutter / manual shutter。

## 4. 触觉反馈

- 触觉反馈仍只在 `onWheelStep` 成功返回后触发。
- 边界、LOCK、重复值、不可调状态不会触发滚轮档位反馈。
- RESET / AUTO 仍为一次轻反馈。
- 本包未引入 heavy feedback，也未增加高频反馈。

## 5. 功能合同保护

本包未改变以下合同：

- 底部五参数仍为 `EV / WB / TINT / ISO / S`；
- Focus 不回到底部五参数栏；
- TINT 是 `RESET`，不是 `AUTO`；
- WB 调节保留 TINT；
- TINT 调节保留 WB Kelvin；
- WB AUTO 后 TINT 回 0；
- ISO 非 Auto 时 Shutter LOCK；
- EV / WB / TINT / ISO / Shutter 的 runtime 写入路径未改。

## 6. 修改文件

- `SellerCamera/CaptureBottomParameterBar.swift`
- `SellerCamera/CaptureScreen.swift`
- `README.md`
- `docs/reports/r41_five_parameter_dial_damping_and_precision_tuning.md`
- `docs/reports/r41_five_parameter_dial_damping_and_precision_tuning.json`

## 7. 验证结果

- 已执行 iOS Simulator Debug 构建：
  - `xcodebuild -project /Users/sungning/Projects/SellerCamera/SellerCamera.xcodeproj -scheme SellerCamera -configuration Debug -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO build`
- 结果：通过。
- 真机滚轮手感：当前会话内未执行真机安装与人工滑动验证，需后续在真实设备上确认“是否明显更慢、是否更容易停到目标档”。

## 8. 遗留风险

1. 阻尼和档位密度已在代码层修正，但真实手感仍需真机验证。
2. WB / ISO / Shutter 的设备能力裁剪会因不同镜头/设备略有差异，仍需在目标真机上观察可用档位。
3. 本包未做 Focus 独立系统，也未触碰白底和拍后链路。

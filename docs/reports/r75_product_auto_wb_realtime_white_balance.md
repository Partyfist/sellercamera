# R75 商品 Auto WB 实时白平衡优化 1.0 报告

## 1. 改动摘要

本轮新增商品 Auto WB 1.0，基于 R74 系列已经接入的低频 preview sample buffer 分析链路，在同一次 downsample BGRA 遍历中同时产出 Auto EV metrics 与 Auto WB metrics。Auto WB 使用近白区域的 RGB 均值判断偏暖、偏冷、偏绿风险，输出目标 Kelvin，并通过现有 AVCaptureDevice white balance gains 路径做平滑写入。

本轮只实现白平衡自动校正闭环，不自动修改 ISO、Shutter、Focus、Lens，不改白底处理链路，不改拍后 Review / Save 流程。

## 2. 文件清单

- `SellerCamera/ProductAutoWhiteBalanceOptimizer.swift`
  - 新增 Product Auto WB metrics、recommendation 与规则型 optimizer。
  - 负责 near-white confidence、red/blue cast、green cast hold、稳定命中、Kelvin 目标与单步平滑。
- `SellerCamera/CaptureLivePreviewView.swift`
  - 扩展 preview frame analysis，复用 R74 视频帧输出同时计算 EV 与 WB 指标。
  - 接入 Auto WB 可写性判断、手动接管暂停、WB Auto 恢复、设备 white balance 写入与 Debug 日志。
- `docs/reports/r75_product_auto_wb_realtime_white_balance.md`
  - 新增本报告。
- `README.md`
  - 增加 R75 报告索引。

## 3. Auto WB 设计

Auto WB 的输入是 preview frame 的近白区域色彩指标和当前 white balance temperature。输出是可选的下一步 Kelvin 写入值。

决策边界：

- 仅在 WB 当前为 Auto 时工作。
- 用户手动 WB 后暂停。
- 用户点击 WB Auto 后 reset optimizer 并恢复等待新预览帧判断。
- 不新增全局商品 Auto 按钮。
- 不影响 Auto EV 的状态机。
- 不接管 ISO、Shutter、Focus、Lens。

第一版采用 Kelvin-only 策略，偏绿只记录并 hold，不强行做 tint 修正，避免第一版在 LED 混光场景下引入色偏震荡。

## 4. 近白区域分析

本轮复用 `AVCaptureVideoDataOutput`，没有新增第二条 competing video output。BGRA downsample 遍历中继续计算 R74 Auto EV 的 luma / highlight / clipped / shadow / nearWhite 指标，同时新增 Auto WB 近白候选统计。

Auto WB 近白候选条件：

- luma > 0.55
- luma < 0.96
- saturation < 0.25
- channelMax < 0.98

输出指标：

- nearWhiteRatio
- meanRed
- meanGreen
- meanBlue
- meanLuma
- redBlueDelta = meanRed - meanBlue
- greenCast = meanGreen - average(meanRed, meanBlue)
- confidence = nearWhiteRatio / 0.20 后裁剪到 0...1

如果没有候选像素，也会输出 confidence = 0 的 metrics，确保 Debug 日志能明确说明 lowConfidence hold，而不是静默无输出。

## 5. WB 决策规则

ProductAutoWhiteBalanceOptimizer 的第一版规则：

- confidence < 0.35：lowConfidence，保持当前 WB。
- abs(greenCast) > 0.07：greenCastHold，记录偏绿风险但不强写 tint。
- abs(redBlueDelta) < 0.06：neutralHold，认为近白区域基本中性，保持当前 WB。
- redBlueDelta > 0：warmCastCoolDown，目标 Kelvin 向冷方向移动。
- redBlueDelta < 0：coolCastWarmUp，目标 Kelvin 向暖方向移动。

Kelvin 目标：

- Auto WB 工作范围限制在 3000K...7500K。
- 单次目标 correction 为 200K...600K，随 redBlueDelta 强度变化。
- 目标与写入值按 50K 对齐。
- 连续命中 3 次同类目标后才允许写入。
- 当前与目标差值小于 100K 时忽略。

## 6. 写入与平滑策略

写入路径复用现有 runtime 的 AVCaptureDevice white balance 能力：

1. 根据目标 Kelvin 构造 `AVCaptureDevice.WhiteBalanceTemperatureAndTintValues`，tint 第一版固定为 0。
2. 使用系统 `deviceWhiteBalanceGains(for:)` 转换为 gains。
3. 使用现有 gains normalize helper 裁剪到设备 maxWhiteBalanceGain 范围。
4. 调用 `setWhiteBalanceModeLocked(with:)` 写入设备。
5. 主线程更新 currentWhiteBalanceTemperature / currentWhiteBalanceTint / productAutoWhiteBalanceAppliedTemperature。

平滑策略：

- Auto WB 写入间隔不少于 1.0 秒。
- 单次最多移动 100K。
- 小于 100K 的目标变化忽略。
- Debug 日志不少于 1.0 秒间隔。
- WB 比 Auto EV 更慢，降低色温呼吸风险。

## 7. 手动接管与 WB Auto 恢复

用户手动 WB：

- `applyWhiteBalanceManualValues` 会 reset ProductAutoWhiteBalanceOptimizer。
- 清空 `productAutoWhiteBalanceAppliedTemperature`。
- 状态变为 `商品 WB 暂停 · 手动WB`。
- Auto WB 不再写入。

用户点击 WB Auto：

- 恢复系统 WB Auto。
- reset ProductAutoWhiteBalanceOptimizer。
- 清空已应用商品 WB 温度。
- 状态变为 `商品 WB 恢复`，等待新预览帧重新判断。

本轮未改变 TINT 合同：WB Auto 仍回收 tint 为 0。

## 8. 与 Auto EV 的共存关系

Auto EV 与 Auto WB 共享同一个低频 frame analysis 入口，但状态和写入路径隔离：

- Auto EV 继续只处理 exposureTargetBias。
- Auto WB 只处理 white balance Kelvin/gains。
- 手动 EV 只暂停 Auto EV，不暂停 Auto WB。
- 手动 WB 只暂停 Auto WB，不暂停 Auto EV。
- EV Auto 只恢复 Auto EV。
- WB Auto 只恢复 Auto WB。

真机 console 中已同时观察到 `[ProductAutoExposure]` 与 `[ProductAutoWB]` 低频日志，说明两条 optimizer 共享帧分析但分别决策。

## 9. Lock / 不可写保护

Auto WB 在以下状态不写入：

- 设备不支持 WB Auto 或 WB preset。
- WB 当前不是 Auto。
- AEAF-L / focus exposure locked。
- AE-L / exposure locked。
- 拍摄或预览交互临时受限。
- 正在切镜头。
- 设备不支持 custom white balance gains lock。

进入不可写状态时会 reset optimizer、清空 appliedTemperature，并输出对应 status。

## 10. UI 与 Debug 日志

UI 轻量表达：

- WB 仍保留底部五参数结构，不新增参数入口。
- 当商品 Auto WB 写入过 Kelvin 后，WB Auto 显示为 `Auto ####K`。
- 手动 WB 后恢复现有手动 Kelvin 显示。

Debug-only 日志：

```text
[ProductAutoWB] whiteRatio=0.103 R=0.773 G=0.761 B=0.690 Y=0.759 redBlue=+0.083 greenCast=+0.030 confidence=0.51 target=nil next=nil current=3898K reason=stable decision=warmCastCoolDown stableHitCount=1 status=商品 WB
```

日志包含 near-white ratio、RGB 均值、redBlueDelta、greenCast、confidence、target、next、current、reason、decision、stableHitCount 与 status，便于下一包基于实物样本做阈值校准。

## 11. 性能与线程处理

本轮没有新增第二个 `AVCaptureVideoDataOutput`。Auto WB 指标在 R74 已有低频 sample buffer delegate 中一并计算：

- sample buffer 像素遍历仍在 delegate 队列执行，不在主线程做像素遍历。
- main thread 只接收小型 metrics 并做状态/写入调度。
- Auto WB 写入间隔 1 秒，低于 Auto EV 写入频率，避免频繁 white balance lock。
- Debug 日志 1 秒节流。

## 12. 构建与运行验证

已执行：

```bash
xcodebuild -scheme SellerCamera -project SellerCamera.xcodeproj -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/SellerCameraR75Build CODE_SIGNING_ALLOWED=NO clean build
```

结果：`BUILD SUCCEEDED`。

已执行真机验证：

- 设备：iPhone 14 Pro Max
- iOS：18.7.7
- 安装：成功
- 启动：成功
- console：已捕获 `[ProductAutoWB]` 与 `[ProductAutoExposure]` 低频日志

真机观察结论：

- Auto WB preview metrics 链路已运行。
- Auto WB 在 lowConfidence / neutralHold 场景下保持当前 WB。
- 观察到 warmCastCoolDown candidate 命中，但短时随手环境未达到连续 3 次稳定写入。
- Auto EV 仍正常输出日志，说明 R74B 链路未被本轮破坏。

本轮未完成主观色彩样本验收：

- 未使用稳定暖光白底、冷光白底、彩色背景、偏绿 LED 等标准样本做完整色彩判断。
- 未确认 Auto WB 写入后白底主观观感改善程度。

## 13. 风险与真机待复核项

风险：

- 第一版 Kelvin-only 不处理 tint，偏绿 LED 场景只 hold 并记录，后续可能需要 R76 做 tint 闭环。
- 当前 confidence 阈值偏保守，彩色背景安全，但白底占比小的商品场景可能不触发。
- 连续命中 3 次和 100K min delta 偏稳，能减少呼吸，但响应速度需要实物复核。
- 商品 Auto WB 写入使用 locked gains，但 app-level selected preset 仍保持 Auto；这是为了表达“商品 Auto WB 接管中”，需要继续通过真机观察确认与系统 auto WB 的交互手感。

下一步建议：

- R76：商品 Auto WB 真机样本阈值校准，覆盖暖光白底、冷光白底、绿色 LED、彩色背景和白色商品，判断是否需要加入轻量 tint 修正。

# R75A 商品 Auto WB 真机场景校准报告

## 1. 改动摘要

本轮在 R75 商品 Auto WB 1.0 的基础上做真机日志复核与小幅阈值收口。R75 真机日志显示 Auto WB 主链路可运行，但多数场景停在 lowConfidence / neutralHold，且部分 warmCast 连续命中 3 次后因为设备当前读数 3898K 与 50K 量化目标之间差值略低于 100K，导致有效 100K 档位没有写入。

R75A 的处理：

- near-white 候选放宽灰白底亮度下限，提升白纸 / 白底触发概率。
- 同时收紧 saturation 与 clipped 上限，降低彩色背景 / 高光误判。
- confidence 归一化从 20% 近白占比调整为 16%，让白底占比不大的商品场景更容易进入可用置信度。
- warm / cool cast 阈值从 0.060 下调到 0.055。
- minKelvinDelta 从 100K 调整为 75K，允许 3898K -> 3800K 这类实际 100K 档位写入。
- Debug 日志增加 nearWhite sample count 与 confidenceReason。

本轮未做 tint 修正，未做偏绿 LED 闭环，未改 ISO / Shutter / Focus / Lens，未改白底和拍后流程。

## 2. 文件清单

- `SellerCamera/ProductAutoWhiteBalanceOptimizer.swift`
  - 调整 confidence、warm/cool cast、minKelvinDelta 阈值。
  - 增加 nearWhiteSampleCount metrics 字段。
- `SellerCamera/CaptureLivePreviewView.swift`
  - 调整 near-white candidate 规则。
  - 调整 confidence scoring。
  - 增加 `[ProductAutoWB]` 日志的 whiteCount 与 confidenceReason。
- `docs/reports/r75a_product_auto_wb_real_device_calibration.md`
  - 新增本报告。
- `README.md`
  - 增加 R75A 报告索引。

## 3. 真机验证环境

- 设备：iPhone 14 Pro Max
- iOS：18.7.7
- 连接：有线连接，developer mode enabled
- 安装：成功
- 启动：成功
- 验证方式：通过 `devicectl --console` 捕获 `[ProductAutoWB]` 与 `[ProductAutoExposure]` 日志
- 场景：桌面随手环境，包含近白/暗场/高光变化；未使用固定暖光、冷光、彩色背景标准样本

## 4. R75 Auto WB 现状复核

R75 已确认：

- preview sample buffer 链路正常。
- Auto WB 与 Auto EV 共用同一低频 downsample 分析。
- `[ProductAutoWB]` 日志低频输出。
- lowConfidence / neutralHold 能正确 hold。
- warmCastCoolDown / coolCastWarmUp candidate 能被识别。

R75A 发现的实际问题：

- R75 confidence 偏保守，nearWhiteRatio 约 0.08...0.13 时常被视为边缘或低置信度。
- R75 redBlueDelta 0.055 附近会被 neutralHold，部分轻微暖光白底不触发。
- 设备当前 WB 读数可能是 3898K 这类非 50K 对齐值，写入 3800K 的实际差值约 98K，被 100K minDelta 误挡。

## 5. 暖光白底校准

目标：

- 暖光 / 偏黄白底能够进入 warmCastCoolDown。
- Kelvin 逐步向冷方向移动。
- 不因为轻微红蓝差异直接大幅跳冷。

调整：

- castThreshold：0.060 -> 0.055
- confidence：nearWhiteRatio / 0.20 -> nearWhiteRatio / 0.16
- minimumEffectiveDelta：100K -> 75K

真机日志观察：

- 已观察到 usableNearWhite 下的 warmCastCoolDown。
- 已观察到 stableHitCount 到 3。
- 已观察到 current WB 从约 3898K 进入 3800K，说明写入闭环已实际生效。

未完成：

- 未使用固定暖光灯 + 白纸/白桌样本做主观“降黄不过冷”确认。

## 6. 冷光 / 阴天校准

目标：

- 冷光 / 阴天白底能进入 coolCastWarmUp。
- 不把中性白底过度调黄。

调整：

- cool 与 warm 使用同一 0.055 redBlueDelta 阈值。
- stableHitCount 保持 3。
- singleStep 保持 100K。
- writeInterval 保持 1.0s。

真机日志观察：

- 已观察到 redBlueDelta < 0 时进入 coolCastWarmUp candidate。
- 已观察到 current WB 从 3800K 回到 3900K 的写入迹象。

未完成：

- 未使用阴天窗边 / 冷白 LED 固定样本确认主观回暖幅度。

## 7. 中性白底校准

目标：

- 中性白底主要保持 neutralHold。
- 不因微小 redBlueDelta 来回写入。

保留策略：

- redBlueDelta deadband 仍有 0.055。
- stableHitCount 仍为 3。
- minKelvinDelta 仍有 75K 防抖。
- writeInterval 仍为 1.0s。

真机日志观察：

- redBlueDelta 约 0.03...0.05 的近白区域保持 neutralHold。
- confidence 可用时仍不会因为轻微差异写入。

## 8. 彩色背景 / low confidence 校准

目标：

- 彩色背景或 near-white 不足时保持 lowConfidence。
- 不被红色 / 蓝色商品主体误认为白底。

调整：

- luma 下限：0.55 -> 0.50，允许灰白底进入。
- saturation 上限：0.25 -> 0.22，收紧彩色背景。
- channelMax 上限：0.98 -> 0.97，减少 clipped 高光参与 WB。
- confidenceReason 日志新增 lowNearWhite / marginalNearWhite / usableNearWhite。

真机日志观察：

- whiteCount 为 0 或 nearWhiteRatio 很低时保持 lowConfidence。
- nearWhiteRatio 低于 0.08 但 confidence 过线时标记为 marginalNearWhite，便于下一轮判断是否需要继续收紧。

## 9. near-white 阈值调整

R75A 最终 near-white 候选：

- luma > 0.50
- luma < 0.96
- saturation < 0.22
- channelMax < 0.97

confidence：

- confidence = min(1.0, nearWhiteRatio / 0.16)
- minimumConfidence = 0.30

这样白纸 / 白底占比约 5% 以上且色彩足够低饱和时可以进入边缘可用区；高饱和彩色背景仍会被 saturation 限制排除。

## 10. WB 决策优先级

R75A 后优先级保持：

1. unavailable / manual / lock guard
2. lowConfidence hold
3. greenCast record-only hold
4. warmCastCoolDown
5. coolCastWarmUp
6. neutralHold

偏绿仍只记录并 hold，不自动 tint 修正。

## 11. 手动接管与 WB Auto 恢复

本轮未改手动接管语义，继续沿用 R75：

- 用户手动 WB：reset optimizer，清空 applied temperature，状态为 `商品 WB 暂停 · 手动WB`。
- WB Auto：恢复系统 Auto，reset optimizer，等待新预览帧重新判断。
- AE-L / AEAF-L / 拍摄中 / 切镜头：不可写，不强行写 WB。

本轮未进行手动 UI 操作真机复核，需后续人工在相机页面实际拖动 WB / 点击 WB Auto 确认。

## 12. Auto EV 共存验证

真机 console 中继续同时出现：

- `[ProductAutoExposure]`
- `[ProductAutoWB]`

说明 Auto EV 与 Auto WB 仍共享低频分析但独立输出。R75A 未修改 Auto EV 阈值、写入路径或半自动曝光规则。

## 13. 性能验证

本轮没有新增第二条 video output，没有新增主线程像素遍历。

真机启动日志观察：

- sample buffer 分析持续输出。
- Debug 日志低频。
- 短时启动观察未出现崩溃。

未完成：

- 未做长时间发热、掉帧和参数表盘拖动压力测试。

## 14. 阈值最终值

- nearWhite luma lower：0.50
- nearWhite luma upper：0.96
- nearWhite saturation upper：0.22
- nearWhite channelMax upper：0.97
- confidence denominator：0.16
- minimumConfidence：0.30
- redBlueDelta threshold：0.055
- greenCast threshold：0.07
- stableHitCount：3
- singleStep：100K
- minKelvinDelta：75K
- writeInterval：1.0s
- WB range：3000K...7500K
- alignment：50K

## 15. 风险与后续建议

风险：

- 当前只做 Kelvin，不处理 tint，偏绿 LED 仍可能只能 hold。
- 随手场景下已确认写入闭环，但四类标准样本主观验收仍不足。
- marginalNearWhite 进入 warm/cool candidate 后是否会在复杂商品场景误触发，需要实物样本继续复核。

后续建议：

- R75B / R76：固定样本真机复核，覆盖暖光白纸、冷光白纸、中性白底、彩色背景、白色商品、透明塑料和绿色 LED，决定是否加入 tint 微调或进一步收紧 marginalNearWhite 写入条件。

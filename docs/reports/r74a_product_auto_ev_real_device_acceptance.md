# R74A 商品 Auto EV 真机验收与阈值收口报告

## 1. 改动摘要

R74A 对 R74 商品 Auto EV 做真机链路验收与最小阈值收口：

- 真机 Debug 构建、安装、启动成功。
- 真机 console 捕获到 `[ProductAutoExposure]` 日志，确认 preview sample buffer、luma metrics、target EV 计算、EV 写入链路在真实设备上工作。
- 根据真机日志发现 R74 stable 场景会把目标拉回固定 `+0.10`，存在暗场/灰白底提亮后轻微回落再提亮的呼吸风险。
- 将 stable 场景目标从固定 `+0.10` 调整为保持当前 EV bias，避免无高光风险时主动回落。
- 增加 Debug-only 低频摘要日志，包含 metrics、target、next、applied、reason 与 availability status。
- 未改 ISO / Shutter / WB / Focus / Lens。
- 未改白底和拍后流程。

## 2. 文件清单

- `SellerCamera/ProductAutoExposureOptimizer.swift`
  - stable 场景从固定回落目标改为保持当前 bias。

- `SellerCamera/CaptureLivePreviewView.swift`
  - 新增商品 Auto EV Debug 摘要日志节流。
  - 在 unavailable、write interval、stable、recommendation 分支统一输出低频观测信息。

- `docs/reports/r74a_product_auto_ev_real_device_acceptance.md`
  - 新增 R74A 验收与阈值收口报告。

- `README.md`
  - 增加 R74A 报告索引。

## 3. 真机验证环境

- 设备：iPhone14 pro Max
- iOS：18.7.7
- UDID：`00008120-001655913E7BC01E`
- 构建方式：`xcodebuild` Debug 真机构建
- 安装方式：`xcrun devicectl device install app`
- 启动方式：`xcrun devicectl device process launch --console`
- 光线场景：Codex 侧完成设备启动和日志链路验证；受控暗场、灰白底、高光商品样本仍需用户在真机前复核。
- 商品样本：未由 Codex 直接控制摆放，未宣称完成完整商品样本主观验收。

## 4. R74 Auto EV 现状复核

真机首次运行 R74 时捕获到以下日志模式：

```text
[ProductAutoExposure] mean=0.345 highlight=0.018 clipped=0.000 shadow=0.359 nearWhite=0.135 target=+0.40 next=+0.10 reason=darkSceneLift
[ProductAutoExposure] mean=0.384 highlight=0.023 clipped=0.000 shadow=0.290 nearWhite=0.167 target=+0.40 next=+0.20 reason=darkSceneLift
[ProductAutoExposure] mean=0.435 highlight=0.020 clipped=0.000 shadow=0.269 nearWhite=0.236 target=+0.60 next=+0.30 reason=grayWhiteLift
[ProductAutoExposure] mean=0.454 highlight=0.036 clipped=0.000 shadow=0.246 nearWhite=0.252 target=+0.60 next=+0.40 reason=grayWhiteLift
[ProductAutoExposure] mean=0.459 highlight=0.074 clipped=0.002 shadow=0.192 nearWhite=0.256 target=+0.10 next=+0.30 reason=stableClean
```

结论：

- 真机 preview frame metrics 能生成。
- 暗场规则能产生 `darkSceneLift`。
- 灰白底规则能产生 `grayWhiteLift`。
- EV 能以 0.1EV 步进逐步写入。
- R74 stableClean 会把 target 拉回 `+0.10`，在亮度接近阈值时可能造成回落/再提亮。

## 5. 暗场提亮验证

已确认：

- 真机日志中 `meanLuma` 低于暗场阈值时，会触发 `darkSceneLift`。
- `next` 从 `+0.10` 逐步上升至更高 EV。
- R74A 后在极暗日志场景中，EV 提升到 `+0.40` 后进入 stable 保持，不再主动回落到 `+0.10`。

仍需人工复核：

- 真实商品暗场下画面是否足够亮。
- 暗场提亮是否有可见噪点或画面发灰问题。
- 是否需要将 dark target 从 `+0.4` 进一步调到 `+0.5 ~ +0.6`。

## 6. 灰白底提亮验证

已确认：

- 真机日志中 `nearWhiteRatio` 超过阈值且 `nearWhiteMeanLuma` 偏低时，会触发 `grayWhiteLift`。
- R74 灰白底目标为 `+0.60`，在日志中能逐步应用。

仍需人工复核：

- 白纸 / 白桌 / 白底布场景下，白底是否从灰变干净。
- 白色商品、透明包装、浅色文字是否被洗掉。
- 是否需要将 grayWhite target 提高到 `+0.7 ~ +0.8`，或调整 nearWhiteRatio / nearWhiteMeanLuma 阈值。

## 7. 高光保护验证

本轮未在 Codex 可控条件下完成强反光商品样本测试。

已保留 R74 高光优先级：

- `clippedRatio > 0.03` 时目标不高于 `0.0`。
- `highlightRatio > 0.12` 时目标不高于 `+0.3`。
- 高光保护仍优先于灰白底提亮。

仍需人工复核：

- 透明塑料、金色包装、亮面卡纸、灯光直射场景。
- clipped / highlight 上升时是否停止继续提亮。
- 如仍炸白，建议下一轮优先降低 clipped danger 到 `0.02` 或 highlight caution 到 `0.10`。

## 8. 平滑与抽动验证

R74A 发现并修复的平滑性风险：

- R74 stableClean 返回固定 `+0.10`。
- 真机日志显示暗场 / 灰白底提亮后，stableClean 可能把 `next` 拉低。
- R74A 改为 stable 场景保持当前 bias，不在无高光风险时主动回落。

R74A 后真机日志示例：

```text
[ProductAutoExposure] metrics mean=0.002 highlight=0.000 clipped=0.000 shadow=1.000 nearWhite=0.000 nearWhiteLuma=0.000 target=nil next=nil applied=+0.40 reason=stable status=商品 Auto
```

结论：

- stable 场景不再产生固定回落目标。
- Debug 摘要日志节流到约 1 秒一次。
- 未调整 `stableHitCount`、`writeInterval`、`singleStep`，避免在未完成受控场景前过度保守。

## 9. 手动 EV 接管验证

代码级复核：

- 用户手动 EV 写入时，`switchesToManual == true` 路径会 reset optimizer。
- `productAutoExposureStatusText` 进入 `商品 Auto 暂停 · 手动EV`。
- `productAutoExposureAppliedBias` 清空。
- `productAutoExposureAvailability()` 在 `isExposureBiasAutoMode == false` 时阻止 Auto EV 写入。
- 点击 EV Auto 后调用自动恢复路径，reset optimizer 并恢复 `商品 Auto 恢复`。

真机仍需人工复核：

- Auto EV 正在工作时手动拖 EV，等待数秒是否不再自动改写。
- 点击 EV Auto 后是否重新恢复 Auto EV。

## 10. Lock / AE-L / AEAF-L 验证

代码级复核：

- `isFocusExposureLocked` 时返回 `商品 Auto 暂停 · AEAF-L`。
- `isExposureLocked` 时返回 `商品 Auto 暂停 · AE-L`。
- `isManualExposurePresetActive` 时返回 `商品 Auto 暂停 · 手动曝光`。
- `isPreviewInteractionTemporarilyRestricted` 时返回 `商品 Auto 暂停 · 拍摄中`。
- `isSwitchingCamera` 时返回 `商品 Auto 暂停 · 切镜头`。

真机仍需人工复核：

- AE-L / AEAF-L 开启时 Auto EV 是否停止写入。
- 解锁后 Auto EV 是否按既有状态恢复。
- 手动 ISO / Shutter 时是否保持 R68 语义，不让 EV 自动写入。

## 11. 性能验证

已验证：

- 真机构建成功。
- 真机安装成功。
- 真机启动成功。
- App console 能连续输出 Auto EV 摘要日志。
- 预览 sample buffer 能持续生成 metrics。

未完成：

- 未通过仪表或长时间手持测试验证发热。
- 未通过稳定帧率工具量化 preview FPS。
- 未做长时间拍照 / 参数拖动 / Auto EV 同时运行的压力测试。

当前实现仍保持 R74 的性能边界：

- sample buffer 分析间隔 `0.35s`。
- metrics 在 video analysis queue 生成。
- 主线程只接收结果并做状态判断 / EV 写入调度。
- Debug 日志约 1 秒输出一次，不高频刷屏。

## 12. 本次阈值调整

本次只做一个有真机日志证据支持的阈值收口：

- stable 场景：`target = 0.1` 改为 `target = currentBias`。

未调整：

- `maxAutoBias` 仍为 `+0.8`。
- `minAutoBias` 仍为 `-0.3`。
- `maxStepPerWrite` 仍为 `0.1`。
- `minimumEffectiveDelta` 仍为 `0.05`。
- 连续命中次数仍为 `2`。
- 写入间隔仍为 `0.35s`。
- clipped / highlight / grayWhite / dark / shadow 阈值保持 R74。

原因：

- 当前真机证据已经足够支持 stable 不应固定回落。
- 暗场、灰白底、高光的阈值强弱需要用户在真实商品样本前继续复核，不应凭一次不可控镜头画面大幅调参。

## 13. 风险与后续建议

风险：

- stable 保持当前 bias 后，如果场景从暗场切到普通场景但未触发 highlight / clipped，EV 可能保持较亮，需真机观察是否过亮。
- 强高光场景未由 Codex 完成受控验证。
- 发热 / FPS 未完成长时间量化。

下一步建议：

- R74B 做受控三场景阈值校准：暗场商品、灰白底商品、反光包装。
- 若发现偏亮，优先调整 highlight caution 与 clipped danger。
- 若发现响应慢，再考虑 `dark target`、`grayWhite target` 和 `singleStep`。
- 暂不扩展到 Auto WB / ISO / Shutter，保持 Auto EV 单能力闭环稳定。

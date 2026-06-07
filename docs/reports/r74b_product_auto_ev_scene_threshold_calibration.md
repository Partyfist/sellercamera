# R74B 商品 Auto EV 场景阈值校准报告

## 1. 改动摘要

R74B 在 R74A 真机链路验证基础上，对商品 Auto EV 的四类场景规则做最小阈值收口：

- 暗场提亮目标从 `+0.40` 小幅提高到 `+0.45`。
- 灰白底识别略放宽，并将目标从 `+0.60` 提高到 `+0.65`。
- clipped 高光保护从 `0.03` 提前到 `0.025`。
- highlight 保护上限从 `+0.30` 收紧到 `+0.25`。
- 普通亮场新增 `stableBrightDecay` 慢回落逻辑，避免 R74A 的 hold 在亮场长期偏亮。
- Debug 摘要日志新增 `decision` 与 `stableBrightCount`，便于后续真机四场景复核。
- 未改 ISO / Shutter / WB / Focus / Lens。
- 未改拍照、白底、拍后 Review / Save 流程。

## 2. 文件清单

- `SellerCamera/ProductAutoExposureOptimizer.swift`
  - 收口 dark / grayWhite / highlight / clipped 阈值。
  - 新增 stable bright 连续计数与慢回落。
  - 新增 optimizer Debug state。

- `SellerCamera/CaptureLivePreviewView.swift`
  - Auto EV Debug 日志追加 `decision` 和 `stableBrightCount`。

- `docs/reports/r74b_product_auto_ev_scene_threshold_calibration.md`
  - 新增 R74B 场景阈值校准报告。

- `README.md`
  - 增加 R74B 报告索引。

## 3. 真机验证环境

- 设备：iPhone14 pro Max
- iOS：18.7.7
- UDID：`00008120-001655913E7BC01E`
- 安装方式：`xcrun devicectl device install app`
- 启动方式：`xcrun devicectl device process launch --console`
- 验证方式：真机构建 / 安装 / 启动 / Auto EV console 日志
- 场景说明：Codex 侧验证了真实设备上的 Auto EV 链路与日志输出；四类商品样本的主观画面效果仍需用户在设备前复核。

## 4. R74A 现状问题

R74A 修复了 stable 场景固定回落 `+0.10` 的呼吸风险，但也带来一个需要收口的问题：

- 如果从暗场或灰白底进入普通亮场，stable hold 可能让较高 EV 停留太久。
- 普通亮场需要慢回落，但不能恢复 R74 时代的固定快速回落。

R74B 因此加入 `stableBrightDecay`：

- 只有连续稳定亮场命中后才开始回落。
- 每次回落目标为当前 EV 减 `0.05`。
- 回落下限为 `+0.15`。
- 回落速度慢于提亮，避免画面忽明忽暗。

## 5. 暗场校准

最终规则：

- `meanLuma < 0.45` 时触发 `darkSceneLift`。
- 目标 EV 从 R74A 的 `+0.40` 调整为 `+0.45`。

真机日志验证：

```text
[ProductAutoExposure] metrics mean=0.001 highlight=0.000 clipped=0.000 shadow=1.000 nearWhite=0.000 nearWhiteLuma=0.000 target=+0.45 next=+0.30 applied=+0.20 reason=darkSceneLift decision=darkSceneLift stableBrightCount=0 status=商品 Auto
```

结论：

- 暗场规则在真实设备上能触发。
- 目标小幅提高，避免 R74A 偏保守。
- 未提高到 `+0.6 ~ +0.8`，因为缺少受控商品样本画面证据。

仍需真机复核：

- 弱光商品是否足够亮。
- 包装文字是否因提亮而发灰。
- 是否需要下一轮把 dark target 提到 `+0.55` 或 `+0.60`。

## 6. 灰白底校准

最终规则：

- `nearWhiteRatio > 0.18`
- 且 `nearWhiteMeanLuma < 0.84`
- 触发 `grayWhiteLift`
- 目标 EV 从 `+0.60` 调整为 `+0.65`

调整原因：

- R74A 日志已确认 grayWhiteLift 能触发。
- 商品拍摄里灰白底需要更积极一些，但不能越过高光保护。
- 本轮只做轻微提高，不直接跳到 `+0.8 ~ +0.9`。

仍需真机复核：

- 白纸 / 白桌 / 白底布是否更干净。
- 白色商品是否被洗掉。
- 浅色包装文字是否发白。

## 7. 高光保护校准

最终规则：

- `clippedRatio > 0.025` 触发 `clippedGuard`，目标不高于 `0.0`。
- `highlightRatio > 0.12` 触发 `highlightGuard`，目标不高于 `+0.25`。
- 高光保护优先级仍高于灰白底和暗场提亮。

调整原因：

- clipped 阈值从 `0.03` 提前到 `0.025`，更早防止局部纯白炸裂。
- highlight cap 从 `+0.30` 收到 `+0.25`，给亮面包装和透明塑料更多余量。

仍需真机复核：

- 透明塑料、金色包装、银色包装、灯光直射下是否仍炸白。
- 如果仍炸，下一轮优先将 clipped 阈值降到 `0.02` 或 highlight 阈值降到 `0.10`。

## 8. 普通亮场 stable / slow decay 校准

新增 stable bright 条件：

- `meanLuma >= 0.54`
- `shadowRatio < 0.22`
- `highlightRatio < 0.09`
- `clippedRatio < 0.01`
- 且 `nearWhiteRatio < 0.16` 或 `nearWhiteMeanLuma >= 0.84`
- 当前 EV 高于 baseline `+0.15` 足够距离

慢回落策略：

- 连续命中 `5` 次 stable bright 后触发。
- 每次 target 为 `max(currentBias - 0.05, +0.15)`。
- 仍经过原有 candidate hit 与写入节流。

设计目的：

- 普通亮场不会长期保持暗场提亮后的高 EV。
- 回落比提亮更慢，降低呼吸风险。
- 不恢复 R74 的固定 `+0.10` 回落。

## 9. 决策优先级

R74B 后 Auto EV 决策优先级：

1. `clippedGuard`
2. `highlightGuard`
3. `grayWhiteLift`
4. `darkSceneLift`
5. `shadowLift`
6. `stableBrightDecay`
7. `stableHold`

说明：

- 高光保护永远最高。
- 灰白底优先于普通暗场。
- stableBright 只负责慢回落。
- stableHold 保持 R74A 的稳定防呼吸策略。

## 10. 手动接管与锁定复核

代码路径保持 R74A：

- 用户手动 EV：reset optimizer，`isExposureBiasAutoMode = false` 后 Auto EV 不写入。
- 点击 EV Auto：reset optimizer，回到 Auto EV 可判断状态。
- AE-L：`商品 Auto 暂停 · AE-L`。
- AEAF-L：`商品 Auto 暂停 · AEAF-L`。
- 手动 ISO / Shutter：`商品 Auto 暂停 · 手动曝光`。
- 拍摄、切镜头、preview restricted：均暂停 Auto EV。

本轮未改这些状态语义。

## 11. 性能复核

已验证：

- generic iOS Debug build 通过。
- iPhone14 pro Max Debug build 通过。
- 真机安装成功。
- 真机启动成功。
- Auto EV console 日志正常输出。
- 日志仍按 R74A 的 1 秒节流输出。

未完成：

- 未做长时间 FPS / 发热量化。
- 未做长时间拍摄压力测试。

性能边界保持：

- sample buffer 分析间隔仍为 `0.35s`。
- EV 写入间隔仍为 `0.35s`。
- 单次最大 EV step 仍为 `0.1`。

## 12. 阈值最终值

- `minAutoBias`: `-0.3`
- `maxAutoBias`: `+0.8`
- `maxStepPerWrite`: `0.1`
- `minimumEffectiveDelta`: `0.05`
- `baselineAutoBias`: `+0.15`
- `stableBrightHitThreshold`: `5`
- `stableBrightDecayStep`: `0.05`
- `clippedGuard`: `clippedRatio > 0.025`
- `highlightGuard`: `highlightRatio > 0.12`, cap `+0.25`
- `grayWhiteLift`: `nearWhiteRatio > 0.18 && nearWhiteMeanLuma < 0.84`, target `+0.65`
- `darkSceneLift`: `meanLuma < 0.45`, target `+0.45`
- `shadowLift`: `shadowRatio > 0.35`, target `+0.30`
- `stableBrightDecay`: `meanLuma >= 0.54 && shadowRatio < 0.22 && highlightRatio < 0.09 && clippedRatio < 0.01`

## 13. 风险与后续建议

风险：

- 四类实物样本主观画面仍需用户真机复核。
- 灰白底目标 `+0.65` 可能对白色商品偏积极。
- stableBrightDecay 的 `5` 次命中可能仍偏慢；如亮场偏亮持续太久，可降到 `4`。
- 强反光场景如仍炸白，应优先继续提前 clipped / highlight guard，而不是降低所有 Auto EV。

下一步建议：

- R74C 只做四场景人工样本复核后的最终阈值微调。
- 暂不扩展 Auto WB / Auto ISO / Auto Shutter。
- 继续保持商品 Auto EV 为单能力、低频、可手动接管的辅助控制。

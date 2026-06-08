# R76A 商品清晰度检测真机样本校准报告

## 1. 改动摘要

- 基于 R76 真机 console 日志，对 `ProductSharpnessAnalyzer` 做保守阈值收口。
- 清晰判定门槛略提高，低纹理与低置信度保护略收紧，降低纯白 / 低纹理场景误触发 AF 的风险。
- 增强 `[ProductSharpness]` Debug 日志，新增 `blocked=...` 字段，方便真机判断 AF 辅助未触发的原因。
- 本轮未修改 AF cooldown、blur hit count、Focus runtime 写入、Auto EV / WB、ISO / Shutter / Lens、白底或拍后流程。

## 2. 文件清单

- `SellerCamera/ProductSharpnessAnalyzer.swift`
  - 提取并调整 sharpness / edge / confidence 阈值常量。
  - 收紧 low texture 与 minimum confidence 条件。
- `SellerCamera/CaptureLivePreviewView.swift`
  - `[ProductSharpness]` 日志增加 `blocked=...`。
- `docs/reports/r76a_product_sharpness_real_device_calibration.md`
  - 本轮真机日志与阈值校准报告。
- `README.md`
  - 增加 R76A 报告索引。

## 3. 真机验证环境

- 设备：iPhone 14 Pro Max
- Identifier：`E7D43088-7946-5FDB-BB14-E38124BB37DB`
- iOS：18.7.7
- 连接：wired / paired / developer mode enabled
- 样本：命令行可见的真实相机启动与取景环境；本轮无法远程摆放固定的清晰 / 虚焦 / 低纹理 / 纯白样本。

## 4. R76 现状复核

- R76 已可输出 `[ProductSharpness]` 与 `[ProductAutoScene] Focus(...)`。
- R76 进入相机初始暗帧时输出：
  - `state=lowConfidence`
  - `reason=tooDark`
  - `autoAF=skipped:lowConfidence`
- 画面稳定后输出：
  - `state=sharp`
  - `reason=sharpEdges`
  - `autoAF=notRequested`
- 这说明 preview analysis、清晰度指标、状态流与 Debug 日志链路已经跑通。

## 5. 清晰商品样本验证

- 可采集到的真实取景日志中，清晰画面稳定为 `sharp`。
- 代表日志范围：
  - `score=12.24 edge=0.514 conf=1.00 state=sharp`
  - `score=14.63 edge=0.637 conf=1.00 state=sharp`
  - `score=16.25 edge=0.664 conf=1.00 state=sharp`
- 结果：
  - 未出现连续 `blurry`。
  - `blurHit=0`。
  - `autoAF=notRequested`。
  - 未出现未对焦提示。

## 6. 故意虚焦样本验证

- 本轮未能通过命令行远程摆放或制造故意虚焦样本。
- 已保留 R76 的连续 3 次 `blurry` 才提示 / 尝试一次 AF 规则。
- 已保留同一 blur episode 只触发一次 AF 的保护。
- 待人工复核：
  - 近距离虚焦商品是否连续进入 `blurry`。
  - 是否最多触发一次中心 AF。
  - 持续虚焦时是否不连续抽焦。

## 7. 低纹理商品验证

- 本轮未能远程摆放低纹理商品样本。
- 本次阈值调整优先增强低纹理保护：
  - `lowTextureEdgeDensity` 从隐式 `0.012` 提高到 `0.018`。
  - `lowTextureContrast` 从隐式 `0.030` 提高到 `0.040`。
- 预期：
  - 纯色 / 低纹理商品更容易进入 `lowConfidence`，而不是误报 `blurry`。
  - lowConfidence 不触发 AF。

## 8. 纯白 / 白底场景验证

- 启动初始暗帧已验证可进入 `lowConfidence` 且不触发 AF。
- 本轮未能远程摆放纯白 / 白底无主体样本。
- 本次通过收紧 low texture 与 confidence，降低白纸 / 白桌无边缘画面误触发风险。
- 待人工复核：
  - 纯白背景是否 `lowConfidence` 或保持不打扰。
  - 是否不显示“商品可能未对焦”。
  - 是否不触发 AF。

## 9. 一次性 AF 辅助验证

- 可采集日志中清晰画面未触发 AF：
  - `autoAF=notRequested`
  - `blocked=none`
  - `cooldown=0.0`
- lowConfidence 暗帧未触发 AF：
  - `autoAF=skipped:lowConfidence`
  - `blocked=lowConfidence`
- 未完成故意虚焦触发验证。
- 规则仍为：
  - 连续 3 次 blurry；
  - confidence 足够；
  - 非 MF / 非 LOCK / 非拍摄或切镜头；
  - 用户近期未点击对焦 / 拖动 MF；
  - 7 秒 cooldown；
  - 同一 blur episode 只辅助一次。

## 10. MF / 点击对焦 / LOCK 保护验证

- 代码级复核：
  - MF ruler 打开会调用 `setProductFocusAssistManualSuppression(true)`。
  - MF 拖动会刷新 `lastManualFocusInteractionAt` 并清空 blurry hit。
  - 点击 / 长按预览会刷新 `lastUserFocusInteractionAt` 并清空 blurry hit。
  - AE-L / AEAF-L、拍摄中、切镜头均在 `productFocusAssistAvailability` 中阻断。
- 本轮未执行手动 UI 操作样本验证；需在真机上复核 MF、点击对焦和 LOCK 下的 `blocked=manualFocus/recentUserFocus/AE-L/AEAF-L`。

## 11. 阈值调整

- `sharpnessScore`
  - sharp：`4.8 -> 5.8`
  - slightlySoft：`2.8 -> 3.0`
- `edgeDensity`
  - sharp：`0.055 -> 0.065`
  - slightlySoft：`0.030 -> 0.035`
- `contrast`
  - lowTexture：`0.030 -> 0.040`
- `confidence`
  - minimum：`0.40 -> 0.45`
- `blurHitCount`
  - 保持 3。
- `cooldown`
  - 保持 7 秒。

## 12. UI 与日志验证

- `[ProductSharpness]` 已验证输出：
  - `score`
  - `edge`
  - `conf`
  - `state`
  - `reason`
  - `blurHit`
  - `sharpHit`
  - `autoAF`
  - `blocked`
  - `cooldown`
- `[ProductAutoScene]` 已验证继续输出 `Focus(...)`。
- 清晰画面未显示虚焦提示。
- 未完成故意虚焦提示真机观察。

## 13. 性能验证

- 通用 iOS 构建通过。
- 真机签名构建通过。
- 真机安装、启动、短时 console 采集成功。
- 短时观察中 `[ProductAutoExposure]`、`[ProductAutoWB]`、`[ProductSharpness]` 均低频输出。
- 未观察到 sample buffer 日志刷屏。
- 未完成长时间发热 / 掉帧观察。

## 14. 风险与后续建议

- 故意虚焦、低纹理、纯白背景仍需要人工真机摆样本复核；本轮只完成清晰画面与 lowConfidence 暗帧的真机日志验证。
- 若虚焦样本识别不足，下一步优先检查 ROI 是否覆盖主体，再小幅降低 blurry 阈值。
- 若纯白 / 低纹理仍误触发，下一步继续提高 low texture edge / contrast 门槛或增加 ROI 纹理面积约束。
- 建议 R76B 做固定样本人工日志采集：清晰包装文字、近距离虚焦、纯白纸、纯色低纹理商品、AEAF-L / MF / 点击对焦保护。

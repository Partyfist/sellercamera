# R76B 商品清晰度检测固定样本验收报告

## 1. 改动摘要

- 本轮执行 R76B 固定样本验收流程的可执行部分：构建、真机设备确认、真机启动、短时 console 日志采集。
- 当前命令行环境无法物理摆放固定样本，也无法远程完成 MF / 点击对焦 / AE-L / AEAF-L 操作，因此未做阈值调整。
- 新增本报告并更新 README 索引。
- 未改 `ProductSharpnessAnalyzer` 阈值、AF cooldown、blur hit count、Focus runtime、Auto EV / WB、ISO / Shutter / Lens、白底或拍后流程。

## 2. 文件清单

- `docs/reports/r76b_product_sharpness_fixed_sample_acceptance.md`
  - R76B 验收报告。
- `README.md`
  - 增加 R76B 报告索引。

## 3. 真机验证环境

- 设备：iPhone 14 Pro Max
- Identifier：`E7D43088-7946-5FDB-BB14-E38124BB37DB`
- iOS：18.7.7
- 连接：wired / paired / developer mode enabled
- 样本：命令行可见的实时取景环境；未能远程摆放清晰商品、故意虚焦、低纹理商品、纯白背景四类固定样本。

## 4. 清晰商品样本验收

- R76A 已记录真实清晰取景环境稳定输出 `sharp`。
- R76B 本轮未能重新摆放有文字包装 / 蜡烛吸卡 / 纸盒彩印 / 边缘明显叉子等固定样本。
- 当前结论：
  - 清晰样本固定验收未完成。
  - 既有 R76A 日志表明清晰画面可稳定 `sharp` 且不触发 AF。
- 待人工记录字段：
  - `score`
  - `edge`
  - `conf`
  - `state`
  - `reason`
  - `blurHit`
  - `sharpHit`
  - `autoAF`
  - `blocked`

## 5. 故意虚焦样本验收

- 本轮未能通过命令行制造前景虚焦、背景对焦后移入商品、或手动 MF 调偏的固定样本。
- 未触发 `blurry`，因此未验证 UI 提示、一次性中心 AF、cooldown 与连续抽焦保护的真实场景表现。
- 当前结论：
  - 故意虚焦验收未完成。
  - 不做阈值下调，避免无证据降低 confidence 或 blurry 门槛。

## 6. 低纹理商品样本验收

- 本轮短时日志持续出现低纹理 / 低置信度形态：
  - `score=0.95~1.25`
  - `edge=0.000`
  - `conf=0.19~0.24`
  - `state=lowConfidence`
  - `reason=lowConfidence`
  - `autoAF=skipped:lowConfidence`
  - `blocked=lowConfidence`
- 当前结论：
  - 有限验证表明低边缘 / 低置信度画面不会误报 blurry，不触发 AF。
  - 但未能确认具体低纹理商品样本，如纯白纸盘、纯色叉子、纯色包装袋。

## 7. 纯白 / 白底样本验收

- 本轮未能摆放白纸、白桌、白背景布且无明显主体边缘的固定样本。
- R76A 已验证暗帧 `lowConfidence/tooDark` 不触发 AF。
- R76B 本轮日志验证低边缘画面 `lowConfidence` 且 `blocked=lowConfidence`。
- 当前结论：
  - 纯白 / 白底固定样本验收未完成。
  - 当前保护方向符合预期：低纹理 / 低置信度不触发 AF。

## 8. MF / 点击对焦 / LOCK 保护验收

- 本轮未能远程执行拍摄页 UI 操作。
- 代码级保护仍保持：
  - MF ruler 打开时 `setProductFocusAssistManualSuppression(true)`。
  - MF 拖动刷新 manual cooldown。
  - 点击 / 长按预览刷新 recent user focus guard。
  - AE-L / AEAF-L、拍摄中、切镜头均会阻断 Focus Assist。
- 待人工复核日志：
  - `blocked=manualFocus`
  - `blocked=recentUserFocus`
  - `blocked=AE-L`
  - `blocked=AEAF-L`
  - `blocked=restricted`
  - `blocked=switchingCamera`

## 9. 阈值调整

- 本轮无阈值调整。
- 原因：
  - 未取得固定虚焦、纯白、低纹理商品、LOCK / MF / 点击对焦场景的完整样本证据。
  - 当前低纹理 / 低置信度日志未误触发 AF，无需进一步收紧。
- 保持 R76A 阈值：
  - sharpnessScore sharp：`5.8`
  - sharpnessScore slightlySoft：`3.0`
  - edgeDensity sharp：`0.065`
  - edgeDensity slightlySoft：`0.035`
  - lowTexture contrast：`0.040`
  - minimum confidence：`0.45`
  - blurHitCount：`3`
  - cooldown：`7s`

## 10. 与 Auto EV / WB 共存验证

- 真机短时日志中 `[ProductAutoExposure]`、`[ProductAutoWB]`、`[ProductAutoScene]` 均继续输出。
- R76B 未修改 Auto EV / WB 阈值或写入路径。
- 观察到 ProductSharpness 与 Auto EV / WB 共用 preview analysis 后，日志仍低频输出。

## 11. UI 与性能验证

- UI：
  - 本轮未观察到虚焦提示，因为未进入 `blurry`。
  - 低置信度场景未显示虚焦提示，符合“不打扰”目标。
- 性能：
  - `xcodebuild` generic iOS Debug 构建通过。
  - 真机短时启动与 console 采集成功。
  - 日志低频，未见刷屏。
  - 未完成长时间预览帧率、发热、参数拖动与拍照操作观察。

## 12. 风险与后续建议

- R76B 在当前命令行环境下只能完成链路级与低置信度日志复核，不能替代人工固定样本验收。
- 下一步建议人工按任务书固定样本采集四组日志：
  1. 清晰文字包装；
  2. 故意虚焦文字商品；
  3. 纯色低纹理商品；
  4. 纯白 / 白底无主体边缘。
- 如果故意虚焦仍无法进入 `blurry`，优先检查 ROI 是否覆盖主体，再考虑小幅降低 blurry 判定门槛。
- 如果纯白 / 低纹理误触发 AF，优先继续收紧 low texture / confidence，而不是关闭整套清晰度检测。

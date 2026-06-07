# R75B 商品 Auto EV + WB 联合真机样本验收报告

## 1. 改动摘要

R75B 在 R74B Auto EV 与 R75A Auto WB 的基础上做联合真机链路验收。本轮重点确认 EV 与 WB 是否能在同一 preview analysis 管线中同时工作、是否各自保持独立状态、是否在真机日志中出现预期决策。

本轮没有继续调整阈值。原因是当前可操作环境只完成了真机安装、启动和随手场景日志捕获，未完成固定商品样本、固定光源与人工主观画面比对；继续改阈值会变成猜测式调参，不符合 R75B 的验收目标。

本轮新增 R75B 联合验收报告并更新 README 报告索引。未改 Auto EV / Auto WB runtime 写入路径，未改 ISO / Shutter / Focus / Lens，未改白底和拍后流程。

## 2. 文件清单

- `docs/reports/r75b_product_auto_ev_wb_joint_acceptance.md`
  - 新增 R75B 联合真机验收报告。
- `README.md`
  - 增加 R75B 报告索引。

## 3. 真机验证环境

- 设备：iPhone 14 Pro Max
- 设备标识：E7D43088-7946-5FDB-BB14-E38124BB37DB
- iOS：18.7.7
- 构建：Debug / iPhoneOS / 真机签名
- 安装：成功
- 启动：成功
- 日志方式：`xcrun devicectl device process launch --console`
- 日志文件：`/tmp/sellercamera-r75b-launch.log`
- 样本：未完成固定商品样本摆拍；本轮为随手取景环境下的联合链路日志验证
- 光源：未固定；包含暗场、近白区域、高光变化等动态取景片段

## 4. 样本与光源

任务书建议的四类固定样本：

- 白底 + 白色 / 透明商品
- 白底 + 彩色商品
- 白底 + 反光商品
- 彩色背景 / 非白底

本轮未完成上述固定样本的人工摆拍和主观画面对比。已完成的是同一真机启动窗口内的联合日志捕获，日志中覆盖了暗场、灰白底候选、高光 guard、near-white 低置信度、warm/cool/neutral WB 决策等状态。

因此本报告的验收结论分为：

- 已确认：联合日志链路、真机安装启动、EV/WB 决策并行输出、部分写入迹象。
- 未确认：四类标准商品样本的主观画质，包括白底是否更干净、商品色彩是否更中性、反光商品细节是否保留。

## 5. 白底 + 白色 / 透明商品验收

已观察到与该场景相关的日志信号：

- Auto EV 出现 `grayWhiteLift`，例如 nearWhiteRatio 约 0.305...0.356、nearWhiteLuma 约 0.757...0.808 时目标 EV 指向 +0.65。
- Auto WB 出现 usable near-white，whiteRatio 约 0.247...0.441 时可进入 `neutralHold` 或 `coolCastWarmUp`。

未完成：

- 未用白色叉子、透明叉子、纸盘、透明包装袋做固定画面对比。
- 未人工确认白色商品是否被洗掉、透明边缘是否仍清楚。

结论：

- 代码与日志层面具备处理白底 + 白/透明商品的输入信号。
- 仍需要人工固定样本复核，尤其是 Auto EV grayWhiteLift 与 clippedGuard 的边界。

## 6. 白底 + 彩色商品验收

已观察到的相关信号：

- Auto WB 在 near-white 低置信度时进入 `lowConfidence` 并保持，不会因没有可靠白点直接写入。
- Auto WB 在 redBlueDelta 小于 deadband 时进入 `neutralHold`。
- Auto EV 仍可根据 meanLuma / nearWhiteRatio 触发 darkSceneLift 或 grayWhiteLift。

未完成：

- 未使用彩色生日蜡烛、彩色餐具、彩色包装卡纸等样本做主观色彩准确性验证。
- 未确认 EV 提亮后彩色商品是否发淡。

结论：

- 状态机未发现 EV 与 WB 互相抢状态。
- 彩色商品场景还需要固定样本复核，特别是 high saturation 商品是否会错误进入 near-white。

## 7. 白底 + 反光商品验收

已观察到的相关信号：

- Auto EV 出现 `clippedGuard` 2 次。
- 日志中出现 clippedRatio 约 0.255、highlightRatio 约 0.270 的高光风险片段，EV 决策进入高光保护，而不是继续 grayWhiteLift。
- Auto WB near-white 候选排除了 `luma >= 0.96` 与 `channelMax >= 0.97` 的高光像素，降低 clipped 高光误导 WB 的风险。

未完成：

- 未使用金色/银色包装、亮面卡纸、透明塑料反光商品做固定画面对比。
- 未人工确认高光细节保留和透明边缘是否可见。

结论：

- 高光 guard 在真机日志中能触发。
- 固定反光商品主观验收仍是下一轮最关键项。

## 8. 彩色背景 / 非白底验收

已观察到的相关信号：

- Auto WB 在 whiteCount 为 0 或 whiteRatio 很低时输出 `lowConfidence`。
- R75A 的 `confidenceReason` 能区分 `lowNearWhite`、`marginalNearWhite` 与 `usableNearWhite`。
- Auto EV 不依赖 WB 状态，仍可按亮度继续输出 darkSceneLift / stable / guard。

未完成：

- 未使用彩色桌布、深色桌面、木纹桌面固定样本验证。
- 未人工确认大面积彩色商品是否会被误当白点。

结论：

- 当前低置信度 hold 机制仍工作。
- 彩色背景仍需固定样本验证，尤其是 marginalNearWhite 是否会在复杂商品场景误触发。

## 9. Auto EV 与 Auto WB 联合日志分析

本轮真机 console 共捕获 60 条 Auto EV / Auto WB 日志行。

决策计数：

- `darkSceneLift`：23
- `grayWhiteLift`：5
- `clippedGuard`：2
- `warmCastCoolDown`：2
- `coolCastWarmUp`：10
- `neutralHold`：10
- `lowConfidence`：8

关键片段：

- Auto EV 暗场提亮：
  - `decision=darkSceneLift`
  - observed `target=+0.45` / `next=+0.30`
- Auto EV 灰白底提亮：
  - `decision=grayWhiteLift`
  - observed nearWhiteRatio 约 0.305...0.416
- Auto EV 高光保护：
  - `decision=clippedGuard`
  - observed clippedRatio 约 0.255
- Auto WB 暖色修正：
  - `decision=warmCastCoolDown`
  - observed `target=3650K` / `next=3800K` / `current=3898K`
- Auto WB 冷色修正：
  - `decision=coolCastWarmUp`
  - observed `target=4250K` / `next=4100K` / `current=4000K`
- Auto WB 中性保持：
  - `decision=neutralHold`
- Auto WB 低置信度保持：
  - `decision=lowConfidence`

联合结论：

- EV 与 WB 共用同一次 sample buffer analysis，但各自独立 optimizer、独立 availability、独立 write interval。
- 日志显示二者可在同一启动窗口内交替输出，未观察到互相暂停或互相覆盖状态。
- 未观察到崩溃。
- 未观察到日志刷屏；Debug 摘要仍为低频输出。

## 10. 阈值调整

本轮未调整阈值。

原因：

- 已有 R74B / R75A 阈值在真机日志中能触发关键状态。
- 本轮没有固定样本、固定光源、人工主观画面对比，不足以判断需要更亮、更冷、更暖或更保守。
- 继续调阈值可能破坏 R74B / R75A 已经跑通的暗场、灰白底、高光和 Kelvin-only 白平衡链路。

当前保留：

- Auto EV：R74B 的 darkSceneLift、grayWhiteLift、clippedGuard、highlightGuard、stableBrightDecay。
- Auto WB：R75A 的 near-white 条件、0.30 confidence、0.055 redBlueDelta、75K minDelta、3 次 stable hit、100K 单次步进。

## 11. 手动 EV / WB 接管验证

代码级复核：

- 手动 EV：`productAutoExposureAvailability()` 会在非 EV Auto 状态下返回 `商品 Auto 暂停 · 手动EV`，并 reset Auto EV optimizer。
- 手动 WB：`productAutoWhiteBalanceAvailability()` 会在非 WB Auto 状态下返回 `商品 WB 暂停 · 手动WB`，并 reset Auto WB optimizer。
- EV Auto 与 WB Auto 走各自 reset 路径，不共享同一个 paused 状态。
- Auto EV 不修改 WB state；Auto WB 不修改 EV state。

真机 UI 操作：

- 本轮未人工拖动 EV / WB ruler，也未点击 EV Auto / WB Auto 做交互复核。

结论：

- 代码级状态隔离清楚。
- 手动接管仍需要下一轮固定样本验收时同步做人工 UI 验证。

## 12. UI 状态验证

本轮未改 UI。

代码级复核：

- Auto EV 状态仍通过 `productAutoExposureStatusText` 表达。
- Auto WB 状态仍通过 `productAutoWhiteBalanceStatusText` 表达。
- 手动 EV / 手动 WB 会分别显示暂停状态。

未完成：

- 未在真机上逐项点击 EV / WB 参数栏确认 UI 文案与状态联动。

## 13. 性能验证

已确认：

- 本轮未新增第二条 video output。
- EV 与 WB 仍共用同一低频 preview frame analysis。
- 像素遍历仍在 capture output 队列中完成，主线程只处理两个 metrics handler。
- 真机启动与 35 秒 console 捕获期间未崩溃。
- Debug 日志低频，未出现明显刷屏。

未完成：

- 未做长时间发热测试。
- 未做参数表盘拖动压力测试。
- 未做拍照保存、白底处理和拍后 Review 全链路真机复核。

## 14. 风险与后续建议

风险：

- 四类固定商品样本主观验收仍未完成，不能宣称最终画质已达标。
- Auto WB 仍是 Kelvin-only，偏绿 LED 和 tint 偏色仍只 hold / 记录。
- Auto EV grayWhiteLift 与 clippedGuard 在白色透明商品、反光包装上的边界仍需实物确认。
- EV 提亮后可能改变 near-white confidence，当前只通过日志看到联动存在，未完成稳定画面对比。

后续建议：

- R75C：固定样本拍摄验收，至少覆盖白纸 + 透明叉、白纸 + 彩色蜡烛、白纸 + 反光包装、彩色背景 + 彩色商品。
- 每个样本记录 10 秒日志、拍摄前后主观画面对比、是否过曝、是否色温呼吸、是否手动 EV/WB 接管正常。
- 只有在固定样本证据明确后，再决定是否调整 EV guard、WB confidence、WB deadband 或引入 tint 微调。

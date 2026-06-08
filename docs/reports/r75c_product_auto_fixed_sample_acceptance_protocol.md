# R75C 商品 Auto 固定样本验收与日志采集规范报告

## 1. 改动摘要

R75C 不做 Auto EV / Auto WB 阈值调整。本轮目标是把后续调参从“随手日志判断”收口为“固定样本 + 固定光源 + 统一日志 + 主观评分”的可复现流程。

本轮新增 Debug-only `[ProductAutoScene]` 联合摘要日志，将同一 preview analysis 下的 EV 与 WB 状态压缩到一行，便于后续把 console 日志与真实画面主观评分对应起来。该日志只在 DEBUG 编译输出，不改变 EV / WB 决策，不写 runtime，不影响 Release 行为。

本轮同时新增固定样本验收模板、固定光源模板、主观评分模板、手动接管复核模板、性能复核模板和后续阈值调整决策规则。

## 2. 文件清单

- `SellerCamera/CaptureLivePreviewView.swift`
  - 新增 Debug-only `[ProductAutoScene]` 联合摘要日志。
  - 日志复用现有 preview frame analysis，不新增 video output，不改 EV / WB 写入链路。
- `docs/reports/r75c_product_auto_fixed_sample_acceptance_protocol.md`
  - 新增 R75C 固定样本验收与日志采集规范。
- `README.md`
  - 增加 R75C 报告索引。

## 3. 为什么本轮不调阈值

R74B / R75A / R75B 已经确认：

- Auto EV 可输出 darkSceneLift、grayWhiteLift、highlight / clipped guard、stableBrightDecay。
- Auto WB 可输出 warmCastCoolDown、coolCastWarmUp、neutralHold、lowConfidence。
- EV 与 WB 可共用同一 preview analysis，并保持独立决策与独立写入。

但当前缺口是固定样本证据不足：

- 没有同一商品、同一构图、同一光源下的稳定主观评分。
- 没有白底 + 白/透明商品、彩色商品、反光商品、彩色背景四类样本的可复现日志。
- 没有明确区分“白底偏灰”“白底偏黄”“商品被洗白”“彩色背景误判”“画面呼吸”等问题的证据归因。

因此 R75C 只建立采集规范和 Debug 采集辅助，不继续猜测式调参。

## 4. 固定样本验收模板

### 4.1 白底 + 白色 / 透明商品

样本建议：

- 白色一次性叉子
- 透明一次性叉子
- 白色纸盘
- 透明包装袋

摆放方式：

- 使用白纸、白桌或白底布作为背景。
- 商品占取景区域约 35%...60%。
- 保持商品边缘、透明边缘和白底同时可见。
- 每个光源下保持取景 10 秒，复制对应 `[ProductAutoScene]`、`[ProductAutoExposure]`、`[ProductAutoWB]` 日志片段。

记录字段：

- EV decision
- WB reason
- nearWhiteRatio
- nearWhiteMeanLuma
- highlightRatio
- clippedRatio
- redBlueDelta
- greenCast
- subject detail
- subjective score

验收重点：

- Auto EV 是否把白底提亮。
- 白色商品是否被洗掉。
- 透明边缘是否仍可见。
- Auto WB 是否让白底更中性。
- 是否出现高光过曝。

### 4.2 白底 + 彩色商品

样本建议：

- 彩色生日蜡烛
- 彩色餐具
- 彩色包装卡纸
- 派对用品

摆放方式：

- 白底背景保持不变。
- 商品主体至少包含红、蓝、绿、黄等明显颜色之一。
- 保持白底和商品颜色同时占画面主要区域。

验收重点：

- 色彩是否准确。
- WB 是否过度校正。
- EV 提亮后颜色是否发淡。
- 彩色商品是否被误判为 near-white。
- 白底是否干净。

### 4.3 白底 + 反光商品

样本建议：

- 金色包装
- 银色包装
- 亮面吸卡
- 透明塑料反光商品

摆放方式：

- 让反光区域位于画面内但不要完全占满画面。
- 至少保留包装文字或边缘细节用于判断是否被洗掉。
- 每个光源下记录高光最强和正常角度两个片段。

验收重点：

- clippedGuard 是否及时触发。
- 反光区域是否炸白。
- 包装文字是否保留。
- Auto WB 是否被高光误导。
- EV 是否过度提亮。

### 4.4 彩色背景 / 非白底

样本建议：

- 彩色桌布
- 木纹桌面
- 深色桌面
- 大面积彩色商品

摆放方式：

- 不放白纸或白底布。
- 让背景占画面 40% 以上。
- 记录暖光、冷光或普通亮场下的日志片段。

验收重点：

- near-white 不足时 Auto WB 是否 hold。
- 彩色背景是否误触发 warm / cool。
- Auto EV 是否仍能合理提亮。
- 是否出现偏色。

## 5. 固定光源验收模板

每个样本尽量覆盖至少两类光源。

### 5.1 室内暖光

目的：

- 验证 WB 是否能降黄。
- 验证 EV 提亮后是否加重黄色感。
- 验证 WB 与 EV 是否协同。

记录：

- 暖光色温体感。
- `redBlueDelta` 是否为正。
- WB 是否进入 `warmCastCoolDown`。

### 5.2 冷白 LED / 阴天窗边

目的：

- 验证 WB 是否适度回暖。
- 验证白底是否不发蓝。
- 验证不过度发黄。

记录：

- `redBlueDelta` 是否为负。
- WB 是否进入 `coolCastWarmUp`。
- 调整后白底是否中性。

### 5.3 普通亮场

目的：

- 验证 EV 不长期偏亮。
- 验证 stableBrightDecay。
- 验证 WB neutralHold。

记录：

- `stableBrightCount`
- `stableBrightDecay` 是否出现。
- 是否有亮度呼吸。

### 5.4 强高光 / 反光

目的：

- 验证 highlightGuard / clippedGuard。
- 验证 WB 是否排除 clipped 高光。
- 验证商品细节是否保留。

记录：

- `highlightRatio`
- `clippedRatio`
- `clippedGuard`
- `highlightGuard`

## 6. Debug 日志与场景采集格式

### 6.1 现有日志

继续保留：

- `[ProductAutoExposure]`
- `[ProductAutoWB]`

这两类日志用于查看详细 EV / WB 单项决策。

### 6.2 新增联合摘要日志

R75C 新增：

```text
[ProductAutoScene] sceneId=unlabeled t=... EV(decision=..., stableBrightCount=..., applied=..., mean=..., shadow=..., hi=..., clip=..., white=..., whiteY=...) WB(decision=..., stableHitCount=..., current=..., whiteRatio=..., whiteCount=..., rb=..., green=..., conf=..., confReason=...)
```

说明：

- 仅 DEBUG 输出。
- 低频输出，默认约 1 秒一条。
- `sceneId=unlabeled` 表示当前未通过 UI 标记场景，后续人工记录时可在测试表中手动对应样本名称。
- 该日志不参与算法，不写 runtime。
- 该日志用于把同一时间点的 EV 与 WB 状态放在一行，便于复制 console 和主观评分对应。

建议后续人工记录时使用以下 sceneId 名称：

- `white_transparent_warm`
- `white_transparent_window`
- `color_product_warm`
- `color_product_window`
- `reflective_highlight`
- `color_background`

## 7. 主观评分模板

每个样本 / 光源组合填写：

```text
样本：
光源：
取景时间：
日志时间段：

亮度：1-5
白底干净度：1-5
色彩准确度：1-5
高光保留：1-5
商品细节：1-5

是否抽动：是 / 否
是否偏黄：是 / 否
是否偏蓝：是 / 否
是否过曝：是 / 否
是否需要调 EV：是 / 否
是否需要调 WB：是 / 否

主观备注：
对应日志摘要：
```

判定标准：

- 4 分以上：可接受。
- 3 分：需要微调。
- 2 分以下：对应阈值需要收口。
- 出现过曝 / 抽动 / 手动抢回：必须修。

## 8. EV / WB 联合判断规则

### 8.1 白底偏灰

优先检查：

- Auto EV `grayWhiteLift`
- `nearWhiteMeanLuma`
- `maxAutoBias`
- `highlightRatio` / `clippedRatio`

不要先改 WB。

### 8.2 白底偏黄

优先检查：

- Auto WB warm threshold
- nearWhite confidence
- Kelvin target delta

不先做 tint。

### 8.3 白底偏蓝

优先检查：

- Auto WB cool threshold
- warmUp delta
- neutral deadband

### 8.4 商品被洗白

优先检查：

- Auto EV highlight / clipped guard
- grayWhiteLift 上限
- stableBrightDecay

不用 WB 解决曝光问题。

### 8.5 彩色背景误判

优先检查：

- nearWhite saturation 上限
- maxRGB-minRGB 限制
- confidence threshold
- nearWhiteRatio threshold

### 8.6 画面呼吸

优先检查：

- EV / WB stableHitCount
- writeInterval
- minDelta
- neutral deadband
- slow decay 条件

## 9. 手动接管复核模板

### 9.1 EV 手动接管

步骤：

1. 确认 Auto EV 正在工作。
2. 手动拖 EV。
3. 等待 5 秒。
4. 确认 Auto EV 不抢回。
5. 点击 EV Auto。
6. 确认 Auto EV 恢复。

记录：

- 手动前 EV 状态：
- 手动后状态：
- 5 秒内是否自动写入：
- EV Auto 后是否恢复：

### 9.2 WB 手动接管

步骤：

1. 确认 Auto WB 正在工作。
2. 手动拖 WB。
3. 等待 5 秒。
4. 确认 Auto WB 不抢回。
5. 点击 WB Auto。
6. 确认 Auto WB 恢复。

记录：

- 手动前 WB 状态：
- 手动后状态：
- 5 秒内是否自动写入：
- WB Auto 后是否恢复：

### 9.3 双手动

步骤：

1. 手动 EV + 手动 WB。
2. 确认两者都暂停。
3. 分别点击 EV Auto 和 WB Auto。
4. 确认状态不互相污染。

记录：

- EV 是否独立暂停：
- WB 是否独立暂停：
- EV Auto 是否只恢复 EV：
- WB Auto 是否只恢复 WB：

## 10. 性能复核模板

每次固定样本测试后记录：

```text
预览是否卡顿：
参数拖动是否卡顿：
拍照是否正常：
日志是否刷屏：
设备是否明显发热：
运行时长：
sample buffer 是否堆积：
```

如果无法量化 FPS，也至少做主观记录。

## 11. 后续调参决策规则

R75D / R76 只有在固定样本证据明确后才调整阈值。

建议规则：

- 同一问题在至少 2 个相近样本中复现，再考虑调阈值。
- 如果只有单个样本异常，先判断是否为摆放、光源、反光角度导致。
- 如果出现过曝、抽动、手动抢回，优先修保护与状态。
- 如果只是白底轻微偏灰或偏黄，先保守微调，避免破坏其它场景。
- 每次调阈值后必须回跑白色/透明、彩色、反光、彩色背景四组最小样本。

## 12. 验证结果

已执行：

- `git status`
- `xcodebuild -scheme SellerCamera -project SellerCamera.xcodeproj -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/SellerCameraR75CBuild CODE_SIGNING_ALLOWED=NO clean build`
- `xcodebuild -scheme SellerCamera -project SellerCamera.xcodeproj -configuration Debug -destination 'id=E7D43088-7946-5FDB-BB14-E38124BB37DB' -derivedDataPath /tmp/SellerCameraR75CDeviceBuild build`
- `xcrun devicectl device install app --device E7D43088-7946-5FDB-BB14-E38124BB37DB /tmp/SellerCameraR75CDeviceBuild/Build/Products/Debug-iphoneos/SellerCamera.app`
- `xcrun devicectl device process launch --device E7D43088-7946-5FDB-BB14-E38124BB37DB --terminate-existing --console com.partyfist.SellerCamera`

结果：

- generic iOS clean build：通过，`BUILD SUCCEEDED`。
- iPhone 14 Pro Max 真机构建：通过，`BUILD SUCCEEDED`。
- 真机安装：成功。
- 真机启动：成功。
- `[ProductAutoScene]`：已确认低频输出。
- `[ProductAutoExposure]`：已确认仍可输出。
- `[ProductAutoWB]`：已确认仍可输出。

说明：

- 本轮真机启动取景接近全黑 / 遮挡场景，日志只能证明 Debug 采集链路、低频输出和三类日志并存，不用于固定样本阈值判断。
- 本轮未执行拍照、白底处理、拍后 Review 的完整真机回归。

## 13. 风险与后续建议

风险：

- `sceneId=unlabeled` 目前是日志占位，不是正式 UI 标记；后续仍需要人工在测试记录中标注场景。
- 固定样本模板只能保证测试可复现，不能替代真实拍摄环境覆盖。
- `[ProductAutoScene]` 为 Debug 日志，Release 不输出；不要依赖它作为产品功能。

后续建议：

- R75D：按本报告模板做固定样本真机验收，收集每个样本至少 10 秒日志和主观评分。
- R76：基于 R75D 样本证据做 EV / WB 阈值小幅调整；若偏绿 LED 问题明确，再单独开 tint 微调包。

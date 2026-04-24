# 白底后段衔接第二阶段微调小结（第 5.5 包 / R2.2）

- 日期：2026-04-20
- 关联样本套件：`whitebg-vision-core-v1`
- 对照基线（R2.1）：`WhiteBackgroundBaseline/runs/whitebg-vision-core-v1/baseline-20260420-r21.jsonl`
- 本包复测（R2.2）：`WhiteBackgroundBaseline/runs/whitebg-vision-core-v1/baseline-20260420-r22.jsonl`
- 本包人工对照：`WhiteBackgroundBaseline/manual_review.core_v1.r22.json`

## 1. 本包目标（范围内）

本包不新增后段策略，只对 R2.1 已落地三条策略做定向微调，聚焦：

1. `S010` 底边接地自然度窄化
2. `S008` near-white 交界收口
3. `S005` 透明末端 cleanup 平衡

并继续守住：`ready/review` 不回退、无新增不可接受失败。

## 2. 为什么 R2.1 有轻度改善但仍不够明确

工程判断（基于代码与 R2.1 记录）：

1. R2.1 的三条后段策略已命中并可见，但参数仍偏保守，优先保证“先稳住不回退”；
2. 底边支撑带命中区域偏宽，导致 `S010` 上“收灰浮”与“接地自然”之间仍有余量；
3. near-white 后段保护与去污染风险区交界仍有轻度冲突，`S008` 上主体稳定性提升可见但不够明确；
4. 透明末端 cleanup 在 `S005` 上已起效，但强度与命中范围仍偏克制，末端净化尚可再收一步。

## 3. 本包代码侧微调落点（R2.2）

实现文件：`CaptureWhiteBackgroundProcessor.swift`

### 3.1 S010：底边接地自然度窄化
- `bottomInfluenceBlurRadius`: `0.62 -> 0.52`
- `bottomGrayFloatSupportWeight`: `0.18 -> 0.22`
- 新增 `bottomZoneUpperRatio = 0.46`，将底边支撑聚焦到更窄下沿区域，减少“命中过宽”的副作用。

### 3.2 S008：near-white 交界收口
- `nearWhiteProtectThreshold`: `0.72 -> 0.70`
- `nearWhiteProtectBlurRadius`: `0.56 -> 0.48`
- `nearWhiteProtectGuardWeight`: `0.75 -> 0.82`
- near-white 保护掩码从 `refinedMask` 约束改为 `subjectCoreMask` 优先，避免保护区过宽冲淡风险区清理效果。

### 3.3 S005：透明末端 cleanup 平衡
- `edgeTailCleanupBlurRadius`: `0.44 -> 0.38`
- `edgeTailCleanupWeight`: `0.18 -> 0.22`
- 目标是末端更净，同时维持透明感，不走“整条边重清理”。

### 3.4 可复核标记
- `r2_2_bottom_zone_focus = enabled`
- `r2_2_near_white_core_priority = enabled`
- `r2_2_tail_cleanup_balance_tuning = enabled`

## 4. core_v1 复测结果（R2.1 -> R2.2）

### 4.1 分布与稳定性
- `ready/review`: `9/1 -> 9/1`（无回退）
- `hard_case_signal=stable`: `10/10`
- 未观测到新的不可接受失败
- 运行环境：`iPhone15,3` / `iOS 18.7.7` / `visionRevision=1`

### 4.2 目标样本人工对照（摘要）
- `S010`: 底边灰浮较 R2.1 再收一小步，接地自然度更明确；未出现假阴影或底边发脏。
- `S008`: near-white 主体稳定性较 R2.1 再提升一小步，主体更立；未见明显硬边或块感副作用。
- `S005`: 透明末端污染较 R2.1 再收一小步，透明感仍保留；未出现末端过实、断边。

结论：
- 本包把“轻度可见改善”推进到“更明确可见改善（仍属保守级）”；
- 仍未出现分布跃迁，符合“低风险微调”预期。

## 5. 本包刻意没做（边界）

1. 未接入新分割主干（U²-Net / BiRefNet / 其他）
2. 未重做 refinement（4/4.5 包逻辑保持）
3. 未做去污染大改或合成重写
4. 未引入投影/阴影系统
5. 未重排主处理顺序
6. 未扩样本池（继续只用 core_v1）

## 6. 下一包建议（低风险）

建议进入“第 5.6 包：后段微调收官评估（仍沿用 core_v1 + 小范围更大样本验证准备）”：

1. 继续小步验证 `S010/S008/S005` 是否还能在不引入副作用前提下再收一点；
2. 若收益继续变小，优先准备“更大样本验证包”而不是继续在 core_v1 过度微调；
3. 在更大样本验证后，再决定是否进入“新主干准入评估”。

# 白底去污染/合成衔接第一阶段小结（第 5 包 / R2.1）

- 日期：2026-04-20
- 关联样本套件：`whitebg-vision-core-v1`
- 对照基线（R1.5）：`WhiteBackgroundBaseline/runs/whitebg-vision-core-v1/baseline-20260419-r15.jsonl`
- 本包复测（R2.1）：`WhiteBackgroundBaseline/runs/whitebg-vision-core-v1/baseline-20260420-r21.jsonl`
- 本包人工对照：`WhiteBackgroundBaseline/manual_review.core_v1.r21.json`

## 1. 本包目标（范围内）

本包只做去污染/合成衔接第一阶段收口，不改分割主干、不重排主流程，聚焦三类问题：

1. 底边灰浮收口（重点：`S010`）
2. 近白主体稳定性保持（重点：`S008`）
3. 透明边缘末端污染抑制（重点：`S005`）

## 2. 当前后段职责与本包落点

工程判断（基于当前链路）：

1. refinement 负责前段 mask 与边缘基础收口；
2. 去污染阶段负责边缘邻域污染抑制与风险区去色；
3. 合成阶段负责最终白底衔接观感。

第 4/4.5 包已让前段策略进入主链并拿到轻度改善；本包聚焦“后段是否再次放大灰浮/发虚/末端污染”。

本包落点：
- 去污染风险区的 near-white 守护
- 底边支撑带的轻量补偿
- 透明边缘尾段污染抑制

## 3. 代码侧最小收口（R2.1）

实现文件：`CaptureWhiteBackgroundProcessor.swift`

### 3.1 底边灰浮收口
- 新增底边支撑区参数：
  - `bottomShiftY`
  - `bottomInfluenceBlurRadius`
  - `bottomGrayFloatSupportWeight`
- 在去污染路径中加入底边支撑带，避免底边在后段再次发灰、发飘。

### 3.2 近白主体稳定性保持
- 新增 near-white 保护参数：
  - `nearWhiteProtectThreshold`
  - `nearWhiteProtectBlurRadius`
  - `nearWhiteProtectGuardWeight`
- 在去污染风险区抑制前引入 near-white 反向保护，减少后段对核心近白主体的再次冲淡。

### 3.3 透明边缘末端污染抑制
- 新增尾段清理参数：
  - `edgeTailCleanupBlurRadius`
  - `edgeTailCleanupWeight`
- 在 `chromaSpillRiskMask` 末端加入轻量 cleanup blend，压制透明边缘末端污染残留。

### 3.4 可复核标记
- 新增 metadata 标记：
  - `r2_1_decontam_bottom_gray_float_support`
  - `r2_1_decontam_near_white_guard`
  - `r2_1_decontam_edge_tail_cleanup`

## 4. core_v1 复测结果（R1.5 -> R2.1）

### 4.1 分布与稳定性
- `ready/review`：`9/1 -> 9/1`（无分布回退）
- `hard_case_signal=stable`：`10/10`
- 未观测到新的不可接受失败
- 运行环境：`iPhone15,3` / `iOS 18.7.7` / `visionRevision=1`

### 4.2 目标样本人工对照（摘要）
- `S005`：透明边缘末端污染有轻度收口，透明感保持，未见明显实化副作用。
- `S008`：近白主体核心稳定性轻度提升，主体发虚感略减，但“更立”幅度仍有限。
- `S010`：贴地边缘灰浮轻度收口，接触区自然度略有提升，仍属保守级改善。

结论：
- 本包实现了“后段开始收口且不回退”；
- 改善为轻度、局部、可见，但尚未达到“明显跃迁”。

## 5. 本包刻意没做（边界）

1. 未接入新分割主干（U²-Net / BiRefNet / 其他）
2. 未做 refinement 大改或回滚 4/4.5 包路径
3. 未做白底合成重写或阴影系统
4. 未重排主处理顺序
5. 未扩样本池（继续使用 `core_v1`）

## 6. 下一包建议（低风险）

建议进入“第 5.5 包：后段微调第二阶段（仍沿用 core_v1）”，优先做：

1. `S010` 底边灰浮支撑区进一步窄化与权重小步校准
2. `S008` 近白主体保护区与去污染风险区交界处的抑制冲突再收口
3. `S005` 透明边缘尾段 cleanup 强度与透明感保持的平衡微调

如果 5.5 包后仍只有轻度收益，再评估是否进入“更大样本池验证 + 新主干 AB 准入判断”。

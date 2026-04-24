# 白底 refinement 第二阶段微调小结（第 4.5 包）

- 日期：2026-04-19
- 关联样本套件：`whitebg-vision-core-v1`
- 对照基线（R1.4）：`WhiteBackgroundBaseline/runs/whitebg-vision-core-v1/baseline-20260419-r14.jsonl`
- 本包复测（R1.5）：`WhiteBackgroundBaseline/runs/whitebg-vision-core-v1/baseline-20260419-r15.jsonl`
- 本包人工对照：`WhiteBackgroundBaseline/manual_review.core_v1.r15.json`

## 1. 本包目标（范围内）

本包不新增算法方向，只对第 4 包已落地的三条 refinement 策略做低风险微调：

1. 薄边保真
2. 贴地边缘支撑
3. 近白主体核心锚定

并且强制给出同样本人工对照结论（`S001/S003/S005/S008/S010`）。

## 2. 为什么第 4 包“命中但可见性有限”

工程判断（基于代码与 R1.4 记录）：

1. 三条策略都已命中并落盘，但命中强度偏保守，优先保证了“不会回退”。
2. 当前 JSONL 风险字段粒度较粗，细节边缘改善不容易反映为分布变化。
3. R1.4 在目标样本上的变化主要停留在“可感知但不够明确”，需要再做小步阈值/权重校准。

## 3. 本包微调落点（R1.5）

实现文件：`CaptureWhiteBackgroundProcessor.swift`

### 3.1 薄边保真
- 收紧边缘保留区域 blur（`edgePreserveRegionBlurRadius: 0.34 -> 0.30`）
- 提升细结构保留增益（`thinStructurePreserveBoostFactor: 0.15 -> 0.20`）

### 3.2 贴地边缘支撑
- 接触支撑区下移增强（`contactEdgeShiftY: 1.6 -> 1.8`）
- 收紧接触支撑 blur（`contactEdgeSupportBlurRadius: 0.52 -> 0.44`）
- 提升接触支撑增益（`contactEdgeSupportBoostFactor: 0.17 -> 0.21`）

### 3.3 近白主体核心锚定
- 扩展 near-white 核心命中范围（`nearWhiteCoreThreshold: 0.76 -> 0.73`）
- 收紧 near-white 核心 blur（`nearWhiteCoreBlurRadius: 0.52 -> 0.46`）
- 提升 near-white 核心增益（`nearWhiteCoreBoostFactor: 0.13 -> 0.17`）
- 提升核心锚定权重（`nearWhiteCoreAnchorWeight: 0.18 -> 0.24`）

## 4. core_v1 对比结果（R1.4 -> R1.5）

### 4.1 分布与稳定性
- `ready/review`: `9/1 -> 9/1`（不回退）
- `hard_case_signal`: `stable` 仍为 `10/10`
- 未出现新的不可接受失败

### 4.2 目标样本人工对照（摘要）
- `S001`: 薄边连续性轻度改善，可见但有限
- `S003`: 高反细边断裂感轻度缓解，可见但有限
- `S005`: 透明薄边与接触边缘自然度轻度提升，可见但有限
- `S008`: 近白主体核心“更立”轻度改善，仍需继续收口
- `S010`: 贴地边缘灰浮感轻度缓解，仍建议下一包继续专项打磨

说明：
- 本包已将结论从“策略存在”推进到“目标样本局部改善开始可见”。
- 但提升幅度仍属保守级，尚未达到“明显分布跃迁”。

## 5. 本包刻意没做（边界）

1. 未接入新分割主干（U²-Net / BiRefNet / 其他）
2. 未做去污染大改
3. 未做合成重写
4. 未改主处理顺序
5. 未扩样本池（仍使用 `core_v1`）

## 6. 下一包建议（低风险）

建议第 5 包进入“去污染/合成衔接收口”小包，但继续沿用 `whitebg-vision-core-v1` 做同样本对照，优先针对：

1. 贴地边缘灰浮残留
2. 近白主体立体感稳定性
3. 透明边缘污染的末端抑制

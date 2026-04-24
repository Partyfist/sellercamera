# Seller Camera 新主干准入最小实验（R01）

## 1) 实验目标与边界
- 本轮目标：按 `admission_v1` 做“单候选主干最小准入实验”，判断是否值得进入下一轮。
- 候选主干：`vision_attention_saliency`（`VNGenerateAttentionBasedSaliencyImageRequest`）。
- 改动边界：仅通过 `SegmentationProvider` 切换分割来源；Vision 默认路径保留；未改白底主流程顺序，未联动改 refinement/去污染/合成。

### 1.1 为什么先选 `vision_attention_saliency`
1. 接入成本最低：同属 Vision 栈，能在现有 `SegmentationProvider` 边界内做最小替换，不引入新模型资产管理与推理运行时依赖。  
2. 变量最可控：与现有 Vision 基线路径同平台，便于先验证 admission 流程和硬门槛判断是否可执行。  
3. 风险最小：即使实验失败，也不会影响默认 Vision 主链和既有 baseline 资产。

## 2) 运行环境与样本
- suite：`whitebg-backbone-admission-v1`
- 样本覆盖：`26/26`
- 环境：`iPhone Simulator (arm64), iOS 26.4.1, app 1.0(1)`

## 3) 记录资产
- 候选主干记录：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260420-admission-v1-r01-attention.jsonl`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260420-admission-v1-r01-attention.txt`
- Vision 对照记录（同 suite、同环境）：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260420-admission-v1-r01-vision.jsonl`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260420-admission-v1-r01-vision.txt`

## 4) 首轮结果
### 4.1 候选主干（attention saliency）
- `failed=26/26`
- 失败共性：`NSOSStatusErrorDomain`, code `-1`
- 失败描述：`Failed to create espresso context.`

### 4.2 Vision 对照（同环境）
- `failed=26/26`
- 失败共性：`com.apple.Vision`, code `9`
- 失败描述：`Could not create inference context`

## 5) admission_v1 准入判断（R01）
- 硬门槛：未触达（`EV006` 仍失败，且全样本无有效产出）。
- 稳定样本旁证：无法判断（无可用输出结果）。
- 红线判断：当前不属于“模型回退导致红线触发”，而是“运行环境推理上下文不可用”导致整轮失效。

## 6) 结论
1. 本轮 **不能** 对候选主干做“继续/停止”的能力结论；当前结论仅为“模拟器环境下 admission 实验不可判定”。  
2. 候选路径与 Vision 对照路径在同环境均全量失败，说明本轮阻塞优先级是**运行环境推理能力不可用**，不是 admission 资产或样本组织问题。  
3. 本轮状态定义为：`Blocked (runtime inference context unavailable)`。

## 7) 下一步最小动作（不扩包）
1. 在可用真机环境（建议沿用历史基线设备族）复跑 `whitebg-backbone-admission-v1`。  
2. 先跑 Vision 对照确认环境可产出，再跑候选主干；两轮都保留 JSONL + check 结果。  
3. 仅在“可产出”前提下，再按 `new_backbone_admission_prep_v1.md` 的硬门槛/红线做首轮准入判断。  

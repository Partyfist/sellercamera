# Seller Camera BiRefNet 候选入场审查与最小接入 R01

## 1) 本轮目标与范围
- 目标：按 `new_backbone_candidate_prep_v1.md` 对 `BiRefNet` 执行正式入场审查；仅在审查通过时进入最小接入与 `admission_v1` 首轮实验。
- 边界：不并行接第二候选，不改白底主流程，不联动改 refinement / 去污染 / 合成。

## 2) 入场审查结论
### 2.1 候选
- 候选 ID：`birefnet`
- 轨道标识（预留）：`admission_candidate_birefnet_v1`

### 2.2 审查结果
**未通过（stop_current_candidate）**

### 2.3 审查项逐条结论
1. 问题命中价值：**通过（理论层）**  
   BiRefNet 作为高质量 DIS 主干，理论上对复杂背景、同色前后景与跨域边界问题有命中潜力。
2. 最小接入可行：**不通过（工程层）**  
   当前仓库未提供任何 BiRefNet 可运行模型资产（`.mlmodel/.mlpackage/.mlmodelc/.onnx` 均未发现）。
3. 移动端实验可行：**不通过（运行层）**  
   当前无 iOS 推理包装、无输入输出桥接实现、无真机推理基线，无法形成可复核的最小实验路径。
4. 失败可回退：**不适用（本轮未接入）**  
   因审查未通过，本轮未进入接入阶段，自然无回退污染。

## 3) 为什么本轮不进入最小接入
1. 本轮被阻塞在“候选入场审查”阶段，未满足进入接入动作的前提条件。  
2. 强行接入会越过 `new_backbone_candidate_prep_v1.md` 的入场纪律，违背“先审查再接入”。  
3. 在缺少模型与桥接的前提下进入接入，只会产生不可复核结果，不具备 admission 价值。

## 4) admission_v1 首轮实验执行情况
- `sample_manifest.backbone_admission_v1.json`：**未执行**  
- Vision / candidate 对照 JSONL：**无新增运行资产**  
- check 输出：**无新增检查文件**  
- 原因：入场审查未通过，按纪律停止后续实验。

## 5) 首轮阶段结论（三选一）
**停止当前候选（stop_current_candidate）**

理由：
1. 本轮结论来源于“入场审查不通过”，不是运行后淘汰。  
2. 该停止结论仅针对当前仓库条件与当前轮次，不外推到 BiRefNet 在其他工程条件下的潜在效果。  
3. admission 纪律保持有效：未通过入场标准的候选不进入接入与跑测阶段。

## 6) 本轮产出
- 审查结构化记录：`WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r01.birefnet.audit.json`
- 本报告：`WhiteBackgroundBaseline/new_backbone_candidate_experiment_birefnet_r01.md`

## 7) 下一步建议（仅相邻最小增量）
如果后续仍希望评估 BiRefNet，应先进入“候选实验可行化准备”小包，目标仅限：
1. 明确可在 iOS 侧运行的 BiRefNet 模型资产形式；  
2. 明确最小推理桥接接口并验证可回退；  
3. 在不改主链前提下达到“可执行 admission_v1 首轮实验”的入场条件。  
未完成以上前置前，不建议重复开启 BiRefNet admission R01 实验包。

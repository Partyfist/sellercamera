# Seller Camera 新主干准入第二轮评估（R02）

## 1) 第二轮评估必要性
首轮最小准入实验（R01）在模拟器环境被推理上下文阻塞，无法形成候选主干能力判断；随后真机补跑显示 attention 候选已具备继续价值，但首轮“继续”仅说明硬门槛被触达，不等于可以直接扩大范围或切主链。  
因此本轮目标是：在不扩接入边界的前提下，补齐 admission_v1 的更完整人工对照，明确收益结构、稳定样本风险与继续/停止结论。

## 2) 实验边界（保持不变）
- 仅评估一个候选主干：`vision_attention_saliency`
- 仅在 `SegmentationProvider` 边界内替换分割来源
- Vision 默认路径保留且可回退
- 未改 segmentation/refine/decontam/compose/fidelity/quality 主顺序
- 未引入第二候选主干

## 3) 运行环境与记录
- suite: `whitebg-backbone-admission-v1`
- 设备: `iPhone15,3`
- iOS: `18.7.7`
- Vision 对照记录：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260421-admission-v1-r02-vision-device.jsonl`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260421-admission-v1-r02-vision-device.txt`
- attention 候选记录：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260421-admission-v1-r02-attention-device.jsonl`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260421-admission-v1-r02-attention-device.txt`
- 二轮人工判读：
  - `WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r02.device.json`

## 4) admission_v1 二轮结果（更完整判断）

### 4.1 样本覆盖
- Vision: `26/26`
- attention: `26/26`

### 4.2 质量分布
- Vision: `ready=25, failed=1`
- attention: `ready=26, failed=0`

### 4.3 三层样本分布对照
- `hard_gate`
  - Vision: `ready=7, failed=1`
  - attention: `ready=8, failed=0`
- `focus_comparison`
  - Vision: `10/10 ready`
  - attention: `10/10 ready`
- `stability_witness`
  - Vision: `8/8 ready`
  - attention: `8/8 ready`

## 5) 收益结构（R02）

### 5.1 已确认收益
1. **硬门槛 EV006 被实质触达**：`EV006_beaded_string_on_texture` 从 Vision 的 `failed` 转为 attention 的 `ready`。  
2. **硬门槛层完整通过**：attention 在 8 个 hard_gate 样本全部 `ready`。

### 5.2 有改善但仍有限
1. `focus_comparison` 层目前体现为“未回退 + 全部可产出”，但本轮证据主要是 quality-level 稳态，尚不能证明每个重点问题都出现了足够强的像素级收益。  
2. 复杂背景/跨域样本的细粒度边缘收益仍需下一轮受控扩大范围来确认稳定性。

### 5.3 尚未证明有价值
1. 尚未在更大范围（expanded 受控子集）证明 attention 对所有复杂场景都优于 Vision。  
2. 尚未形成可支持“主链切换”的充分证据。

### 5.4 风险观察项
1. `stability_witness` 当前未触发 ready->review 回退，但仍需在下一轮扩大样本时继续观察轻微灰边/发雾/透明边实化风险。  
2. 本轮未新增像素级导出对照资产，后续扩大实验必须继续做人工复核闭环。

## 6) 稳定样本旁证与红线核查
- 当前结论：**未触发 admission 红线**
  - 未出现稳定样本批量回退
  - 未出现新增不可接受失败
  - 未出现“难例提升但稳定样本明显恶化”信号

## 7) 第二轮准入结论
### 结论
**继续停留在 admission_v1 再补一轮（不是切主链，也不是直接扩大范围）。**

### 理由
1. 硬门槛核心样本 EV006 已被实质触达。  
2. hard_gate/focus/stability 三层在本轮均未出现回退红线。  
3. 但除 EV006 外，hard_gate 其余样本当前主要体现为“未恶化”，尚缺“至少 4/8 硬门槛样本主问题可复核改善”的充分证据（按 `new_backbone_admission_prep_v1.md` 准入口径）。  

### 边界
1. 本结论仅代表“候选主干值得继续，但证据还不足以扩大范围”。  
2. 当前不建议直接推进到 `expanded_v1` 子集验证，更不建议进入主链切换判断。

## 8) 下一步最小建议（供下一包直接复用）
1. 保持单候选（attention）不变。  
2. 在 admission_v1 内补一轮“硬门槛主问题人工复核强化”（优先 hard_gate 8 张，不扩样本机制）。  
3. 若下一轮达到“4/8 硬门槛样本主问题可复核改善”且稳定层无红线，再进入更大范围受控实验。  

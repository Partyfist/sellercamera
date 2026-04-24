# Seller Camera 新候选准入第二轮评估（R02, foreground_objectness_hybrid）

## 1) 为什么第二轮是必要的
`foreground_objectness_hybrid` 的 R01 已经成立两件事：  
1) 入场审查通过，且最小接入边界可控；  
2) admission_v1 上 EV006 从 `failed -> ready`。  

但 R01 仍不充分：除 EV006 外，其余 hard_gate 主要是“ready parity”，不足以支撑“升级到更大范围受控实验”。因此本轮目标是：在不扩边界前提下，把 hard_gate 主问题证据强度补到可决策水平。

## 2) 本轮边界（保持不扩散）
- 仅评估一个候选：`vision_foreground_objectness_hybrid`
- 仅使用 `sample_manifest.backbone_admission_v1.json`
- 仅复用既有 R01 真机记录，不新增更大样本实验
- 不改白底主流程，不联动改 refinement / 去污染 / 合成
- Vision 默认路径继续保留、可回退

## 3) 运行资产与对照来源
- Vision 对照记录：  
  `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260421-admission-v1-r01-foreground-objectness-hybrid-vision-device.jsonl`
- hybrid 候选记录：  
  `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260421-admission-v1-r01-foreground-objectness-hybrid-candidate-device.jsonl`
- 对应 check：  
  `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260421-admission-v1-r01-foreground-objectness-hybrid-vision-device.txt`  
  `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260421-admission-v1-r01-foreground-objectness-hybrid-candidate-device.txt`
- 第二轮人工复核：  
  `WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r02.foreground_objectness_hybrid.hard_gate.json`

## 4) admission_v1 二轮结果摘要（hybrid）

### 4.1 覆盖与质量分布
- Vision：`26/26`，`ready=25, failed=1`
- hybrid：`26/26`，`ready=26, failed=0`

### 4.2 三层分布
- `hard_gate`：Vision `7 ready + 1 failed`；hybrid `8 ready + 0 failed`
- `focus_comparison`：Vision `10/10 ready`；hybrid `10/10 ready`
- `stability_witness`：Vision `8/8 ready`；hybrid `8/8 ready`

## 5) hard_gate 问题级复核（核心）

### 5.1 已确认收益
- `EV006_beaded_string_on_texture`：**clear_improved**  
  Vision 失败（subjectMaskUnavailable）在 hybrid 下转为 `ready`，硬门槛触达成立。

### 5.2 有改善但仍有限
- 当前未形成可复核的 `changed_but_insufficient` 样本。  
  除 EV006 外，hard_gate 其余样本在质量层与 coverage_ratio 上均呈 parity。

### 5.3 尚未证明有价值
- `EV013_full_body_person_gray_bg`
- `EV021_hand_with_beads`
- `EV028_flower_vase_garden_bg`
- `EV033_blue_vase_blue_curtain`
- `EV038_dark_shoes_shelf_plants`
- `EV042_cakes_in_booth_scene`
- `EV044_person_outdoor_complex`

这些样本当前主要结论为：`not_proven`（未观察到可复核主问题改善证据）。

## 6) 收益结构与稳定样本风险

### 6.1 收益结构
- **已确认收益**：EV006 硬门槛失败转可产出（`1/8 clear`）。
- **有改善但仍有限**：当前未形成可复核 `changed_but_insufficient` 样本。
- **尚未证明收益**：同色分离、复杂背景纹理残留、跨域边界、多主体聚焦等阻塞位仍无主问题级证据。

### 6.2 稳定样本风险
- `stability_witness` 维持 `8/8 ready`，未触发红线（无 `ready->review`）。
- 当前判定：`no_abnormal_signal`（未观测到可确认的轻微回退信号）。

## 7) 第二轮准入判断（三选一）
结论：**继续停留在 admission_v1**

理由：
1. hybrid 仍有价值（EV006 clear hit）；  
2. hard_gate 主问题明确改善仍为 `1/8`，未达到 `new_backbone_admission_prep_v1.md` 的 `>=4/8` 升级门槛；  
3. 稳定层未触发红线，不支持“停止”；但证据强度也不足以“扩大范围”。

## 8) 当前边界与下一步
- 本结论仅在 `admission_v1` 范围内成立，不外推到 expanded 全量。  
- 本轮不支持升级范围，也不支持切主链。  
- 下一包若继续，应只做 admission_v1 内 hard_gate 关键阻塞位证据强化，不扩样本机制。

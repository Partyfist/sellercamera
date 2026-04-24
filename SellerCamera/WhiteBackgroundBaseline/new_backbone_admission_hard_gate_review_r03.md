# Seller Camera hard_gate 主问题强化人工复核（R03）

## 1) 任务范围与边界
- 仅针对 `admission_v1` 的 `hard_gate` 样本做问题级人工复核。
- 对照范围仅使用：
  - Vision r02: `baseline-20260421-admission-v1-r02-vision-device.jsonl`
  - attention r02: `baseline-20260421-admission-v1-r02-attention-device.jsonl`
- 本轮不扩样本、不改接入边界、不改白底主流程。

## 2) hard_gate 样本与主问题
| sample_id | 主问题（1-2项） | 为什么是硬门槛 |
|---|---|---|
| EV006_beaded_string_on_texture | `subject_mask_unavailable`、细结构丢失 | 当前链路真实失败样本，必须先从失败变可产出 |
| EV013_full_body_person_gray_bg | 跨域主体边界、背景残留 | 复杂语义场景稳定性与误分离风险 |
| EV021_hand_with_beads | 细珠串细结构、跨域复杂度 | 细结构 + 人体复合场景，易暴露分割边界 |
| EV028_flower_vase_garden_bg | 复杂背景残留、自然背景分离 | 复杂背景下主体边界稳定性 |
| EV033_blue_vase_blue_curtain | 同色前后景分离、边缘污染 | 同色分离是主干能力敏感点 |
| EV038_dark_shoes_shelf_plants | 背景残留、灰边 | 深色主体叠加复杂背景的边缘污染风险 |
| EV042_cakes_in_booth_scene | 多主体聚焦、接地边缘 | 多主体复杂场景下主体聚焦稳定性 |
| EV044_person_outdoor_complex | 跨域前后景分离、背景残留 | 户外跨域高复杂样本，风险放大项 |

## 3) Vision vs attention 问题级对照（R03）

### 3.1 已明确改善
- `EV006_beaded_string_on_texture`
  - Vision r02：`failed`
  - attention r02：`ready`
  - 判断：主问题被明确触达（从 pipeline fail 到可产出）。

### 3.2 有变化但证据仍不足
- `EV013_full_body_person_gray_bg`
- `EV021_hand_with_beads`
- `EV042_cakes_in_booth_scene`
  - 共同特征：quality level 维持 ready 且未回退，但尚无足够证据证明“主问题已明确改善”。

### 3.3 尚未证明改善
- `EV028_flower_vase_garden_bg`
- `EV033_blue_vase_blue_curtain`
- `EV038_dark_shoes_shelf_plants`
- `EV044_person_outdoor_complex`
  - 共同特征：当前证据主要是“未恶化”，不足以证明主问题改善。

## 4) 三档分层结果
- 已明确改善：`1/8`
- 有变化但证据不足：`3/8`
- 尚未证明改善：`4/8`

## 5) 升级门槛判断
- 结论：**当前 hard_gate 整体仍未达到升级范围门槛**。
- 理由：
  1. EV006 明确改善成立（关键正向证据）。
  2. 但除 EV006 外，hard_gate 主问题改善证据仍不足，整体仍以“未回退”证据为主。
  3. 现阶段直接扩大范围，判断风险高于收益确定性。

## 6) 三选一主结论
- 主结论：**继续停留在 admission_v1**。
- 不是“扩大到更大范围受控实验”，也不是“停止候选主干”。
- 解释：
  - 有明确正向信号（EV006）=> 不应停止；
  - 但 hard_gate 整体主问题证据不足 => 暂不升级范围。

## 7) 下一步最小建议（相邻包）
1. 继续在 admission_v1 内补一轮 hard_gate 主问题复核（不扩样本机制）。  
2. 仅当 hard_gate 明确改善样本数显著增加且稳定旁证仍无红线，再进入更大范围受控实验。  

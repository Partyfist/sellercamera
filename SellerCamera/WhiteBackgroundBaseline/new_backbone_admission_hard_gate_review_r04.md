# Seller Camera hard_gate 主问题复核强化（R04）

## 1) 本轮目标与边界
- 目标：只补 `hard_gate` 中“证据不足/尚未证明改善”样本的主问题证据强度。
- 对照资产：
  - Vision r02：`WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260421-admission-v1-r02-vision-device.jsonl`
  - attention r02：`WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260421-admission-v1-r02-attention-device.jsonl`
- 边界：不扩样本、不改接入边界、不改白底主流程。

## 2) 本轮主攻样本（只聚焦证据不足样本）
### 主攻样本
- `EV028_flower_vase_garden_bg`
- `EV033_blue_vase_blue_curtain`
- `EV038_dark_shoes_shelf_plants`
- `EV042_cakes_in_booth_scene`
- `EV044_person_outdoor_complex`

### 参考样本
- `EV013_full_body_person_gray_bg`
- `EV021_hand_with_beads`
- `EV006_beaded_string_on_texture`（已明确改善锚点，不重复作为主攻）

## 3) 主问题压细（问题级）
- `EV028`: 茎叶外轮廓与园景纹理混叠；花瓶外缘自然背景残留。
- `EV033`: 花瓶肩线与蓝幕同色分离不足；幕布纹理向主体边缘渗出。
- `EV038`: 深色鞋体外缘与货架/植物杂背景交界不稳；鞋跟/鞋带周边灰边风险。
- `EV042`: 多主体聚焦一致性不足；盘边接触线污染收口证据弱。
- `EV044`: 人体轮廓与树枝背景交界分离不足；跨域背景残留风险持续。

## 4) Vision vs attention 问题级对照结论（R04）
### 已明确改善（1/8）
- `EV006_beaded_string_on_texture`
  - 由 Vision `failed` 转为 attention `ready`，硬门槛实质触达成立。

### 有变化但证据仍不足（3/8）
- `EV013_full_body_person_gray_bg`
- `EV021_hand_with_beads`
- `EV042_cakes_in_booth_scene`
  - 共同结论：存在“无回退/局部变化”信号，但主问题改善证据未达可升级强度。

### 尚未证明改善（4/8）
- `EV028_flower_vase_garden_bg`
- `EV033_blue_vase_blue_curtain`
- `EV038_dark_shoes_shelf_plants`
- `EV044_person_outdoor_complex`
  - 共同结论：当前仍以“未恶化”证据为主，无法证明主问题已被明确改善。

## 5) 三档分层更新（相对 R03）
- 已明确改善：`1/8`
- 有变化但证据不足：`3/8`
- 尚未证明改善：`4/8`
- 与 R03 对比：**样本档位无变化**  
  本轮主要增量是把主问题定义压细并锁定阻塞点，而非形成新档位跃迁。

## 6) 升级门槛判断
- 结论：**当前仍未达到升级范围门槛**。
- 依据：
  1. 升级参考门槛（内部口径）要求 hard_gate 出现更广泛、可复核的主问题改善（至少达到 `4/8 clear_improved` 的量级）。
  2. 当前仅 `EV006` 满足“已明确改善”，其余样本以证据不足/未证明改善为主。

## 7) 三选一主结论
- **继续停留在 admission_v1**（主结论）
- 不扩大到更大范围受控实验（当前证据不足）
- 不停止当前候选主干（EV006 的明确改善仍构成继续观察价值）

## 8) 下一步最小建议（相邻包）
1. 继续保持单候选与同一 admission_v1 边界。  
2. 仅对本轮 5 个主攻样本补“主问题可复核证据”而非扩样本。  
3. 只有在 hard_gate 出现实质档位提升后，再讨论是否升级范围。  

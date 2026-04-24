# Seller Camera hard_gate 终局判断（R06）

## 1) 本轮定位（终局判断，不再扩评估）
- 目标：在 admission_v1 内给出 hard_gate 升级门槛终局结论。
- 边界：不扩样本、不改代码边界、不引入第二候选主干。
- 依据：r03/r04/r05 结构化人工复核 + r02 真机 Vision/attention 对照资产。

## 2) 终局阻塞样本最小集合（3）
- `EV033_blue_vase_blue_curtain`：同色前后景分离
- `EV038_dark_shoes_shelf_plants`：复杂背景纹理残留
- `EV044_person_outdoor_complex`：跨域主体边界稳定性

保留这 3 个样本的原因：它们是当前是否升级范围的决定性阻塞位；其余样本要么已明确改善（EV006），要么属于次级阻塞位（changed_but_insufficient 但非最强门槛卡点）。

## 3) 终局问题级判断（Vision vs attention）
- `EV033`：**not_proven**
  - attention 有分割几何变化，但同色交界主问题没有形成可复核明确改善证据。
- `EV038`：**not_proven**
  - attention 未触发回退，但复杂纹理背景残留主问题仍缺明确改善证据。
- `EV044`：**not_proven**
  - attention 在跨域人物边界上仍未形成主问题级可复核改善。

## 4) 最终分档（hard_gate 全体）
- `clear_improved`: `1/8`（EV006）
- `changed_but_insufficient`: `3/8`
- `not_proven`: `4/8`

相对 r05：**无档位变化**。

## 5) hard_gate 门槛终局判断
- 结论：**未达到升级范围门槛**。
- 核心原因：终局最小阻塞集合 3/3 仍为 `not_proven`，且 r03-r05 持续未出现关键档位跃迁。

## 6) 三选一终局结论
- **暂停当前候选主干**（attention）。

理由（简版）：
1. 已确认价值主要集中在 EV006 单点硬触达，无法支撑整体升级。  
2. 终局阻塞样本未被实质触动，继续停留 admission_v1 的边际收益已不足。  
3. 暂停比“继续循环证据补强”更符合当前低风险决策纪律。  

> 注：暂停不等于否定既有实验资产；仅表示当前候选在 admission_v1 阶段的迭代到此收口，后续应在新候选或新证据前提下再重启。

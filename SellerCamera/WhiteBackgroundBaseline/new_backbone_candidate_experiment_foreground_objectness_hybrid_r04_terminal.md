# Seller Camera foreground_objectness_hybrid 候选终局判断（R04）

## 1) 本轮定位（终局收口，不再同类循环）
- 目标：基于 admission_v1 既有资产给出 foreground_objectness_hybrid 当前阶段三选一正式结论。
- 边界：不新增运行轮次、不扩样本、不改代码边界、不引入第二候选。

## 2) 终局阻塞样本最小集合（3）
- `EV033_blue_vase_blue_curtain`：同色前后景分离
- `EV038_dark_shoes_shelf_plants`：复杂背景纹理残留
- `EV044_person_outdoor_complex`：跨域主体边界稳定性

保留原因：这 3 个样本直接决定“是否可升级范围”；其余样本要么已 clear（EV006），要么在终局阶段非最强阻塞位。

## 3) 每样本唯一关键问题终局判断
- `EV033`：**not_proven**
  - 同色交界分离未形成可复核改善证据（quality/hard_case/coverage 均 parity）。
- `EV038`：**not_proven**
  - 复杂纹理背景残留主问题未形成可复核改善证据。
- `EV044`：**not_proven**
  - 跨域人物边界稳定性无有效变化信号。

## 4) hard_gate 终局门槛判断
- 当前是否达到升级门槛：**否**（`hard_gate_threshold_met=false`）。
- 核心阻塞：终局最小集合 3/3 均未证明改善，关键阻塞位没有档位跃迁。

## 5) 最终三选一结论
- **暂停 foreground_objectness_hybrid 候选**。

理由（硬结论）：
1. 关键阻塞位证据强度不足，无法支持升级范围；  
2. 继续停留 admission_v1 的同类证据循环边际收益已低；  
3. stability 未触发红线，说明当前结论是“暂停当前候选”，不是否定 admission 体系。  

## 6) 下一步建议（最小）
- 进入“下一候选最小准入实验包”，复用现有 admission 纪律，不再继续 foreground_objectness_hybrid 的同类型证据补强循环。

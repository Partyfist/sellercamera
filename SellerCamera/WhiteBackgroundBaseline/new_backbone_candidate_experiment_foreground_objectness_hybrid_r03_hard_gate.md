# Seller Camera foreground_objectness_hybrid 候选 hard_gate 关键阻塞位证据强化（R03）

## 1) 本轮定位（更小、更聚焦）
- 目标：只补 foreground_objectness_hybrid 在 admission_v1 的关键 hard_gate 阻塞位证据强度，不做泛评估。
- 边界：不扩样本、不加候选、不改主链、不新增运行轮次。
- 依据：R01 真机运行记录 + R02 结构化 hard_gate 复核。

## 2) 本轮主攻样本（4）
1. `EV033_blue_vase_blue_curtain`（同色前后景分离）
2. `EV038_dark_shoes_shelf_plants`（复杂背景纹理残留）
3. `EV042_cakes_in_booth_scene`（多主体聚焦与接触边一致性）
4. `EV044_person_outdoor_complex`（跨域主体边界稳定性）

选择原因：这 4 个样本覆盖当前升级门槛最关键阻塞位；其余 hard_gate 样本本轮不再平均用力。

## 3) 每样本唯一关键主问题与证据结论

### EV033（同色前后景）
- 唯一关键主问题：花瓶肩线与蓝幕同色交界是否形成可复核分离收益。
- 结论：`not_proven`
- 证据要点：quality/hard_case parity；coverage `0.3843 -> 0.3843`（`+0.0000`）。

### EV038（复杂纹理背景）
- 唯一关键主问题：深色鞋体外缘在杂乱背景纹理中的残留是否明显减少。
- 结论：`not_proven`
- 证据要点：quality/hard_case parity；coverage `0.4510 -> 0.4510`（`+0.0000`）。

### EV042（多主体场景）
- 唯一关键主问题：主主体聚焦是否更一致，接触边是否更稳定。
- 结论：`not_proven`
- 证据要点：quality/hard_case parity；coverage `0.3216 -> 0.3216`（`+0.0000`）。

### EV044（跨域边界）
- 唯一关键主问题：人物外轮廓与树枝背景交界稳定性是否明显增强。
- 结论：`not_proven`
- 证据要点：quality/hard_case parity；coverage `0.3216 -> 0.3216`（`+0.0000`）。

## 4) 档位变化（vs R02）
- `clear_improved`：无新增（仍仅 EV006）
- `changed_but_insufficient`：无新增
- `not_proven`：EV033 / EV038 / EV042 / EV044 维持不变
- 本轮结论：**关键阻塞样本无档位升级**

## 5) 升级门槛判断
- 当前是否达到升级门槛：**否**
- 核心缺口：关键阻塞位仍无 clear 级主问题证据，hard_gate 改善仍集中在 EV006 单点。

## 6) 三选一结论
- 结论：**继续停留在 admission_v1**
- 理由：
  1. hybrid 仍有价值（EV006 clear hit 持续成立）；  
  2. 关键阻塞位无档位升级，不支持扩大范围；  
  3. 稳定层未触发红线，不支持停止候选。  

## 7) 下一步最小建议
- 进入终局判断包：基于现有 R01/R02/R03 资产做路线收口三选一，不再继续同类型证据补强循环。

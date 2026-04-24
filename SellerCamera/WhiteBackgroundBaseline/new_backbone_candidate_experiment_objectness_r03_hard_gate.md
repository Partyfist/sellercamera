# Seller Camera objectness 候选 hard_gate 关键阻塞位证据强化（R03）

## 1) 本轮定位（更小、更聚焦）
- 目标：只补 objectness 在 admission_v1 的关键 hard_gate 阻塞位证据强度，不做泛评估。
- 边界：不扩样本、不加候选、不改主链、不新增运行轮次。
- 依据：R01 真机运行记录 + R02 结构化 hard_gate 复核。

## 2) 本轮主攻样本（4）
1. `EV033_blue_vase_blue_curtain`（同色前后景分离）
2. `EV038_dark_shoes_shelf_plants`（复杂背景纹理残留）
3. `EV042_cakes_in_booth_scene`（多主体聚焦与接触边一致性）
4. `EV044_person_outdoor_complex`（跨域主体边界稳定性）

选择原因：这 4 个样本覆盖了当前是否可升级范围的最核心阻塞位；其余 hard_gate 样本在本轮不再平均用力。

## 3) 每样本唯一关键主问题与证据结论

### EV033（同色前后景）
- 唯一关键主问题：花瓶肩线与蓝幕同色交界是否形成可复核分离收益。
- 结论：`changed_but_insufficient`
- 证据要点：quality/hard_case 维持 parity；coverage 有变化（`+0.0588`），但不足以确认主问题已明确改善。

### EV038（复杂纹理背景）
- 唯一关键主问题：深色鞋体外缘在杂乱背景纹理中的残留是否明显减少。
- 结论：`changed_but_insufficient`
- 证据要点：quality/hard_case 维持 parity；coverage 有变化（`+0.0549`），但主问题仍缺 clear 证据。

### EV042（多主体场景）
- 唯一关键主问题：主主体聚焦是否更一致，接触边是否更稳定。
- 结论：`changed_but_insufficient`
- 证据要点：coverage 变化较大（`+0.1725`），但目前仍不足以把多主体主问题升级到 clear。

### EV044（跨域边界）
- 唯一关键主问题：人物外轮廓与树枝背景交界稳定性是否明显增强。
- 结论：`not_proven`
- 证据要点：coverage 基本无变化（`-0.0040`），当前仍无主问题收益证据。

## 4) 档位变化（vs R02）
- `clear_improved`：无新增
- `changed_but_insufficient`：EV033 / EV038 / EV042 维持不变
- `not_proven`：EV044 维持不变
- 本轮结论：**关键阻塞位无档位升级**

## 5) 升级门槛判断
- 当前是否达到升级门槛：**否**
- 核心缺口：关键阻塞位仍缺 clear 级主问题证据，hard_gate 改善仍主要集中在 EV006 单点。

## 6) 三选一结论
- 结论：**继续停留在 admission_v1**
- 理由：
  1. objectness 仍有价值（EV006 clear hit 持续成立）；  
  2. 关键阻塞位无档位升级，不支持扩大范围；  
  3. 稳定层未触发红线，不支持停止候选。  

## 7) 下一步最小建议
- 仅在 admission_v1 内继续做一轮“关键阻塞位主问题证据补强或终局判断收口”二选一，不建议直接扩到 expanded 子集。

# Seller Camera BiRefNet tiny admission 终局判断（R21）

## 1) 当前候选身份与终局判断口径

本轮评估对象仍是：**`BiRefNet-general-bb_swin_v1_tiny-epoch_232`**。  
本轮定位是：**admission 阶段终局收口判断**，不是 expanded，不是第三轮全量大包，也不是主链替换结论。

为什么进入终局判断：
1. R19 已完成有效首轮并给出 `continue_to_admission_round2_review`；  
2. R20 已将 hard_gate review 收敛到关键阻塞位，并完成问题级重判；  
3. 当前 admission 决策信息已集中到最小阻塞集合，继续同类型循环复核边际收益低。

与 RMBG-2 的关系：
1. tiny 仍是商业可控替代路线候选；  
2. 本轮结论不等同于“已可替代 RMBG-2”。

---

## 2) 终局样本最小集合（2+1）

主阻塞位：
1. `EV033_blue_vase_blue_curtain`
2. `EV044_person_outdoor_complex`

门槛锚点：
1. `EV006_beaded_string_on_texture`

仅盯这 2+1 的原因：
1. `EV033/EV044` 是 R20 中仍为 `not_proven` 的决定性阻塞位；  
2. `EV006` 保留为薄细结构门槛锚点，用于判断候选是否仍具局部正向价值；  
3. 其他样本在当前终局阶段不再决定三选一主结论。

---

## 3) 每样本唯一关键主问题

### EV033_blue_vase_blue_curtain
- 唯一关键主问题：**蓝瓶与蓝幕同色交界分离是否形成可确认改善。**
- 终局关键性：同色前后景分离是 hard_gate 最核心阻塞之一，若仍未证明则难支撑升级。

### EV044_person_outdoor_complex
- 唯一关键主问题：**人物外轮廓与户外枝叶跨域交界分离稳定性是否形成可确认改善。**
- 终局关键性：跨域复杂边界是 admission 是否继续推进的重要门槛位。

### EV006_beaded_string_on_texture
- 唯一关键主问题：**细珠串连续细结构在纹理背景中的边缘完整性是否达到可放行级。**
- 终局关键性：该样本是 thin-detail 门槛锚点，用于确认候选是否仍具可保留价值。

---

## 4) 终局问题级判断（基于现有证据链）

证据来源：
1. R19 有效首轮重跑记录/check；  
2. R20 第二轮 hard_gate 问题级复核（不新增运行轮次）。

### EV033
- 当前状态：`quality=review`, `hard_case_signal=softEdge`。  
- 终局判断：**未出现足够明确改善证据**。  
- 结论：`not_proven`。

### EV044
- 当前状态：`quality=review`, `hard_case_signal=thinDetailEdge`。  
- 终局判断：**未出现足够明确改善证据**。  
- 结论：`not_proven`。

### EV006（锚点）
- 当前状态：`quality=review`, `hard_case_signal=thinDetailEdge`，已稳定可消费/可记录。  
- 终局判断：**锚点价值成立但未升档到 clear 级**。  
- 结论：`changed_but_insufficient`。

阻塞位收敛判断：
1. 剩余阻塞确已收敛到 `EV033/EV044`；  
2. 但两者均未形成可升级所需的问题级明确改善证据；  
3. 当前不满足“升级到下一范围/下一阶段”的门槛。

---

## 5) 终局分层结果（2+1）

1. `clear_improved`: `0/3`  
2. `changed_but_insufficient`: `1/3`（`EV006`）  
3. `not_proven`: `2/3`（`EV033 / EV044`）

解释：
1. 主阻塞位 2/2 仍 `not_proven`；  
2. 锚点样本仍是“有变化但不足”而非“明确改善”。

---

## 6) 终局门槛判断与最终三选一结论

### 门槛判断
1. **不满足升级到下一范围/下一阶段条件**（主阻塞位未证明）。  
2. **不建议继续停留当前 admission 循环**（同类型复核继续下去边际收益低、已进入长尾）。

### 最终三选一
**结论：暂停当前候选（pause_current_candidate）。**

理由：
1. 终局最小阻塞集合中 `EV033/EV044` 仍为 `not_proven`，未形成升级证据；  
2. `EV006` 仅能作为锚点保留，尚不足以反转终局判断；  
3. 继续在当前 admission 体系内同路径复核，已进入低收益循环，不符合收口目标。

边界声明：
1. “暂停”仅针对当前 admission 阶段，不等于永久否定 tiny 路线；  
2. 不代表主链替换结论；  
3. 不代表 tiny 可替代 RMBG-2。

---

## 7) 下一包建议（最小相邻增量）

建议下一包：**tiny 暂停后重启前提定义包（非 admission）**
1. 明确重启 tiny admission 的硬前提（必须触发的新增证据类型）；  
2. 若无新增证据来源，则保持暂停，不再循环同类复核。

不应进入：
1. expanded 扩范围实验；  
2. 主链替换讨论；  
3. 下游联动改造。


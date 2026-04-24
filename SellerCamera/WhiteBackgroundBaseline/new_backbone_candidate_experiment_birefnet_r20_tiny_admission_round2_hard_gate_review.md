# Seller Camera BiRefNet tiny admission 第二轮 hard_gate 关键阻塞位复核（R20）

## 1) 当前候选与第二轮复核口径

本轮评估对象仍是：**`BiRefNet-general-bb_swin_v1_tiny-epoch_232`**。  
本轮定位是：**admission 第二轮、仅 hard_gate 关键阻塞位复核**，不是 expanded，不是第二轮全量大包，也不是主链替换结论。

与 RMBG-2 的关系说明：
1. tiny 仍是“商业可控替代路线候选”；
2. 本轮结论不等同于“已可替代 RMBG-2”；
3. 本轮只判断 tiny 是否还值得继续停留在 admission 体系内。

---

## 2) 本轮范围与不做项

本轮只做：
1. 锁定并复核 R19 仍为 review 的 5 个 hard_gate 样本；  
2. 每样本压缩为 1 个唯一关键主问题；  
3. 给出问题级证据复核与分层重判；  
4. 输出继续/停止二选一结论。

本轮刻意不做：
1. expanded 子集实验；  
2. focus/stability 全量复跑；  
3. 白底主流程与下游链路改造。

---

## 3) 本轮主攻样本（固定 5 个）

仅复核：
1. `EV006_beaded_string_on_texture`
2. `EV021_hand_with_beads`
3. `EV028_flower_vase_garden_bg`
4. `EV033_blue_vase_blue_curtain`
5. `EV044_person_outdoor_complex`

只盯这 5 个的原因：
1. 它们是 R19 hard_gate 中剩余 `review` 的全部阻塞位；  
2. 继续/停止判断的边际信息主要来自这 5 个样本是否还能提供“可继续复核价值”；  
3. 扩到其他层会稀释第二轮 hard_gate 复核目标。

---

## 4) 每样本唯一关键主问题 + 问题级证据复核

### EV006_beaded_string_on_texture
- 唯一关键主问题：**细珠串连续细结构与纹理背景交界处的细边完整性是否足够稳定。**
- 证据要点：
1. `quality=review`，`hard_case_signal=thinDetailEdge`；  
2. candidate 已稳定产出（R19 `processedPhotoID` 存在，非 `subjectMaskUnavailable`）；  
3. 但仍未升到 `ready`，说明“可运行”已成立，但“细结构完整性”仍不足。
- 复核结论：`changed_but_insufficient`

### EV021_hand_with_beads
- 唯一关键主问题：**手部与珠串邻接区域的前景保真（洗薄/边缘丢失）是否被实质抑制。**
- 证据要点：
1. `quality=review`，`hard_case_signal=foregroundWashout`；  
2. candidate 在复杂复合主体上可稳定输出，但核心阻塞仍落在前景洗薄风险类别；  
3. 说明有变化，但不足以判定主问题已清晰解决。
- 复核结论：`changed_but_insufficient`

### EV028_flower_vase_garden_bg
- 唯一关键主问题：**自然复杂纹理背景下花枝外轮廓分离稳定性。**
- 证据要点：
1. `quality=review`，`hard_case_signal=thinDetailEdge`；  
2. candidate 具备稳定输出与可复核信号，但复杂背景边界仍未升档；  
3. 主问题仍停在“有变化但不足”。
- 复核结论：`changed_but_insufficient`

### EV033_blue_vase_blue_curtain
- 唯一关键主问题：**同色前后景（蓝瓶/蓝幕）交界分离能力是否形成可确认改善。**
- 证据要点：
1. `quality=review`，`hard_case_signal=softEdge`；  
2. 在同色交界场景中，当前证据仍未给出可确认的边界改善信号；  
3. 现有信息更接近“仍未证明主问题被触达”。
- 复核结论：`not_proven`

### EV044_person_outdoor_complex
- 唯一关键主问题：**人物外轮廓与户外枝叶跨域交界的分离稳定性。**
- 证据要点：
1. `quality=review`，`hard_case_signal=thinDetailEdge`；  
2. 当前虽然可稳定输出，但对跨域复杂边界主问题缺少清晰改善证据；  
3. 仍不能判定该阻塞位被有效触达。
- 复核结论：`not_proven`

---

## 5) 样本分层重判（R20）

1. `clear_improved`: `0/5`  
2. `changed_but_insufficient`: `3/5`（`EV006 / EV021 / EV028`）  
3. `not_proven`: `2/5`（`EV033 / EV044`）

相对 R19 的增量：
1. 本轮不是重跑全量，而是把 review 阻塞位压缩到“每样本唯一主问题 + 问题级结论”；  
2. 阻塞结构由“标签级 review”收敛为“3 个可继续复核、2 个仍未证明”。

---

## 6) 第二轮 hard_gate 复核结论（二选一）

**结论：值得继续停留在 admission 体系并进入下一步复核。**

判定理由：
1. 5 个阻塞样本中已有 `3/5` 达到 `changed_but_insufficient`，说明主问题存在可跟进变化而非全量停滞；  
2. `2/5 not_proven` 仍是关键风险，但尚未达到“全局无继续价值”的停止条件；  
3. 结合 R19 的 hard_gate 总体结构（`3 ready + 5 review + 0 failed`）与当前未触发 failed 红线，继续做下一步最小复核收益高于立即停止。

边界声明：
1. 本结论仅表示“继续留在 admission 体系复核”；  
2. 不代表 tiny 已通过 admission；  
3. 不代表 tiny 已可替代 RMBG-2 或可切主链。

---

## 7) 下一包建议（最小相邻增量）

建议下一包：**tiny admission 第三轮 hard_gate 终局判断小包**
1. 仅围绕 `EV033 / EV044` 两个 `not_proven` 核心卡点 + `EV006` 作为门槛锚点做终局判断；  
2. 明确三选一路线：继续停留 admission / 暂停当前候选 /（若证据跃迁）进入下一范围；  
3. 不扩 expanded，不改主链，不并行新候选。

不应进入：
1. 主链替换结论；  
2. expanded 扩范围实验；  
3. 下游联动改造。


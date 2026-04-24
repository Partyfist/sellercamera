# Seller Camera BiRefNet tiny admission R01 重开首轮最小准入实验（R19，有效首轮）

## 1) 当前候选身份与重跑口径

本轮评估对象是：**`BiRefNet-general-bb_swin_v1_tiny-epoch_232`**。  
本轮口径是：**入口恢复 + 覆盖恢复 + 信号恢复后的有效首轮重跑**，不是 admission 第二轮。

关键边界：
1. 该候选是 BiRefNet tiny 商业可控替代路线候选，不等同于原版 BiRefNet 全链路打通；  
2. 本轮仍仅在 `SegmentationProvider` 边界内做 `admission_v1` 首轮判断；  
3. 本轮结论不外推为“已可替代 RMBG-2”或“已可切主链”。

---

## 2) 本轮范围与不做项

本轮只做：
1. 使用 `sample_manifest.backbone_admission_v1.json` 执行 tiny 有效首轮重跑；  
2. 产出 Vision 对照与 tiny candidate 记录/check；  
3. 基于 hard_gate/focus/stability 给出继续/停止二选一结论。

本轮刻意不做：
1. admission 第二轮；  
2. expanded 子集实验；  
3. 白底主流程和下游（refinement/去污染/合成）改造。

---

## 3) 运行资产与覆盖情况（有效首轮重跑）

- manifest：`WhiteBackgroundBaseline/sample_manifest.backbone_admission_v1.json`
- Vision 对照记录（r5）：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260423-admission-v1-r01-reopen-birefnet-tiny-vision-sim-ios26_4-r5.jsonl`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260423-admission-v1-r01-reopen-birefnet-tiny-vision-sim-ios26_4-r5.txt`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/runlog-20260423-admission-v1-r01-reopen-birefnet-tiny-vision-sim-ios26_4-r5-probe.log`
- tiny candidate 记录（r5）：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260423-admission-v1-r01-reopen-birefnet-tiny-candidate-sim-ios26_4-r5.jsonl`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260423-admission-v1-r01-reopen-birefnet-tiny-candidate-sim-ios26_4-r5.txt`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/runlog-20260423-admission-v1-r01-reopen-birefnet-tiny-candidate-sim-ios26_4-r5-probe.log`

覆盖结果：
1. Vision：`26/26`（全 failed）；  
2. tiny candidate：`26/26`（`ready=19, review=7, failed=0`）；  
3. candidate 路由与信号模式连续有效：
   - `segmentation_provider=birefnet_tiny_ort`（`26/26`）
   - `quality_metadata_mode=tiny_ort_runtime_signal_v1`（`26/26`）。

---

## 4) hard_gate / focus / stability 有效首轮结果

### 4.1 hard_gate（8 样本）
1. Vision：`8/8 failed`；  
2. tiny candidate：`3 ready + 5 review + 0 failed`。  

样本层：
1. ready：`EV013 / EV038 / EV042`；  
2. review：`EV006 / EV021 / EV028 / EV033 / EV044`。

结论：hard_gate 已出现可确认收益点，但关键阻塞位仍有 5 个处于 review，尚需第二轮聚焦复核。

### 4.2 focus_comparison（10 样本）
1. Vision：`10/10 failed`；  
2. tiny candidate：`9 ready + 1 review + 0 failed`。  

样本层：
1. review：`S008_white_tubes_near_white_bg`；  
2. 其余 9 个 focus 样本为 ready。

结论：focus 层出现明确结构性正向信号，不是简单 parity。

### 4.3 stability_witness（8 样本）
1. Vision：`8/8 failed`；  
2. tiny candidate：`7 ready + 1 review + 0 failed`。  

样本层：
1. review：`S007_snacks_on_dark_plate`；  
2. 其余 7 个 stability 样本为 ready。

结论：stability 无 `ready -> failed` 红线，当前可继续保留。

---

## 5) 收益分层（本轮有效证据口径）

### 已确认收益
1. hard_gate 中 `EV013 / EV038 / EV042` 达到 ready；  
2. focus 中 9/10 达到 ready；  
3. stability 中 7/8 达到 ready。

### 有变化但仍有限
1. hard_gate 仍有 5 个关键阻塞样本停在 review；  
2. focus 仍有 `S008` 为 review；  
3. stability 仍有 `S007` 为 review。

### 尚未证明有价值
1. 对 `EV006 / EV021 / EV028 / EV033 / EV044` 尚未形成 ready/clear 级证据，需要下一轮继续复核。

---

## 6) 红线与风险

1. 本轮未触发 candidate 失败红线（`failed=0`）；  
2. 仍有 review 样本，主要集中在 hard_gate 复杂阻塞位；  
3. 当前风险是“关键阻塞位尚未充分清空”，不是入口/覆盖/信号无效。

---

## 7) 首轮重跑准入结论（二选一）

**结论：值得继续进入 tiny admission 第二轮复核（`continue_to_admission_round2_review`）。**

理由：
1. 本轮已满足有效首轮前提（入口有效 + 覆盖完整 + 信号可分层）；  
2. hard_gate/focus/stability 三层均拿到可判别证据，且出现 ready 级收益；  
3. 无 failed 红线，继续第二轮复核的收益高于停止。

边界声明：
1. 本结论仅表示“继续留在 admission 体系进行第二轮复核”；  
2. 不等同于 tiny 已通过 admission；  
3. 不等同于 tiny 已可替代 RMBG-2。

---

## 8) 下一包建议（最小相邻增量）

建议下一包：**tiny admission 第二轮 hard_gate 关键阻塞位复核包**
1. 只聚焦当前 hard_gate review 样本：`EV006 / EV021 / EV028 / EV033 / EV044`；  
2. 每个样本仅保留一个关键主问题，判断是否从 review 升档；  
3. 不扩到 expanded，不开并行候选，不改主链。

不应进入：
1. expanded 子集实验；  
2. 主链替换决策；  
3. 下游联动大改。

---

## 9) 商业替代路线口径提醒

本轮结论表示：tiny 候选已具备继续留在 admission 体系内复核的价值。  
不等同于：
1. tiny 已可替代 RMBG-2；  
2. tiny 已通过 admission；  
3. 原版 BiRefNet 已完成全链路打通。

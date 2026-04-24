# Seller Camera BiRefNet tiny admission R01 重开首轮最小准入实验（R17，有效首轮）

## 1) 当前候选身份与重跑口径

本轮评估对象是：**`BiRefNet-general-bb_swin_v1_tiny-epoch_232`**。  
本轮口径是：**覆盖恢复后的有效首轮重跑（R01 reopen effective）**，不是 admission 第二轮。

关键边界：
1. R16 仅恢复了 tiny 的正式 provider/runtime 完整覆盖能力（`26/26`），不等于 admission 已通过；  
2. 本轮仍仅在 `SegmentationProvider` 边界内做 `admission_v1` 最小首轮；  
3. 本轮结论不外推为“可替代 RMBG-2”或“可切主链”。

---

## 2) 本轮范围与不做项

本轮只做：
1. 用 `sample_manifest.backbone_admission_v1.json` 做 tiny admission R01 有效首轮重跑；  
2. 产出 Vision 对照与 tiny candidate 记录、check、结构化判读；  
3. 给出“继续/停止”二选一结论。

本轮刻意不做：
1. admission 第二轮；  
2. expanded 子集实验；  
3. 白底主流程和下游（refinement/去污染/合成）改造。

---

## 3) 运行资产与覆盖情况（有效首轮重跑）

- manifest：`WhiteBackgroundBaseline/sample_manifest.backbone_admission_v1.json`
- Vision 重跑记录（r3）：  
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260423-admission-v1-r01-reopen-birefnet-tiny-vision-sim-ios26_4-r3.jsonl`  
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260423-admission-v1-r01-reopen-birefnet-tiny-vision-sim-ios26_4-r3.txt`  
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/runlog-20260423-admission-v1-r01-reopen-birefnet-tiny-vision-sim-ios26_4-r3-probe.log`
- tiny candidate 重跑记录（r3）：  
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260423-admission-v1-r01-reopen-birefnet-tiny-candidate-sim-ios26_4-r3.jsonl`  
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260423-admission-v1-r01-reopen-birefnet-tiny-candidate-sim-ios26_4-r3.txt`  
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/runlog-20260423-admission-v1-r01-reopen-birefnet-tiny-candidate-sim-ios26_4-r3-probe.log`

覆盖结果：
1. Vision：`26/26`（全 failed）；  
2. tiny candidate：`26/26`（全 review）；  
3. candidate 运行时入口字段连续有效：`segmentation_provider=birefnet_tiny_ort`、`segmentation_request=ORTSession(BiRefNetTinyONNX)`，并且 `quality_metadata_mode=tiny_ort_runtime_fallback` 为 `26/26`。

---

## 4) hard_gate / focus / stability 有效首轮结果

### 4.1 hard_gate（8 样本）
1. Vision：`8/8 failed`；  
2. tiny candidate：`8/8 review`（无 failed，但也无 ready）；  
3. 包括 `EV006 / EV033 / EV038 / EV042 / EV044` 在内的关键阻塞位本轮都拿到了记录，但均停在 review。

结论：hard_gate 已拿到“完整可运行证据”，但未形成“已确认收益”级命中。

### 4.2 focus_comparison（10 样本）
1. Vision：`10/10 failed`；  
2. tiny candidate：`10/10 review`。

结论：focus 层本轮没有 ready 信号，当前只能判为“有变化但仍有限”。

### 4.3 stability_witness（8 样本）
1. Vision：`8/8 failed`；  
2. tiny candidate：`8/8 review`，未出现 `ready -> failed` 类型回退红线。

结论：stability 层无红线，但也未建立 ready 级稳定性旁证。

---

## 5) 收益分层（本轮有效证据口径）

### 已确认收益
1. 无已确认收益项（本轮无 ready 级样本）。

### 有变化但仍有限
1. candidate 相比 Vision 从 failed 变为 review，且覆盖完整；  
2. hard_gate/focus/stability 三层均形成可记录结果，但全部停留在 review，未进入可确认收益档位。

### 尚未证明有价值
1. hard_gate 关键阻塞位尚无 clear 命中；  
2. focus 无结构性正向信号；  
3. stability 无红线但也无 ready 旁证，无法支持继续第二轮复核。

---

## 6) 红线与风险

1. 本轮未触发“明显回退红线”（candidate 无 failed）；  
2. 但 `quality_metadata_mode=tiny_ort_runtime_fallback` 覆盖 `26/26`，导致质量分层全部停在 review；  
3. 在该信号分辨率下继续 admission 第二轮，难以获得增量判断价值。

---

## 7) 首轮重跑准入结论（二选一）

**结论：停止当前候选（`stop_current_candidate`）。**

理由：
1. 本轮虽已完成“有效首轮覆盖”，但三层样本全部停在 review，缺少进入第二轮所需的已确认收益；  
2. hard_gate 关键阻塞位没有形成 ready/clear 命中，无法支撑“值得继续复核”的证据门槛；  
3. 在当前质量信号仍为 fallback 模式的情况下继续 admission，属于低收益重复投入。

边界声明：
1. 本结论针对 R17 有效首轮边界成立，不外推为 tiny 路线永久不可行；  
2. 本结论不等同于原版 BiRefNet 打通结论，不等同于 RMBG-2 替代结论。

---

## 8) 下一包建议（最小相邻增量）

建议下一包：**tiny runtime 质量信号恢复包（非 admission）**，只做：
1. 在保持 ORT provider 与 `26/26` 覆盖稳定的前提下，恢复非 fallback 的质量元数据分层能力；  
2. 先验证 hard_gate/focus/stability 能否产出可区分的 ready/review/failed 证据；  
3. 仅在质量分层恢复后，再考虑是否重开 tiny admission R01。

不建议下一包进入：
1. admission 第二轮；  
2. expanded 子集实验；  
3. 主链/下游联动改造。

---

## 9) 商业替代路线口径提醒

本轮结论仅表示：tiny 候选在当前“有效首轮 + fallback 质量信号”边界下，不具备继续 admission 第二轮价值。  
不等同于：
1. tiny 已可替代 RMBG-2；  
2. tiny 路线永久停止；  
3. 原版 BiRefNet 已全链路打通。

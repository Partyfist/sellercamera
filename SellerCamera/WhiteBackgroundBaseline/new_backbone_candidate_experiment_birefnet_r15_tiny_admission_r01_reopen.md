# Seller Camera BiRefNet tiny admission R01 重开首轮最小准入实验（R15）

## 1) 当前候选身份与重跑口径

本轮评估对象是：**`BiRefNet-general-bb_swin_v1_tiny-epoch_232`**。  
本轮口径是：**入口恢复后的首轮重跑（R01 reopen）**，不是 admission 第二轮。

关键边界：
1. R14 只恢复了 tiny 的正式 provider/runtime 入口资格，不等于 admission 已通过；  
2. 本轮仍仅在 `SegmentationProvider` 边界内做 `admission_v1` 最小首轮；  
3. 本轮结论不外推为“可替代 RMBG-2”或“可切主链”。

---

## 2) 本轮范围与不做项

本轮只做：
1. 用 `sample_manifest.backbone_admission_v1.json` 做 tiny admission R01 重开首轮；  
2. 产出 Vision 对照与 tiny candidate 记录、check、结构化判读；  
3. 给出“继续/停止”二选一结论。

本轮刻意不做：
1. admission 第二轮；  
2. expanded 子集实验；  
3. 白底主流程和下游（refinement/去污染/合成）改造。

---

## 3) 运行资产与覆盖情况（重开首轮）

- manifest：`WhiteBackgroundBaseline/sample_manifest.backbone_admission_v1.json`
- Vision 重跑记录（r2）：  
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260422-admission-v1-r01-reopen-birefnet-tiny-vision-sim-ios26_4-r2.jsonl`  
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-admission-v1-r01-reopen-birefnet-tiny-vision-sim-ios26_4-r2.txt`
- tiny candidate 重跑记录（r2）：  
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260422-admission-v1-r01-reopen-birefnet-tiny-candidate-sim-ios26_4-r2.jsonl`  
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-admission-v1-r01-reopen-birefnet-tiny-candidate-sim-ios26_4-r2.txt`
- 同轮复现证据（candidate r1，与 r2 同分布）：  
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-admission-v1-r01-reopen-birefnet-tiny-candidate-sim-ios26_4.txt`

覆盖结果：
1. Vision：`26/26`（全 failed，主因 `com.apple.Vision code=9`）；  
2. tiny candidate：`3/26`（仅 `EV006 / EV013 / EV021`，其余 23 样本缺失）；  
3. candidate 在 r1、r2 两次重跑均停在同一覆盖分布，说明本轮“首轮重跑入口”仍未形成可用的全量 admission 覆盖。

---

## 4) hard_gate / focus / stability 首轮重跑结果

### 4.1 hard_gate（8 样本）
1. tiny candidate 覆盖 `3/8`：`EV006 / EV013 / EV021` 均为 `ready`；  
2. 关键阻塞位 `EV033 / EV038 / EV042 / EV044` 本轮仍未进入 candidate 记录；  
3. 结论：hard_gate 无法形成完整可比较证据，当前仅能判定“局部有记录，不足以给出首轮门槛判断”。

### 4.2 focus_comparison（10 样本）
1. tiny candidate 覆盖 `0/10`；  
2. 结论：无可用 focus 首轮信号，无法判断结构性收益。

### 4.3 stability_witness（8 样本）
1. tiny candidate 覆盖 `0/8`；  
2. 结论：无可用 stability 证据，无法建立“继续保留”的安全旁证。

---

## 5) 收益分层（本轮有效证据口径）

### 已确认收益
1. 仅在已覆盖的 3 个 hard_gate 样本上出现 `ready` 记录。

### 有变化但仍有限
1. 当前变化仅限 `hard_gate` 局部覆盖，且未触达主阻塞位全集。

### 尚未证明有价值
1. focus_comparison 与 stability_witness 均无有效覆盖；  
2. hard_gate 关键阻塞位仍缺失，无法支持“继续第二轮复核”所需的首轮完整证据。

---

## 6) 首轮重跑准入结论（二选一）

**结论：停止当前候选（`stop_current_candidate`）。**

理由：
1. 本轮目标是“入口恢复后有效首轮重跑”，但 candidate 两次重跑均只到 `3/26`，首轮有效覆盖未成立；  
2. hard_gate/focus/stability 三层中，仅 hard_gate 局部有记录，focus/stability 证据为 0；  
3. 在该证据完整度下继续 admission 第二轮会放大无效投入，不符合当前 admission 纪律。

边界声明：
1. 本结论针对 R15 首轮重跑边界成立，不外推为 tiny 路线永久不可行；  
2. 本结论不等同于原版 BiRefNet 打通结论，不等同于 RMBG-2 替代结论。

---

## 7) 下一包建议（最小相邻增量）

建议下一包：**tiny runtime 连续覆盖稳定性修复包（非 admission）**，只做：
1. 在正式 provider/runtime 入口下，定位并修复 candidate 从第 4 样本开始停滞的问题；  
2. 验证 candidate 能稳定覆盖 `admission_v1` 全量样本；  
3. 覆盖稳定后再重开 tiny admission R01（仍按首轮口径，不直接跳第二轮）。

不建议下一包进入：
1. admission 第二轮；  
2. expanded 子集实验；  
3. 主链/下游联动改造。


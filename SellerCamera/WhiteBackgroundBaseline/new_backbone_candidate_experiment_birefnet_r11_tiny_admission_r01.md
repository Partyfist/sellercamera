# Seller Camera BiRefNet tiny admission R01 最小准入实验（R11）

## 1) 当前候选身份与边界

本轮评估对象是：**`BiRefNet-general-bb_swin_v1_tiny-epoch_232`**。  
这不等同于“原版 BiRefNet 已完全打通”，也不等同于“已可替代 RMBG-2”。

当前边界：
1. R10 已通过 tiny 单点 `load -> infer -> mask` 闭环，满足 admission 前置运行资格；  
2. 本轮仅做 `admission_v1` 首轮最小准入实验；  
3. 本轮结论仅在 `SegmentationProvider` 现有合同与当前实验边界内成立。

---

## 2) 本轮范围与不做项

本轮仅做：
1. 在 `SegmentationProvider` 边界内运行 `admission_v1` 首轮；
2. 产出 Vision 对照与 tiny candidate 记录、check、结构化判读；
3. 给出首轮“继续/停止”二选一结论。

本轮刻意不做：
1. expanded 子集实验；  
2. 第二候选并行接入；  
3. 白底主流程或下游（refinement/去污染/合成）改造。

---

## 3) 运行资产与覆盖情况

- manifest：`WhiteBackgroundBaseline/sample_manifest.backbone_admission_v1.json`
- Vision 对照记录：`WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260422-admission-v1-r01-birefnet-tiny-vision-sim-ios26_4.jsonl`
- Vision 对照检查：`WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-admission-v1-r01-birefnet-tiny-vision-sim-ios26_4.txt`
- candidate 记录：`WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260422-admission-v1-r01-birefnet-tiny-candidate-sim-ios26_4.jsonl`
- candidate 检查：`WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-admission-v1-r01-birefnet-tiny-candidate-sim-ios26_4.txt`

覆盖结果：
1. Vision：`26/26`  
2. candidate：`26/26`

---

## 4) hard_gate / focus / stability 首轮结果

### 4.1 hard_gate（8 样本）

1. Vision：`8/8 failed`（主因：`com.apple.Vision code=9`，`Could not create inference context`）  
2. candidate：`8/8 failed`（主因：`SellerCamera.CaptureWhiteBackgroundProcessorError code=3`，`分割模型资产不可用`）

关键点：
1. `EV006` 未形成正向触达（failed 对 failed）；  
2. 其余关键阻塞位（`EV033/EV038/EV042/EV044`）均未产出可比较正向证据。

### 4.2 focus_comparison（10 样本）

1. Vision：`10/10 failed`  
2. candidate：`10/10 failed`

结论：focus 层没有出现任何可支持继续第二轮的结构性正向信号。

### 4.3 stability_witness（8 样本）

1. Vision：`8/8 failed`  
2. candidate：`8/8 failed`

结论：稳定层无 ready 样本，无法建立“无回退”安全旁证。

---

## 5) 收益分层（首轮）

### 已确认收益
1. 本轮无已确认收益项。

### 有变化但仍有限
1. 本轮无可用正向变化项。

### 尚未证明有价值
1. hard_gate 全量未命中；  
2. focus/stability 均未形成继续证据。

---

## 6) 红线与风险

1. 本轮 candidate 未形成任何相对 Vision 的可用正向命中；  
2. candidate 失败模式稳定指向 `segmentationModelUnavailable`，说明在当前 provider 合同下 tiny ONNX 轨道尚未形成可用 admission 输入资产；  
3. 在此状态下继续 admission 第二轮属于低收益重复投入。

---

## 7) 首轮准入结论（二选一）

**结论：停止当前候选（`stop_current_candidate`）。**

理由：
1. candidate 在 `admission_v1` 首轮 `26/26` 全量 failed，hard_gate/focus/stability 全层无正向证据；  
2. 失败主因稳定且集中在模型资产可用性合同层（`CaptureWhiteBackgroundProcessorError code=3`）；  
3. 当前不满足进入 admission 第二轮复核的最小价值条件。

---

## 8) 下一包建议（最小相邻增量）

建议进入：**tiny 路线运行时合同重审包（非 admission 第二轮包）**，只做：
1. 明确 tiny ONNX 在现有 `SegmentationProvider` 合同下的可消费路径；
2. 仅做最小运行时合同打通验证（不扩 admission 样本）；
3. 成功后再判断是否重开 tiny admission R01。

不建议进入：
1. tiny admission 第二轮复核；  
2. 任意“先继续看看”的同层重复包。

---

## 9) 商业替代路线口径提醒

本轮结论仅表示：tiny 候选在当前 `admission_v1` 首轮边界下不具备继续价值。  
不等同于：
1. 原版 BiRefNet 已打通；  
2. tiny 路线永久不可行；  
3. RMBG-2 轨道已被 tiny 正式替代。

# Seller Camera BiRefNet（RMBG-2 CoreML INT8 轨道）admission R01 最小准入实验（R07）

## 1) 本轮评估口径

本轮评估对象是：**BiRefNet（RMBG-2 CoreML INT8 轨道）**。  
这不等同于“原版 BiRefNet CoreML 转换链已完全打通”，也不等同于“可商业上线主干”。

当前边界：
1. R06 已通过单点 `load -> infer -> output_3 -> mask` 闭环；  
2. 本轮是 `admission_v1` 首轮最小准入实验；  
3. 许可仍受 CC BY-NC 4.0 限制，商业用途需单独授权。

---

## 2) 本轮范围与不做项

本轮仅做：
1. 在 `SegmentationProvider` 边界内运行 `admission_v1` 首轮；
2. 产出 Vision 对照与 candidate 记录、check、结构化判读；
3. 给出首轮“继续/停止”结论。

本轮刻意不做：
1. expanded 子集实验；  
2. 第二候选并行接入；  
3. 白底主流程或下游（refinement/去污染/合成）改造。

---

## 3) 运行资产与覆盖情况

- manifest：`WhiteBackgroundBaseline/sample_manifest.backbone_admission_v1.json`
- Vision 对照记录：`WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260422-admission-v1-r01-birefnet-rmbg2-vision-sim-ios18_0.jsonl`
- Vision 对照检查：`WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-admission-v1-r01-birefnet-rmbg2-vision-sim-ios18_0.txt`
- candidate 记录：`WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260422-admission-v1-r01-birefnet-rmbg2-candidate-sim-ios18_0.jsonl`
- candidate 检查：`WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-admission-v1-r01-birefnet-rmbg2-candidate-sim-ios18_0.txt`

覆盖结果：
1. Vision：`26/26`  
2. candidate：`26/26`

---

## 4) hard_gate / focus / stability 首轮结果

### 4.1 hard_gate（8 样本）

1. Vision：`8/8 failed`（失败主因：`com.apple.Vision code=9`，`Could not create inference context`）  
2. candidate：`8/8 failed`（失败主因：`com.apple.Vision code=15`，`The model does not have a valid input feature of type image`）

关键点：
1. `EV006` 在本轮未保持正向触达（failed 对 failed）。  
2. 其余关键阻塞位（EV033/EV038/EV042/EV044）均未产出可比较的正向证据。

### 4.2 focus_comparison（10 样本）

1. Vision：`10/10 failed`  
2. candidate：`10/10 failed`

结论：focus 层未出现可支持继续第二轮的任何正向信号。

### 4.3 stability_witness（8 样本）

1. Vision：`8/8 failed`  
2. candidate：`8/8 failed`

结论：稳定层没有可用 ready 样本，无法建立“无回退”安全旁证。

---

## 5) 收益分层（首轮）

### 已确认收益
1. 本轮无已确认收益项。

### 有变化但仍有限
1. 本轮无“可用正向变化”项。

### 尚未证明有价值
1. EV006 与其余 hard_gate 阻塞位均未显示可用收益；  
2. focus/stability 同样未形成可继续证据。

---

## 6) 红线与风险

1. 本轮未出现“candidate 相对 Vision 的可用正向证据”；  
2. candidate 失败模式稳定指向输入类型不匹配（code=15），属于当前 provider 合同与资产 I/O 不兼容问题；  
3. 在此状态下继续 admission 第二轮属于低收益重复投入。

---

## 7) 首轮准入结论（二选一）

**结论：停止当前候选（`stop_current_candidate`）。**

理由：
1. candidate 在 admission_v1 首轮 `26/26` 全量 failed，未触达任何 hard_gate 正向命中；  
2. `EV006` 未保持 R06 单点闭环阶段的正向触达；  
3. focus/stability 均无继续价值信号；  
4. 当前边界下继续 admission 复核不具备投入产出比。

---

## 8) 下一包建议（最小相邻增量）

建议进入：**候选切换包或 provider 合同重审包（非本候选继续包）**，并保持以下边界：
1. 不扩 admission 样本范围；  
2. 不改白底主流程；  
3. 不并行接入第二候选。

不建议进入：
1. BiRefNet（RMBG-2 轨道）admission 第二轮；  
2. 任意“先继续看看”的同层重复包。

---

## 9) 许可与商业边界提醒

当前资产来自 `sihai0506/rmbg2.0-coreml`，模型卡许可为 **CC BY-NC 4.0**。  
本轮结论仅用于工程准入评估，不构成商业上线许可判断。

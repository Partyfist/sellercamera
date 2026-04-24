# Seller Camera 新候选最小准入实验（R01, foreground_objectness_hybrid）

## 1) 候选与入场审查
### 1.1 本轮唯一候选
- 候选 ID：`vision_foreground_objectness_hybrid`
- 分割请求：`VNGenerateForegroundInstanceMaskRequest + VNGenerateObjectnessBasedSaliencyImageRequest`
- 轨道标识：`admission_candidate_foreground_objectness_hybrid_v1`

### 1.2 为什么先试这个候选
基于 `new_backbone_candidate_prep_v1.md` 的入场标准，本候选满足：
1. **问题命中价值**：对当前最关键硬门槛 EV006（细结构 + 复杂纹理背景）具备“前景实例优先 + objectness 回退”双路径命中能力。
2. **最小接入可行**：仅在 `SegmentationProvider` 边界替换分割来源，不要求联动改 refinement / 去污染 / 合成。
3. **移动端可运行**：完全依赖系统 Vision 请求族，真机接入风险低，便于首轮快速复核。
4. **失败可回退**：Vision 默认路径和实验开关保留，失败时可直接回退。

### 1.3 为什么比 foreground_latest 更值得试
`foreground_latest` 首轮在 admission_v1 与 Vision 同分布，且 EV006 仍 failed；本候选通过 objectness fallback 具备更高概率触达 EV006 这类真实失败位，符合“先命中硬门槛”的优先级。

## 2) 最小接入边界（本轮未扩散）
- 仅在 `CaptureWhiteBackgroundProcessor` 的 `SegmentationProvider` 边界使用 `vision_foreground_objectness_hybrid` provider 与别名解析：
  - `vision-foreground-objectness-hybrid`
  - `foreground_objectness_hybrid`
  - `candidate_foreground_objectness_hybrid`
- Vision 默认路径完整保留；白底主流程顺序未改。
- 未联动改 refinement / 去污染 / 合成。
- 未接入第二候选。

## 3) 运行资产与覆盖（真机）
- suite：`whitebg-backbone-admission-v1`
- 设备：`iPhone15,3`
- iOS：`18.7.7`

### 3.1 Vision 对照
- 记录：`WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260421-admission-v1-r01-foreground-objectness-hybrid-vision-device.jsonl`
- 检查：`WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260421-admission-v1-r01-foreground-objectness-hybrid-vision-device.txt`

### 3.2 foreground_objectness_hybrid 候选
- 记录：`WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260421-admission-v1-r01-foreground-objectness-hybrid-candidate-device.jsonl`
- 检查：`WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260421-admission-v1-r01-foreground-objectness-hybrid-candidate-device.txt`

### 3.3 人工判读（本轮）
- `WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r01.foreground_objectness_hybrid.device.json`

## 4) 首轮结果摘要（admission_v1）
### 4.1 覆盖
- Vision：`26/26`
- foreground_objectness_hybrid：`26/26`

### 4.2 质量分布
- Vision：`ready=25, failed=1`
- foreground_objectness_hybrid：`ready=26, failed=0`

### 4.3 三层结果
- `hard_gate`
  - Vision：`ready=7, failed=1`
  - foreground_objectness_hybrid：`ready=8, failed=0`
- `focus_comparison`
  - Vision：`10/10 ready`
  - foreground_objectness_hybrid：`10/10 ready`
- `stability_witness`
  - Vision：`8/8 ready`
  - foreground_objectness_hybrid：`8/8 ready`

### 4.4 关键硬门槛信号
- `EV006_beaded_string_on_texture`：Vision `failed` → foreground_objectness_hybrid `ready`。

## 5) 首轮准入判断
### 5.1 结论
**继续（continue_within_admission_v1）**

### 5.2 理由
1. 候选在最关键硬门槛 EV006 上实现实质触达（failed→ready）。
2. 三层样本未触发稳定样本回退红线。
3. 首轮已满足“值得继续”的最低价值，但尚不足以直接升级范围。

### 5.3 当前不能夸大的边界
1. 本轮仍是 admission_v1 首轮最小实验，不等于可直接进入 expanded 子集实验。
2. 除 EV006 外，其余 hard_gate 样本当前主要体现为 parity，仍需下一轮主问题级复核。
3. 未做像素级并排导出，不将本轮结果外推为全局边界突破。

## 6) 本轮路线建议（仅相邻最小增量）
下一包建议进入：**foreground_objectness_hybrid 候选 admission_v1 第二轮 hard_gate 主问题复核包**，仅在 admission_v1 内补问题级证据，不扩样本边界。

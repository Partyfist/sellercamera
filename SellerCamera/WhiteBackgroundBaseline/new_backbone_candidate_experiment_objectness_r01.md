# Seller Camera 新候选最小准入实验（R01, objectness）

## 1) 候选与入场审查
### 1.1 本轮唯一候选
- 候选 ID：`vision_objectness_saliency`
- 分割请求：`VNGenerateObjectnessBasedSaliencyImageRequest`
- 轨道标识：`admission_candidate_objectness_saliency_v1`

### 1.2 为什么先试这个候选
基于 `new_backbone_candidate_prep_v1.md` 的入场标准，本候选满足：
1. **问题命中价值**：对“复杂背景中的主体显著性聚焦”有直接理论命中，优先对应当前 hard_gate 阻塞位（复杂背景纹理残留、跨域边界不稳、同色分离困难）。
2. **最小接入可行**：可在既有 `SegmentationProvider` 边界内替换分割来源，不要求联动重写下游链路。
3. **移动端可运行**：同属 Vision 请求族，设备侧推理链路与现有工程兼容，接入风险低于引入全新推理框架。
4. **失败可回退**：Vision 默认路径保留，可通过环境变量切换，不污染当前稳定主链。

### 1.3 为什么不是其它候选
本轮目标是“最小准入实验”，不是候选横评。按入场纪律先选“命中 hard_gate + 最小接入风险”组合最优者；未经过同等入场审查的其它候选本轮不入场。

## 2) 最小接入边界（本轮未扩散）
- 仅在 `CaptureWhiteBackgroundProcessor` 的 `SegmentationProvider` 边界增加 `vision_objectness_saliency` provider 解析与 metadata 轨道标识。
- Vision 路径完整保留，默认稳定路径不变。
- 未改 white background 主处理顺序（segmentation/refine/decontam/compose/fidelity/quality）。
- 未联动改 refinement、去污染、合成逻辑。
- 未引入第二候选主干。

## 3) 运行资产与覆盖
- suite：`whitebg-backbone-admission-v1`
- 设备：`iPhone15,3`
- iOS：`18.7.7`

### 3.1 Vision 对照（同轮）
- 记录：`WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260421-admission-v1-r01-objectness-vision-device.jsonl`
- 检查：`WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260421-admission-v1-r01-objectness-vision-device.txt`

### 3.2 objectness 候选
- 记录：`WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260421-admission-v1-r01-objectness-candidate-device.jsonl`
- 检查：`WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260421-admission-v1-r01-objectness-candidate-device.txt`

### 3.3 人工判读（本轮）
- `WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r01.objectness.device.json`

## 4) 首轮结果摘要（admission_v1）
### 4.1 覆盖
- Vision：`26/26`
- objectness：`26/26`

### 4.2 质量分布
- Vision：`ready=25, failed=1`
- objectness：`ready=26, failed=0`

### 4.3 三层结果
- `hard_gate`
  - Vision：`ready=7, failed=1`
  - objectness：`ready=8, failed=0`
- `focus_comparison`
  - Vision：`10/10 ready`
  - objectness：`10/10 ready`
- `stability_witness`
  - Vision：`8/8 ready`
  - objectness：`8/8 ready`

### 4.4 关键硬门槛信号
- `EV006_beaded_string_on_texture`：Vision `failed` → objectness `ready`。

## 5) 首轮准入判断
### 5.1 结论
**继续（continue within admission_v1）**

### 5.2 理由
1. 候选主干在硬门槛样本 EV006 上形成实质触达（failed→ready）。
2. 三层样本首轮未触发稳定样本回退红线。
3. 候选具备进入下一轮更细 hard_gate 主问题复核的最小价值。

### 5.3 当前仍不能夸大的边界
1. 本轮是 admission_v1 首轮最小实验，不等于可直接升级到更大范围受控实验。
2. 除 EV006 外，其余 hard_gate 样本当前主要体现为“未回退 + 可产出”，仍需后续问题级证据判断。
3. 本轮未引入像素级并排导出资产，不能把质量分布优势直接外推为全局边界突破。

## 6) 本轮路线建议（仅相邻最小增量）
下一包建议进入：**新候选准入第二轮评估（仅 admission_v1，不扩样本边界）**，重点补 hard_gate 主问题级人工对照证据，再判定是否允许升级范围。

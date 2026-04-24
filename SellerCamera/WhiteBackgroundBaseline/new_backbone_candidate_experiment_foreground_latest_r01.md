# Seller Camera 新候选最小准入实验（R01, foreground_latest）

## 1) 候选与入场审查
### 1.1 本轮唯一候选
- 候选 ID：`vision_foreground_latest_revision`
- 分割请求：`VNGenerateForegroundInstanceMaskRequest`
- 轨道标识：`admission_candidate_foreground_latest_revision_v1`

### 1.2 为什么先试这个候选
基于 `new_backbone_candidate_prep_v1.md` 的入场标准，本候选满足：
1. **问题命中价值**：通过 pin 到 `VNGenerateForegroundInstanceMaskRequest` 最新支持 revision，验证“同一请求族中 revision 策略”能否触达当前 hard_gate 阻塞位（尤其 EV006）。
2. **最小接入可行**：完全复用现有 Vision 前景分割链路，仅替换 revision policy，不依赖下游联动改造。
3. **移动端可运行**：仍在系统 Vision 能力内，真机兼容风险最低，便于快速完成首轮可复核对照。
4. **失败可回退**：Vision 默认 provider 保留，环境变量可切换，主链无污染。

### 1.3 为什么不是其它候选
本轮目标是“最小准入实验”，先验证最低接入风险且最容易复核的候选；其它候选未在本轮并行接入，避免变量扩散。

## 2) 最小接入边界（本轮未扩散）
- 仅在 `CaptureWhiteBackgroundProcessor` 的 `SegmentationProvider` 边界新增 `vision_foreground_latest_revision` provider 与别名解析：
  - `vision-foreground-latest`
  - `foreground_latest_revision`
  - `candidate_foreground_latest`
- Vision 默认路径完整保留，白底主流程顺序未改。
- 未联动改 refinement / 去污染 / 合成。
- 未接入第二候选。

## 3) 运行资产与覆盖（真机）
- suite：`whitebg-backbone-admission-v1`
- 设备：`iPhone15,3`
- iOS：`18.7.7`

### 3.1 Vision 对照
- 记录：`WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260421-admission-v1-r01-foreground-latest-vision-device.jsonl`
- 检查：`WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260421-admission-v1-r01-foreground-latest-vision-device.txt`

### 3.2 foreground_latest 候选
- 记录：`WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260421-admission-v1-r01-foreground-latest-candidate-device.jsonl`
- 检查：`WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260421-admission-v1-r01-foreground-latest-candidate-device.txt`

### 3.3 人工判读（本轮）
- `WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r01.foreground_latest.device.json`

## 4) 首轮结果摘要（admission_v1）
### 4.1 覆盖
- Vision：`26/26`
- foreground_latest：`26/26`

### 4.2 质量分布
- Vision：`ready=25, failed=1`
- foreground_latest：`ready=25, failed=1`

### 4.3 三层结果
- `hard_gate`
  - Vision：`ready=7, failed=1`
  - foreground_latest：`ready=7, failed=1`
- `focus_comparison`
  - Vision：`10/10 ready`
  - foreground_latest：`10/10 ready`
- `stability_witness`
  - Vision：`8/8 ready`
  - foreground_latest：`8/8 ready`

### 4.4 关键硬门槛信号
- `EV006_beaded_string_on_texture`：Vision `failed`，foreground_latest 仍 `failed`（未触达硬门槛）。

## 5) 首轮准入判断
### 5.1 结论
**停止当前候选（stop_current_candidate）**

### 5.2 理由
1. EV006 仍 failed，未触达当前 admission_v1 最关键硬门槛。
2. hard_gate / focus / stability 与 Vision 同分布，仅证明 parity，未证明新增价值。
3. 在“最小接入 + 首轮准入”范围内，继续投入该候选的边际收益不足。

### 5.3 当前不夸大边界
1. 本结论仅在 admission_v1 首轮最小实验边界内成立，不外推到更大样本全域表现。
2. 本结论是“暂停当前候选”，不是否定最新 revision 策略在其他任务上的可能性。

## 6) 本轮路线建议（仅相邻最小增量）
下一包建议：按 `new_backbone_candidate_prep_v1.md` 重新执行“下一候选入场审查”，选择新的单一候选进入首轮最小准入实验；不再对 `foreground_latest` 在 admission_v1 内开同类型复核轮次。

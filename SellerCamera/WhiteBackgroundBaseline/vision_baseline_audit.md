# Vision 分割基线路径核查（当前仓库）

## 当前调用主线
1. `CaptureLivePreviewView.triggerProcessingForConfirmedLatest()`
2. `CaptureWhiteBackgroundProcessor.process(confirmedStillPhoto:)`
3. `CaptureWhiteBackgroundProcessor.processOnSupportedSystem(...)`
4. `SegmentationProvider.makeMask(...)`（默认实现为 Vision）
5. refinement / decontam / boundary / fidelity / quality metadata

## 当前 Vision 请求
- 请求类型：`VNGenerateForegroundInstanceMaskRequest`
- 默认 provider：`visionSegmentationProvider`
- 默认 revision 策略：**default_unpinned**（本轮只记录，不改行为）
- 输出：`generateScaledMaskForImage(...)` 生成 mask，再进入后续白底阶段

## 本轮新增的最小可复核点
- 在处理 metadata 中追加：
  - `segmentation_provider`
  - `segmentation_request`
  - `segmentation_revision_policy`
  - `segmentation_revision_resolved`
  - `segmentation_instance_count`
  - `segmentation_boundary`

## 一致性风险（当前仍需关注）
1. Vision revision 目前为默认策略，跨 iOS / 设备存在潜在差异风险。
2. 若不记录运行环境，后续对比难以定位“算法变化 vs 环境变化”。
3. 同一批样本复测若没有固定 sample_id，会丢失横向可比性。

## 本轮边界
- 不替换 Vision 主干；
- 不改处理顺序；
- 不做效果增强；
- 仅补“可记录、可复核”的基线信息。

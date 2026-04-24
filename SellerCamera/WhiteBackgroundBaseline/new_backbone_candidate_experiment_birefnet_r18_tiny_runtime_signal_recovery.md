# Seller Camera BiRefNet tiny runtime 质量信号恢复（R18，非 admission）

## 1) 当前唯一问题层级（固定）

R17 的 `stop_current_candidate` 根因是：  
**tiny 在正式 runtime 下虽然已恢复 `26/26` 覆盖，但质量元数据分层失去判别力（`26/26 review`），导致证据层不可分。**

这不是效果问题，原因：
1. provider/runtime 入口在 R14 已恢复，且 R16 已恢复覆盖到 `26/26`；  
2. R17 的 stop 不是 hard_gate/focus/stability 出现效果红线，而是 quality metadata 一刀切为 review；  
3. 在 signal 未恢复前继续 admission 第二轮，会重复低判别力证据。

---

## 2) `26/26 review` 根因定位（逐层）

### 2.1 质量元数据来源
1. tiny ORT 路径在 simulator 下命中 `shouldUseTinyORTCoverageMetadataFallback(...)`；  
2. fallback 进入 `makeTinyORTCoverageFallbackMetadata()`，输出固定保守元数据。

### 2.2 判定链路失真点
1. fallback 固定 `quality_level=review`；  
2. fallback 固定 `hard_case_signal=stable`；  
3. 风险分数固定 `0.0000`，导致 `ready/review/failed` 无法真实分层。

### 2.3 fallback 影响范围
1. 影响的不只是 metadata 记录格式，而是直接压扁质量结论分层；  
2. segmentation provider 与 ORT 推理本身可运行，但质量信号被统一降级。

### 2.4 样本级分布证据（R17）
1. hard_gate `8/8 review`；  
2. focus `10/10 review`；  
3. stability `8/8 review`。  

结论：核心阻塞位已从“入口/覆盖”收敛为“signal recoverability”。

---

## 3) 唯一主修复路线

本轮只选一条路线：  
**保留 coverage 稳定性兜底，但把 tiny ORT 质量元数据从一刀切 fallback 改成“基于 ORT logits 的轻量信号分层”。**

为什么选这条：
1. 直接命中当前唯一阻塞（signal 丧失），且不触碰白底主流程；  
2. 仍保持 `SegmentationProvider` 边界内最小修复；  
3. 可在非 admission probe 下直接验证 `ready/review/failed` 判别力是否恢复。

为什么不选其他路线：
1. 本轮不做质量系统大修；  
2. 本轮不做效果优化；  
3. 本轮不重开 admission。

---

## 4) 最小实现改动

文件：`CaptureWhiteBackgroundProcessor.swift`

1. 新增 tiny ORT 信号结构与统计：
   - `TinyORTSignalSummary`
   - `summarizeTinyORTSignals(logitsData:width:height:)`
2. tiny ORT 推理返回从“仅 mask”扩展为“mask + signal metadata”：
   - `runBiRefNetTinyORTInference(...) -> TinyORTInferenceOutput`
3. fallback 分支替换：
   - 原：`makeTinyORTCoverageFallbackMetadata()`（固定 review）
   - 新：`makeTinyORTRuntimeSignalMetadata(segmentationMetadata:)`（信号驱动分层）
4. 元数据模式升级为：
   - `quality_metadata_mode=tiny_ort_runtime_signal_v1`

边界声明：
1. 未改白底主流程顺序；  
2. 未改 refinement/去污染/合成链路策略；  
3. Vision 默认路径与回退语义保持不变。

---

## 5) 非 admission 质量信号复验结果

复验方式：正式 app runtime/provider 路径 probe（非 admission 包）  
记录资产：
1. `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260423-birefnet-r18-tiny-runtime-signal-probe-sim-ios26_4-r2.jsonl`
2. `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260423-birefnet-r18-tiny-runtime-signal-probe-sim-ios26_4-r2.txt`
3. `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260423-birefnet-r18-tiny-runtime-signal-probe-sim-ios26_4-r2.json`
4. `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/runlog-20260423-birefnet-r18-tiny-runtime-signal-probe-sim-ios26_4-r2.log`

复验结果：
1. 覆盖保持 `26/26`；  
2. provider 分布：`birefnet_tiny_ort = 26`；  
3. metadata mode 分布：`tiny_ort_runtime_signal_v1 = 26`；  
4. 质量分布：`ready = 19`, `review = 7`, `failed = 0`；  
5. hard case 分布：`stable = 19`, `thinDetailEdge = 4`, `softEdge = 2`, `foregroundWashout = 1`。

结论：已不再是 `26/26 review` 一刀切，signal 判别力恢复。

---

## 6) 质量信号恢复通过标准（本包口径）

本包通过标准定义为：
1. 覆盖完整：正式 runtime probe 必须 `26/26`；  
2. 路由稳定：`segmentation_provider` 持续命中 tiny ORT；  
3. 元数据模式统一可复核：`quality_metadata_mode=tiny_ort_runtime_signal_v1`；  
4. 分层恢复：`quality_level` 不能单桶塌缩，至少出现可复核的多层（本轮为 ready+review）；  
5. hard_case 不能一刀切 `stable`。

未恢复判定：
1. 再次出现 `26/26 review`（或全同级别单桶）；  
2. 覆盖跌回 `<26/26`；  
3. provider 或 metadata mode 不稳定。

---

## 7) 二选一结论

**结论：当前正式 runtime 质量信号已恢复，值得重开 tiny admission R01。**

理由：
1. 当前 stop 根因（signal 分层不足）已被直接修复并复验；  
2. 复验建立在正式 runtime/provider 路径，不是独立脚本推断；  
3. 质量信号已恢复为可区分分层，具备重新开展有效首轮准入判断条件。

边界声明：
1. 本结论仅表示“可重开 admission R01 的入口与证据信号条件恢复”；  
2. 不代表 tiny 已通过 admission；  
3. 不代表 tiny 已可替代 RMBG-2。

---

## 8) 下一包建议（最小相邻增量）

建议下一包：**tiny admission R01 重开（有效首轮重跑）**
1. 继续使用 `sample_manifest.backbone_admission_v1.json`；  
2. 只在 `SegmentationProvider` 边界内重跑首轮；  
3. 重点验证 hard_gate/focus/stability 是否出现可判别的样本级收益。

不应进入：
1. admission 第二轮；  
2. expanded 子集实验；  
3. 白底主流程或下游联动改造。

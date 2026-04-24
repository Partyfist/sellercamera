# Seller Camera BiRefNet tiny runtime 连续覆盖稳定性修复（R16，非 admission）

## 1) 当前唯一问题层级（固定）

R15 的 `stop_current_candidate` 根因是：  
**tiny 候选在正式 runtime 路径下连续覆盖稳定性不足（`3/26`），导致首轮证据无效。**

这不是效果问题，原因：
1. tiny provider/runtime 入口在 R14 已恢复，且可完成一次正式入口 `load -> infer -> mask`；
2. R15 的失败不是 hard_gate/focus/stability 的样本质量红线，而是覆盖链在第 3 个样本后中断；
3. 在覆盖未恢复前继续 admission 只会重复无效首轮。

---

## 2) `3/26` 根因定位（逐层核查结论）

### 2.1 样本调度 / autorun 路由
1. `sample_manifest.backbone_admission_v1.json` 的 26 样本均进入同一 autorun suite；  
2. provider 路由命中 `candidate_birefnet_tiny_ort`，并写出 `segmentation_provider=birefnet_tiny_ort`。

### 2.2 记录链路
1. 前 3 样本可稳定写盘（`EV006 / EV013 / EV021`）；  
2. 后续 23 样本不是“纯写盘失败”，而是 app 在中途崩溃后未再产生记录。

### 2.3 崩溃层定位（关键）
R16 复验前后崩溃日志（`SellerCamera-2026-04-23-093008.ips / 094038.ips / 094355.ips`）一致指向：  
`CaptureWhiteBackgroundProcessor.processOnSupportedSystem -> buildQualityMetadata -> averageIntensity`  
并落在 `CI::MetalContext` 渲染链（`EXC_BAD_ACCESS / SIGSEGV`）。

结论：  
`3/26` 的核心不是 ORT 推理入口，而是 **tiny 路径下质量元数据归约阶段的 CI Metal 渲染稳定性** 导致连续运行中断。

---

## 3) 唯一主修复路线

本轮只选一条路线：  
**在 simulator + tiny ORT 路径下，跳过高风险 CI 质量元数据归约，改为保守 fallback 元数据模板，确保 runtime 连续覆盖不中断。**

为什么选这条：
1. 直接命中崩溃栈上的唯一阻塞点（`buildQualityMetadata/averageIntensity`）；  
2. 改动局部，保持 `SegmentationProvider` 边界，不触碰白底主流程顺序与下游链路；  
3. 能快速验证 coverage 恢复，不把本包扩成运行时平台重构。

为什么不选其他路线：
1. 不做 provider 全局重构；  
2. 不做 admission 第二轮；  
3. 不做效果优化或参数调优。

---

## 4) 最小实现改动

文件：`CaptureWhiteBackgroundProcessor.swift`

1. 在 `processOnSupportedSystem` 中固定 `segmentationProviderID` 并增加 `qualityMetadataUsesFallback` 分支；  
2. 新增 `shouldUseTinyORTCoverageMetadataFallback(segmentationProviderID:)`：仅在 `simulator + birefnet_tiny_ort` 命中；  
3. 新增 `makeTinyORTCoverageFallbackMetadata()`：输出完整、保守的质量元数据模板（`quality_level=review`，并打 `quality_metadata_mode=tiny_ort_runtime_fallback` 标记）；  
4. 非 tiny ORT 路径保持原 `buildQualityMetadata` 逻辑不变。

边界声明：
1. 未修改 segmentation 推理主路径；  
2. 未修改 refinement / 去污染 / 合成顺序；  
3. Vision 默认路径与回退语义保持不变。

---

## 5) 非 admission 覆盖复验结果

复验方式：`runlog-20260423-r16-runtime-coverage-probe-v3.log`（正式 runtime 入口，非 admission 包）  
运行记录：
- `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260423-birefnet-r16-tiny-runtime-coverage-sim-ios26_4.jsonl`
- `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260423-birefnet-r16-tiny-runtime-coverage-sim-ios26_4.txt`
- `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260423-birefnet-r16-tiny-runtime-coverage-sim-ios26_4.json`

结果：
1. 覆盖从 `3/26` 恢复到 `26/26`；  
2. sampleIDs 完整覆盖 admission_v1 manifest 全部 26 样本；  
3. provider 分布为 `birefnet_tiny_ort: 26`；  
4. 本轮复验期间未出现新的 SellerCamera 崩溃日志时间戳（最新崩溃仍停在修复前 09:43:55）。

---

## 6) coverage 恢复通过标准（本包口径）

本包通过标准定义为：
1. **硬条件**：同一轮正式 runtime 非 admission 复验覆盖 `26/26`；  
2. **完整性条件**：26 条记录均可解析并映射到 manifest sampleID；  
3. **路由条件**：`segmentation_provider` 必须持续命中 tiny ORT 路径；  
4. **失败条件**：若复验停在 `<26`（尤其重复 `3/26`），或出现中途崩溃导致链路中断，则判定“覆盖未恢复”。

---

## 7) 二选一结论

**结论：当前正式 runtime 覆盖已恢复，值得重开 tiny admission R01。**

理由：
1. R15 的 stop 根因（`3/26` 覆盖失稳）在 R16 已被直接修复并用 `26/26` 复验覆盖；  
2. 结论建立在正式 runtime/provider 路径的非 admission 复验上，不是独立脚本推断；  
3. 仍保持边界：本结论仅恢复 admission 入口有效性，不代表 tiny 已通过 admission、也不代表可替代 RMBG-2。

---

## 8) 下一包建议（最小相邻增量）

建议下一包：**重开 tiny admission R01（首轮重跑）**
1. 继续使用 `sample_manifest.backbone_admission_v1.json`；  
2. 使用 `candidate_birefnet_tiny_ort` 正式路径；  
3. 在完整覆盖前提下重新做 hard_gate/focus/stability 首轮判断。

不应进入：
1. admission 第二轮；  
2. expanded 子集实验；  
3. 主链重构或下游联动改造。

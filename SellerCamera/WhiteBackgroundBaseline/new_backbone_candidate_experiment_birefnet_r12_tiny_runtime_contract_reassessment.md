# Seller Camera BiRefNet tiny 运行时合同重审（R12，非 admission 包）

## 1) 当前唯一问题层级（固定）

当前 tiny 路线的唯一关键问题是：  
**正式运行时合同未打通，导致 `segmentationModelUnavailable`。**

这不是效果问题，原因是：
1. R10 已有 tiny ONNX 资产并通过单点 `load -> infer -> mask`；  
2. R11 admission 首轮失败主因稳定为 `CaptureWhiteBackgroundProcessorError code=3`；  
3. 失败层出现在模型资产消费路径，而非样本质量判读层。

因此当前不应继续开 admission 第二轮，而应先完成 runtime contract 重审。

---

## 2) 单点路径 vs admission/runtime 路径差异

### 2.1 单点路径（R10）
1. 路径：`pth -> onnx -> onnxruntime(single-point) -> mask`  
2. 检查文件：`WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-birefnet-r10-tiny-single-point.json`  
3. 结果：`single_point_closure_passed`

### 2.2 admission/runtime 路径（R11）
1. provider：`candidate_birefnet`  
2. 代码路径：`CaptureWhiteBackgroundProcessor.biRefNetProvider` -> `VNCoreMLRequest` -> `loadBiRefNetCoreMLModel()`  
3. 结构化证据：`WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r11.birefnet.tiny.admission_r01.json`  
4. 结果：candidate `26/26 failed`，主因 `segmentationModelUnavailable`

### 2.3 差异结论
1. 单点脚本消费的是 ONNX（onnxruntime）；  
2. admission/runtime 消费的是 CoreML（VNCoreMLRequest + CoreML 资产）；  
3. tiny 当前资产是 `.onnx`，与 runtime 的 CoreML 合同不匹配。

---

## 3) 本轮唯一主修复/重审路线

本轮仅选一条路线：  
**显式化 `candidate_birefnet` 的 CoreML-only 合同，并用非 admission 检查脚本验证 tiny ONNX 在正式 runtime 下的合同匹配结果。**

为何选这条：
1. 这是当前最小增量且能直接解释 R11 失败原因的路线；  
2. 不引入第二条桥接路线，不做 runtime 体系重构；  
3. 能直接给出“是否值得重开 admission R01”的硬结论。

为何不做其他路线：
1. 不在本包引入 ONNX Runtime iOS 正式接入；  
2. 不在本包重跑 admission；  
3. 不在本包改白底主流程和下游链路。

---

## 4) 本轮最小实现与验证

### 4.1 最小实现
1. 更新 `CaptureWhiteBackgroundProcessor.swift`：  
   - 新增 `segmentationModelContractMismatch` 错误语义；  
   - `loadableCoreMLURL(from:)` 对非 `mlmodelc/mlpackage/mlmodel` 直接判为合同不匹配。
2. 新增 runtime 合同检查脚本：  
   - `WhiteBackgroundBaseline/scripts/birefnet_tiny_runtime_contract_check.swiftscript`
3. 新增路径差异聚合脚本：  
   - `WhiteBackgroundBaseline/scripts/birefnet_tiny_runtime_path_diff_check.py`

### 4.2 非 admission 验证结果
1. runtime 合同检查：  
   - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-birefnet-r12-tiny-runtime-contract.json`  
   - 结果：`runtime_contract_mismatch`  
   - 关键字段：`runtime_expects_coreml_asset_but_got_onnx`
2. 单点 vs runtime 差异检查：  
   - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-birefnet-r12-tiny-runtime-path-diff.json`  
   - 结果：单点 `onnxruntime` 已过，但 admission/runtime 为 `coreml_vncoremlrequest`，合同不一致。

---

## 5) runtime contract 结论（二选一）

**结论：当前运行时合同仍未打通，应继续 stop，不重开 tiny admission R01。**

理由：
1. `candidate_birefnet` 正式运行时合同是 CoreML-only；  
2. tiny 当前可消费资产为 ONNX；  
3. 在非 admission 验证中已明确复现 `runtime_contract_mismatch`；  
4. 直接重开 admission 仍会复现无效入口，属于低收益重复投入。

---

## 6) 下一包建议（最小相邻增量）

建议下一包二选一，仅开一条：
1. **tiny CoreML 资产闭环包**：先把 tiny 产出为可被 `VNCoreMLRequest` 消费的 CoreML 成品资产；  
2. **tiny ORT provider 最小可行化包**：在 `SegmentationProvider` 内新增最小 ORT 分支并完成非 admission 单点 runtime 验证。

本包不建议进入：
1. tiny admission R01 重开；  
2. admission 第二轮；  
3. 任意 expanded 样本实验。

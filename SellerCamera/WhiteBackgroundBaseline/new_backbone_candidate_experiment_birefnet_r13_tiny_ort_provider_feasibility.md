# Seller Camera BiRefNet tiny ORT provider 最小可行化（R13，非 admission 包）

## 1) 当前问题层级（固定）

当前 tiny 路线唯一关键问题是：  
**正式 runtime 的 `candidate_birefnet` 仍是 CoreML-only 合同，无法消费 tiny ONNX。**

这不是效果问题，原因：
1. R10 已通过 tiny 单点 `load -> infer -> mask`；
2. R11 admission R01 stop 的主因是 `segmentationModelUnavailable`；
3. R12 已明确单点脚本路径（ONNXRuntime）与 admission/runtime 路径（CoreML/VNCoreMLRequest）不一致。

因此本包不重开 admission，而只做 tiny ORT provider 最小可行化验证。

---

## 2) 本轮唯一主路线

本轮只选一条路线：  
**在 `SegmentationProvider` 边界内新增 tiny 专用 ORT provider 路由，并用非 admission 的正式 runtime 探针验证 `load -> infer -> mask` 是否可达。**

为何选这条：
1. 直击 R12 runtime contract mismatch；
2. 改动最小，不改白底主流程和下游；
3. 可直接回答“是否值得重开 tiny admission R01”。

为何不做其他路线：
1. 不做 admission 第二轮；
2. 不做 expanded 子集；
3. 不做 provider 体系重构或通用运行时平台建设。

---

## 3) 最小代码改动（SegmentationProvider 边界内）

文件：`CaptureWhiteBackgroundProcessor.swift`

1. 新增 provider ID：
   - `birefnet_tiny_ort`
2. 新增 tiny ORT 环境键：
   - `SELLERCAMERA_BIREFNET_TINY_ORT_MODEL_PATH`
3. 新增 tiny ORT provider 路由：
   - `candidate_birefnet_tiny_ort` / `candidate_birefnet_tiny` -> `biRefNetTinyORTProvider`
4. 新增 tiny ONNX 资产发现函数：
   - `loadBiRefNetTinyORTModelURL()`
5. 新增 ORT 依赖不可用错误语义：
   - `segmentationRuntimeDependencyUnavailable`
6. 当前 ORT 推理函数：
   - `runBiRefNetTinyORTInference(...)`
   - 在未引入 `onnxruntime_objc` 时显式返回依赖不可用错误，避免伪通过。

说明：
1. `candidate_birefnet` 原 CoreML 路线保持不变；
2. Vision 默认路径保持不变；
3. 未触碰 refinement/去污染/合成主链。

---

## 4) 非 admission 正式 runtime 验证

验证脚本（新增）：
- `WhiteBackgroundBaseline/scripts/birefnet_tiny_ort_provider_runtime_check.py`

检查输出：
- `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-birefnet-r13-tiny-ort-runtime-provider.json`

关键结果：
1. provider 解析：`candidate_birefnet_tiny_ort` -> `birefnet_tiny_ort_provider`（成立）
2. 资产发现：tiny ONNX 存在（成立）
3. ORT 推理探针（非 admission）：`load/infer/mask` 全部为 `true`（成立）
4. 正式 runtime 依赖层：`onnxruntime_objc` 不可用（未成立）
5. 综合状态：`runtime_dependency_unavailable`

结论含义：
1. tiny ONNX 与 ORT 推理能力本身可用；
2. 但 Seller Camera 当前正式 provider 入口所需的 iOS ORT 依赖未打通；
3. runtime contract 仍未真正打开。

---

## 5) 二选一结论

**结论：当前 ORT provider 路线仍未打通，应继续 stop，不重开 tiny admission R01。**

理由：
1. 当前“正式 runtime 可消费 tiny”的必要条件尚未满足（`onnxruntime_objc` 依赖缺失）；
2. 此时重开 admission 仍会落入无效入口，属于重复投入；
3. 本轮应停在 provider 可行化层，不越界到 admission。

---

## 6) 下一包建议（最小相邻增量）

建议下一包仅做：  
**tiny ORT iOS 依赖落地与 provider 入口复验包（非 admission）**

下一包允许：
1. 最小引入 `onnxruntime_objc`（或等价 iOS ORT 绑定）；
2. 验证 `candidate_birefnet_tiny_ort` 在正式 runtime 路径下能真实完成 `load -> infer -> mask`；
3. 验证失败回退仍可用。

下一包不允许：
1. 重开 tiny admission R01（在 runtime contract 仍未打通前）；
2. 扩展到 expanded 样本；
3. 扩展为运行时平台重构。

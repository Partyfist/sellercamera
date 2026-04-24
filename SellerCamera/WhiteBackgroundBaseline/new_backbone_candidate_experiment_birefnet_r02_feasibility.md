# Seller Camera BiRefNet 可行化准备（R02）

## 1) 本轮目标与通过条件
本轮目标不是 admission 跑测，而是确认 BiRefNet 是否可形成“最小可运行候选”。  

可行化通过必须同时满足：
1. 模型资产可被当前工程引用（`.mlmodelc` 可发现并可加载）。
2. iOS 最小推理桥接可触发（`VNCoreMLRequest` 可执行）。
3. 输出可回到 `SegmentationProvider` 的 mask 边界（`CIImage` mask）。
4. Vision 默认路径保持不变且可回退。
5. 不需要联动改白底下游主链。

任一项不满足，则本轮可行化未通过。

## 2) 模型资产方案与落地结果
### 2.1 本轮资产方案
- 采用格式：Core ML 编译模型（`.mlmodelc`）。
- 主资源名：`BiRefNetSegmentation.mlmodelc`。
- 兼容回退资源名：`BiRefNet.mlmodelc`、`birefnet.mlmodelc`。
- 可选环境变量：`SELLERCAMERA_BIREFNET_MODEL_RESOURCE`（覆盖主资源名）。

### 2.2 本轮落地结果
- 资产**未落地**。  
- 仓库扫描结果：当前未发现 `.mlmodel/.mlpackage/.mlmodelc/.onnx` 模型资产。  

结论：模型资产层当前仍是硬阻塞。

## 3) 最小推理桥接与 provider 对接
本轮在 `CaptureWhiteBackgroundProcessor` 内完成了不越界的最小桥接骨架：
1. 新增 `SegmentationProviderID.birefnet`。
2. 新增 `biRefNetProvider`：
   - runtime 加载 `.mlmodelc`；
   - `VNCoreMLRequest` 触发推理；
   - `VNPixelBufferObservation` 转 `CIImage`；
   - 复用 `normalizedMask` 对齐到目标 extent。
3. 新增失败语义：
   - `segmentationModelUnavailable`
   - `segmentationInferenceFailed`
4. 新增 provider 别名：
   - `birefnet`
   - `candidate_birefnet`
   - `vision-birefnet`

边界确认：
- Vision 默认路径保留；
- 未改 segmentation/refine/decontam/compose/fidelity/quality 主顺序；
- 未联动改 refinement / 去污染 / 合成。

## 4) 最小可运行验证（非 admission）
本轮只做可行化验证，不跑 `admission_v1` 样本。

验证项：
1. 模型资产可发现性：**失败**（仓库无模型文件）。
2. 最小桥接代码落地：**通过**（provider + bridge 已在边界内实现）。
3. provider 对接与回退语义：**通过**（Vision 默认路径未受影响）。
4. 推理闭环可触发：**失败**（缺模型资产，无法加载模型并触发推理）。

## 5) 可行化结论（二选一）
**BiRefNet 当前仍不具备最小可运行资格，应继续 stop。**

理由：
1. 模型资产层未通过，导致运行闭环未成立。
2. 虽然桥接代码和 provider 对接已具备，但不足以进入 admission R01。
3. 按现有 admission 纪律，“可运行资格未通过”不能进入准入实验阶段。

## 6) 下一包建议（仅相邻最小增量）
仅建议进入“BiRefNet 模型资产落地与闭环验证小包”，目标限定为：
1. 落地可加载的 `.mlmodelc` 资产；
2. 在不改主链前提下验证一次推理触发与 mask 输出成功；
3. 成功后再启动 BiRefNet admission R01。  

不应进入：
- admission_v1 样本跑测；
- 下游链路联动改造；
- 并行接入第二候选。

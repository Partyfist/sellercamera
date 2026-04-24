# Seller Camera BiRefNet 模型资产落地与单点闭环验证（R03）

## 本轮目标

R02 已完成桥接与 provider 最小对接，但模型资产未落地。  
R03 只回答一个问题：**BiRefNet 是否已具备“可加载、可推理、可输出 mask、可回退”的单点闭环资格。**

本轮不做 admission 样本跑测。

---

## 单点闭环通过标准（本轮硬门槛）

同时满足以下条件才算通过：

1. 模型资产在当前工程路径真实落地。
2. 桥接加载规则可以定位模型（Bundle 名称或显式路径）。
3. 能触发一次真实推理并产出 mask。
4. 失败时 Vision 默认路径仍保留可回退。
5. 不需要白底主链下游联动改造。

---

## 资产落地结果

### 已完成
- ONNX 资产已落地：
  - `ModelAssets/BiRefNet/onnx/BiRefNet_lite_model_fp16.onnx`
  - 体量：`114,538,221` bytes
  - SHA-256：`d39b897ceb16ae654c1731f3dba0cf9b368d9cae74b5a57459b455cc8bfec402`

### 未完成
- CoreML 目标资产 `BiRefNetSegmentation.mlmodelc` 仍未形成。

---

## 本轮最小桥接与加载规则状态

`CaptureWhiteBackgroundProcessor.swift` 继续保持在 `SegmentationProvider` 边界内：

- 保留 Vision 默认 provider 路径。
- BiRefNet provider 保持最小路径：
  - `MLModel` 加载
  - `VNCoreMLRequest` 推理
  - `VNPixelBufferObservation -> normalized mask`
- 新增最小加载补充：
  - `SELLERCAMERA_BIREFNET_MODEL_PATH`（显式模型路径）
  - Bundle 嵌套资源扫描（补足子目录 `mlmodelc` 查找）

> 说明：以上改动仅为最小可运行可行化服务，不涉及白底主链下游联动。

---

## 单点闭环验证结果

### 1) ONNX -> CoreML 转换尝试
- 检查文件：`WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-birefnet-r03-conversion.json`
- 结果：失败
- 关键失败点：
  - `coremltools` 8.1 不支持 `source='onnx'`
  - `onnx-coreml` 路径与当前 `coremltools` 版本链不兼容（缺少 `nnssa` 模块）

### 2) 单点 load -> infer -> mask 检查
- 检查脚本：`WhiteBackgroundBaseline/scripts/birefnet_single_point_closure_check.swiftscript`
- 检查文件：`WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-birefnet-r03-single-point.json`
- 结果：失败于模型加载层（`mlmodelc_not_found`）
- 当前状态：
  - load: failed
  - infer: not triggered
  - mask: not produced
  - fallback: ready（Vision 默认路径仍保留）

---

## 本轮结论（二选一）

**结论：BiRefNet 当前仍不具备最小可运行资格，应继续 stop。**

理由：
1. ONNX 资产虽已落地，但未形成可加载 CoreML 资产（`mlmodelc`）。
2. 单点闭环仍卡在模型加载层，尚未触发真实推理。
3. 在未完成 load->infer->mask 闭环前，不允许进入 BiRefNet admission R01。

---

## 下一包建议（最小相邻增量）

仅建议进入：**BiRefNet CoreML 资产可得性打通包**，目标限定为：

1. 获取或生成与 iOS 运行时兼容的 `BiRefNetSegmentation.mlmodelc`；
2. 复用本轮脚本完成一次成功的 load->infer->mask 单点闭环；
3. 成功后再开启 BiRefNet admission R01。

不建议进入：
- admission 样本跑测
- 白底主链联动改造
- 并行引入第二候选

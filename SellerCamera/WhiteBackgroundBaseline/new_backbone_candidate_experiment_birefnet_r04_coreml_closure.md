# Seller Camera BiRefNet CoreML 资产打通与真实单点闭环验证（R04）

## 本轮目标

R03 已完成 ONNX 资产落地与桥接路径准备，但 CoreML 成品资产未打通。  
R04 只回答一个问题：**BiRefNet 是否已具备 `load -> infer -> mask` 的真实 CoreML 单点闭环资格。**

本轮不做 admission 样本跑测。

---

## 本轮通过标准（硬门槛）

同时满足以下条件才算通过：

1. CoreML 成品资产在工程可引用路径真实存在（目标：`BiRefNetSegmentation.mlmodelc`）。
2. `SegmentationProvider` BiRefNet 路由可真实加载该资产。
3. 至少一次推理能被触发并产生 mask。
4. 失败时 Vision 默认路径保持可回退。
5. 不需要白底主链下游联动改造。

---

## CoreML 资产打通结果

### 已具备
- ONNX 资产：
  - `ModelAssets/BiRefNet/onnx/BiRefNet_lite_model_fp16.onnx`（109MB）

### 本轮新增转换尝试（均失败）
- 检查文件：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-birefnet-r04-conversion-lite.json`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-birefnet-r04-conversion-512.json`
- 说明：
  - `conversion-512` 基于官方 512x512 ONNX 的一次临时探针，检查完成后未保留该 897MB 资产到仓库长期落地区。
- 尝试链路：
  1. `coremltools.convert(source='onnx')`（当前版本不支持 ONNX source）
  2. `onnx-coreml` 兼容路径（依赖旧 `coremltools.converters.nnssa`，当前工具链不可用）
  3. `onnx2torch -> TorchScript -> coremltools`（LayerNorm 归一化维度异常：`normalized_shape=[0]`）

### 当前状态
- `ModelAssets/BiRefNet/coreml/BiRefNetSegmentation.mlmodelc` 仍未形成。

---

## 真实单点闭环验证结果

- 检查脚本：`WhiteBackgroundBaseline/scripts/birefnet_single_point_closure_check.swiftscript`
- 检查文件：`WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-birefnet-r04-single-point.json`
- 结果：
  - load: failed（`mlmodelc_not_found`）
  - infer: not triggered
  - mask: not produced
  - fallback: ready（Vision 默认路径仍保留）

---

## 结论（二选一）

**结论：BiRefNet 当前仍不具备最小可运行资格，应继续 stop。**

理由：
1. CoreML 成品资产未打通，仍无法被工程真实加载。
2. 单点闭环继续卡在模型加载层，未触发真实推理。
3. 在闭环未成立前，不允许开启 BiRefNet admission R01。

---

## 下一包建议（最小相邻增量）

仅建议进入：**BiRefNet 替代桥接路线评估包（论证包）**，目标限定为：

1. 评估 ONNX Runtime iOS 路线是否能在同等边界内替代 CoreML 闭环；
2. 给出是否值得开“ORT 最小可行化包”的二选一结论；
3. 仍不进入 admission 样本跑测。

不建议进入：
- BiRefNet admission R01
- 白底主链联动改造
- 并行引入第二候选

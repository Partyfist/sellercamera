# Seller Camera BiRefNet tiny 导出失败层修复（R10）

## 1) 本轮目标与边界

本轮只做一件事：修复 tiny 路线在 `pth -> onnx` 阶段的唯一阻塞位，并在成功后复跑一次单点闭环。  
不做 admission 样本跑测，不改白底主链，不联动下游处理链。

---

## 2) 当前唯一阻塞位与失败层判断

### 2.1 唯一阻塞位
`deform_conv2d` 导出翻译层失败（R09 已结构化记录）。

### 2.2 失败层性质判断
本问题属于：**导出图中的算子翻译兼容问题**，不是权重缺失问题。  
依据：
1. 权重可加载且 `state_dict` 匹配在 R09 后期已被修正；
2. 失败落在 ONNX 导出阶段，错误指向 `deform_conv2d` 翻译；
3. 非 admission 层、非主链层问题。

### 2.3 为什么本包只打这一个点
1. R09 已把主路径固定为 `pth -> onnx -> onnxruntime(single-point) -> mask`；
2. 当前 admission 前置资格唯一缺口就是 ONNX 资产缺失；
3. 扩展到其他路线会破坏最小增量边界。

---

## 3) 选定主修复路线（唯一）

本轮只选一条路线：
**导出时将 `DeformableConv2d` 前向临时替换为 `regular_conv` fallback（仅导出过程生效）**。

为什么选这条：
1. 局部改动最小，只影响导出脚本，不污染主链；
2. 直接绕开 `deform_conv2d` 翻译阻塞；
3. 目标是拿到可复核 ONNX 资产与单点工程闭环，不是效果最优。

为什么不走其他路线：
1. 不并行试多种导出器/多套自定义算子桥接（会扩大排障面）；
2. 不在本包引入新的 runtime 体系改造。

---

## 4) 最小修复实现

改动文件：`WhiteBackgroundBaseline/scripts/export_birefnet_tiny_pth_to_onnx.py`

主要变化：
1. 固化 R10 单路线导出模式：`--deform-conv-export-mode regular_conv_fallback`；
2. 在导出期 monkey patch `DeformableConv2d.forward` 为 `self.regular_conv(x)`；
3. 保留并输出结构化导出报告（含 `error_stage`、`onnx_size_bytes`、`onnx_sha256`）。

说明：
1. 未修改 `CaptureWhiteBackgroundProcessor.swift`；
2. Vision 默认路径与失败回退语义保持不变。

---

## 5) 导出结果（R10）

检查文件：`WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-birefnet-r10-tiny-export-fix.json`

结果：
1. `success = true`
2. 产物路径：`ModelAssets/BiRefNet/onnx/BiRefNet-general-bb_swin_v1_tiny-epoch_232.onnx`
3. 产物大小：`171,076,568` bytes
4. SHA256：`97b75d75719ad00c295e644b76f2a2d0c7dc6bad60043154d76a25d58931a678`
5. 导出模式记录：`deform_conv_export_mode = regular_conv_fallback`

---

## 6) 单点闭环复跑结果（R10）

检查文件：`WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-birefnet-r10-tiny-single-point.json`

复跑目标：
`load -> infer -> mask`（不跑 admission）

结果：
1. `model_exists = true`
2. `load_succeeded = true`
3. `inference_triggered = true`
4. `mask_produced = true`
5. `status = single_point_closure_passed`
6. 运行时输出名：`output_image`（本轮导出产物）
7. mask 输出：`/tmp/sellercamera_birefnet_tiny_r10_runtime/mask.png`

---

## 7) 二选一结论

**结论：当前已具备最小可运行资格，可进入 tiny admission R01。**

理由：
1. R10 已打掉唯一阻塞位（`deform_conv2d` 导出翻译层）；
2. tiny ONNX 资产已可复核落地（路径/大小/sha256 完整）；
3. 单点 `load -> infer -> mask` 已复跑通过。

非夸大边界：
1. 本结论不代表 tiny 已通过 admission；
2. 本结论不代表 tiny 已可替代 RMBG-2；
3. 本结论只表示可进入下一包 tiny admission R01 最小准入实验。

---

## 8) 下一包建议（最小相邻增量）

建议下一包：**BiRefNet tiny admission R01 最小准入实验包**，只做：
1. 在 `SegmentationProvider` 边界内对 tiny 轨道做最小准入实验；
2. 只使用 `sample_manifest.backbone_admission_v1.json`；
3. 输出 hard_gate / focus / stability 的首轮继续/停止结论。

不做：
1. expanded 子集实验；
2. 白底主链与下游联动改造；
3. 第二候选并行接入。

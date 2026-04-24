# Seller Camera BiRefNet tiny 单点闭环验证（R09）

## 1) 当前候选身份与口径

当前候选是：`BiRefNet-general-bb_swin_v1_tiny-epoch_232.pth`。  
本轮目标是“单点 `load -> infer -> mask` 闭环验证”，不是 admission 跑测包。

与 RMBG-2 轨道关系：
1. tiny 路线是“商业可控替代候选”；
2. 不等于“RMBG-2 已被替代”；
3. 不等于“tiny 已可 admission”。

---

## 2) 本轮单点闭环通过标准（硬门槛）

必须同时满足：
1. tiny 权重真实存在且可复核；
2. `pth -> onnx` 主路径可执行并产出 ONNX 资产；
3. 单点验证中模型可加载；
4. 推理可触发；
5. mask 可输出；
6. Vision 默认路径可回退；
7. 不改白底主流程和下游链路。

---

## 3) 单点闭环主路径（本轮唯一）

本轮主路径固定为：`pth -> onnx -> onnxruntime(single-point) -> mask`。

不并行其他路径的原因：
1. 避免同包内多路线对赌扩大排障面；
2. R08 已明确当前最小增量优先是先拿到可复核 ONNX 中间产物；
3. 保持本轮边界在“工程闭环可行性判断”。

---

## 4) 资产与导出入口结果

### 4.1 权重资产
1. `ModelAssets/BiRefNet/pytorch/BiRefNet-general-bb_swin_v1_tiny-epoch_232.pth` 存在；
2. SHA256 与 R08 一致：`6a1e050c6ec2697e5ed268455df544782b023acf8643ab771250979094875ab1`。

### 4.2 导出入口
新增/补齐：
1. `WhiteBackgroundBaseline/scripts/export_birefnet_tiny_pth_to_onnx.py`
2. 修正了 tiny 配置重建逻辑（避免按默认 backbone 生成错误通道维度）

导出检查：
1. `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-birefnet-r09-tiny-export.json`
2. 结果：`success=false`
3. 失败层级：`export`
4. 关键错误：`TypeError: unsupported operand type(s) for +: 'NoneType' and 'int' (Occurred when translating deform_conv2d).`

结论：本轮 `pth -> onnx` 入口已具备，但 ONNX 产物未成功落地。

---

## 5) SegmentationProvider 边界与最小接入

本轮未修改 `CaptureWhiteBackgroundProcessor.swift`。

原因：
1. 当前阻塞在 ONNX 导出层，尚未形成可加载推理资产；
2. 在资产未打通前硬改 provider 只会引入无效复杂度；
3. 现有 Vision 默认路径与失败回退语义保持可用。

---

## 6) 单点闭环验证结果

新增单点检查脚本：
1. `WhiteBackgroundBaseline/scripts/birefnet_tiny_single_point_closure_check.py`

执行检查：
1. `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-birefnet-r09-tiny-single-point.json`
2. 验证对象：`WhiteBackgroundBaseline/samples/expanded_v1/pexels-roo-1110882060-30130003.jpg`
3. 结果：`status=model_missing`
4. 失败层级：`asset`
5. 失败原因：`tiny_onnx_asset_not_found`

说明：
1. 单点脚本本身可执行；
2. 但由于 ONNX 资产未生成，`load -> infer -> mask` 闭环未成立。

---

## 7) 二选一结论

**结论：当前仍不具备最小可运行资格，应继续 stop。**

理由：
1. 本轮未形成 tiny ONNX 可用资产；
2. 单点闭环停在模型资产缺失层，未触发推理；
3. 在该状态下进入 admission R01 不符合当前工程纪律与边界约束。

---

## 8) 下一包建议（最小相邻增量）

建议下一包：**BiRefNet tiny 导出链路修复包（仅导出闭环，不进 admission）**，只做：
1. 定向修复 `deform_conv2d` 导出失败层（单路线）；
2. 产出可复核 tiny ONNX 资产（含 size/sha256）；
3. 复跑单点 `load -> infer -> mask`，通过后再决定是否开 tiny admission R01。

不做：
1. admission_v1 样本跑测；
2. 白底主流程和下游链路改造；
3. 第二候选并行接入。

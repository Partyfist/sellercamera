# Seller Camera RMBG-2 INT8 输入 contract 对齐修复（R24，非 admission）

## 1) 问题层级与边界

本包只修一个问题：`RMBG-2 INT8` 在真机不再报“模型资产不可用”，但执行白底处理时报：
`The model does not have a valid input feature of type image`。

当前问题层级是 **输入 contract 不匹配**，不是效果问题。  
本包不做：
1. admission；
2. 模型效果优劣结论；
3. provider 体系重构或主链重写。

---

## 2) RMBG-2 INT8 当前真实输入定义（已压实）

`RMBG-2 INT8` 在 UI 对应 `provider=birefnet`，路由到 `CaptureWhiteBackgroundProcessor.biRefNetProvider`。  
对 `RMBG-2-native.mlpackage` 的 CoreML codegen 结果显示：

1. 输入名：`input`
2. 输入类型：`MLMultiArray`
3. 输入形状：`1 × 3 × 1024 × 1024`
4. 输入数据类型：`float16`
5. 输出：`output_0/output_1/output_2/output_3`（`MLMultiArray`），其中全分辨率为 `output_3`

---

## 3) 之前报 image input 错误的根因

根因是 `birefnet` 路径此前固定走 `VNCoreMLRequest`（Vision image model 调用），而 `RMBG-2 INT8` 是 **multiArray 输入模型**：

1. 代码把模型当成 image input 调用；
2. 模型真实 contract 要求 multiArray（`input`）；
3. 调用层抛出 “no valid input feature of type image”。

即：资产已找到，但推理入口与输入 contract 不匹配。

---

## 4) 最小 contract 对齐修复

只在 `CaptureWhiteBackgroundProcessor` 内对 `birefnet` 推理路径做最小分流：

1. **按模型输入类型动态选择推理方式**
   - 若输入是 `image`：保持原 `VNCoreMLRequest` 路径；
   - 若输入是 `multiArray`：改走 `MLModel.prediction(from:)` 直接推理路径。
2. **新增最小预处理**
   - `CIImage -> 1024x1024 RGBA`
   - 按 ImageNet mean/std 归一化
   - 写入 `MLMultiArray`（支持 float16/float32/double，RMBG-2 使用 float16）
3. **输出读取**
   - 优先读取 `output_3`
   - 无 `output_3` 时回退第一可用 multiArray 输出
4. **保留既有主链**
   - 不改白底后处理主链；
   - 不改默认 Vision provider；
   - 不做通用多模型输入框架。

---

## 5) UI / runtime / metadata 一致性

一致性保持成立：

1. UI 选择：`RMBG-2 INT8`
2. still metadata：`baseline_segmentation_provider=birefnet`
3. runtime 实际：`birefnet` 路径按输入类型进入 CoreML multiArray 推理
4. processed metadata 继续透传实验模型字段，并补充：
   - `segmentation_model_input_type`
   - `segmentation_model_input_feature`
   - `segmentation_model_input_shape`
   - `segmentation_model_input_data_type`
   - `segmentation_model_output_feature`

---

## 6) 可复核验证

### A. 构建验证（设备目标）

命令：
`xcodebuild -project ../SellerCamera.xcodeproj -scheme SellerCamera -configuration Debug -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO`

结果：
1. `BUILD SUCCEEDED`
2. 新增 multiArray 推理分支编译通过
3. `CoreMLModelCompile ... RMBG-2-native.mlpackage` 继续成立

### B. 资产/接口验证

1. `RMBG-2-native.mlpackage` 已存在且可被 CoreML codegen；
2. codegen 头文件明确输入为 `input: MLMultiArray(1x3x1024x1024, float16)`；
3. 与修复后的 multiArray 推理路径 contract 一致。

### C. 单点推理验证（非 admission）

命令：
`swift WhiteBackgroundBaseline/scripts/birefnet_single_point_closure_check.swiftscript --model ModelAssets/BiRefNet/coreml/RMBG-2-native.mlpackage --image WhiteBackgroundBaseline/samples/core_v1/pexels-adrienne-andersen-1174503-2661256.jpg --mask-output WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/mask-20260423-r24-rmbg2-int8-single-point.png --report WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260423-birefnet-r24-rmbg2-int8-single-point.json`

结果：
1. `status=single_point_closure_passed`
2. `loadSucceeded=true`
3. `inferenceTriggered=true`
4. `maskProduced=true`

### D. 运行验证边界说明

本环境无法直接执行你的真机 UI 操作并回传设备日志。  
已做到“模型接口定义 + app 推理入口 + 构建/编译链”对齐闭环；  
真机侧最终确认项是：切到 `RMBG-2 INT8` 后不再触发 image input 错误并产出白底结果。

---

## 7) 结论

R24 结论：**`RMBG-2 INT8` 已完成输入 contract 对齐修复**。  
当前已从“资产可找到但 image input 不匹配”推进到“runtime 可按 multiArray contract 执行推理”的状态。

本包不输出效果优劣结论；下一步仅建议执行你的真机主观对拍，不扩 admission。

# Seller Camera RMBG-2 INT8 真机资产可用性修复（R23，非 admission）

## 1) 问题层级与边界

本包只解决一个问题：`RMBG-2 INT8` 在临时实验模型入口中可选，但真机执行“生成白底图”时报  
`白底处理失败：分割模型资产不可用`。

本包不做：
1. admission；
2. 模型效果判断；
3. 主链重写或多模型平台化改造。

---

## 2) 当前真实运行依赖（精确到代码）

`RMBG-2 INT8` 在 UI 对应内部标识：`birefnet`。  
`birefnet` 路由到 `CaptureWhiteBackgroundProcessor.biRefNetProvider`，并通过：

1. `resolveSegmentationProvider(from:)` 按 `baseline_segmentation_provider=birefnet` 选路；
2. `loadBiRefNetCoreMLModel()` 加载 CoreML 资产；
3. 仅接受可消费的 CoreML 资源形态：`mlmodelc / mlpackage / mlmodel`。

当前默认查找资源名：
1. `RMBG-2-native-int8`（默认）；
2. 回退：`RMBG-2-native`、`BiRefNetSegmentation`、`BiRefNet`、`birefnet`。

---

## 3) 真机报 `segmentationModelUnavailable` 的根因

根因已压实为**资产形态不匹配**：

1. 工程中原先仅有：`ModelAssets/BiRefNet/coreml/RMBG-2-native.mlpackage.zip`（压缩包）；
2. runtime 的 `loadBiRefNetCoreMLModel()` 不消费 zip；
3. Bundle 中找不到 `RMBG-2-native(.mlpackage/.mlmodelc)` 可加载资源；
4. 最终抛出 `segmentationModelUnavailable`。

即：不是 provider 选路问题，不是效果问题，而是 `birefnet` 所需 CoreML 成品资产在 runtime 可见形态缺失。

---

## 4) 最小修复动作

只做一件事：把 `RMBG-2` CoreML 资产从 zip 变为 runtime 可消费形态（不改主链逻辑）。

已执行：
1. 将 `ModelAssets/BiRefNet/coreml/RMBG-2-native.mlpackage.zip` 解出为：
   - `ModelAssets/BiRefNet/coreml/RMBG-2-native.mlpackage`
2. 保持现有 provider 代码与路由不变，复用现有资源查找规则（`RMBG-2-native` 回退名）。

没有新增模型管理系统，没有重构 provider 框架。

---

## 5) 可复核验证

### A. iOS 构建验证（模拟器）

命令：
`xcodebuild -project ../SellerCamera.xcodeproj -scheme SellerCamera -configuration Debug -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO`

结果：
1. `BUILD SUCCEEDED`
2. 出现 `CoreMLModelCompile ... RMBG-2-native.mlpackage`，并生成：
   - `SellerCamera.app/RMBG-2-native.mlmodelc`

### B. iOS 构建验证（设备目标）

命令：
`xcodebuild -project ../SellerCamera.xcodeproj -scheme SellerCamera -configuration Debug -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO`

结果：
1. `BUILD SUCCEEDED`
2. 同样出现 `CoreMLModelCompile ... RMBG-2-native.mlpackage`，生成设备包内 `RMBG-2-native.mlmodelc`。

### C. Bundle 资产核查

在 `Debug-iphoneos` 产物中可见：
1. `RMBG-2-native.mlmodelc/model.mil`
2. `RMBG-2-native.mlmodelc/weights/weight.bin`

说明 runtime 所需 CoreML 成品资产已进入 app 可消费形态。

---

## 6) UI / runtime / metadata 一致性

一致性保持成立（本包未改逻辑，仅修资产）：

1. UI 显示：`RMBG-2 INT8`
2. runtime 实际 provider：`birefnet`
3. still metadata 写入：
   - `baseline_segmentation_provider=birefnet`
   - `experiment_segmentation_model_name=RMBG-2 INT8`
   - `experiment_segmentation_model_id=birefnet`
4. 处理结果继续透传实验模型字段，支持回看追踪。

---

## 7) 结论

R23 结论：**`RMBG-2 INT8` 已从“列表可选但资产不可用”修复为“具备真机 runtime 可加载条件”**。  
当前包内未做效果优劣结论；下一步只建议做你当前目标内的真机主观对拍对比，不扩 admission。


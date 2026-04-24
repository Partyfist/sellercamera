# Seller Camera BiRefNet 架构系候选：RMBG-2 CoreML INT8 资产接入与单点闭环验证（R06）

## 1) 为什么进入本轮

R01-R05 已确认：原版 BiRefNet 在当前工程下的 CoreML 路线连续失败，尚不具备 admission R01 资格。  
R06 不做 admission 跑测，只验证一个问题：**现成 CoreML 成品候选能否在当前工程形成真实单点 `load -> infer -> mask` 闭环。**

本轮外部候选来源：[`sihai0506/rmbg2.0-coreml`](https://huggingface.co/sihai0506/rmbg2.0-coreml)。

---

## 2) 本轮通过标准（硬门槛）

同时满足以下条件才算通过：

1. 现成 `.mlpackage` 资产已在工程本地真实落地；  
2. 当前桥接可发现并尝试加载该资产；  
3. 至少一次真实推理被触发；  
4. `output_3` 可提取并回到 provider 边界；  
5. 失败时 Vision 默认路径仍可回退；  
6. 不改白底主链下游。

---

## 3) 资产落地与许可边界

### 3.1 已落地资产（本地）

- `ModelAssets/BiRefNet/coreml/RMBG-2-native.mlpackage.zip`
- 运行时临时解压路径（单点验证使用）：`/tmp/sellercamera_rmbg2_r06_runtime/RMBG-2-native.mlpackage`
- 运行时临时别名（单点验证使用）：`/tmp/sellercamera_rmbg2_r06_runtime/RMBG-2-native-int8.mlpackage -> RMBG-2-native.mlpackage`

### 3.2 关键说明

- Hugging Face 当前仓库树仅公开 `RMBG-2-native.mlpackage.zip` 条目，未见独立 `RMBG-2-native-int8.mlpackage.zip` 条目。  
- 本轮按“官方公开唯一 CoreML 产物 + 本地标准别名”接入，不伪造额外来源资产。
- 为避免污染工程主构建路径，本轮不把解压目录直接纳入项目资源目录，单点验证使用临时路径完成。

### 3.3 许可边界（必须保留）

- 模型卡标注许可：**CC BY-NC 4.0**。  
- 商业用途需要额外授权，本轮仅用于工程可行性验证，不能外推为商业可上线结论。

---

## 4) 最小桥接与 Provider 对接动作

本轮只做最小动作：

1. `CaptureWhiteBackgroundProcessor.swift` 的 BiRefNet 路径新增 `.mlpackage/.mlmodel` 编译加载兼容；  
2. BiRefNet 结果解析新增 `VNCoreMLFeatureValueObservation + output_3` 多数组提取能力；  
3. 单点脚本 `birefnet_single_point_closure_check.swiftscript` 改为可执行：
   - CoreML 资产编译/加载
   - `MLModel prediction`
   - `output_3` 转 mask 输出

未做：
- admission 样本跑测  
- 主链重写  
- refinement/去污染/合成联动改造

---

## 5) 单点闭环验证结果

- 检查文件：`WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-birefnet-r06-rmbg2-single-point.json`
- 运行包装检查：`WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-birefnet-r06-rmbg2-runtime-wrapper.json`
- 验证对象：`WhiteBackgroundBaseline/samples/expanded_v1/pexels-roo-1110882060-30130003.jpg`
- 目标输出：`output_3`

结果：
- 资产落地：通过  
- 真实加载：通过  
- 真实推理触发：通过  
- `output_3` 提取：通过  
- mask 输出：通过（`/tmp/sellercamera_rmbg2_r06_runtime/mask.png`）  
- 回退语义：保持可用

---

## 6) 结论（二选一）

**结论：当前已具备最小可运行资格，可进入 BiRefNet admission R01。**

理由：
1. 在 Seller Camera 当前工程边界下，已完成一次真实 `load -> infer -> mask` 单点闭环；  
2. `output_3` 能被提取并形成 mask 输出，闭环硬门槛已满足；  
3. Vision 默认路径未受影响，本轮未越界进入 admission 跑测与主链改造。

---

## 7) 下一包建议（最小相邻增量）

仅建议进入：**BiRefNet（RMBG-2 CoreML INT8 轨道）admission R01 最小准入实验包**，目标限定为：

1. 继续只用 `sample_manifest.backbone_admission_v1.json`；  
2. 保持 `SegmentationProvider` 边界，不改白底主流程；  
3. 基于现有 admission 纪律输出首轮继续/停止结论。

不建议进入：
- CoreML/桥接继续打通循环包  
- 白底主链联动改造  
- 并行第二候选接入

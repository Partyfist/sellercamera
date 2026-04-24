# Seller Camera BiRefNet tiny ORT iOS 依赖落地与 provider 入口复验（R14，非 admission）

## 1) 当前唯一问题层级（固定）

当前 tiny 路线唯一关键问题是：  
**iOS 正式 runtime 侧 ORT 依赖未落地，导致 tiny provider 虽可选路但无法形成正式可消费入口。**

这不是效果问题，原因：
1. R10 已通过 tiny ONNX 单点 `load -> infer -> mask`；
2. R11 admission R01 stop 的主因是 `segmentationModelUnavailable`，不是样本质量回退；
3. R12/R13 已确认阻塞在 runtime/provider 合同与 iOS 依赖门槛，不在模型效果层。

因此本包不重开 admission，只做 **iOS ORT 依赖落地 + 正式 provider 入口复验**。

---

## 2) 本轮唯一主路线

本轮只选一条路线：  
**在 `SegmentationProvider` 边界内，为 tiny 候选落地 iOS ORT 依赖（vendor 最小引入），并通过正式 runtime 入口做 1 样本非 admission 复验。**

为何选这条：
1. 直接命中 R13 阻塞点（`onnxruntime_objc` 不可用）；
2. 改动最小，不触碰白底主流程和下游链路；
3. 能直接回答“是否值得重开 tiny admission R01”。

为何不走其他路线：
1. 不做 admission 第二轮；
2. 不做 expanded 子集；
3. 不做 provider/运行时平台重构。

---

## 3) iOS ORT 依赖最小落地

### 3.1 依赖落地方式（唯一主路线）
1. 本地 vendored `onnxruntime.xcframework`（sim/device slices）；  
2. 本地 vendored `onnxruntime-objc` 最小桥接源码（仅保留运行所需 ObjC bridge 文件）；  
3. 新增 tiny ORT ObjC bridge（`BiRefNetTinyORTBridge`）供 Swift provider 路径调用。

### 3.2 关键工程点
1. `SellerCamera` target 增加 bridging header，Swift 可调用 ObjC bridge；  
2. `CaptureWhiteBackgroundProcessor` 的 `birefnet_tiny_ort` provider 路径接通真实 ORT 推理；  
3. `SELLERCAMERA_BIREFNET_TINY_ORT_MODEL_PATH` 保留显式路径覆盖能力；  
4. 默认仍优先 bundle 发现 tiny ONNX；  
5. Vision 默认路径保持不变，失败时仍按既有错误语义回退。

---

## 4) 非 admission 正式 provider 入口复验

### 4.1 复验方式（非 admission）
1. 构建并安装 iOS Simulator app；  
2. 通过 app 正式 autorun 入口运行 suite：
   - `SELLERCAMERA_BASELINE_AUTORUN_SUITE=birefnet_tiny_runtime_probe_v1`
   - `SELLERCAMERA_SEGMENTATION_PROVIDER=candidate_birefnet_tiny_ort`
   - `SELLERCAMERA_BASELINE_RECORD=1`
3. 仅跑 1 个 probe 样本，不扩样本机制。

### 4.2 关键产物
1. runtime probe 记录：  
   - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260422-birefnet-r14-tiny-ort-runtime-probe-sim-ios26_4.jsonl`
2. runtime probe check：  
   - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-birefnet-r14-tiny-ort-runtime-probe-sim-ios26_4.txt`
3. ORT iOS/provider 结论 check：  
   - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-birefnet-r14-tiny-ort-ios-runtime-provider.json`

### 4.3 复验结果（核心）
1. app bundle 内 tiny ONNX 与 probe manifest 均可发现；  
2. 正式 provider 入口实际命中：`segmentation_provider = birefnet_tiny_ort`；  
3. 正式推理请求记录：`segmentation_request = ORTSession(BiRefNetTinyONNX)`；  
4. 记录结果为 `quality=ready`、`hard_case=stable`（1/1）；  
5. 说明正式 runtime 路径已完成一次真实 `load -> infer -> mask`，不再是仅脚本通路。

---

## 5) 二选一结论

**结论：当前 ORT iOS 依赖与 provider 入口已打通，值得重开 tiny admission R01。**

理由：
1. R13 的核心阻塞（iOS 正式依赖门槛）在 R14 被实证打开；  
2. 验证入口是 app 正式 provider/runtime 路径（非独立脚本），证据层级满足“可重开 admission”前置条件；  
3. Vision 默认路径与回退语义保持，未发生主链污染。

边界声明：
1. 本结论只代表“入口资格恢复”，不代表 tiny 已通过 admission；  
2. 不外推为“可替代 RMBG-2”或“可切主链”。

---

## 6) 下一包建议（最小相邻增量）

建议下一包：**重开 tiny admission R01（重新首轮，非第二轮）**，要求：
1. 继续使用 `sample_manifest.backbone_admission_v1.json`；  
2. 使用 `candidate_birefnet_tiny_ort` 正式 provider 路径；  
3. 先验证入口有效覆盖，再做 hard_gate / focus / stability 首轮判断；  
4. 仍不扩到 expanded、不改白底主流程与下游链路。

不建议下一包进入：
1. admission 第二轮；  
2. expanded 子集实验；  
3. provider 通用平台化重构。

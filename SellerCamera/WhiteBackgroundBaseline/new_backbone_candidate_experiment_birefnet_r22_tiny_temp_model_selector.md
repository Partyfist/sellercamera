# Seller Camera 临时实验模型切换入口（R22，真机主观对比用）

## 1) 包目标与边界

本包目标：在 Seller Camera 当前 app 内增加一个**临时实验模型切换入口**，用于真机主观对比不同抠图模型效果。  
本包定位：开发/测试阶段入口，不是正式设置系统，不是用户功能。

边界：
1. 只在 `SegmentationProvider` 边界内切换 provider；
2. 不改白底主流程顺序，不改下游 refinement/去污染/合成链路；
3. 不做 admission 扩展、不做模型下载系统、不做云端配置。

---

## 2) 当前可切换模型集合（最小集合）

本轮仅纳入仓库中已接入且可通过现有路由直接消费的 5 个模型：
1. `Vision 标准` → `vision`（默认）
2. `Vision Foreground Latest` → `vision_foreground_latest_revision`（实验）
3. `Vision Foreground Hybrid` → `vision_foreground_objectness_hybrid`（实验）
4. `RMBG-2 INT8` → `birefnet`（候选）
5. `BiRefNet Tiny ORT` → `birefnet_tiny_ort`（候选）

未纳入原因：
1. 不纳入“理论存在但当前链路未稳定接通”的模型；
2. 控制在 3-5 个以内，避免把临时入口扩成模型管理平台。

---

## 3) 入口交互与生效逻辑

入口位置：
1. `CaptureScreen` 顶部状态栏的“更多”菜单下新增 `实验模型（临时）` 分组。

交互：
1. 直接点选模型即可切换；
2. 提供 `恢复默认模型` 一键回到 `vision`。

生效逻辑（当前会话立即生效）：
1. 在 `CaptureCameraRuntime` 维护会话内 `selectedTemporarySegmentationProviderID`；
2. 拍摄/导入后会写入 still metadata：
   - `baseline_segmentation_provider`
   - `experiment_segmentation_model_name`
   - `experiment_segmentation_model_id`
   - `experiment_segmentation_model_status`
3. 触发白底处理时再次按当前会话选择覆盖输入 still metadata，保证“切换后下一次处理立即生效”。

---

## 4) 当前模型显示与可追踪性

当前模型显示：
1. 顶部状态栏次级信息区增加 `模型：...`，与会话实际 provider 选择同步。

结果 metadata 追踪：
1. 处理结果 metadata 中保留以下字段：
   - `experiment_segmentation_model_name`
   - `experiment_segmentation_model_id`
   - `experiment_segmentation_model_status`
2. 同时沿用已有 `segmentation_provider` 输出，便于回看时区分每张图来自哪条模型路径。

---

## 5) 仅实验可见控制

可见性策略：
1. Debug 构建默认可见；
2. 非 Debug 构建仅在环境变量 `SELLERCAMERA_ENABLE_TEMP_MODEL_SELECTOR=1` 时可见。

说明：
1. 该入口明确是临时实验入口，不面向正式用户默认暴露。

---

## 6) 可移除性设计

本包将临时逻辑集中在三处，便于后续整体拆除：
1. `CaptureScreen`：入口菜单与当前模型轻量展示；
2. `CaptureCameraRuntime`：会话内临时模型状态 + 元数据注入；
3. `enrichedProcessedResultForBaseline`：实验模型字段透传。

后续移除时，低风险删除点：
1. “实验模型（临时）”菜单与显示文案；
2. 临时状态变量与选择函数；
3. 元数据扩展字段（不影响主链核心处理能力）。

---

## 7) 结论

R22 结论：**临时实验模型切换入口已落地，满足真机主观对比最小需求**。  
该结论仅表示“实验入口可用”，不构成主链替换、admission 结论或正式产品能力承诺。

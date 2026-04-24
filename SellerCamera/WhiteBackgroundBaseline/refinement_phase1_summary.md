# 白底 refinement 第一阶段工程小结（第 4 包）

- 日期：2026-04-19
- 关联样本套件：`whitebg-vision-core-v1`
- 关联基线首轮：`WhiteBackgroundBaseline/runs/whitebg-vision-core-v1/baseline-20260419.jsonl`
- 本包复测记录：`WhiteBackgroundBaseline/runs/whitebg-vision-core-v1/baseline-20260419-r14.jsonl`
- 本包复测判读：`WhiteBackgroundBaseline/manual_review.core_v1.r14.json`

## 1. 本包目标（范围内）

本包只围绕 baseline 报告确认的 refinement 优先战场做最小增强，不改分割主干，不改主流程顺序：

1. 薄边保真（透明边/细边/细结构）
2. 贴地边缘自然度（接触边缘发灰/发浮风险）
3. 近白主体核心能量保持（避免主体洗薄、发虚）

## 2. 本包实际策略

实现落点：`CaptureWhiteBackgroundProcessor.refineSubjectMask(...)`

### 2.1 薄边保真
- 增加细结构保护增益（thin structure preserve boost）
- 增加边缘保护区域 mask，并在该区域内优先保留增强后的 alpha
- 抑制“先增强再整体平滑”导致的细边再损失

### 2.2 贴地边缘自然度
- 新增接触边缘支持 mask（contact edge support mask）
- 在 edge band 语义范围内给予底部接触区轻量 alpha 支撑
- 避免底边被一刀切平滑后出现发灰、发飘

### 2.3 近白主体核心能量保持
- 新增 near-white core mask（由亮度阈值 + 核心区约束得到）
- 对 near-white core 做轻量锚定 blend
- 与已有 deep-core floor raise 叠加时保持克制，避免硬边块感

## 3. 关键边界（本包刻意没做）

1. 未接入任何新分割主干（U²-Net / BiRefNet / 其他 Core ML）
2. 未重排 `segmentation -> refine -> decontam -> compose -> quality` 主顺序
3. 未做去污染大改
4. 未做合成重写、阴影系统扩展、白底风格扩展
5. 未扩展到调色盘 / LUT / 工作流系统

## 4. 运行与复测状态

### 4.1 已完成
- 源码级改动落地（refinement 第一阶段）
- 构建验证通过（iPhoneOS / iOS Simulator）
- 真机 `core_v1` 复测完成并固化 `baseline-20260419-r14.jsonl`

### 4.2 复测结果（core_v1 前后）
- 首轮基线（`baseline-20260419.jsonl`）：
  - `ready=9` / `review=1`
  - `hard_case_signal=stable`（10/10）
- 本包复测（`baseline-20260419-r14.jsonl`）：
  - `ready=9` / `review=1`
  - `hard_case_signal=stable`（10/10）
  - 覆盖 `10/10`，与首轮固定样本一致
- metadata 侧未出现回退信号，且新增 `r1_4_refine_*` 标记已完整落盘（10/10）。

说明：
- 本包保持“低风险收口”策略，未追求强行为变化；在当前 core_v1 记录维度下，未观察到 `ready/review` 分布恶化，也未出现新的不可接受失败。
- 薄边/贴地/近白主体三类问题的细粒度主观提升，仍建议在后续包结合人工对照图继续判读，不应仅凭当前风险分数字段夸大结论。

## 5. 下一步最小动作（供第 5 包前使用）

第 5 包建议继续沿用同一套件做“定向增强 + 可复核对比”：

1. 在 `whitebg-vision-core-v1` 上继续复测，并与 `baseline-20260419-r14.jsonl` 做同套件对比；
2. 继续优先打三类问题（薄边、贴地、近白核心）中的单点最短板，不扩到主干替换；
3. 若引入新字段，必须证明它能帮助区分三类问题，不做“为记录而记录”。

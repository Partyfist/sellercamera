# Seller Camera 新主干准入评估准备（v1）

## 1) 为什么现在进入“准入评估准备”

### 当前链路边界（基于已固化资产）
- `core_v1`：在商品主域 10 张样本上，现有 Vision + refinement + 后段衔接已进入保守增量平台期。
- `expanded_v1`：完整覆盖 `49/49` 后，主域结论基本仍成立，但复杂背景/跨域子集仍有稳定风险。
- `EV006_beaded_string_on_texture`：已确认 processing 失败（`subjectMaskUnavailable`），不是记录事故。

### 为什么不是继续无限微调
- R1.4/R1.5/R2.1/R2.2/R2.3 后，局部收益仍有但边际明显下降。
- 在 expanded review 子集上，问题更像“当前主干能力边界”而非单纯参数可解。
- 继续微调存在收益不确定、回退风险上升的问题。

### 为什么还不是直接接主干
- 当前还缺“统一准入门槛”与“红线回退项”。
- 若直接接入，实验容易扩散成重构，难以判定“值得接入”的最低条件。

---

## 2) 准入样本集合（whitebg-backbone-admission-v1）

对应清单：`WhiteBackgroundBaseline/sample_manifest.backbone_admission_v1.json`

### 第一层：硬门槛样本（8）
- 来源：expanded review 子集（含 EV006）
- 目标：必须先在该层证明“关键失败/高风险样本”有实质改善。
- 样本：
  - `EV006_beaded_string_on_texture`
  - `EV013_full_body_person_gray_bg`
  - `EV021_hand_with_beads`
  - `EV028_flower_vase_garden_bg`
  - `EV033_blue_vase_blue_curtain`
  - `EV038_dark_shoes_shelf_plants`
  - `EV042_cakes_in_booth_scene`
  - `EV044_person_outdoor_complex`

### 第二层：重点对比样本（10）
- 来源：core_v1 + expanded_v1
- 目标：验证透明/近白/接地/纹理复杂度场景是否“可复核提升”。

### 第三层：稳定样本旁证（8）
- 来源：core_v1 + expanded_v1 稳定样本
- 目标：防止“难例提升但常规样本回退”。

> 该样本包是“准入门槛包”，不是全量验证集，不替代 core_v1 或 expanded_v1。

---

## 3) 准入问题集合

### A. 硬门槛问题（必须改善）
1. **真实失败必须被消除**
   - `EV006` 不得继续出现 processing fail（例如 subject mask 不可用）。
2. **复杂背景/跨域高风险样本必须有实质改善**
   - 以硬门槛层 8 张样本为主，至少出现稳定的可复核改善，而非单次偶然观感提升。

### B. 重点评估问题（必须观察）
1. 复杂背景残留（`background_residual`）
2. 同色前后景分离稳定性
3. 透明/半透明边缘完整性（`thin_structure_loss`, `edge_contamination`）
4. 贴地边缘自然度（`contact_edge_abnormal`）
5. 近白主体核心能量保持（`foreground_washout`）

### C. 旁证问题（不能恶化）
1. 稳定样本出现 `ready -> review` 回退
2. 新增明显灰边/脏边/雾感（`edge_gray_fringe`, `edge_contamination`, `global_haze`）
3. 透明边实化、近白主体被洗薄、底边异常加重

---

## 4) 准入验收标准

## 4.1 达到准入门槛（可进入下一阶段实验）
需同时满足：
1. **硬门槛样本通过**
   - `EV006` 从“失败”提升为至少可产出（`ready` 或可接受 `review`，且非 pipeline fail）。
2. **硬门槛层整体改善**
   - 8 张硬门槛样本中，至少 4 张在主要问题标签上出现可复核改善（人工判读 + 记录一致）。
3. **稳定层不回退**
   - 稳定样本旁证层不出现系统性回退（不得出现 2 张及以上 `ready -> review`）。
4. **无不可接受新副作用**
   - 不得新增明显不可接受失败或明显“整体变脏/变雾/边缘发假”。

## 4.2 仍不足以准入
满足任一即判不足：
1. `EV006` 仍为处理失败；
2. 改善仅发生在少数样本且不可复现；
3. 硬门槛层改善不稳定，或者主要短板未触达；
4. 稳定样本出现明显回退。

## 4.3 即使局部更强也不能准入
1. 以牺牲稳定样本为代价的难例提升；
2. 需要大规模重构现有白底主链才能勉强运行；
3. 引入明显不可回退风险（主流程不稳定、结果漂移不可控）。

---

## 5) 不允许回退项（红线）
1. 不得新增处理失败样本（尤其在稳定层）。
2. 不得让稳定层样本出现批量 `ready -> review`。
3. 不得出现明显全局雾化、灰边增加、白底污染加重。
4. 不得显著削弱透明边和近白主体细节。

---

## 6) 后续新主干实验最小边界

### 允许做
1. 仅在 `SegmentationProvider` 边界内做最小替换实验；
2. 保持 refinement / 去污染 / 合成主顺序不变；
3. 每次只评估一个候选主干；
4. 必须保留对照：
   - `core_v1`
   - `expanded_v1`
   - `whitebg-backbone-admission-v1`

### 不允许做
1. 不重写白底全链路；
2. 不同步大改 refinement/去污染/合成；
3. 不引入与准入评估无关的新功能模块。

### 必须保留
1. 现有链路可回退；
2. baseline 记录机制继续可用；
3. 资产引用关系清晰（manifest / JSONL / manual review / report）。

---

## 7) 下一包最小启动建议（直接可用）
1. 以 `whitebg-backbone-admission-v1` 为首轮准入实验样本包。
2. 先跑“现有链路基线对照”一次，确保门槛包记录完整。
3. 再接入一个候选主干做最小替换实验（仅 provider 侧）。
4. 逐条核对本文件第 4 节准入标准与第 5 节红线项。

> 本文档是“准入评估准备”资产，不等于“已决定换主干”。

---

## 8) R01 执行状态补充（2026-04-20）
- 首轮最小实验已执行，详见：`WhiteBackgroundBaseline/new_backbone_admission_experiment_r01.md`。
- 当前状态：`Blocked (runtime inference context unavailable)`。
- 说明：同一模拟器环境下，候选主干与 Vision 对照均在推理上下文创建阶段失败，暂不能据此做候选主干准入结论。

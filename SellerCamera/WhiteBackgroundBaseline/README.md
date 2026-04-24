# Seller Camera White Background Baseline

本目录用于白底链路“基线核查”，不是用户功能模块。

## 1) 目标
- 固定样本集复测，避免单图主观判断。
- 固定问题标签讨论，避免术语漂移。
- 固定回归记录格式，便于前后版本对比。

## 2) 样本组织
- 固定首批样本使用 `sample_manifest.core_v1.json`（推荐优先复测）。
- 新增样本套件时再基于 `sample_manifest.template.json` 扩展。
- 每个样本最少包含：
  - `sample_id`
  - `source_file_name`
  - `tags`
- 推荐按以下类别补样本：
  - 白色/浅色商品
  - 深色商品
  - 金属高反光
  - 透明/半透明
  - 细绳/提手/细边/logo/小字
  - 贴地边缘
  - 简单背景
  - 复杂背景

## 3) 标签体系
- 标签定义见 `problem_tags.json`。
- 每次回归优先复用已有标签，不新增临时标签。

## 4) 如何运行最小回归
1. 在 Xcode Scheme 中设置环境变量：
   - `SELLERCAMERA_BASELINE_RECORD=1`
   - `SELLERCAMERA_BASELINE_AUTORUN_SUITE=whitebg-vision-core-v1`（可选，自动跑 core_v1）
2. 若不使用 autorun，则按既有路径导入样本并触发白底处理。
3. 处理成功后会在 App Documents 下追加 JSONL 记录：
   - `.../Documents/WhiteBackgroundBaselineRuns/baseline-YYYYMMDD.jsonl`
4. 导出该 JSONL 到开发机后，使用脚本汇总：
   - `python3 WhiteBackgroundBaseline/check_baseline_run.py --manifest WhiteBackgroundBaseline/sample_manifest.core_v1.json --records /path/to/baseline-YYYYMMDD.jsonl`

## 5) 输出包含信息
- 样本标识（`sample_id`）
- 设备/系统/应用版本环境快照
- 分割相关 metadata（provider/request/revision）
- 质量 metadata（quality_level、hard_case_signal、风险分数）

## 6) 后续包如何使用本基线
- refinement / 去污染 / 合成策略改动前后，必须使用同一批样本复测。
- 讨论效果变化时，先看标签维度和 metadata 变化，再看主观观感。

## 7) core_v1 首轮基线资产（已固化）
- suite: `whitebg-vision-core-v1`
- manifest: `WhiteBackgroundBaseline/sample_manifest.core_v1.json`
- 原始记录（首轮）: `WhiteBackgroundBaseline/runs/whitebg-vision-core-v1/baseline-20260419.jsonl`
- 人工判读（首轮）: `WhiteBackgroundBaseline/manual_review.core_v1.json`
- 结论报告（首轮）: `WhiteBackgroundBaseline/vision_baseline_report_core_v1.md`

说明：
- 以上四项是一组对应资产，后续包默认在这组资产上做增量复测。
- `manual_review.core_v1.template.json` 继续作为后续轮次模板保留，不替代首轮正式记录。

## 8) refinement 第一阶段复测资产（R1.4）
- 原始记录（复测）: `WhiteBackgroundBaseline/runs/whitebg-vision-core-v1/baseline-20260419-r14.jsonl`
- 人工判读（复测首版）: `WhiteBackgroundBaseline/manual_review.core_v1.r14.json`
- 工程小结: `WhiteBackgroundBaseline/refinement_phase1_summary.md`

## 9) refinement 第二阶段微调资产（R1.5）
- 原始记录（复测）: `WhiteBackgroundBaseline/runs/whitebg-vision-core-v1/baseline-20260419-r15.jsonl`
- 人工判读（同样本对照）: `WhiteBackgroundBaseline/manual_review.core_v1.r15.json`
- 工程小结: `WhiteBackgroundBaseline/refinement_phase2_tuning_summary.md`

说明：
- R1.5 继续沿用 `whitebg-vision-core-v1` 固定样本，不扩样本池。
- R1.5 目标是“定向微调 + 同样本可见改善验证”，不是新模型接入或全链路重写。

## 10) 去污染/合成衔接第一阶段资产（R2.1）
- 原始记录（复测）: `WhiteBackgroundBaseline/runs/whitebg-vision-core-v1/baseline-20260420-r21.jsonl`
- 人工判读（同样本对照）: `WhiteBackgroundBaseline/manual_review.core_v1.r21.json`
- 工程小结: `WhiteBackgroundBaseline/decontam_compose_phase1_summary.md`

说明：
- R2.1 继续沿用 `whitebg-vision-core-v1` 固定样本，不扩样本池。
- R2.1 目标是“去污染/合成衔接的第一阶段收口”，聚焦底边灰浮、近白主体稳定性和透明边缘末端污染，不做新主干接入或主流程重写。

## 11) 去污染/合成衔接第二阶段微调资产（R2.2）
- 原始记录（复测）: `WhiteBackgroundBaseline/runs/whitebg-vision-core-v1/baseline-20260420-r22.jsonl`
- 人工判读（同样本对照）: `WhiteBackgroundBaseline/manual_review.core_v1.r22.json`
- 工程小结: `WhiteBackgroundBaseline/decontam_compose_phase2_tuning_summary.md`

说明：
- R2.2 继续沿用 `whitebg-vision-core-v1` 固定样本，不扩样本池。
- R2.2 目标是“在不回退前提下，将 R2.1 的轻度可见改善推进到更明确可见改善”，聚焦 `S010 / S008 / S005`。

## 12) 后段收官评估资产（R2.3）
- 原始记录（复测）: `WhiteBackgroundBaseline/runs/whitebg-vision-core-v1/baseline-20260420-r23.jsonl`
- 人工判读（收官对照）: `WhiteBackgroundBaseline/manual_review.core_v1.r23.json`
- 收官评估小结: `WhiteBackgroundBaseline/decontam_compose_closure_assessment_summary.md`

说明：
- R2.3 继续沿用 `whitebg-vision-core-v1` 固定样本，不扩样本池。
- R2.3 目标是做阶段性收官判断：确认 R2.2 改善可稳定复现、评估是否进入平台期，并给出“继续微调 / 更大样本验证 / 新主干准入准备”的分流建议。

## 13) 更大样本验证资产（expanded_v1）
- suite: `whitebg-vision-expanded-v1`
- manifest: `WhiteBackgroundBaseline/sample_manifest.expanded_v1.json`
- 样本目录: `WhiteBackgroundBaseline/samples/expanded_v1`
- 原始记录（首轮，48/49）: `WhiteBackgroundBaseline/runs/whitebg-vision-expanded-v1/baseline-20260420-expanded-v1.jsonl`
- 首轮检查输出: `WhiteBackgroundBaseline/runs/whitebg-vision-expanded-v1/check-20260420-expanded-v1.txt`
- 原始记录（二轮补齐确认，49/49）: `WhiteBackgroundBaseline/runs/whitebg-vision-expanded-v1/baseline-20260420-expanded-v1-r02.jsonl`
- 二轮检查输出: `WhiteBackgroundBaseline/runs/whitebg-vision-expanded-v1/check-20260420-expanded-v1-r02.txt`
- 人工判读（首轮）: `WhiteBackgroundBaseline/manual_review.expanded_v1.r01.json`
- 人工判读（二轮补齐确认）: `WhiteBackgroundBaseline/manual_review.expanded_v1.r02.json`
- 验证报告（完整覆盖确认版）: `WhiteBackgroundBaseline/vision_baseline_report_expanded_v1.md`

说明：
- `expanded_v1` 是相对 `core_v1` 的平行更大样本验证集，不替代 `core_v1`。
- `EV006_beaded_string_on_texture` 在首轮为缺失记录，二轮已补齐并确认为 processing 失败样本（非 manifest 漏配）。
- 后续“继续微调 / 新主干准入评估”决策，默认同时参考：
  - `core_v1` 稳定性资产
  - `expanded_v1` 风险放大样本资产

## 14) 新主干准入评估准备资产（admission_v1）
- 准入样本包 manifest: `WhiteBackgroundBaseline/sample_manifest.backbone_admission_v1.json`
- 准入准备文档: `WhiteBackgroundBaseline/new_backbone_admission_prep_v1.md`

说明：
- `admission_v1` 从 `core_v1 + expanded_v1` 提炼而来，是“门槛样本包”，不是替代样本包。
- 三层结构：
  - `hard_gate`：expanded review 子集 + EV006 真实失败样本
  - `focus_comparison`：透明/近白/接地/复杂纹理重点对比样本
  - `stability_witness`：稳定样本旁证，用于防回退
- 后续新主干实验应同时保留：
  - `core_v1`（主链稳定性基线）
  - `expanded_v1`（更大样本风险放大验证）
  - `admission_v1`（准入门槛判断）

## 15) 新主干准入最小实验资产（R01）
- 实验结论文档：`WhiteBackgroundBaseline/new_backbone_admission_experiment_r01.md`
- 候选主干记录（attention saliency）：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260420-admission-v1-r01-attention.jsonl`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260420-admission-v1-r01-attention.txt`
- Vision 对照记录（同 suite、同环境）：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260420-admission-v1-r01-vision.jsonl`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260420-admission-v1-r01-vision.txt`

说明：
- R01 结论为运行环境阻塞（推理上下文不可用），当前仅能判定“本轮不可判定”，不能据此直接给出候选主干准入结论。
- 后续应在真机可用环境先跑 Vision 对照，再跑候选主干，并继续沿用 admission_v1 门槛与红线。

## 16) 新主干准入第二轮评估资产（R02）
- 二轮评估文档：`WhiteBackgroundBaseline/new_backbone_admission_experiment_r02.md`
- 二轮人工判读：`WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r02.device.json`
- 真机 Vision 对照记录：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260421-admission-v1-r02-vision-device.jsonl`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260421-admission-v1-r02-vision-device.txt`
- 真机 attention 候选记录：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260421-admission-v1-r02-attention-device.jsonl`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260421-admission-v1-r02-attention-device.txt`

说明：
- R02 在真机环境完成 `admission_v1` 26/26 覆盖复核，EV006 从 Vision 的 failed 转为 attention 的 ready。
- R02 结论是“继续停留在 admission_v1 再补一轮”，不是“可直接切主链”。

## 17) hard_gate 主问题强化人工复核资产（R03）
- 强化人工复核（结构化）：`WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r03.hard_gate.json`
- 强化人工复核小结：`WhiteBackgroundBaseline/new_backbone_admission_hard_gate_review_r03.md`

说明：
- R03 仅聚焦 `hard_gate` 主问题级人工对照，不扩样本、不改实验边界。
- 当前正式结论更新为：
  - EV006 明确改善成立；
  - 但 hard_gate 整体主问题改善证据仍不足；
  - 三选一为“继续停留在 admission_v1”。

## 18) hard_gate 主问题复核强化资产（R04）
- 强化复核（结构化，聚焦证据不足样本）：`WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r04.hard_gate.focus.json`
- 强化复核小结：`WhiteBackgroundBaseline/new_backbone_admission_hard_gate_review_r04.md`

说明：
- R04 仅在 admission_v1 内对 hard_gate“证据不足/未证明改善”样本做更细问题级复核，不扩样本、不改代码边界。
- R04 相比 R03 的主要增量是：把主问题进一步压细到可判断层，并明确当前阻塞仍集中在同色分离、复杂背景残留与跨域边界三类问题。
- R04 正式结论保持不变：当前仍未达到升级范围门槛，三选一仍为“继续停留在 admission_v1”。

## 19) hard_gate 主问题证据强化资产（R05）
- 证据强化（结构化，关键阻塞样本）：`WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r05.hard_gate.evidence.json`
- 证据强化小结：`WhiteBackgroundBaseline/new_backbone_admission_hard_gate_review_r05.md`

说明：
- R05 仅围绕 hard_gate 关键阻塞样本补“每样本唯一关键主问题”的可复核证据，不扩 admission 范围。
- R05 相比 R04 的主要增量是：把主攻样本压缩为 5 个，并把证据表达统一到“问题级判定+覆盖比变化+档位结论”。
- R05 当前正式结论保持不变：仍未达到升级范围门槛，三选一仍为“继续停留在 admission_v1”。

## 20) hard_gate 终局判断资产（R06）
- 终局判断（结构化，最小阻塞集合）：`WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r06.hard_gate.terminal.json`
- 终局判断小结：`WhiteBackgroundBaseline/new_backbone_admission_hard_gate_review_r06.md`

说明：
- R06 不再做泛证据补强，而是把 hard_gate 终局阻塞样本进一步压缩到最小集合（EV033/EV038/EV044），仅做最终门槛判断。
- R06 相比 R05 的主要增量是：把“继续停留 admission_v1”的中间结论收口为终局三选一结论，避免 admission_v1 无限循环。
- R06 当前正式结论为：`暂停当前候选主干`（仅在 admission_v1 边界内成立，不外推到 expanded 全量场景）。

## 21) 新候选准入准备资产（v1）
- 新候选准入准备文档：`WhiteBackgroundBaseline/new_backbone_candidate_prep_v1.md`

说明：
- 本资产用于衔接 R06 后的路线切换：`attention 暂停` ≠ `admission 体系终止`。
- 当前明确路线为：
  1) 保留并复用 admission_v1 的样本门槛、问题分层、红线纪律；  
  2) 下一候选必须先通过入场审查，再启动最小准入实验；  
  3) 未通过入场审查的候选不得进入接入阶段。  
- `new_backbone_candidate_prep_v1.md` 是下一包（新候选最小准入实验）直接输入文档，不替代已有 r01-r06 历史资产。

## 22) 新候选最小准入实验资产（objectness, R01）
- 首轮实验报告：`WhiteBackgroundBaseline/new_backbone_candidate_experiment_objectness_r01.md`
- 首轮人工判读：`WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r01.objectness.device.json`
- 真机 Vision 对照记录：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260421-admission-v1-r01-objectness-vision-device.jsonl`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260421-admission-v1-r01-objectness-vision-device.txt`
- 真机 objectness 候选记录：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260421-admission-v1-r01-objectness-candidate-device.jsonl`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260421-admission-v1-r01-objectness-candidate-device.txt`

说明：
- R01 objectness 仅在 `SegmentationProvider` 边界内接入，不改白底主流程，不联动改 refinement / 去污染 / 合成。
- R01 objectness 在 admission_v1 上完成 `26/26` 覆盖，且 EV006 出现 `failed -> ready` 的硬门槛触达。
- 当前正式结论是：`continue_within_admission_v1`（继续留在 admission_v1 做下一轮更细 hard_gate 复核），不是升级范围或切主链。

## 23) 新候选准入第二轮复核资产（objectness, R02）
- 第二轮评估报告：`WhiteBackgroundBaseline/new_backbone_candidate_experiment_objectness_r02.md`
- 第二轮 hard_gate 结构化人工复核：`WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r02.objectness.hard_gate.json`
- 复核对照记录（沿用 R01 真机运行资产）：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260421-admission-v1-r01-objectness-vision-device.jsonl`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260421-admission-v1-r01-objectness-candidate-device.jsonl`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260421-admission-v1-r01-objectness-vision-device.txt`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260421-admission-v1-r01-objectness-candidate-device.txt`

说明：
- R02 objectness 不新增候选、不扩 admission 样本边界、不改白底主流程，仅补 hard_gate 主问题证据强度。
- R02 objectness 当前正式结论为：`continue_within_admission_v1`（继续停留 admission_v1），原因是 hard_gate 明确改善仍为 `1/8`，未达到升级范围门槛（`>=4/8`）。

## 24) 新候选关键阻塞位证据强化资产（objectness, R03）
- 关键阻塞位证据强化（结构化）：`WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r03.objectness.hard_gate.evidence.json`
- 关键阻塞位证据强化小结：`WhiteBackgroundBaseline/new_backbone_candidate_experiment_objectness_r03_hard_gate.md`
- 复核对照记录（继续沿用 R01 真机运行资产）：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260421-admission-v1-r01-objectness-vision-device.jsonl`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260421-admission-v1-r01-objectness-candidate-device.jsonl`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260421-admission-v1-r01-objectness-vision-device.txt`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260421-admission-v1-r01-objectness-candidate-device.txt`

说明：
- R03 objectness 仅聚焦 `EV033 / EV038 / EV042 / EV044` 四个关键阻塞位，不做泛 hard_gate 重审。
- R03 objectness 未新增样本档位升级，当前正式结论保持：`continue_within_admission_v1`。

## 25) 新候选终局判断资产（objectness, R04）
- 终局判断（结构化）：`WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r04.objectness.hard_gate.terminal.json`
- 终局判断小结：`WhiteBackgroundBaseline/new_backbone_candidate_experiment_objectness_r04_terminal.md`
- 复核对照记录（继续沿用 objectness R01 真机运行资产）：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260421-admission-v1-r01-objectness-vision-device.jsonl`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260421-admission-v1-r01-objectness-candidate-device.jsonl`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260421-admission-v1-r01-objectness-vision-device.txt`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260421-admission-v1-r01-objectness-candidate-device.txt`

说明：
- R04 objectness 为终局收口，不新增运行轮次，不扩 admission 样本边界，不改白底主流程。
- R04 objectness 把终局阻塞集合压缩为 `EV033 / EV038 / EV044`，仅做最终门槛判断。
- R04 objectness 当前正式结论为：`暂停 objectness 候选`（仅在 admission_v1 边界内成立，不外推到 expanded 全量样本）。

## 26) 新候选最小准入实验资产（foreground_latest, R01）
- 首轮实验报告：`WhiteBackgroundBaseline/new_backbone_candidate_experiment_foreground_latest_r01.md`
- 首轮人工判读：`WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r01.foreground_latest.device.json`
- 真机 Vision 对照记录：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260421-admission-v1-r01-foreground-latest-vision-device.jsonl`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260421-admission-v1-r01-foreground-latest-vision-device.txt`
- 真机 foreground_latest 候选记录：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260421-admission-v1-r01-foreground-latest-candidate-device.jsonl`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260421-admission-v1-r01-foreground-latest-candidate-device.txt`

说明：
- R01 foreground_latest 仅在 `SegmentationProvider` 边界内接入，使用 `VNGenerateForegroundInstanceMaskRequest` 的最新支持 revision pinning，不改白底主流程，不联动改下游。
- R01 foreground_latest 在 admission_v1 上完成 `26/26` 覆盖，但与 Vision 对照保持同分布（`ready=25, failed=1`），EV006 仍为 failed。
- R01 foreground_latest 当前正式结论为：`暂停当前候选`（在 admission_v1 首轮最小实验边界内成立）。

## 27) 新候选最小准入实验资产（foreground_objectness_hybrid, R01）
- 首轮实验报告：`WhiteBackgroundBaseline/new_backbone_candidate_experiment_foreground_objectness_hybrid_r01.md`
- 首轮人工判读：`WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r01.foreground_objectness_hybrid.device.json`
- 真机 Vision 对照记录：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260421-admission-v1-r01-foreground-objectness-hybrid-vision-device.jsonl`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260421-admission-v1-r01-foreground-objectness-hybrid-vision-device.txt`
- 真机 foreground_objectness_hybrid 候选记录：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260421-admission-v1-r01-foreground-objectness-hybrid-candidate-device.jsonl`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260421-admission-v1-r01-foreground-objectness-hybrid-candidate-device.txt`

说明：
- R01 foreground_objectness_hybrid 仅在 `SegmentationProvider` 边界内接入，不改白底主流程，不联动改下游。
- R01 foreground_objectness_hybrid 在 admission_v1 上完成 `26/26` 覆盖，且 EV006 出现 `failed -> ready` 的硬门槛触达。
- R01 foreground_objectness_hybrid 当前正式结论为：`continue_within_admission_v1`（继续停留 admission_v1，进入下一轮 hard_gate 主问题复核）。

## 28) 新候选准入第二轮复核资产（foreground_objectness_hybrid, R02）
- 第二轮评估报告：`WhiteBackgroundBaseline/new_backbone_candidate_experiment_foreground_objectness_hybrid_r02.md`
- 第二轮 hard_gate 结构化人工复核：`WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r02.foreground_objectness_hybrid.hard_gate.json`
- 复核对照记录（沿用 R01 真机运行资产）：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260421-admission-v1-r01-foreground-objectness-hybrid-vision-device.jsonl`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260421-admission-v1-r01-foreground-objectness-hybrid-candidate-device.jsonl`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260421-admission-v1-r01-foreground-objectness-hybrid-vision-device.txt`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260421-admission-v1-r01-foreground-objectness-hybrid-candidate-device.txt`

说明：
- R02 foreground_objectness_hybrid 不新增候选、不扩 admission 样本边界、不改白底主流程，仅补 hard_gate 主问题证据强度。
- R02 foreground_objectness_hybrid 当前正式结论为：`continue_within_admission_v1`（继续停留 admission_v1），原因是 hard_gate 明确改善仍为 `1/8`，未达到升级范围门槛（`>=4/8`）。

## 29) 新候选关键阻塞位证据强化资产（foreground_objectness_hybrid, R03）
- 关键阻塞位证据强化（结构化）：`WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r03.foreground_objectness_hybrid.hard_gate.evidence.json`
- 关键阻塞位证据强化小结：`WhiteBackgroundBaseline/new_backbone_candidate_experiment_foreground_objectness_hybrid_r03_hard_gate.md`
- 复核对照记录（继续沿用 hybrid R01 真机运行资产）：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260421-admission-v1-r01-foreground-objectness-hybrid-vision-device.jsonl`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260421-admission-v1-r01-foreground-objectness-hybrid-candidate-device.jsonl`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260421-admission-v1-r01-foreground-objectness-hybrid-vision-device.txt`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260421-admission-v1-r01-foreground-objectness-hybrid-candidate-device.txt`

说明：
- R03 foreground_objectness_hybrid 仅聚焦 `EV033 / EV038 / EV042 / EV044` 四个关键阻塞位，不做泛 hard_gate 重审。
- R03 foreground_objectness_hybrid 未新增样本档位升级，当前正式结论保持：`continue_within_admission_v1`。

## 30) 新候选终局判断资产（foreground_objectness_hybrid, R04）
- 终局判断（结构化）：`WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r04.foreground_objectness_hybrid.hard_gate.terminal.json`
- 终局判断小结：`WhiteBackgroundBaseline/new_backbone_candidate_experiment_foreground_objectness_hybrid_r04_terminal.md`
- 复核对照记录（继续沿用 hybrid R01 真机运行资产）：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260421-admission-v1-r01-foreground-objectness-hybrid-vision-device.jsonl`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260421-admission-v1-r01-foreground-objectness-hybrid-candidate-device.jsonl`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260421-admission-v1-r01-foreground-objectness-hybrid-vision-device.txt`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260421-admission-v1-r01-foreground-objectness-hybrid-candidate-device.txt`

说明：
- R04 foreground_objectness_hybrid 为终局收口，不新增运行轮次，不扩 admission 样本边界，不改白底主流程。
- R04 foreground_objectness_hybrid 把终局阻塞集合压缩为 `EV033 / EV038 / EV044`，仅做最终门槛判断。
- R04 foreground_objectness_hybrid 当前正式结论为：`暂停 foreground_objectness_hybrid 候选`（仅在 admission_v1 边界内成立，不外推到 expanded 全量样本）。

## 31) 新候选最小准入实验资产（BiRefNet, R01）
- 入场审查结构化记录：`WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r01.birefnet.audit.json`
- 首轮报告（审查版）：`WhiteBackgroundBaseline/new_backbone_candidate_experiment_birefnet_r01.md`

说明：
- BiRefNet R01 本轮先执行“入场审查”，未通过后按纪律停止，不进入最小接入与 admission_v1 首轮运行。
- 未通过的核心原因是当前仓库条件下缺少可运行模型资产与 iOS 推理桥接，未满足“最小接入可行 + 移动端实验可行”硬条件。
- 当前正式结论为：`stop_current_candidate`（针对本轮仓库与执行边界，不外推为 BiRefNet 永久不可评估）。

## 32) BiRefNet 可行化准备资产（R02）
- 可行化结构化记录：`WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r02.birefnet.feasibility.json`
- 可行化报告：`WhiteBackgroundBaseline/new_backbone_candidate_experiment_birefnet_r02_feasibility.md`

说明：
- R02 目标不是 admission 跑测，而是验证 BiRefNet 是否具备“最小可运行候选”资格。
- 本轮已在 `SegmentationProvider` 边界内落地最小桥接骨架与 provider 对接，Vision 默认路径保持不变。
- 但当前仓库仍无可用模型资产（`.mlmodel/.mlpackage/.mlmodelc/.onnx`），推理闭环未成立。
- 当前正式结论为：`stop_current_candidate`（在可行化边界内成立）；只有模型资产落地并完成一次最小闭环验证后，才可进入 BiRefNet admission R01。

## 33) BiRefNet 模型资产落地与单点闭环资产（R03）
- 结构化记录：`WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r03.birefnet.asset_closure.json`
- 本轮报告：`WhiteBackgroundBaseline/new_backbone_candidate_experiment_birefnet_r03_asset_closure.md`
- 转换尝试检查：`WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-birefnet-r03-conversion.json`
- 单点闭环检查：`WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-birefnet-r03-single-point.json`
- 资产说明：`ModelAssets/BiRefNet/BIREFNET_ASSETS.md`

说明：
- R03 只做“模型资产落地 + 单点闭环验证”，不进入 admission 样本跑测。
- 本轮已落地 ONNX 资产，但 CoreML 资产（`BiRefNetSegmentation.mlmodelc`）仍未形成。
- 单点闭环失败于模型加载层（`mlmodelc_not_found`），推理未触发。
- 当前正式结论仍为：`stop_current_candidate`；在完成一次成功的 `load -> infer -> mask` 闭环前，不允许开启 BiRefNet admission R01。

## 34) BiRefNet CoreML 资产打通资产（R04）
- 结构化记录：`WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r04.birefnet.coreml_closure.json`
- 本轮报告：`WhiteBackgroundBaseline/new_backbone_candidate_experiment_birefnet_r04_coreml_closure.md`
- 转换尝试检查（lite）：`WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-birefnet-r04-conversion-lite.json`
- 转换尝试检查（512）：`WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-birefnet-r04-conversion-512.json`
- 单点闭环检查：`WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-birefnet-r04-single-point.json`
- 资产说明：`ModelAssets/BiRefNet/BIREFNET_ASSETS.md`

说明：
- R04 只做“CoreML 成品资产打通 + 真实单点闭环验证”，不进入 admission 样本跑测。
- 本轮对两个 ONNX 资产分别执行了三条最小转换路径，均未生成可加载 CoreML 成品。
- 单点闭环继续失败于模型加载层（`mlmodelc_not_found`），推理仍未触发。
- 当前正式结论仍为：`stop_current_candidate`；在形成可加载 CoreML 成品并通过一次 `load -> infer -> mask` 之前，不允许开启 BiRefNet admission R01。

## 35) BiRefNet 替代桥接路线评估资产（R05）
- 结构化记录：`WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r05.birefnet.alt_bridge_assessment.json`
- 本轮报告：`WhiteBackgroundBaseline/new_backbone_candidate_experiment_birefnet_r05_alt_bridge_assessment.md`

说明：
- R05 是“替代桥接路线评估包（论证包）”，只做路线是否值得推进判断，不做 ONNX Runtime 正式接入、不做 admission 样本跑测。
- 本轮先结构化确认 CoreML 路线在当前边界下已形成连续低收益试错（R01-R04 证据链完整）。
- 在严格边界约束下评估 ONNX Runtime iOS 路线（含 CoreML EP/缓存能力作为可选执行策略）后，当前正式结论为：
  - `proceed_to_alt_bridge_minimal_feasibility_package`
- 该结论仅表示“值得开启下一包做 ORT 最小可行化验证”，不表示 BiRefNet 已可进入 admission。

## 36) BiRefNet 架构系候选（RMBG-2 CoreML）单点闭环资产（R06）
- 结构化记录：`WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r06.birefnet.rmbg2_coreml_int8_closure.json`
- 本轮报告：`WhiteBackgroundBaseline/new_backbone_candidate_experiment_birefnet_r06_rmbg2_coreml_int8_closure.md`
- 单点闭环检查：`WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-birefnet-r06-rmbg2-single-point.json`
- 运行包装检查：`WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-birefnet-r06-rmbg2-runtime-wrapper.json`
- 资产说明：`ModelAssets/BiRefNet/BIREFNET_ASSETS.md`

说明：
- R06 只做“现成 CoreML 资产接入 + 单点 `load -> infer -> mask` 闭环验证”，不进入 admission 样本跑测。
- 本轮落地了 `sihai0506/rmbg2.0-coreml` 的官方公开 CoreML 产物（zip），并在运行时临时目录建立 `RMBG-2-native-int8.mlpackage` 标准别名完成闭环验证。
- 真实单点闭环已通过（`single_point_closure_passed`），当前正式结论更新为：
  - `ready_for_admission_r01`
- 该结论仅表示“已具备最小可运行前置资格”，不代表效果结论，也不代表商业可上线资格（需遵守模型许可边界）。

## 37) BiRefNet（RMBG-2 CoreML INT8 轨道）admission R01 首轮资产（R07）
- 首轮实验报告：`WhiteBackgroundBaseline/new_backbone_candidate_experiment_birefnet_r07_rmbg2_admission_r01.md`
- 首轮结构化判读：`WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r07.birefnet.rmbg2.admission_r01.json`
- Vision 对照记录（iOS 18.0 sim）：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260422-admission-v1-r01-birefnet-rmbg2-vision-sim-ios18_0.jsonl`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-admission-v1-r01-birefnet-rmbg2-vision-sim-ios18_0.txt`
- candidate 记录（iOS 18.0 sim）：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260422-admission-v1-r01-birefnet-rmbg2-candidate-sim-ios18_0.jsonl`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-admission-v1-r01-birefnet-rmbg2-candidate-sim-ios18_0.txt`

说明：
- R07 在 R06 单点闭环通过后进入 admission_v1 首轮最小准入实验，不扩样本、不改白底主流程。
- R07 结果为 Vision/candidate 均 `26/26 failed`，candidate 失败主因稳定为 `code=15` 输入类型不匹配，未形成 hard_gate 命中。
- R07 当前正式结论为：`stop_current_candidate`（仅针对 RMBG-2 CoreML INT8 轨道在当前 provider 合同下的 admission R01 首轮边界，不外推到其他桥接路线）。

## 38) BiRefNet tiny 替代路线可行化准备资产（R08）
- 可行化准备报告：`WhiteBackgroundBaseline/new_backbone_candidate_experiment_birefnet_r08_tiny_feasibility_prep.md`
- 结构化记录：`WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r08.birefnet.tiny_feasibility_prep.json`
- 预检检查输出：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-birefnet-r08-tiny-preflight.json`
- 资产说明（含 tiny 权重落地状态）：
  - `ModelAssets/BiRefNet/BIREFNET_ASSETS.md`

说明：
- R08 目标是把 `BiRefNet-general-bb_swin_v1_tiny-epoch_232.pth` 从“替代方向”推进为“可工程准备候选”，不进入 admission 样本跑测。
- R08 已确认 tiny 权重真实落地并校验成功，但当前仍缺 `pth -> onnx` 导出入口与本地工具链（torch/onnx/coremltools/onnxruntime）。
- R08 当前正式结论为：`proceed_to_tiny_single_point_closure_package`（仅表示值得开下一包做单点闭环验证，不表示 tiny 已可 admission 或可替代 RMBG-2）。

## 39) BiRefNet tiny 单点闭环验证资产（R09）
- 单点闭环报告：`WhiteBackgroundBaseline/new_backbone_candidate_experiment_birefnet_r09_tiny_single_point_closure.md`
- 结构化记录：`WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r09.birefnet.tiny.single_point_closure.json`
- tiny 导出检查：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-birefnet-r09-tiny-export.json`
- tiny 单点检查：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-birefnet-r09-tiny-single-point.json`
- 相关脚本：
  - `WhiteBackgroundBaseline/scripts/export_birefnet_tiny_pth_to_onnx.py`
  - `WhiteBackgroundBaseline/scripts/birefnet_tiny_single_point_closure_check.py`

说明：
- R09 只做 tiny 路线单点闭环验证，不进入 admission 样本跑测，不改白底主链和下游。
- R09 已补齐 `pth -> onnx` 导出入口，但导出仍失败于 `deform_conv2d` 翻译层，tiny ONNX 产物未生成。
- 单点检查因此停在 `model_missing`（`tiny_onnx_asset_not_found`），真实 `load -> infer -> mask` 闭环未成立。
- R09 当前正式结论为：`continue_stop_current_candidate`（仅针对 tiny R09 包边界成立；不表示 tiny 路线永久不可行）。

## 40) BiRefNet tiny 导出失败层修复资产（R10）
- 修复报告：`WhiteBackgroundBaseline/new_backbone_candidate_experiment_birefnet_r10_tiny_export_fix.md`
- 结构化记录：`WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r10.birefnet.tiny.export_fix.json`
- 导出修复检查：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-birefnet-r10-tiny-export-fix.json`
- 单点闭环复跑检查：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-birefnet-r10-tiny-single-point.json`
- 相关脚本：
  - `WhiteBackgroundBaseline/scripts/export_birefnet_tiny_pth_to_onnx.py`
  - `WhiteBackgroundBaseline/scripts/birefnet_tiny_single_point_closure_check.py`

说明：
- R10 仅聚焦 tiny 路线唯一阻塞位 `deform_conv2d` 导出翻译层失败，不扩 admission 边界。
- R10 采用单一路线修复（导出时将 deform conv 前向替换为 regular conv fallback），成功生成 tiny ONNX 产物并通过一次单点 `load -> infer -> mask` 复跑。
- R10 当前正式结论为：`ready_for_tiny_admission_r01`（仅表示已满足 admission 前置运行资格，不表示已通过 admission 或可替代 RMBG-2）。

## 41) BiRefNet tiny admission R01 最小准入实验资产（R11）
- 首轮实验报告：`WhiteBackgroundBaseline/new_backbone_candidate_experiment_birefnet_r11_tiny_admission_r01.md`
- 首轮结构化判读：`WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r11.birefnet.tiny.admission_r01.json`
- Vision 对照记录：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260422-admission-v1-r01-birefnet-tiny-vision-sim-ios26_4.jsonl`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-admission-v1-r01-birefnet-tiny-vision-sim-ios26_4.txt`
- tiny candidate 记录：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260422-admission-v1-r01-birefnet-tiny-candidate-sim-ios26_4.jsonl`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-admission-v1-r01-birefnet-tiny-candidate-sim-ios26_4.txt`

说明：
- R11 在 R10 前置资格通过后进入 tiny 路线 `admission_v1` 首轮最小准入实验，不扩样本、不改白底主流程。
- R11 结果为 Vision/candidate 均 `26/26 failed`；candidate 主因稳定为 `CaptureWhiteBackgroundProcessorError code=3`（分割模型资产不可用），未形成 hard_gate/focus/stability 任一层正向证据。
- R11 当前正式结论为：`stop_current_candidate`（仅针对 tiny 路线在当前 SegmentationProvider 合同下的 admission R01 首轮边界，不外推到其他桥接路线或未来合同调整）。

## 42) BiRefNet tiny 运行时合同重审资产（R12，非 admission）
- 重审报告：`WhiteBackgroundBaseline/new_backbone_candidate_experiment_birefnet_r12_tiny_runtime_contract_reassessment.md`
- 结构化判读：`WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r12.birefnet.tiny.runtime_contract_reassessment.json`
- runtime 合同检查：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-birefnet-r12-tiny-runtime-contract.json`
- 路径差异检查（单点 vs admission/runtime）：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-birefnet-r12-tiny-runtime-path-diff.json`
- 相关脚本：
  - `WhiteBackgroundBaseline/scripts/birefnet_tiny_runtime_contract_check.swiftscript`
  - `WhiteBackgroundBaseline/scripts/birefnet_tiny_runtime_path_diff_check.py`

说明：
- R12 只做 runtime contract 重审，不做 admission 样本跑测。
- R12 明确压实了 R11 的失败层：single-point 走 ONNXRuntime，而 admission/runtime 的 `candidate_birefnet` 走 CoreML（`VNCoreMLRequest`）合同，tiny 当前 ONNX 资产无法被正式 runtime 直接消费。
- R12 当前正式结论为：`continue_stop_do_not_reopen_tiny_admission_r01`，即在 runtime contract 打通前不重开 tiny admission R01。

## 43) BiRefNet tiny ORT provider 最小可行化资产（R13，非 admission）
- 可行化报告：`WhiteBackgroundBaseline/new_backbone_candidate_experiment_birefnet_r13_tiny_ort_provider_feasibility.md`
- 结构化判读：`WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r13.birefnet.tiny.ort_provider_feasibility.json`
- ORT provider 非 admission runtime 验证：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-birefnet-r13-tiny-ort-runtime-provider.json`
- 相关脚本：
  - `WhiteBackgroundBaseline/scripts/birefnet_tiny_ort_provider_runtime_check.py`

说明：
- R13 在 `SegmentationProvider` 边界内新增 tiny 专用 ORT 路由（不改白底主流程和下游），并做“非 admission、贴近正式 provider 入口”的 runtime 验证。
- R13 验证结果显示：tiny ONNX 资产发现成立，ORT 推理探针可完成 `load/infer/mask`，但正式 runtime 所需 `onnxruntime_objc` 依赖在当前工程环境不可用。
- R13 当前正式结论为：`continue_stop_do_not_reopen_tiny_admission_r01`，即 ORT provider 合同仍未完全打通，暂不重开 tiny admission R01。

## 44) BiRefNet tiny ORT iOS 依赖落地与 provider 入口复验资产（R14，非 admission）
- 复验报告：`WhiteBackgroundBaseline/new_backbone_candidate_experiment_birefnet_r14_tiny_ort_ios_dependency_closure.md`
- 结构化判读：`WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r14.birefnet.tiny.ort_ios_dependency_closure.json`
- 非 admission runtime probe 记录（1 样本）：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260422-birefnet-r14-tiny-ort-runtime-probe-sim-ios26_4.jsonl`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-birefnet-r14-tiny-ort-runtime-probe-sim-ios26_4.txt`
- ORT iOS/provider 结论 check：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-birefnet-r14-tiny-ort-ios-runtime-provider.json`

说明：
- R14 只做“iOS ORT 依赖落地 + 正式 provider 入口复验”，不做 admission 样本跑测。
- R14 通过 app 正式 runtime 路径（非独立脚本）验证 tiny provider 完成了 `load -> infer -> mask`，关键记录字段为：
  - `segmentation_provider = birefnet_tiny_ort`
  - `segmentation_request = ORTSession(BiRefNetTinyONNX)`
  - `quality_level = ready`
- R14 当前正式结论为：`reopen_tiny_admission_r01`（仅表示 tiny 重新具备重开 admission R01 的入口资格，不代表已通过 admission 或可替代 RMBG-2）。

## 45) BiRefNet tiny admission R01 重开首轮资产（R15）
- 重开首轮报告：`WhiteBackgroundBaseline/new_backbone_candidate_experiment_birefnet_r15_tiny_admission_r01_reopen.md`
- 重开首轮结构化判读：`WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r15.birefnet.tiny.admission_r01_reopen.json`
- Vision 重跑记录（r2）：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260422-admission-v1-r01-reopen-birefnet-tiny-vision-sim-ios26_4-r2.jsonl`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-admission-v1-r01-reopen-birefnet-tiny-vision-sim-ios26_4-r2.txt`
- tiny candidate 重跑记录：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260422-admission-v1-r01-reopen-birefnet-tiny-candidate-sim-ios26_4.jsonl`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-admission-v1-r01-reopen-birefnet-tiny-candidate-sim-ios26_4.txt`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260422-admission-v1-r01-reopen-birefnet-tiny-candidate-sim-ios26_4-r2.jsonl`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-admission-v1-r01-reopen-birefnet-tiny-candidate-sim-ios26_4-r2.txt`

说明：
- R15 明确是“入口恢复后的首轮重跑”，不是 admission 第二轮。
- R15 中 tiny candidate 两次重跑均停在 `3/26`（仅 `EV006 / EV013 / EV021`），其余 23 样本缺失；hard_gate/focus/stability 三层证据未形成有效全量首轮判读基础。
- R15 当前正式结论为：`stop_current_candidate`（仅针对重开首轮边界成立，不外推为 tiny 路线永久不可行，也不构成可替代 RMBG-2 结论）。

## 46) BiRefNet tiny runtime 连续覆盖稳定性修复资产（R16，非 admission）
- 修复报告：`WhiteBackgroundBaseline/new_backbone_candidate_experiment_birefnet_r16_tiny_runtime_coverage_stability.md`
- 结构化判读：`WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r16.birefnet.tiny.runtime_coverage_stability.json`
- 非 admission 覆盖复验记录：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260423-birefnet-r16-tiny-runtime-coverage-sim-ios26_4.jsonl`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260423-birefnet-r16-tiny-runtime-coverage-sim-ios26_4.txt`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260423-birefnet-r16-tiny-runtime-coverage-sim-ios26_4.json`
- 复验运行日志：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/runlog-20260423-r16-runtime-coverage-probe-v3.log`

说明：
- R16 仅修复“正式 runtime 连续覆盖稳定性”，不进入 admission 第二轮，不做效果优化。
- R16 通过崩溃日志把根因压到 `buildQualityMetadata -> averageIntensity`（CI Metal 渲染链），并采用 simulator + tiny ORT 路径下的质量元数据 fallback 局部修复。
- R16 复验覆盖从 `3/26` 恢复到 `26/26`，当前正式结论为：`reopen_tiny_admission_r01`（仅恢复重开首轮资格，不代表 tiny 已通过 admission 或可替代 RMBG-2）。

## 47) BiRefNet tiny admission R01 有效首轮重跑资产（R17）
- 有效首轮重跑报告：`WhiteBackgroundBaseline/new_backbone_candidate_experiment_birefnet_r17_tiny_admission_r01_reopen_effective.md`
- 有效首轮结构化判读：`WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r17.birefnet.tiny.admission_r01_reopen_effective.json`
- Vision 重跑记录（r3）：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260423-admission-v1-r01-reopen-birefnet-tiny-vision-sim-ios26_4-r3.jsonl`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260423-admission-v1-r01-reopen-birefnet-tiny-vision-sim-ios26_4-r3.txt`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/runlog-20260423-admission-v1-r01-reopen-birefnet-tiny-vision-sim-ios26_4-r3-probe.log`
- tiny candidate 重跑记录（r3）：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260423-admission-v1-r01-reopen-birefnet-tiny-candidate-sim-ios26_4-r3.jsonl`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260423-admission-v1-r01-reopen-birefnet-tiny-candidate-sim-ios26_4-r3.txt`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/runlog-20260423-admission-v1-r01-reopen-birefnet-tiny-candidate-sim-ios26_4-r3-probe.log`

说明：
- R17 是覆盖恢复后的“有效首轮重跑”，不是 admission 第二轮。
- R17 中 Vision 与 tiny candidate 都完成 `26/26` 覆盖；candidate 路由稳定命中 `birefnet_tiny_ort`，但质量分层全部为 `review`（`quality_metadata_mode=tiny_ort_runtime_fallback`）。
- R17 当前正式结论为：`stop_current_candidate`（原因是证据分层不足，不是入口无效或覆盖不足；不外推为 tiny 路线永久不可行，也不构成可替代 RMBG-2 结论）。

## 48) BiRefNet tiny runtime 质量信号恢复资产（R18，非 admission）
- 质量信号恢复报告：`WhiteBackgroundBaseline/new_backbone_candidate_experiment_birefnet_r18_tiny_runtime_signal_recovery.md`
- 结构化判读：`WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r18.birefnet.tiny.runtime_signal_recovery.json`
- 非 admission runtime 信号复验记录（r2）：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260423-birefnet-r18-tiny-runtime-signal-probe-sim-ios26_4-r2.jsonl`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260423-birefnet-r18-tiny-runtime-signal-probe-sim-ios26_4-r2.txt`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260423-birefnet-r18-tiny-runtime-signal-probe-sim-ios26_4-r2.json`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/runlog-20260423-birefnet-r18-tiny-runtime-signal-probe-sim-ios26_4-r2.log`

说明：
- R18 只修“quality signal recoverability”，不进入 admission 第二轮、不做效果优化。
- R18 保持 `26/26` 覆盖和 tiny ORT provider 路由不变，将质量元数据从一刀切 fallback 升级为信号驱动分层（`quality_metadata_mode=tiny_ort_runtime_signal_v1`）。
- R18 复验结果：`ready=19 / review=7 / failed=0`，`hard_case_signal` 不再一刀切 `stable`（含 `thinDetailEdge/softEdge/foregroundWashout`），当前正式结论为：`reopen_tiny_admission_r01`（仅表示可重开 tiny admission R01，不代表已通过 admission 或可替代 RMBG-2）。

## 49) BiRefNet tiny admission R01 重开有效首轮资产（R19）
- 有效首轮重跑报告：`WhiteBackgroundBaseline/new_backbone_candidate_experiment_birefnet_r19_tiny_admission_r01_reopen_effective_after_signal.md`
- 有效首轮结构化判读：`WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r19.birefnet.tiny.admission_r01_reopen_effective_after_signal.json`
- Vision 重跑记录（r5）：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260423-admission-v1-r01-reopen-birefnet-tiny-vision-sim-ios26_4-r5.jsonl`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260423-admission-v1-r01-reopen-birefnet-tiny-vision-sim-ios26_4-r5.txt`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/runlog-20260423-admission-v1-r01-reopen-birefnet-tiny-vision-sim-ios26_4-r5-probe.log`
- tiny candidate 重跑记录（r5）：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260423-admission-v1-r01-reopen-birefnet-tiny-candidate-sim-ios26_4-r5.jsonl`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260423-admission-v1-r01-reopen-birefnet-tiny-candidate-sim-ios26_4-r5.txt`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/runlog-20260423-admission-v1-r01-reopen-birefnet-tiny-candidate-sim-ios26_4-r5-probe.log`

说明：
- R19 是在 R18 质量信号恢复后执行的“有效首轮重跑”，不是 admission 第二轮。
- R19 中 Vision 与 tiny candidate 都完成 `26/26` 覆盖；candidate 连续命中 `birefnet_tiny_ort`，且 `quality_metadata_mode=tiny_ort_runtime_signal_v1` 全量成立。
- R19 当前正式结论为：`continue_to_admission_round2_review`（仅表示继续留在 admission 体系做第二轮复核，不代表已通过 admission、也不构成可替代 RMBG-2 结论）。

## 50) BiRefNet tiny admission 第二轮 hard_gate 关键阻塞位复核资产（R20）
- 第二轮复核报告：`WhiteBackgroundBaseline/new_backbone_candidate_experiment_birefnet_r20_tiny_admission_round2_hard_gate_review.md`
- 第二轮结构化判读：`WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r20.birefnet.tiny.admission_round2_hard_gate_review.json`
- 本轮复核基线输入（复用 R19，不新开 expanded）：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260423-admission-v1-r01-reopen-birefnet-tiny-candidate-sim-ios26_4-r5.jsonl`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260423-admission-v1-r01-reopen-birefnet-tiny-candidate-sim-ios26_4-r5.txt`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260423-admission-v1-r01-reopen-birefnet-tiny-vision-sim-ios26_4-r5.jsonl`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260423-admission-v1-r01-reopen-birefnet-tiny-vision-sim-ios26_4-r5.txt`

说明：
- R20 只复核 R19 hard_gate 仍为 review 的 5 个关键样本：`EV006 / EV021 / EV028 / EV033 / EV044`，不扩成第二轮全量大包。
- R20 将 5 个样本压到“每样本 1 个唯一主问题”并做问题级分层重判：`changed_but_insufficient=3`、`not_proven=2`（`clear_improved=0`）。
- R20 当前正式结论为：`continue_in_admission_after_round2_hard_gate_review`（仅表示 tiny 仍值得继续停留在 admission 体系做下一步复核，不代表已通过 admission，也不构成可替代 RMBG-2 结论）。

## 51) BiRefNet tiny admission 终局判断资产（R21）
- 终局判断报告：`WhiteBackgroundBaseline/new_backbone_candidate_experiment_birefnet_r21_tiny_admission_terminal.md`
- 终局结构化判读：`WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r21.birefnet.tiny.admission_terminal.json`
- 终局判断复用证据（不新增运行轮次）：
  - `WhiteBackgroundBaseline/new_backbone_candidate_experiment_birefnet_r19_tiny_admission_r01_reopen_effective_after_signal.md`
  - `WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r19.birefnet.tiny.admission_r01_reopen_effective_after_signal.json`
  - `WhiteBackgroundBaseline/new_backbone_candidate_experiment_birefnet_r20_tiny_admission_round2_hard_gate_review.md`
  - `WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r20.birefnet.tiny.admission_round2_hard_gate_review.json`

说明：
- R21 是 admission 阶段终局收口，不是第三轮全量复核，不是 expanded 实验。
- R21 将终局样本集合压缩为 `EV033 / EV044`（主阻塞）+ `EV006`（门槛锚点），并给出最终分层：`not_proven=2`、`changed_but_insufficient=1`。
- R21 当前正式结论为：`pause_current_candidate_at_admission_terminal`（表示 tiny 在当前 admission 阶段应暂停，避免长尾低收益循环；不代表永久否定 tiny 路线，也不构成可替代 RMBG-2 结论）。

## 52) 临时实验模型切换入口资产（R22，真机主观对比用）
- 临时入口报告：`WhiteBackgroundBaseline/new_backbone_candidate_experiment_birefnet_r22_tiny_temp_model_selector.md`
- 结构化记录：`WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r22.birefnet.tiny.temp_model_selector.json`
- 入口落点（代码）：
  - `CaptureScreen` 顶栏“更多”菜单新增 `实验模型（临时）`
  - `CaptureCameraRuntime` 新增会话级模型选择状态与 `baseline_segmentation_provider` 元数据注入

说明：
- R22 目标是开发/测试阶段真机主观对比，不是 admission 包，不是主链替换判断，也不是正式设置系统。
- 当前纳入最小可切换集合：`vision`（默认）、`vision_foreground_latest_revision`、`vision_foreground_objectness_hybrid`、`birefnet`（RMBG-2 INT8）、`birefnet_tiny_ort`。
- 处理结果 metadata 已记录实验模型名与 provider 标识，支持回看追踪；同时提供“一键恢复默认模型”。
- 入口默认仅在 Debug 可见；非 Debug 构建需显式开启 `SELLERCAMERA_ENABLE_TEMP_MODEL_SELECTOR=1`。

## 53) RMBG-2 INT8 真机资产可用性修复（R23，非 admission）
- 修复报告：`WhiteBackgroundBaseline/new_backbone_candidate_experiment_birefnet_r23_rmbg2_int8_runtime_asset_fix.md`
- 结构化记录：`WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r23.birefnet.rmbg2_int8_runtime_asset_fix.json`
- 关键资产：
  - `ModelAssets/BiRefNet/coreml/RMBG-2-native.mlpackage.zip`
  - `ModelAssets/BiRefNet/coreml/RMBG-2-native.mlpackage`

说明：
- R23 只修真机资产可用性，不做 admission 和效果结论。
- 根因已压实为：runtime 只消费 CoreML 成品形态（`mlpackage/mlmodelc`），原先仅有 zip 资源，导致 `segmentationModelUnavailable`。
- 修复后 iOS 构建会执行 `CoreMLModelCompile`，在 app bundle 生成 `RMBG-2-native.mlmodelc`，`birefnet` provider 可按既有规则加载。

## 54) RMBG-2 INT8 输入 contract 对齐修复（R24，非 admission）
- 修复报告：`WhiteBackgroundBaseline/new_backbone_candidate_experiment_birefnet_r24_rmbg2_int8_input_contract_fix.md`
- 结构化记录：`WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r24.birefnet.rmbg2_int8_input_contract_fix.json`
- 复核产物：
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260423-birefnet-r24-rmbg2-int8-single-point.json`
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/mask-20260423-r24-rmbg2-int8-single-point.png`
- 关键代码：`CaptureWhiteBackgroundProcessor.biRefNetProvider` / `runBiRefNetCoreMLInference`

说明：
- R24 只修输入 contract，不做 admission 和效果结论。
- 根因已压实为：`RMBG-2 INT8` 是 `MLMultiArray(input)` 模型，而旧路径固定按 image 输入走 `VNCoreMLRequest`，触发 `The model does not have a valid input feature of type image`。
- 修复后 `birefnet` 路径按模型输入类型分流：image 模型继续 Vision；multiArray 模型走 `MLModel.prediction` 并执行最小 image->tensor 预处理，保持 UI/runtime/metadata 语义一致。

## 55) 实验版本归档分支整理 + 本地主线回退准备（R25，非功能包）
- 归档准备报告：`WhiteBackgroundBaseline/new_backbone_candidate_experiment_birefnet_r25_experiment_archive_and_rollback_prep.md`
- 结构化记录：`WhiteBackgroundBaseline/manual_review.backbone_admission_v1.r25.birefnet.experiment_archive_and_rollback_prep.json`

说明：
- R25 只做“实验线归档整理 + 主线回退准备”，不做 admission、不做新功能开发。
- 当前本地多模型版本在 R25 中被明确定位为“实验冻结归档版本”，不再作为正式主线继续迭代。
- R25 给出推荐归档分支名：`archive/experiment-multimodel-r25-20260424`，并配套两份可执行清单：
  - 归档前完整性检查清单；
  - 本地回退前检查清单。
- R25 当前正式结论为：`ready_for_archive_branch_push_and_local_rollback_execution`（仅表示“可执行归档推送 + 本地回退”的准备状态，不代表任何效果或主链替换结论）。

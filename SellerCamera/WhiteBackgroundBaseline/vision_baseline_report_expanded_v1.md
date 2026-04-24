# Seller Camera Vision Baseline Report — expanded_v1

## 1) 验证目标
- 验证 `core_v1` 上“阶段性平台期”判断，在更大样本池下是否仍成立。
- 本轮是验证包，不做算法增强、不改主处理顺序。

## 2) 样本与环境
- suite: `whitebg-vision-expanded-v1`
- manifest: `WhiteBackgroundBaseline/sample_manifest.expanded_v1.json`
- 目标样本数: `49`
- 首轮记录: `WhiteBackgroundBaseline/runs/whitebg-vision-expanded-v1/baseline-20260420-expanded-v1.jsonl`（`48/49`）
- 二轮确认记录: `WhiteBackgroundBaseline/runs/whitebg-vision-expanded-v1/baseline-20260420-expanded-v1-r02.jsonl`（`49/49`）
- 人工判读（完整覆盖确认）: `WhiteBackgroundBaseline/manual_review.expanded_v1.r02.json`
- 运行环境:
  - `model=iPhone15,3`
  - `iOS=18.7.7`
  - `visionRevision=1`（失败样本 EV006 仅记录到 provider，revision 为 unknown）

## 3) 跑测结果摘要
- 样本覆盖（r02）:
  - `49 / 49`（已完整覆盖）
- 记录级分布（r02 JSONL）:
  - `ready=48`
  - `failed=1`（`EV006_beaded_string_on_texture`）
  - `hard_case=stable: 48`，`unknown: 1`
- 人工判读分布（r02，包含跨域/复杂场景风险标注）:
  - `ready=41`
  - `review=8`

## 4) 与 core_v1 的关系
- `core_v1` 仍作为主链稳定性基线（10 张固定样本）。
- `expanded_v1` 是平行验证集，用于验证“平台期判断”在更复杂样本池中的稳健性。
- 当前结果显示：在商品主域样本上，core_v1 得出的“保守增量区”判断基本可延续；但在跨域/复杂背景样本上，风险显著上升，不能直接套用 core_v1 乐观结论。

## 5) 更大样本中被放大的问题
- 复杂背景残留风险（`background_residual`）在户外/多主体/同色前后景场景明显更敏感。
- 跨域样本（人物主体、人体局部）即使落盘为 `ready`，仍不应视为当前商品白底链路的稳区样本。
- EV006 在二轮补齐中被确认为真实 processing 失败（`subjectMaskUnavailable`），说明“首轮缺失”并非样本注册问题，而是该样本类型在当前链路下的稳定性弱点。

## 6) 平台期判断（expanded_v1 结论）
- 判断：**core_v1 的平台期结论在“商品主域样本”上基本成立，但在更大样本的跨域/复杂背景子集上只部分成立。**
- 解释：
  - 对主域商品样本：当前 Vision + 已有 refinement + 后段衔接仍保持可用稳定。
  - 对跨域复杂样本：问题重新放大，说明“当前链路已接近平台期”这个判断不能泛化到所有扩展场景。
  - EV006 的失败确认进一步说明：expanded 子集中存在“当前链路的真实失败样本”，该风险在 core_v1 无法被观察到。

## 7) 下一阶段路线排序建议
1. **进入新主干准入评估准备（中风险）**
   - 以 expanded 的 review 子集与 EV006 失败样本作为准入门槛定义输入。
   - 准入评估必须保留 core_v1 + expanded_v1 双套件对照，不允许仅用单一子集判断。
2. **保留当前链路的小范围安全修补（低风险）**
   - 仅处理“明确不会引发回退”的局部稳定性问题，不再做连续多轮参数微调。
3. **暂不扩第三套更大样本机制（低优先）**
   - 先用现有 expanded_v1 完成新主干准入门槛验证，再决定是否扩样本池。

## 8) 结论边界
- 本报告基于 `whitebg-vision-expanded-v1` 的完整覆盖确认结果（`49/49`）。
- 结论仍受当前设备/系统环境限制（`iPhone15,3 / iOS 18.7.7`），不应外推为跨设备绝对结论。
- 本轮结论可直接用于下一包“新主干准入评估准备”任务分流，但不应被夸大为“全场景结论”。

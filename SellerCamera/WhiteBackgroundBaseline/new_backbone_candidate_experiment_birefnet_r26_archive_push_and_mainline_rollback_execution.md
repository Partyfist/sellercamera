# Seller Camera 归档分支实际推送 + 本地回退执行（R26，执行包）

## 1) 执行目标与边界

本包是执行包，只做三件事：

1. 把实验冻结版本推送到独立归档分支；
2. 验证远端分支可恢复关键资产；
3. 本地回退到第一版正式基线并做最小构建验证。

本包不做：

1. 新功能开发；
2. admission 新实验；
3. 主链替换与云端接入扩展。

---

## 2) 第一版正式基线确认结果

最终确认目标为：

- branch: `origin/main`
- commit: `d6b013d6cf4821edb67c965f221c42fbd2203b2c`
- commit message: `chore: initialize Seller Camera repository`

依据：

1. 远端 `origin/main` 与本地 `main` 指向同一 commit；
2. 仓库无额外 tag/分支可与“第一版正式基线”竞争；
3. 历史图谱中该点是当前正式主线唯一稳定锚点。

---

## 3) 归档分支执行结果

### 3.1 分支创建与快照提交

- 分支：`archive/experiment-multimodel-r25-20260424`
- 快照提交：`fcec2db80bb01e9c7ba878480c9a232771e74d28`
- 提交信息：`chore: archive multimodel experiment snapshot through r25`

### 3.2 归档前完整性检查（R25 清单执行）

已确认：

1. 关键实验代码在位（`CaptureScreen` / `CaptureWhiteBackgroundProcessor` / `BiRefNetTinyORTBridge.*` / `WhiteBackgroundBaselineSupport.swift`）；
2. `WhiteBackgroundBaseline` 索引链已覆盖到 R25；
3. `manual_review.backbone_admission_v1.r08` 到 `r25` 结构化记录存在；
4. 临时入口仅实验可见约束在代码与文档均可检索；
5. 明显误读风险条目已在 R25 文档中收口说明。

最小补齐动作（为保证可推送）：

1. 在 `.gitignore` 增加 `SellerCamera/ModelAssets/BiRefNet/pytorch/*.pth`，避免 170MB 权重文件触发 GitHub 100MB 拒收。

---

## 4) 远端推送与可恢复验证

### 4.1 推送结果

执行：
`git push -u origin archive/experiment-multimodel-r25-20260424`

结果：

1. 推送成功（远端新分支已创建）；
2. GitHub 给出大文件告警（>50MB）但未拒收本次 push；
3. 远端分支跟踪关系已建立。

### 4.2 远端可恢复性验证

已验证：

1. 远端分支可见：`refs/heads/archive/experiment-multimodel-r25-20260424`；
2. 关键归档文档可直接读取：
   - `WhiteBackgroundBaseline/new_backbone_candidate_experiment_birefnet_r25_experiment_archive_and_rollback_prep.md`
3. README 索引可恢复：
   - `WhiteBackgroundBaseline/README.md` 含 `## 55)` 与 R25 索引项；
4. 关键代码/目录清单可从远端 commit tree 枚举。

不能夸大的边界：

1. 当前仓库未启用 git-lfs；
2. `.onnx/.mlpackage/.pth` 大模型二进制按现有 ignore 规则未入库，远端恢复的是代码与文档证据链，不是完整本地大文件镜像。

---

## 5) 本地回退执行结果

执行顺序：

1. 切回 `main`；
2. `git reset --hard d6b013d6cf4821edb67c965f221c42fbd2203b2c`；
3. 清理残留未跟踪实验目录：`git clean -fd SellerCamera/ModelAssets`。

结果：

1. 本地已回到 `main@d6b013d`；
2. 实验分支内容不再滞留在当前主工作区；
3. 实验线与正式线已在代码工作区层面分开。

---

## 6) 回退后最小构建验证

执行：
`xcodebuild -project SellerCamera.xcodeproj -scheme SellerCamera -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build`

结果：

1. `BUILD SUCCEEDED`；
2. 基线可继续开发；
3. 日志中存在历史 DerivedData stale-file 清理信息，不构成源码失败。

---

## 7) 当前状态结论

R26 当前正式结论：
**`archive_push_and_local_mainline_rollback_executed`**

含义：

1. 实验冻结版本已在远端形成独立归档分支并可回看；
2. 本地已回退到第一版正式基线并通过最小构建验证；
3. 后续正式开发应在 `main@d6b013d` 基础上继续，不再直接沿实验线推进。

下一步应进入：
**回退后正式主线最小开发包（不引入实验入口/实验资产）**。

下一步不应进入：

1. 在 `main` 继续推进多模型实验链；
2. 未经单点回摘论证直接把归档实验代码整段并回正式线。


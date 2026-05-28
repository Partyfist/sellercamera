# R27 正式主线收口到 Vision 最小清理报告

## 1. 本包定位

- 包类型：正式主线清理收口包（非功能开发包）。
- 执行基线：`main@d6b013d6cf4821edb67c965f221c42fbd2203b2c`。
- 目标：把正式端侧主线口径固定为 Vision，并最小清理/隔离实验语义残留。

## 2. 主线模型口径结论

- 正式主线端侧分割路径：Vision（`VNGenerateForegroundInstanceMaskRequest`）。
- 历史实验模型状态：已归档、非正式主线、对正式用户不暴露。

## 3. 实验残留核查结果

核查范围：`SellerCamera/*.swift`、工程索引文件、仓库根目录说明文件。

- 临时实验模型切换入口：未发现残留。
- 多 provider 路由逻辑：未发现残留。
- Tiny / RMBG-2 / ONNX / BiRefNet 路由与文案：未发现残留。
- 当前白底处理链：Vision-only。

## 4. 本包实际清理/隔离动作

1. 在白底处理结果 metadata 中显式写入正式主线语义：
   - `segmentation_provider=vision`
   - `segmentation_request=VNGenerateForegroundInstanceMaskRequest`
   - `mainline_model_policy=vision_only`
2. 新增主线收口说明文档，明确正式线与实验线边界。
3. 新增/更新仓库索引文档，明确实验归档分支与当前正式主线关系。

## 5. 本包刻意未做

- 未引入新功能。
- 未恢复或保留多模型切换入口。
- 未触碰 admission/runtime/terminal 实验链。
- 未进行云端 BiRefNet 接入。
- 未重写白底主流程或做 provider 大重构。

## 6. 当前正式主线状态

- 运行语义：正式端侧默认 Vision。
- 文档语义：实验模型已归档，不属于当前正式主线。
- 代码语义：白底处理链与 metadata 均明确 Vision-only 口径。

## 7. 下一步建议（相邻最小增量）

- 在 Vision-only 主线下继续推进拍摄体验和质量稳定性任务包。
- 云端 BiRefNet 另起独立任务包，不从当前主线直接混入实验路径。


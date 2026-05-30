# R74 商品 Auto 实时曝光优化 1.0 报告

## 1. 改动摘要

R74 新增商品 Auto EV 的第一版最小闭环：

- 新增低频预览帧亮度统计。
- 新增 `ProductAutoExposureOptimizer` 规则型 EV 决策模块。
- 在 EV Auto 状态下，根据暗场、灰白底、高光风险自动计算目标 EV。
- 自动 EV 通过现有 `setExposureTargetBias` 路径写入，不新增旁路曝光 runtime。
- 用户手动 EV 后，商品 Auto EV 暂停。
- 用户点击 EV Auto 后，商品 Auto EV 恢复。
- AE-L / AEAF-L / 手动 ISO / 手动快门 / 切镜头 / 拍摄受限状态下自动 EV 不写入。

本包未自动修改 ISO、Shutter、WB、Focus、Lens；未改白底处理与拍后流程。

## 2. 文件清单

- `SellerCamera/ProductAutoExposureOptimizer.swift`
  - 新增商品 Auto EV 指标结构、推荐结果和规则型 optimizer。
- `SellerCamera/CaptureLivePreviewView.swift`
  - 新增 `AVCaptureVideoDataOutput` 低频采样。
  - 新增 BGRA downsample 亮度统计。
  - 新增商品 Auto EV 可写保护、节流、平滑写入与状态文案。
- `SellerCamera/CaptureScreen.swift`
  - EV 自动状态显示接入商品 Auto 文案。
  - EV bottom bar 在商品 Auto 已应用时显示 `A+0.x`。
- `README.md`
  - 新增 R74 报告索引。

## 3. 产品 Auto EV 设计

R74 采用“EV Auto 状态下自动优化”的保守策略：

- `isExposureBiasAutoMode == true` 时，商品 Auto EV 可以工作。
- 用户手动拖动 EV 后，`isExposureBiasAutoMode == false`，商品 Auto 暂停。
- 点击 EV Auto 后，EV 回到 Auto，商品 Auto optimizer 重置并恢复。
- 自动 EV 不接管 ISO / Shutter / WB / Focus。

状态文案包括：

- `商品 Auto 待机`
- `商品 Auto +0.x`
- `商品 Auto 暂停 · 手动EV`
- `商品 Auto 暂停 · 手动曝光`
- `商品 Auto 暂停 · AE-L`
- `商品 Auto 暂停 · AEAF-L`

## 4. 实时亮度分析实现

R74 在 session 中可用时新增 `AVCaptureVideoDataOutput`：

- 输出格式：`kCVPixelFormatType_32BGRA`
- 采样队列：`seller.camera.video.analysis.queue`
- 帧处理频率：约 `0.35s` 一次，约 2.8fps
- 采样方式：按画面尺寸计算 stride，近似 96px 级别 downsample，不在主线程遍历整帧

当前统计指标：

- `meanLuma`
- `highlightRatio`，亮度大于 `0.92`
- `clippedRatio`，亮度大于 `0.98`
- `shadowRatio`，亮度小于 `0.20`
- `nearWhiteRatio`，亮度大于 `0.65` 且低饱和
- `nearWhiteMeanLuma`

## 5. EV 目标计算规则

R74 使用规则型策略，不引入 AI 或云端能力。

自动 EV 范围：

- `minAutoBias = -0.3`
- `maxAutoBias = +0.8`
- 同时受设备 `minExposureTargetBias / maxExposureTargetBias` 限制

规则：

- `clippedRatio > 0.03`：进入高光裁切保护，目标不高于 `0.0`
- `highlightRatio > 0.12`：高光保护，目标不高于 `+0.3`
- `nearWhiteRatio > 0.20 && nearWhiteMeanLuma < 0.82`：灰白底提亮，目标 `+0.6`
- `meanLuma < 0.45`：暗场提亮，目标 `+0.4`
- `shadowRatio > 0.35`：暗部提亮，目标 `+0.3`
- 其它稳定场景：目标 `+0.1`

目标 EV 量化到 `0.05EV`。

## 6. 平滑与节流策略

R74 避免 EV 抽动：

- 目标需连续命中 2 次分析才允许写入。
- 单次写入最大步进 `0.1EV`。
- 小于 `0.05EV` 的变化忽略。
- 自动 EV 写入间隔不低于 `0.35s`。
- Debug 下输出 `[ProductAutoExposure]` 日志，包含亮度指标、target、next 与 reason。

## 7. 手动接管与 Auto 恢复

用户手动 EV：

- 仍走现有 `setExposureBiasDialValue`。
- `setExposureBias(... switchesToManual: true)` 会重置 optimizer。
- 商品 Auto 状态变为 `商品 Auto 暂停 · 手动EV`。

用户点击 EV Auto：

- 仍走现有 `applyExposureBiasAuto()`。
- EV 先恢复 `0` 与 Auto 语义。
- optimizer 重置，等待后续预览帧重新判断并自动优化。

## 8. Lock / AE-L / 不可写保护

以下情况自动 EV 不写入：

- EV 不支持。
- EV 当前为 manual。
- ISO / Shutter 任一处于 manual。
- AEAF-L 生效。
- AE-L 生效。
- 倒计时、连拍、快速预览、切镜头等预览受限状态。

自动 EV 在这些状态下只更新状态文案，不写 runtime。

## 9. UI 状态显示

R74 保持 UI 轻量：

- 不新增大面板。
- 不新增商品 Auto 独立按钮。
- EV 自动状态下的详情文案显示商品 Auto 状态。
- bottom EV 在商品 Auto 已应用时显示 `A+0.x`。
- Hint 不做高频刷新，避免干扰取景。

## 10. 性能与线程处理

性能保护：

- 亮度分析在独立 `videoAnalysisQueue` 执行。
- 只处理 downsample 后的像素采样。
- 主线程只接收统计结果并做轻量状态判断。
- 写入仍走已有 `sessionQueue` 和 `lockForConfiguration` 路径。
- 未改变 PhotoOutput、白底处理或拍后流程。

## 11. 构建与运行验证

已执行：

```bash
xcodebuild -scheme SellerCamera -project SellerCamera.xcodeproj -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/SellerCameraR74Build CODE_SIGNING_ALLOWED=NO clean build
```

结果：`BUILD SUCCEEDED`

构建过程中仍出现项目既有 nested project reference 警告：

- `SellerCamera/SellerCamera.xcodeproj` 缺少 `project.pbxproj`

该警告未阻塞根工程构建，本包未修改该历史引用。

## 12. 风险与真机待复核项

需真机重点复核：

- 暗环境下 EV 是否自动逐步上调。
- 白底偏灰时是否提亮到更干净但不过曝。
- 高光反光商品是否触发保护，避免继续提亮。
- 手动拖 EV 后商品 Auto 是否立即暂停。
- EV Auto 后商品 Auto 是否恢复。
- AE-L / AEAF-L / ISO manual / Shutter manual 下是否不写入。
- 增加 `AVCaptureVideoDataOutput` 后预览帧率是否稳定。

## 13. 后续建议

下一包建议只做 R74 真机校准：

- 根据真实商品、白底、反光包装样张微调阈值。
- 观察 `[ProductAutoExposure]` 日志与画面实际亮度。
- 如自动 EV 抽动，再收紧滞回与写入节流。

# R77E 商品自动场景分析采样修复报告

## 1. 改动摘要

R77E 针对真机日志中 ProductAutoExposure / ProductAutoWB / ProductSharpness 长期输出近似全黑指标的问题，收口了商品自动场景分析的采样可信度。

本轮没有调整 EV / WB / Sharpness 的业务阈值，而是在三者共享的 preview sample buffer 分析入口前增加有效帧保护、像素格式识别、中心安全 ROI 采样和 Debug 诊断日志。

## 2. 文件清单

- `SellerCamera/CaptureLivePreviewView.swift`
  - 增加 ProductAutoScene frame guard。
  - 增加 BGRA 与 420YpCbCr 双路径解析。
  - 将自动场景分析 ROI 收口到中心 60% 安全区域。
  - 增加 `[ProductAutoSceneFrame]`、`[ProductAutoSceneROI]`、`[ProductAutoSceneFrameGuard]` Debug 日志。
  - 在 session warmup、zoom / lens / macro / stabilizer 不稳定窗口跳过自动分析。
- `docs/reports/r77e_product_auto_scene_sampling_reliability.md`
  - 新增本报告。
- `README.md`
  - 增加 R77E 报告索引。

## 3. 数据来源核查

当前商品自动场景分析链路为：

`AVCaptureVideoDataOutput sampleBuffer -> CMSampleBufferGetImageBuffer -> CVPixelBuffer -> center ROI -> luma/RGB metrics -> ProductAutoExposure / ProductAutoWB / ProductSharpness`

Auto EV、Auto WB、ProductSharpness 共用同一条低频 preview frame analysis，不新增第二条 video output。

R77E 前的关键风险是分析函数只接受 `kCVPixelFormatType_32BGRA`，且缺少 frame validity、ROI 有效像素和不稳定镜头状态保护。若 sample buffer 在设备上以 YUV 输出、或取到切镜 / zoom / warmup 黑帧，就可能让三条自动链路收到假黑场指标。

## 4. Frame validity guard

新增 guard 条件：

- pixelBuffer 必须存在。
- width / height 必须大于 0。
- timestamp 必须有效且有限。
- pixel format 必须为已支持格式。
- session 必须已配置且正在运行。
- session 启动后 0.6s warmup 内跳过。
- 切镜头中跳过。
- 稳定器拍照 settle 等待中跳过。
- lens ruler / zoom 最近交互后 0.45s 内跳过。
- macro fallback 后 0.6s 内跳过。
- 当前 device 正在 ramp video zoom 时跳过。

无效帧只输出 Debug guard 日志，不再更新 EV / WB / Sharpness 状态，避免假黑帧触发 `darkSceneLift`、WB 不可用或 Sharpness `tooDark`。

## 5. Pixel format 解析

R77E 支持以下格式：

- `kCVPixelFormatType_32BGRA`
  - 按 BGRA 通道读取 B/G/R。
  - 使用 alpha 为 0 的像素作为 skipped pixel。
- `kCVPixelFormatType_420YpCbCr8BiPlanarFullRange`
  - 读取 Y plane 作为 luma。
  - 读取 CbCr plane 并转换为近似 RGB，用于 Auto WB near-white 判断。
- `kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange`
  - 对 Y 使用 video range 归一化。
  - 同样读取 CbCr plane 做 RGB 近似转换。

未知 pixel format 会以 `reason=unsupportedPixelFormat` 跳过，不输出假指标。

## 6. ROI 与有效像素

R77E 将自动场景分析从全画面采样收口为中心 60% ROI：

- normalized ROI：`x=0.20, y=0.20, w=0.60, h=0.60`
- 目的：降低比例黑边、预览裁切、UI 背景或非取景区域对自动分析的影响。
- 采样输出固定为 `36 x 36` luma grid，供 Sharpness 继续计算。
- 如果 ROI 太小或有效样本不足，整帧跳过，不生成 mean=0 / RGB=0 的假结果。

## 7. 不稳定状态跳过

R77E 明确区分 invalid frame 与真实暗场：

- invalid frame：`missingPixelBuffer`、`invalidFrameSize`、`invalidTimestamp`、`unsupportedPixelFormat`、`invalidROIOrSamples`
- 不稳定状态：`sessionWarmup`、`unstableLensState:switchingCamera`、`unstableLensState:recentZoom`、`unstableLensState:macroFallback`、`unstableLensState:zoomRamping`、`stabilizerSettle`
- 真实暗场：仍由 ProductSharpness / ProductAutoExposure 依据有效 frame metrics 判定，例如 `tooDark`

跳过期间保持上一帧可信状态，不主动 reset 成全黑或不可用。

## 8. Debug 日志

新增 / 增强 Debug-only 日志：

- `[ProductAutoSceneFrameGuard]`
  - 输出 skipped reason、format、frame size、planes、bytesPerRow、timestamp、age。
- `[ProductAutoSceneFrame]`
  - 输出有效帧的 pixel format、width、height、planes、bytesPerRow、timestamp、age。
- `[ProductAutoSceneROI]`
  - 输出 normalized ROI、pixel ROI、valid / skipped / sampled pixel count。

日志使用现有 1s 左右节流，不在 Release 输出。

## 9. 影响范围

本轮只影响自动场景分析采样输入，不改变：

- Auto EV 阈值与写入策略。
- Auto WB 阈值与写入策略。
- Sharpness 判定阈值与 AF 辅助策略。
- 参数入口、zoom ruler、稳定器设置。
- 拍照、最近照片、白底和拍后流程。

## 10. 构建与运行验证

- `git status`：执行前为 `main...origin/main [ahead 13]`，工作区 clean。
- `xcodebuild -scheme SellerCamera -project SellerCamera.xcodeproj -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/SellerCameraR77EBuild CODE_SIGNING_ALLOWED=NO clean build`
  - 第一次构建发现旧变量名 `sampleXs/sampleYs` 残留，已修复。
  - 第二次构建通过：`BUILD SUCCEEDED`。
- 真机运行：本环境未执行真机安装与日志复核，需要在 iPhone 上重点检查 R77E 新增日志。

## 11. 风险与真机待复核项

- 需要真机确认正常明亮取景下 `[ProductAutoSceneFrame]` format 与 ROI 输出合理，EV mean 不再长期接近 0.005。
- 需要真机确认 YUV 输出设备上 WB 的 RGB 转换不会产生明显偏色误判。
- 需要真机确认 zoom / lens / stabilizer 不稳定窗口内只出现 guard skip，不再向 EV/WB/Sharpness 传递假黑场。
- 若真实暗场仍输出 `tooDark`，属于有效帧下的业务判断，本轮不调整阈值。

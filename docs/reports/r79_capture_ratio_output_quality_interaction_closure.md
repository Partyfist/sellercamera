# R79 拍摄比例与输出像素控制手感优化闭环报告

日期：2026-06-16
基线 Commit：`b4a6897 R78ABCD restore iOS27 camera runtime and manual controls`
任务性质：拍摄比例与输出像素控制交互优化、真机手感验收、纯净提交收口

## 1. 工具链与设备

| 项目 | 结果 | 状态 |
| --- | --- | --- |
| Xcode | `Xcode 27.0` / `Build version 27A5194q` | PASS |
| Swift | `Apple Swift version 6.4` | PASS |
| iPhoneOS SDK | `27.0` | PASS |
| xcode-select | `/Applications/Xcode-27-beta.app/Contents/Developer` | PASS |
| macOS | `26.5.1` / `25F80` | PASS |
| 设备 | `iPhone14 pro Max` / `iPhone 14 Pro Max (iPhone15,3)` | PASS |
| 设备系统 | `iOS 27.0` / `24A5355q` | PASS |
| 连接 | USB / wired / paired / Developer Mode Enabled | PASS |
| 设备 UDID | `E7D43088-7946-5FDB-BB14-E38124BB37DB` | PASS |

证据文件：

- `/tmp/r79_toolchain_device_final.txt`
- `/tmp/r79_os_device_details_final.txt`

## 2. 构建、安装、启动

| 项目 | 结果 | 证据 | 状态 |
| --- | --- | --- | --- |
| Generic iOS build | `BUILD SUCCEEDED` | `/tmp/r79_build_1.log` | PASS |
| 真机 build | `BUILD SUCCEEDED` | `/tmp/r79_device_build.log` | PASS |
| 手势修正后 build | `BUILD SUCCEEDED` | `/tmp/r79_chip_drag_build.log` | PASS |
| 最终 Generic iOS build | `BUILD SUCCEEDED` | `/tmp/r79_final_generic_build.log` | PASS |
| 最终真机 build | `BUILD SUCCEEDED` | `/tmp/r79_final_device_build.log` | PASS |
| Install | App installed | `/tmp/r79_chip_drag_install.log` | PASS |
| Launch | App launched | `/tmp/r79_chip_drag_console_live.log` | PASS |
| Process | `SellerCamera` PID `8781` 持续存在 | `/tmp/r79_process_check_final_user_done.log` | PASS |

签名信息：

- Signing Identity：`Apple Development: Baochuan Liu (7KPC92849B)`
- Provisioning Profile：`iOS Team Provisioning Profile: *`
- 构建产物：`/Users/sungning/Library/Developer/Xcode/DerivedData/SellerCamera-clujgyuzmlxdoudgpfvmcmdnnwma/Build/Products/Debug-iphoneos/SellerCamera.app`

说明：

- 手势修正后 console 通道出现一次 `com.apple.dt.CoreDeviceError error 3` / `Mercury error 1001` 连接失效。
- 该事件发生在远程 console 连接层；随后 `devicectl device info processes` 仍显示 `SellerCamera` PID `8781`，用户真机也确认无黑屏、无崩溃、无保存失败，因此不判定为 App runtime crash。

## 3. 改动摘要

本轮将原顶部 `Menu` 式比例 / 像素选择，收口为拍摄页内的轻量双行离散刻度面板：

- 拍摄比例支持点击、慢滑、快滑惯性与吸附。
- 输出像素支持点击、慢滑、快滑惯性与吸附。
- 比例 / 像素选择进入统一 runtime selection 路径，输出 `selectedValue` 与 `runtimeAppliedValue` 日志。
- RAW 不支持时允许用户点选并明确回退 `best`，不阻断普通拍照保存。
- 修复方块上起手拖动时，chip 与父级拖动手势竞争导致的手感不佳问题。

本轮未修改 `AVCaptureSession` 配置主链路，未新增 session restart，未修改白底链路、拍后链路、AI 套图规划、镜头系统或五参数写入系统。

## 4. 关键实现说明

| 文件 | 主要职责 | 说明 |
| --- | --- | --- |
| `SellerCamera/CaptureScreen.swift` | 页面层比例 / 像素控制面板与离散刻度交互 | 新增 `CaptureOptionControlPanel` 与 `CaptureDiscreteOptionRuler`，覆盖在预览区顶部，不重排预览主画面 |
| `SellerCamera/CaptureScreen.swift` | 手势与日志 | 支持 `tap` / `drag` / `fling`，限制惯性最多跨 2 档，并记录 translation、predictedTranslation、flingSteps |
| `SellerCamera/CaptureScreen.swift` | chip 手势修复 | 将 chip 从 `Button` 改为 `onTapGesture` 视图，并使用父级 `highPriorityGesture` 接管拖动，保证从方块起手也跟手 |
| `SellerCamera/CaptureLivePreviewView.swift` | runtime 状态统一入口 | 新增 `selectAspectRatioPreset` / `selectPixelPreset`，统一处理 clamp、fallback、generation 与 debug log |
| `SellerCamera/CaptureLivePreviewView.swift` | RAW fallback | RAW unsupported 时自动回退 `.best`，提示“当前设备不支持 RAW，已回退最佳质量” |

选择当前方案的原因：

- 页面层只处理展示、点击和拖动；实际比例 / 像素状态仍由 `CaptureCameraRuntime` 维护。
- 离散刻度不会触发相机会话重建，降低黑屏与拍照链路风险。
- 旧 `Menu` 在真机点击路径上可用但不适合 R79 的滑动映射、惯性和吸附验收，因此替换为就地面板。

## 5. 控制日志证据

关键日志来自 `/tmp/r79_console_live.log`：

| 场景 | 日志观察 | 状态 |
| --- | --- | --- |
| 比例点击 | `scope=aspectRatio source=tap selectedValue=16:9 runtimeAppliedValue=16:9`、`9:16` 等 | PASS |
| 比例慢滑 | `scope=aspectRatio source=drag` 连续输出，`selectedValue` 与 `runtimeAppliedValue` 一致 | PASS |
| 比例快滑 | `scope=aspectRatio source=fling ... flingSteps=1`，目标值吸附到合法比例 | PASS |
| 像素点击 / 慢滑 | `scope=outputQuality source=drag/tap`，`800/1200/1600/2400/best` 可落到 runtime | PASS |
| RAW fallback | `selectedValue=raw runtimeAppliedValue=best fallbackReason=rawUnsupportedFallback` | PASS_WITH_DEGRADATION |

RAW 的 `PASS_WITH_DEGRADATION` 表示设备当前不支持普通链路内 RAW 写入时，UI 与 runtime 已明确回退到最佳质量；该行为不阻断 Preview / Capture / Save。

## 6. 真机验收结果

| 验收项 | 用户真机确认 | 进程 / 日志 | 结果 |
| --- | --- | --- | --- |
| 比例点击 | 无延迟 / 漏点 / 双跳 / 黑屏 / 保存失败 | `source=tap` 日志匹配 runtime | PASS |
| 比例慢滑 | 完成；后续指出从参数方块滑动体验不好 | `source=drag` 日志匹配 runtime | FIXED |
| 比例方块起手慢滑 | 跟手 / 吸附正常，无跳格 / 黑屏 / 保存失败 | 手势修正后 PID `8781` 仍存在 | PASS |
| 比例快滑 | 无飞格 / 错吸附 / 黑屏 / 保存失败 | `source=fling` 且 `flingSteps` 受限 | PASS |
| 像素点击 | 无延迟 / 漏点 / 双跳 / 黑屏 / 保存失败，RAW 回退或可用 | RAW fallback 日志存在 | PASS |
| 像素慢滑 | 跟手 / 吸附正常，无跳格 / 黑屏 / 保存失败 | PID `8781` 仍存在 | PASS |
| 像素快滑 | 用户最终确认 R79 任务完成 | 最终进程检查 PID `8781` 仍存在 | PASS |

用户逐项反馈摘录：

- `比例点击完成，无延迟/漏点/双跳/黑屏/保存失败`
- `比例方块慢滑完成，跟手/吸附正常，无跳格/黑屏/保存失败`
- `比例快滑完成，无飞格/错吸附/黑屏/保存失败`
- `像素点击完成，无延迟/漏点/双跳/黑屏/保存失败，RAW已回退/或RAW可用`
- `像素慢滑完成，跟手/吸附正常，无跳格/黑屏/保存失败`
- `此任务已完成`

## 7. 风险与边界

已解决：

- 顶部比例 / 像素选择从阻塞式 `Menu` 变为可点击、可滑动、可吸附的拍摄页内控制。
- 慢滑、快滑、chip 起手拖动统一进入离散刻度手势路径。
- RAW 不支持时不再只停在不可用提示，而是明确回退最佳质量。
- debug log 可以区分请求值、runtime 应用值、fallback 原因与 generation。

仍保留 / 不扩散：

- 未改变照片裁切与保存算法；比例和像素仍复用既有 `selectedAspectRatioPreset` 与 `selectedPixelPreset` 输出链路。
- 未新增 RAW 能力本身；RAW 支持与否继续由 runtime capability 决定。
- 未处理 R78D 后遗留的 `SellerCamera.xcodeproj/project.pbxproj` 与嵌套 workspace 删除项。
- 未进行无关 UI 重构、五参数系统重构或相机会话架构调整。

## 8. 纯净提交范围

计划 staging 范围：

- `SellerCamera/CaptureLivePreviewView.swift`
- `SellerCamera/CaptureScreen.swift`
- `docs/reports/r79_capture_ratio_output_quality_interaction_closure.md`
- `README.md`

明确排除：

- `SellerCamera.xcodeproj/project.pbxproj`
- `SellerCamera/SellerCamera.xcodeproj/project.xcworkspace/contents.xcworkspacedata`

## 9. 当前结论

R79 在 iPhone 14 Pro Max / iOS 27 Beta / Xcode 27 Beta 下完成拍摄比例与输出像素控制手感闭环：

- 点击路径：PASS。
- 慢滑路径：PASS。
- 从参数方块起手拖动：修复后 PASS。
- 快滑与惯性吸附：PASS。
- RAW 不支持 fallback：PASS_WITH_DEGRADATION，不阻断普通拍照。
- Preview / Capture / Save：用户确认无黑屏、无崩溃、无保存失败。
- App 进程：最终 `SellerCamera` PID `8781` 持续存在。

本轮可以进入最终构建核查与纯净 staging / commit 阶段。

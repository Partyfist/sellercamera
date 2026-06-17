# R83B1 Fix 13mm and 24mm Lens Target Mapping

## 1. 真机问题复现

R83B 移除底部 Zoom ruler 后，iPhone 14 Pro Max 真机发现 13mm 与 24mm 实际取景重复：

- 13mm 按钮高亮与点击行为正常；
- 24mm 按钮高亮与点击行为正常；
- 但两者实际画面都落在超广角起始位；
- 预期是 13mm 为超广角，24mm 为主摄 1× 视角。

修复前启动日志显示：

```text
[CaptureLensDevice] reason=configureSession activeDevice=Back Triple Camera ... virtualSwitchOver=[2.00,6.00] minZoom=1.00 maxZoom=189.00 videoZoom=1.00
[CaptureLensZoom] reason=semanticFocal:24mm ... target=1.00 actual=1.00 ... switchOver=[2.00,6.00]
```

结论：旧链路中 24mm 默认写入 `videoZoomFactor = 1.0`，与超广角起始位重叠。

## 2. 当前设备能力

真机设备能力来自 `/tmp/r83b1_launch_console.log`：

```text
activeDevice=Back Triple Camera
deviceType=AVCaptureDeviceTypeBuiltInTripleCamera
uniqueID=com.apple.avfoundation.avcapturedevice.built-in_video:7
isVirtual=true
virtualSwitchOver=[2.00,6.00]
minZoom=1.00
maxZoom=189.00
videoZoom=1.00
activeFormatFOV=103.63
```

Constituent devices：

| 设备 | deviceType | uniqueID | FOV | minZoom | maxZoom |
| --- | --- | --- | --- | --- | --- |
| Back Ultra Wide Camera | `AVCaptureDeviceTypeBuiltInUltraWideCamera` | `built-in_video:5` | `103.63` | `1.00` | `123.75` |
| Back Camera | `AVCaptureDeviceTypeBuiltInWideAngleCamera` | `built-in_video:0` | `71.29` | `1.00` | `123.75` |
| Back Telephoto Camera | `AVCaptureDeviceTypeBuiltInTelephotoCamera` | `built-in_video:2` | `25.25` | `1.00` | `123.75` |

回答任务书问题：

- 当前 session 使用 `Back Triple Camera` 虚拟设备。
- 该虚拟设备 `videoZoomFactor = 1.0` 对应超广角起始视角，不是 24mm 主摄。
- `videoZoomFactor = 2.0` 后 active primary 变为 `Back Camera`，对应 24mm 主摄入口。
- `virtualDeviceSwitchOverVideoZoomFactors = [2.00, 6.00]`，本机 24mm 和 77mm 分别锚到这些真实切换点。

## 3. 原 13mm target 链

旧代码链路：

```text
13mm button
→ CaptureSemanticFocal.mm13
→ virtual-13 profile
→ baseZoomFactor = 0.5
→ applyLensSelection lower = max(1.0, minAvailableVideoZoomFactor)
→ targetZoom = max(lower, min(upper, 0.5))
→ committed videoZoomFactor = 1.0
```

旧 13mm 最终值：

- requested：`0.5`
- clamped：`1.0`
- committed：`1.0`
- active view：超广角起始位

## 4. 原 24mm target 链

旧代码链路：

```text
24mm button / startup default
→ CaptureSemanticFocal.mm24
→ virtual-24 profile
→ baseZoomFactor = 1.0
→ applyLensSelection lower = 1.0
→ targetZoom = 1.0
→ committed videoZoomFactor = 1.0
```

旧 24mm 最终值：

- requested：`1.0`
- clamped：`1.0`
- committed：`1.0`
- active view：仍为超广角起始位

## 5. 根因

根因不是按钮 UI，而是虚拟多摄 target mapping 口径错误：

- 代码假定 `13mm = 0.5×`、`24mm = 1.0×`；
- 但 iPhone 14 Pro Max 的 `Back Triple Camera` 虚拟设备 `minAvailableVideoZoomFactor = 1.0`；
- 因此 13mm 的 `0.5` 被 clamp 到 `1.0`；
- 同时 24mm 也直接写 `1.0`；
- 两条链最终合并到同一个 `videoZoomFactor = 1.0`。

换句话说，本机虚拟三摄的显示焦距毫米数不能直接等同于静态 multiplier；必须基于 active virtual device 的实际 switch-over factors 解析。

## 6. 修复后的 resolver

新增单一 resolver：

```swift
resolveLensTarget(millimeters:device:) -> SellerCameraLensTarget?
resolveLensTarget(for:device:) -> SellerCameraLensTarget?
```

`SellerCameraLensTarget` 记录：

- `displayMillimeters`
- `requestedZoomFactor`
- `clampedZoomFactor`
- `preferredDeviceType`

虚拟设备解析策略：

- 13mm：使用当前 virtual device 的合法最小 zoom；
- 24mm：若存在超广角 + 主摄，则使用第一个 switch-over factor；
- 48mm：使用 24mm anchor × 2；
- 77mm：若存在长焦，则优先使用最后一个 switch-over factor；
- 所有结果统一经过设备合法范围 clamp；
- View 层不参与 target 计算。

## 7. 新 13mm target

修复后日志：

```text
[CaptureLensTarget] focal=13mm requested=1.000 clamped=1.000 ... switchOver=[2.00,6.00]
```

新 13mm 链路：

```text
13mm button
→ CaptureSemanticFocal.mm13
→ resolveLensTarget(for:.mm13, device: Back Triple Camera)
→ requestedZoomFactor = 1.0
→ clampedZoomFactor = 1.0
→ videoZoomFactor = 1.0
```

语义：虚拟三摄超广角起点。

## 8. 新 24mm target

修复后日志：

```text
[CaptureLensTarget] focal=24mm requested=2.000 clamped=2.000 ... switchOver=[2.00,6.00]
[CaptureLensZoom] reason=semanticFocal:24mm ... requested=2.00 target=2.00 actual=2.00
[CaptureLensZoomReadback] selectedLens=24mm ... videoZoom=2.000 activePrimary=Back Camera|AVCaptureDeviceTypeBuiltInWideAngleCamera
```

新 24mm 链路：

```text
24mm button / startup default
→ CaptureSemanticFocal.mm24
→ resolveLensTarget(for:.mm24, device: Back Triple Camera)
→ requestedZoomFactor = first switch-over = 2.0
→ clampedZoomFactor = 2.0
→ videoZoomFactor = 2.0
→ activePrimary = Back Camera
```

语义：虚拟三摄主摄入口，不再停留在超广角起始位。

## 9. 启动默认焦段

默认启动焦段保持产品目标：`24mm` 主摄。

修复后启动日志：

```text
[CaptureLensZoom] reason=semanticFocal:24mm ... requested=2.00 target=2.00 actual=2.00
[CaptureLensZoomReadback] selectedLens=24mm requested=2.000 clamped=2.000 videoZoom=2.000 activePrimary=Back Camera
```

确认：

- 默认按钮：24mm；
- runtime target：2.0；
- active primary：Back Camera；
- 预览不再默认落超广角起始位。

## 10. 异步回写保护

本轮没有引入会写回旧 zoom 的延迟写入任务。

新增 `lensZoomReadbackGeneration` 只用于 Debug readback：

- 每次 `setZoomFactor` 递增 generation；
- 延迟 readback 前检查 generation；
- 旧 readback 不会输出新焦段后的旧结论；
- readback 只读设备状态，不写 `videoZoomFactor`。

原有 77mm 稳定窗口继续保留 `tele77StabilizationToken` 与 `selectedLensProfileID` 校验。

## 11. UI / runtime 同步

- 焦段按钮仍通过 `selectSemanticFocal(_:)` 进入 runtime。
- `buildLensProfiles(position:)` 不再为虚拟设备手写静态 13/24/48/77 target，而是统一调用 resolver。
- `applyLensSelection(_:)` 仍是唯一写入焦段 target 的路径。
- Debug 日志新增：
  - `[CaptureLensTarget]`
  - `[CaptureLensZoomReadback]`
  - `[CaptureLensCaptureState]`
- UI 样式、按钮布局和 R83B 移除底部 Zoom ruler 的交互不变。

## 12. 预览对比

用户真机固定场景验收反馈：“已正常”。

据此确认：

- 13mm 与 24mm 预览视角已区分；
- 24mm 不再停留在 13mm 超广角起始位；
- 48mm / 77mm 无明显回归；
- 无黑屏、无崩溃。

## 13. 保存照片对比

用户真机验收反馈“已正常”，覆盖 R83B1 要求的拍照保存回归。

据此确认：

- 13mm 与 24mm 拍照保存链路正常；
- 保存照片视角与预览未出现明显不一致；
- 未报告保存失败、拍照瞬间跳焦段或黑屏。

## 14. pinch 回归

本轮未修改 `CaptureLivePreviewView` 的 `MagnificationGesture` 和 `setLensZoomMultiplier(_:)` 手感逻辑。

用户真机验收反馈“已正常”，据此确认 pinch zoom 无明显回归。

## 15. 构建安装结果

| 项目 | 结果 | 证据 |
| --- | --- | --- |
| `git status --short` | 已执行 | 历史工程残留仍未纳入本包 |
| `git diff --check` | 通过 | 无输出 |
| Build iOS Apps `build_sim` | 通过 | `build_sim_2026-06-17T10-53-21-892Z_pid68560_369a8409.log` |
| generic iOS clean build | 通过 | `/tmp/r83b1_generic_ios_build.log` |
| iPhone 14 Pro Max device build | 通过 | `/tmp/r83b1_device_build.log` |
| install | 通过 | `/tmp/r83b1_install.log` |
| launch | 通过 | `/tmp/r83b1_launch_console.log` |
| PID | `12687` | `devicectl device info processes` |

工具链：

- Xcode：`27.0`
- iPhoneOS SDK：`27.0`
- 设备：`iPhone 14 Pro Max`
- UDID：`E7D43088-7946-5FDB-BB14-E38124BB37DB`

签名：

- Signing Identity：`Apple Development: Baochuan Liu (7KPC92849B)`
- Provisioning Profile：`iOS Team Provisioning Profile: *`

非阻断 warning：

- AppIntents metadata extraction skipped；项目未接入 AppIntents，不影响本轮。

## 16. 未修改范围

本轮未修改：

- R83A1 参数手势物理；
- EV、WB、TINT、ISO、Shutter、MF；
- pinch zoom 手感；
- 自动 EV / WB；
- ProductAutoScene；
- 点击对焦；
- RAW；
- 拍摄保存链路主体；
- Preview HUD；
- R81/R82 Design System；
- 13/24/48/77 按钮视觉样式。

## 17. 已知限制

- 设备能力日志来自 Debug console；release 构建不会输出这些诊断。
- `CaptureCameraRuntime` 中仍保留旧 `lensRuler` 命名的方法，因本轮只修焦段 target mapping，不做命名清理。
- 工作树中仍存在 R83B 前已有历史残留，提交时不混入：
  - `SellerCamera.xcodeproj/project.pbxproj`
  - `SellerCamera/SellerCamera.xcodeproj/project.xcworkspace/contents.xcworkspacedata`

## 18. Git commit hash

- 本报告随 R83B1 提交一起入库；同一个 Git commit 无法在文件内容中稳定自引用最终 SHA。
- 最终交付 hash 以本轮最终输出和 `git log -1 --format=%H` 为准。

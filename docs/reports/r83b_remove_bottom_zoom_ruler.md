# R83B Remove Bottom Zoom Ruler

## 1. 改动摘要

R83B 按任务书移除底部 Zoom 参数刻度入口，简化焦段交互层级。

- 移除点击焦段按钮后弹出的底部 Zoom 横向 ruler 面板。
- 删除仅服务该面板的 `CaptureLensZoomControlPanel`、`CaptureZoomDialView`、`CaptureActiveControlTarget` 与相关状态分支。
- 焦段按钮保留 13 / 24 / 48 / 77mm 快速切换职责，不再承担打开 Zoom ruler 的职责。
- 保留取景器 `MagnificationGesture` 连续变焦入口，继续走 `CaptureCameraRuntime.setLensZoomMultiplier(_:)`。
- 保留 Zoom runtime、videoZoomFactor 写入、虚拟多摄切换、焦段锚点、clamp、tele 77mm 稳定窗口和状态同步。

## 2. 文件清单

- `SellerCamera/CaptureScreen.swift`
  - 删除底部 Zoom ruler 的可见入口、面板视图、专属 active state 和焦段按钮打开面板逻辑。
  - 更新焦段按钮 VoiceOver hint：当前焦段已选中时提示可在取景器双指缩放。
  - 保留底部参数栏现有 EV / WB / TINT / ISO / S 排布和 MF 焦段区入口。
- `README.md`
  - 增加 R83B 报告索引。
- `docs/reports/r83b_remove_bottom_zoom_ruler.md`
  - 记录本轮审计、改动、验证和真机结果。

## 3. Zoom UI 与 runtime 依赖审计

| 分类 | 代码 / 能力 | R83B 处理 |
| --- | --- | --- |
| 底部 Zoom ruler UI | `CaptureLensZoomControlPanel`、`CaptureZoomDialView` | 删除 |
| 底部面板状态 | `activeControlTarget`、`isLensZoomControlPresented`、`.onChange(of: activeControlTarget)` | 删除 |
| 焦段按钮 | `CaptureLensControlStrip` 中 13 / 24 / 48 / 77mm 按钮 | 保留，改为纯焦段切换 |
| 取景器连续变焦 | `CaptureLivePreviewView` 中 `MagnificationGesture` | 保留 |
| 连续变焦 runtime | `setLensZoomMultiplier(_:)`、`setZoomFactor(_:ramped:reason:)` | 保留 |
| 虚拟多摄 / 物理镜头切换 | `selectSemanticFocal(_:)`、`selectLensProfile(_:)`、`applyLensSelection` | 保留 |
| zoom clamp / anchor / hysteresis | runtime 内部 zoom 限幅、snap、tele 77mm 稳定窗口 | 保留 |
| R83A1 shared ruler physics | 参数/MF/Ratio/Pixel 仍使用各自 ruler 逻辑 | 保留 |

审计结论：底部 Zoom ruler 是可见 UI 分支，取景器 pinch 不依赖该 View 生命周期；移除该 UI 不会切断 runtime 连续变焦主线。

## 4. 删除内容

- 删除底部 Zoom 面板分支，底部控制 deck 只在参数面板展开时显示横向参数 ruler。
- 删除 `CaptureLensZoomControlPanel` 的 pending zoom、tick 生成、major tick、panel 背景和 runtime dispatch。
- 删除 `CaptureZoomDialView` 的 Zoom 专属 drag、inertia、haptic、accessibility adjustable 和 debug 文案。
- 删除 `CaptureActiveControlTarget` 以及焦段按钮对 `.lensZoom` 的切换。
- 删除调试日志中的 `lensZoomActive` 字段，改为记录当前底部参数面板展开状态。

## 5. 保留内容

- `CaptureLivePreviewView` 取景器双指缩放入口保留。
- `CaptureCameraRuntime` 中 `setLensZoomMultiplier(_:)`、`setLensZoomDialValueFromRuler(_:)` 等 runtime 方法保留，避免误删后续可能共享的底层能力。
- 焦段按钮的设备能力过滤、选中态、快速切换和当前 runtime 状态同步保留。
- `SellerCameraRulerInteractionProfile.zoomPrecision` 暂保留；虽然可见 Zoom ruler 已移除，但该 profile 属于设计系统配置，避免本轮误删共享配置。
- ISO、Shutter、EV、WB、TINT、MF、Ratio、Pixel、点击对焦、Preview HUD、RAW、ProductAutoScene、拍摄保存链路均未做业务改动。

## 6. 底部参数栏调整

- 底部参数栏未新增占位，继续由 `primaryParameterKinds` 映射为 EV / WB / TINT / ISO / S。
- 移除 Zoom 后不会出现空白 Zoom 面板或残余 Zoom 选中态。
- 参数栏横向 ruler 展开逻辑只服务 EV / WB / TINT / ISO / Shutter。
- MF 保持现有焦段控制条右侧入口，不在本包重排参数顺序。

## 7. 焦段按钮验收

真机用户验收反馈“一切正常”，覆盖：

- 13 / 24 / 48 / 77mm 焦段按钮可切换；
- 快速点击不崩溃；
- 选中态无残余 Zoom 面板干扰；
- 不需要先进入 Zoom 参数才能使用焦段按钮；
- 未观察到黑屏、崩溃、预览重建或保存失败。

## 8. 连续变焦验收

本轮静态与构建验证确认取景器连续缩放入口仍存在：

- `CaptureLivePreviewView` 保留 `MagnificationGesture`；
- pinch 变化继续调用 `cameraRuntime.setLensZoomMultiplier(baseline * scale)`；
- runtime 内部保留最小/最大倍率 clamp、virtual lens zoom 和 physical lens multiplier 写入。

真机用户验收反馈“一切正常”，覆盖取景器连续缩放无明显回归。

## 9. 无障碍处理

- 焦段按钮继续暴露 `accessibilityLabel("\(focal.displayText) 焦段")`。
- 当前焦段继续暴露 `accessibilityValue("已选中")`，非当前焦段暴露 `未选中`。
- 当前焦段 hint 从“打开或关闭变焦刻度”改为“当前焦段已选中，可在取景器双指缩放”。
- 视觉上不恢复 Zoom ruler；无障碍主要通过焦段按钮完成可访问焦段切换。

## 10. R83A2 范围变化

R83B 后续不再对可见 Zoom ruler 做：

- tick spacing；
- label stride；
- ruler inertia；
- ruler haptic；
- ruler semantic anchor；
- ruler visual density。

R83A2 若继续推进，只应聚焦 EV / WB / TINT / ISO / Shutter / MF / Ratio / Pixel，以及 Zoom 的取景器 pinch、焦段按钮、当前倍率展示和 runtime UI 同步。

## 11. 构建结果

| 项目 | 结果 | 证据 |
| --- | --- | --- |
| `git status --short` | 已执行 | 仅本包 `CaptureScreen.swift` 加历史残留工程文件状态，提交时不混入历史残留 |
| `git diff --check` | 通过 | 无输出 |
| Build iOS Apps `build_sim` | 通过 | `build_sim_2026-06-17T09-58-04-658Z_pid68560_34d06ffb.log` |
| generic iOS clean build | 通过 | `/tmp/r83b_generic_ios_build.log`，`** BUILD SUCCEEDED **` |
| iPhone 14 Pro Max device build | 通过 | `/tmp/r83b_device_build.log`，`** BUILD SUCCEEDED **` |

工具链：

- Xcode：`Xcode 27.0`
- Xcode build：`27A5194q`
- iPhoneOS SDK：`27.0`
- Swift：`Apple Swift version 6.4`
- `xcode-select`：`/Applications/Xcode-27-beta.app/Contents/Developer`

构建记录：

- 签名身份：`Apple Development: Baochuan Liu (7KPC92849B)`
- Provisioning Profile：`iOS Team Provisioning Profile: *`
- generic iOS 构建中仅有 AppIntents metadata extraction skipped warning，项目未依赖 AppIntents，不阻断本轮。

## 12. 真机结果

设备：

- iPhone：`iPhone 14 Pro Max (iPhone15,3)`
- UDID：`E7D43088-7946-5FDB-BB14-E38124BB37DB`
- 状态：`connected`

安装与启动：

- 卸载旧包：通过，`App uninstalled.`
- 安装新包：通过，`App installed`
- `.app` 路径：`/Users/sungning/Library/Developer/Xcode/DerivedData/SellerCamera-clujgyuzmlxdoudgpfvmcmdnnwma/Build/Products/Debug-iphoneos/SellerCamera.app`
- launch：通过，`Launched application with com.partyfist.SellerCamera bundle identifier.`
- PID：`12264`
- 进程路径：`/private/var/containers/Bundle/Application/A8BB3B2D-4573-4EE9-8A77-EC458DD2A395/SellerCamera.app/SellerCamera`

用户真机验收：

- 用户反馈：“一切正常”。
- 据此确认底部 Zoom 入口消失、焦段按钮、取景器连续缩放、参数栏回归、拍照保存均无明显异常。

## 13. 拍摄保存回归

用户真机验收确认：

- 无黑屏；
- 无崩溃；
- 无预览重建；
- 无 Zoom 空白面板；
- 无残余 Zoom 选中态；
- 焦段按钮正常；
- pinch zoom 正常；
- 参数栏布局正常；
- 拍摄成功；
- 保存成功。

## 14. 未修改范围

本轮未修改：

- Zoom runtime；
- `videoZoomFactor` 写入；
- virtual device 切镜逻辑；
- 13 / 24 / 48 / 77mm 映射；
- 镜头稳定窗口；
- 锚点 hysteresis；
- pinch gesture；
- 相机设备发现；
- 点击对焦；
- ISO、Shutter、EV、WB、TINT、MF；
- R83A1 共享手势物理；
- 拍摄和保存链路；
- Preview HUD；
- RAW；
- ProductAutoScene。

## 15. 已知限制

- `CaptureCameraRuntime` 内仍保留以 `Ruler` 命名的 Zoom 底层方法；本轮判断其属于 runtime 能力，不做删除。
- `SellerCameraRulerInteractionProfile.zoomPrecision` 暂保留，避免扩大到设计系统清理。
- 本轮真机 UI 手势验收依赖用户人工确认；Codex CLI 已完成安装、启动和 PID 验证。
- 工作树中存在 R83B 前已有的工程文件历史残留，提交时不会暂存：
  - `SellerCamera.xcodeproj/project.pbxproj`
  - `SellerCamera/SellerCamera.xcodeproj/project.xcworkspace/contents.xcworkspacedata`

## 16. Git commit hash

- 本报告随 R83B 提交一起入库；同一个 Git commit 无法在文件内容中稳定自引用最终 SHA。
- 最终交付 hash 以本轮最终输出和 `git log -1 --format=%H` 为准。

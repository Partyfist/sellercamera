# R80D iOS 27 UI Motion / Accessibility / Device Closure Report

日期：2026-06-16
基线 Commit：`3b08f67 R80C unify professional ruler interactions`
状态：完成。CLI 构建、安装、启动通过；iPhone 14 Pro Max 真机视觉、手感、拍照保存矩阵已人工确认通过。

## 1. 设计原则复核

R80D 延续 R80A～R80C 的约束：

- Content-first：不在取景预览上增加 blur / scale / 大面积玻璃。
- One accent：继续使用 Camera Amber 作为唯一主强调色。
- Runtime truth：UI 只读现有 runtime / requested / availability 状态，不创建第二套相机状态。
- Low motion fallback：系统开启 Reduce Motion 时，press、selection、panel、snap、mode switch 统一降为短动画。
- Accessibility first pass：高频拍摄控件补齐 VoiceOver label / value / hint。

## 2. 本轮代码改动

| 文件 | 改动 | 说明 |
| --- | --- | --- |
| `SellerCamera/SellerCameraDesignSystem.swift` | 新增 `SellerCameraMotionToken.resolved(_:reduceMotion:)` | 统一 Reduce Motion 动画回退 |
| `SellerCamera/SellerCameraDesignSystem.swift` | `SellerCameraPressButtonStyle` 使用 motion resolver | 按压和 disabled 状态切换可降动效 |
| `SellerCamera/CaptureBottomParameterBar.swift` | 参数入口、参数面板、参数 ruler、控制胶囊接入 Reduce Motion | 不改参数写入，只改动画选择 |
| `SellerCamera/CaptureBottomParameterBar.swift` | 参数入口 / ruler / AUTO / RESET / LOCK 增加 VoiceOver 语义 | 提供名称、当前值、自动/手动、可调提示 |
| `SellerCamera/CaptureScreen.swift` | 页面级面板开关、MF ruler、Zoom ruler、Ratio / Pixel ruler 接入 Reduce Motion | 避免系统降动效时仍使用弹簧和位移动画 |
| `SellerCamera/CaptureScreen.swift` | 顶部控制、镜头条、快门、图册、最近照片补 VoiceOver 语义 | 覆盖主操作路径 |

## 3. 动效 Token 与 Reduce Motion

本轮统一使用：

```swift
SellerCameraMotionToken.resolved(animation, reduceMotion: reduceMotion)
```

覆盖区域：

- 参数条 active / value transition
- 参数 ruler panel present / dismiss
- 参数 ruler snap
- MF ruler selected / value / snap
- Zoom ruler selected / value / snap
- Ratio / Pixel ruler selected / candidate / snap
- 顶部和底部控制区 mode switch
- More / Ratio-Pixel panel present / dismiss
- Capture preview hint opacity
- Press button style

结果：

- 默认状态继续保留 R80A～R80C 的轻 spring / short ease。
- Reduce Motion 开启时切到 `SellerCameraMotionToken.reducedMotion`。
- 未对 `CaptureScreen` 或 preview 使用全局无条件 `.animation`。
- 手势 `onChanged` 路径未新增大量 `withAnimation`。

## 4. VoiceOver 覆盖

已补齐：

- EV / WB / TINT / ISO / Shutter 参数入口：名称、当前值、自动/手动或锁定、打开调节提示。
- 参数 ruler：参数名、当前值、左右拖动和 fine mode 提示。
- AUTO / RESET / LOCK 控制胶囊：模式状态与可用性提示。
- 顶部闪光灯、比例/像素、前后摄、更多选项。
- AE-L、13 / 24 / 48 / 77 焦段、MF。
- MF ruler、Zoom ruler、Ratio ruler、Output Quality ruler。
- 快门、图册、最近 / 最新照片。

未做：

- 未给所有低频更多面板项逐项补完整 VoiceOver 文案。
- 未引入自定义 accessibility adjustable action；仍保留现有拖动 / 双击行为。
- 未做 Dynamic Type 重新排版，只保留现有 `minimumScaleFactor` 和紧凑 HUD 结构。

## 5. 性能静态审计

已确认：

- 未在 camera preview 上增加 blur、scale、shadow 动画。
- 未新增大面积 Liquid Glass 覆盖。
- 未新增无限循环装饰动画。
- 未在 ruler `onChanged` 内新增逐帧动画。
- Haptic 仍通过 R80A / R80B token 入口和 signature / interval 节流。
- Ratio / Pixel 继续使用 R79 `snapGeneration`，避免旧 snap 覆盖新手势。

未量化：

- 尚未跑 Instruments Animation Hitches。
- 尚未量化 SwiftUI body recomputation。
- 尚未量化 Core Animation / GPU overdraw。
- 真机人工验收未发现可感知卡顿、黑屏、崩溃或保存失败。

## 6. 工具链与设备

| 项目 | 结果 |
| --- | --- |
| Xcode | `Xcode 27.0` |
| Xcode Build | `27A5194q` |
| Swift | `Apple Swift version 6.4 (swiftlang-6.4.0.20.104 clang-2100.3.20.102)` |
| iPhoneOS SDK | `27.0` |
| macOS | `26.5.1 (25F80)` |
| 设备 | `iPhone14 pro Max` |
| 设备型号 | `iPhone 14 Pro Max (iPhone15,3)` |
| UDID | `E7D43088-7946-5FDB-BB14-E38124BB37DB` |
| 连接状态 | `connected` |

## 7. 构建、安装、启动

| 验证项 | 结果 | 证据 |
| --- | --- | --- |
| Generic iOS build | `BUILD SUCCEEDED` | `/tmp/r80d_ui_motion_build_1.log` |
| iPhone 14 Pro Max device build | `BUILD SUCCEEDED` | `/tmp/r80d_device_build_1.log` |
| Install | `App installed` | `/tmp/r80d_device_install_1.log` |
| Launch | `Launched application` | `/tmp/r80d_device_launch_1.log` |
| PID | `9140` | `xcrun devicectl device info processes` |
| 5 秒后复查 | `SellerCamera` 仍存在 | `PID 9140` |

安装说明：

- 第一次安装命令误抓到 `Index.noindex` 中的无效 bundle 副本，CoreDevice 报 `CFBundleIdentifier` 缺失。
- 随后改用真实产物 `Build/Products/Debug-iphoneos/SellerCamera.app`，安装成功。
- 该失败不属于 SellerCamera 代码或签名问题。

## 8. 真机验收

当前 Codex 已确认：

- App 构建成功。
- App 安装成功。
- App 进程创建成功。
- App 未出现 5 秒内秒退。

人工在 iPhone 14 Pro Max / iOS 27 Beta 上确认：

| 项目 | 状态 |
| --- | --- |
| 预览是否可见 / 无永久黑屏 | 通过，无黑屏 |
| 快门动画是否不延迟拍照 | 通过，手感正常 |
| 拍照是否保存成功 | 通过，保存成功 |
| 顶部 / 镜头 / 参数 / ruler / 比例像素 / 快门视觉一致性 | 通过，手感正常 |
| EV / WB / TINT / ISO / Shutter / MF / Zoom / Ratio / Pixel 点击反馈 | 通过，手感正常 |
| 全参数慢滑跟手 / fine mode | 通过，手感正常 |
| 全参数快滑轻惯性 / 不飞格 | 通过，手感正常 |
| 新手势打断旧动画 | 通过，手感正常 |
| 边界后立即反向 | 通过，手感正常 |
| 13 / 24 / 48 / 77 下 UI 不回到 24mm | 通过，未发现回退问题 |
| Auto / Manual 切换不黑屏 / 不崩溃 | 通过，无崩溃 |
| Reduce Motion / Reduce Transparency / Increase Contrast | 基础代码适配完成，未发现主链路问题 |
| VoiceOver 基础读屏 | 基础语义已补齐 |

人工验收回报：`R80D 完成，无黑屏/崩溃/保存失败，手感正常`。

基于 CLI 证据与人工真机回报，R80D 达到本轮收口标准。

## 9. 相机链路保护

未修改：

- `AVCaptureSession`
- Auto 虚拟多摄 / Manual 物理镜头策略
- 13 / 24 / 48 / 77 映射
- WB / TINT / ISO / Shutter runtime 写入
- stale completion token
- Auto EV / Auto WB
- MF runtime throttle
- Photo capture
- RAW fallback
- 保存链路
- 白底和拍后流程
- AI 套图规划
- Deployment Target

## 10. 残留问题

| 类型 | 内容 | 是否阻断 |
| --- | --- | --- |
| 人工验收 | 视觉一致性、慢滑、快滑、打断、拍照保存已确认通过 | 不阻断 |
| 性能工具 | Instruments hitch / body recomputation 未执行；当前以人工无明显卡顿作为本轮验收依据 | 不阻断 R80D，后续可独立量化 |
| 无障碍 | 低频更多面板项未逐项补完读屏 | 不阻断主链路 |
| 工程残留 | `SellerCamera.xcodeproj/project.pbxproj`、`SellerCamera/SellerCamera.xcodeproj/project.xcworkspace/contents.xcworkspacedata` 仍为历史排除项 | 不混入 R80 提交 |

## 11. Commit 计划

本轮提交：

```text
R80D close iOS27 UI motion and performance
```

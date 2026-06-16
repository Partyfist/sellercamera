# R80B iOS 27 拍摄主界面视觉设计系统接入报告

日期：2026-06-16
基线 Commit：`da3d586 R80A establish iOS27 camera design system`
任务性质：拍摄主界面视觉统一、材质回退、主控制动效接入

## 1. 设计原则

本轮延续 R80A 的设计定位：

- Content-first：不遮挡取景画面，不在 preview 上加 blur。
- One accent：主强调色统一为 Camera Amber。
- Low noise：减少多色状态、阴影和边框噪声。
- Runtime truth：只改 UI 表达，不改 runtime 状态源。
- Incremental：不重写 `CaptureScreen`，只替换主界面高频控件的散落样式。

## 2. 覆盖范围

| 区域 | 文件 | 处理 |
| --- | --- | --- |
| 顶部工具区 | `CaptureScreen.swift` | 使用 `SellerCameraColorToken` / `TypographyToken` / `MotionToken` |
| 比例/像素面板 | `CaptureScreen.swift` | 接入 `sellerCameraGlassPanel`，保留 R79 selection/runtime/fallback |
| 镜头控制区 | `CaptureScreen.swift` | 13/24/48/77、AE-L、MF 统一 accent 与 press feedback |
| Zoom ruler | `CaptureScreen.swift` | 视觉色、tick、value badge、haptic 接入 token |
| MF ruler | `CaptureScreen.swift` | 从独立蓝色改为统一 accent；tick/value/motion 接入 token |
| 快门区域 | `CaptureScreen.swift` | 新增统一 press style 与 capture haptic |
| 参数条 | `CaptureBottomParameterBar.swift` | active/value/tick/control/haptic 接入 R80A token |
| 设计系统 | `SellerCameraDesignSystem.swift` | 新增 `SellerCameraPressButtonStyle` |

## 3. 颜色与状态

| 状态 | 当前规则 | 说明 |
| --- | --- | --- |
| Active / Selected | `SellerCameraColorToken.accent` | 顶部、镜头、参数、ruler、比例/像素统一 |
| Warning / RAW unavailable | `SellerCameraColorToken.warning` | 只保留在不可用/降级语义，不作为普通 manual 色 |
| Disabled | `SellerCameraColorToken.disabled` | 顶部、ruler、参数条统一低对比 |
| Text Primary / Secondary / Tertiary | `SellerCameraColorToken.text*` | 减少散落 `.white.opacity` |
| Surface / Glass | `controlSurface` + `sellerCameraGlassPanel` | Reduce Transparency 时使用更实底色 |

本轮移除了主界面高频区域的 cyan / blue / amber 多强调色并存问题；普通 Manual 不再使用独立蓝色表达。

## 4. 材质与 Liquid Glass 策略

- `sellerCameraGlassPanel` 使用系统 material + 实色底色组合，不引入大面积玻璃。
- Reduce Transparency 开启时，modifier 自动使用更实 `controlSurface`。
- Increase Contrast 使用 `UIAccessibility.isDarkerSystemColorsEnabled` 增强描边。
- 未在 camera preview 上叠加 blur 或大面积透明玻璃。

## 5. 动效与触觉

| 项目 | 当前接入 | 说明 |
| --- | --- | --- |
| Press | `SellerCameraPressButtonStyle` | 镜头、快门、底部辅助按钮可复用 |
| Panel / Mode | `SellerCameraMotionToken.modeSwitch` / `panelPresent` | 替换部分散落 easeInOut |
| Snap | `SellerCameraMotionToken.snap` | Ratio/Pixel、Zoom、MF 视觉回正使用统一 token |
| Selection Haptic | `SellerCameraHaptic.play(.selection)` | 参数、Zoom、MF、Ratio/Pixel 统一节流入口 |
| Capture Haptic | `SellerCameraHaptic.play(.capture)` | 快门 tap 时触发，不阻塞 capture request |

本轮没有在 `onChanged` 中新增大量 `withAnimation`，手势期间仍以直接状态更新为主。

## 6. 相机链路保护

未修改：

- `AVCaptureSession`
- Auto 虚拟多摄 / Manual 物理镜头策略
- 13 / 24 / 48 / 77 映射
- WB / TINT / ISO / Shutter 写入
- R78 stale completion token
- R79 比例/像素 selection/runtime/fallback
- Photo capture / RAW fallback / 保存链路
- 白底和拍后流程
- Deployment Target

## 7. 验证

| 验证项 | 结果 | 证据 |
| --- | --- | --- |
| Generic iOS build | `BUILD SUCCEEDED` | `/tmp/r80b_interface_build_1.log` |
| R80A token compile | `BUILD SUCCEEDED` | `/tmp/r80a_design_system_build_2.log` |
| 历史工程残留排除 | 未 stage | `git status --short` |

真机视觉验收仍需在后续 R80D 中完成；本轮不声明最终 R80 完成。

## 8. 风险与边界

已解决：

- 主界面高频控件开始统一到单一 accent。
- 顶部、参数条、镜头条、Zoom/MF、比例/像素、快门接入统一 token。
- Reduce Transparency / Increase Contrast 的基础回退入口已存在。
- 快门有轻量按压反馈，但不阻塞拍摄请求。

仍需 R80C / R80D 继续：

- 所有参数 ruler 的交互 profile 还未完全抽象为单一 engine。
- VoiceOver 逐控件可调整说明仍需补充。
- 真机视觉、手感、动画 hitch 仍需 R80D 验收。
- 横屏和多机型布局仍需最终收口。

## 9. Commit 计划

本轮提交：

```text
R80B refine iOS27 capture interface
```

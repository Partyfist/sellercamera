# R81 iOS 27 Camera Design System and Control Unification Report

日期：2026-06-17
基线 Commit：`a4a97c6 R80D close iOS27 UI motion and performance`
状态：完成。代码、构建、安装、启动通过；iPhone 14 Pro Max 真机视觉、参数手感、拍摄保存矩阵已人工确认通过。

## 1. 改动摘要

R81 在 R80D 稳定基线上继续收口拍摄主界面视觉系统。本轮只修改 UI 展示层、布局层、动画 resolver 使用方式和可复用视觉 token，不修改相机 runtime。

完成内容：

- 扩展 `SellerCameraDesignSystem.swift`，新增 R81 语义 token 与控件状态模型。
- 底部参数入口统一为 `SellerCameraControlState` + `SellerCameraControlVisualStyle`。
- EV / WB / TINT / ISO / Shutter 参数 ruler、MF ruler、Zoom ruler、Ratio / Pixel ruler 统一到 `SellerCameraRulerStyle` 的视觉语义。
- 顶部工具区、意图切换、更多面板、镜头条、快门区改用统一 accent、surface、radius、spacing、typography。
- 不可用参数展示统一为 `—`，避免伪造默认值。
- 左右底部入口文案从“最新 / 图册”收敛为更清晰的“照片 / 图片”。

## 2. 文件清单

| 文件 | 职责 |
| --- | --- |
| `SellerCamera/SellerCameraDesignSystem.swift` | 新增 R81 语义色、圆角、间距、字体、控件状态、控件视觉样式、ruler style |
| `SellerCamera/CaptureBottomParameterBar.swift` | 底部参数入口、参数面板入口、参数 ruler、AUTO / RESET / LOCK 控制胶囊视觉统一 |
| `SellerCamera/CaptureScreen.swift` | 顶部工具区、意图切换、比例/像素、更多面板、MF/Zoom ruler、镜头条、快门区视觉收口 |
| `README.md` | R81 报告索引 |
| `docs/reports/r81_ios27_camera_design_system_and_control_unification.md` | 本报告 |

## 3. Design System Token 列表

新增 / 扩展：

- `SellerCameraColor`
  - `canvasBackground`
  - `controlSurfacePrimary`
  - `controlSurfaceSecondary`
  - `controlSurfacePressed`
  - `controlSurfaceDisabled`
  - `textPrimary`
  - `textSecondary`
  - `textTertiary`
  - `textDisabled`
  - `accentPrimary`
  - `accentWarning`
  - `accentLocked`
  - `accentSuccess`
  - `divider`
  - `viewfinderBorder`
  - `focusNormal`
  - `focusLocked`
  - `focusWarning`
- `SellerCameraRadius`
  - `compact`
  - `control`
  - `capsule`
  - `panel`
  - `viewfinder`
- `SellerCameraSpacing`
  - `xxs`
  - `xs`
  - `sm`
  - `md`
  - `lg`
  - `xl`
  - `xxl`
  - `hitTarget`
- `SellerCameraTypography`
  - `toolLabel`
  - `parameterName`
  - `parameterValue`
  - `rulerPrimaryValue`
  - `rulerSecondaryValue`
  - `statusLabel`
- `SellerCameraRulerStyle`
  - `professional`
  - `compactOption`

说明：

- `SellerCameraColor` / `SellerCameraRadius` / `SellerCameraSpacing` / `SellerCameraTypography` 是 R81 面向拍摄页的新语义层。
- 保留 R80 的 `SellerCameraColorToken` 等底层 token 作为兼容底座，避免一次性全局改名造成高风险重构。
- 主强调色仍只有 Camera Amber。

## 4. 控件状态映射

新增：

```swift
enum SellerCameraControlState {
    case normal
    case selected
    case active
    case locked
    case warning
    case disabled
}
```

状态表达：

| 状态 | 视觉表达 | 读屏表达 |
| --- | --- | --- |
| `normal` | 弱 surface、secondary text、低描边 | 可用 |
| `selected` | amber 文字、轻 surface、选中下划线、略强描边 | 已选中 |
| `active` | amber 强一点的 surface / stroke | 正在调节 |
| `locked` | amber locked 语义，不额外使用彩色参数色 | 已锁定 |
| `warning` | warning 只用于 RAW 不可用等风险 | 需要注意 |
| `disabled` | disabled text、disabled surface、弱描边 | 不可用 |

已接入：

- 底部参数入口
- 参数面板顶部入口
- AUTO / RESET / LOCK 控制胶囊
- Ratio / Pixel option chip
- 意图切换
- 顶部工具按钮
- 镜头焦段和 AE-L / MF capsule
- 更多面板按钮

## 5. Ruler 组件复用说明

新增：

```swift
struct SellerCameraRulerStyle
```

统一内容：

- selected / normal tick width
- major / medium / minor tick height
- selected tick height
- current indicator width / height
- value badge height
- active lift 语义

已接入：

- 参数 horizontal ruler
- MF ruler
- Zoom ruler
- Ratio / Pixel discrete ruler

未修改：

- EV / WB / TINT / ISO / Shutter mapping
- MF lens position 写入
- Zoom anchor / soft snap / runtime commit
- Ratio / Pixel R79 selection/runtime/fallback
- 惯性参数、drag sensitivity、runtime throttle

## 6. Reduce Motion 和无障碍说明

保留 R80D：

- `SellerCameraMotionToken.resolved(_:reduceMotion:)`
- 参数入口、ruler、panel、Zoom、MF、Ratio / Pixel 的 Reduce Motion 回退
- VoiceOver label / value / hint

R81 继续增强：

- 控件状态新增 `accessibilityText`。
- 底部参数入口和参数面板入口读出统一状态。
- 不可用参数展示 `—`，VoiceOver 同步读出不可用。
- Ratio / Pixel、镜头、更多面板使用相同状态语义，不只依赖颜色。

未做：

- 未把 ruler 暴露为完整 custom adjustable action；当前仍保留触摸拖动和现有读屏提示。
- 未重排 Dynamic Type 极大字号布局；仍采用 HUD 缩放和最小可读策略。

## 7. 性能风险处理

已遵守：

- 未在拖动路径增加 blur。
- 未在每帧创建 formatter。
- 未对整个 `CaptureScreen` 增加全局隐式动画。
- 手势 `onChanged` 未新增逐帧 `withAnimation`。
- Ruler tick identity 仍保持稳定 index。
- 未重建 `CaptureLivePreviewView` 或 AVCaptureSession 容器。
- Material / glass 使用仍限制在控制面板，不覆盖 preview。

硬编码审计结果：

- 改动前核心文件硬编码命中：`169` 行。
- 改动后核心文件硬编码命中：`34` 行。
- 剩余命中主要集中在 Design System 底层 token、取景遮罩、glyph 细节和 preview 安全 hit area；本轮不继续扩大到无关绘制细节。

## 8. 构建结果

| 验证项 | 结果 | 证据 |
| --- | --- | --- |
| Generic iOS build | `BUILD SUCCEEDED` | `/tmp/r81_design_system_build_2.log` |
| iPhone 14 Pro Max device build | `BUILD SUCCEEDED` | `/tmp/r81_device_build_1.log` |
| `git diff --check` | 通过 | 本轮执行 |

工具链：

- Xcode：`Xcode 27.0`
- Xcode build：`27A5194q`
- Swift：`Apple Swift version 6.4`
- iPhoneOS SDK：`27.0`
- macOS：`26.5.1 (25F80)`

## 9. 真机安装启动结果

设备：

- `iPhone14 pro Max`
- `iPhone 14 Pro Max (iPhone15,3)`
- UDID：`E7D43088-7946-5FDB-BB14-E38124BB37DB`

结果：

| 验证项 | 结果 | 证据 |
| --- | --- | --- |
| Install | `App installed` | `/tmp/r81_device_install_1.log` |
| Launch | `Launched application` | `/tmp/r81_device_launch_1.log` |
| PID | `10394` | `xcrun devicectl device info processes` |
| 5 秒后复查 | `SellerCamera` 仍存在 | PID `10394` |

## 10. 参数交互验收矩阵

Codex 已完成：

- 构建通过。
- 安装通过。
- 启动通过。
- 进程创建和 5 秒保活通过。
- 未修改参数 runtime 和写入节流。

人工在 iPhone 14 Pro Max / iOS 27 Beta 上确认：

| 项目 | 状态 |
| --- | --- |
| ISO Auto / Manual 点击、慢滑、快滑 | 通过 |
| Shutter Auto / Manual 点击、慢滑、快滑 | 通过 |
| EV Auto / Manual / Locked | 通过 |
| WB Auto / Manual | 通过 |
| TINT | 通过 |
| MF 进入、调节、退出 | 通过 |
| Zoom 连续拖动和焦段锚点同步 | 通过 |
| 13 / 24 / 48 / 77 焦段点击 | 通过 |
| 参数快速切换 | 通过 |
| 惯性未结束时重新按下 | 通过 |
| fine / ultraFine 微调 | 通过 |
| Reset / Auto 恢复 | 通过 |

人工验收回报：`R81 完成，无黑屏/崩溃/保存失败，手感和设计感优于 R80D`。

## 11. 拍摄与保存结果

人工确认：

- 预览可见。
- 无永久黑屏。
- 无崩溃。
- 拍摄成功。
- 保存成功。
- R81 设计感与手感优于 R80D。

## 12. 已知限制

- R81 没有完整拆分 `CaptureScreen.swift`；为了避免 runtime 迁移风险，本轮只在现有组件内收口样式。
- `CaptureParameterGlyph` 的内部微型图形仍保留少量局部尺寸和 opacity；它属于 glyph 绘制细节，后续可独立抽成 icon style。
- 取景遮罩和 `CaptureLivePreviewView` 相关低层视觉仍有少量固定色值，本轮不碰 preview 链路。
- Instruments hitch / GPU overdraw 未量化，本轮以 CLI 构建和人工真机手感作为验收依据。

## 13. 未修改范围

未修改：

- AVFoundation session 生命周期
- 相机设备发现与虚拟多摄选择
- ISO / Shutter / EV / WB / TINT / MF runtime 映射
- 自动曝光 / 自动白平衡算法
- ProductAutoScene 分析
- 点击对焦与近距 fallback
- 镜头切换和 zoom runtime
- 稳定器等待逻辑
- RAW 与最佳质量拍摄链路
- 白底处理与分割链路
- 照片保存流程
- R80D Reduce Motion 行为
- 已验证的拖动灵敏度、惯性参数和 runtime 写入节流
- Deployment Target

## 14. Git Commit

本轮提交：

```text
R81 unify iOS27 camera design system and controls
```

Commit hash：以最终回报和 `git log -1 --oneline` 为准

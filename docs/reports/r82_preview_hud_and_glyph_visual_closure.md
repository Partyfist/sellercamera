# R82 Preview HUD and Glyph Visual Closure Report

日期：2026-06-17
基线 Commit：`4192a33 R81 unify iOS27 camera design system and controls`
状态：完成。代码实现、静态检查、generic build、device build、安装、启动、PID 创建、真机视觉补验、拍摄保存与参数回归均已通过。

## 1. 改动摘要

R82 在 R81 Design System 基线上继续收口拍摄预览 HUD 与 glyph 尾项。本轮只修改展示层视觉 token、glyph 绘制、preview overlay、HUD 表面和无障碍信息，不修改相机 runtime。

完成内容：

- 新增 `SellerCameraGlyphMetrics` / `SellerCameraGlyphProminence` / `SellerCameraGlyphStyleModifier`。
- 新增 `SellerCameraPreviewMetrics` / `SellerCameraPreviewStyle`。
- 统一参数自绘 glyph 的线宽、点径、微型文字字号和暗色中心点。
- 统一顶部、更多、提示、底部图片入口的 SF Symbol 尺寸、weight、frame 和状态色。
- 统一 preview 中 AE/AF lock、AE lock、burst、countdown、quick preview 的 HUD 表面。
- 统一网格线、水平仪和对焦框的颜色、线宽、透明度和对比策略。
- 停用重复的内部比例 guide overlay，避免与外层 workspace mask 叠加产生取景区域上方灰边。
- 对焦框增加低成本双层描边，提升白底、暗背景和复杂背景可读性。
- 对焦状态圆点从方框上沿调整到方框中心，避免视觉重心偏移。
- 提升普通文字层级亮度，改善暗场景下文件/按钮文案偏灰问题。

## 2. 文件清单

| 文件 | 职责 |
| --- | --- |
| `SellerCamera/SellerCameraDesignSystem.swift` | 新增 R82 glyph / preview overlay / HUD 视觉 token 与 glyph modifier，调整对焦状态点和文字亮度 token |
| `SellerCamera/CaptureBottomParameterBar.swift` | 参数自绘 glyph 使用统一 metrics，不改变参数按钮布局和点击区域 |
| `SellerCamera/CaptureScreen.swift` | 顶部工具、更多面板、提示 HUD、底部图片入口 SF Symbol 接入统一 glyph style |
| `SellerCamera/CaptureLivePreviewView.swift` | 网格、水平仪、对焦框、锁定/连拍/倒计时/快速预览 HUD 接入 preview token，并停用重复比例 guide |
| `README.md` | 新增 R82 报告索引 |

## 3. 硬编码审计结果

审计范围：

- `SellerCamera/SellerCameraDesignSystem.swift`
- `SellerCamera/CaptureScreen.swift`
- `SellerCamera/CaptureBottomParameterBar.swift`
- `SellerCamera/CaptureLivePreviewView.swift`

审计命令覆盖：

- `.foregroundStyle(.white)`
- `.foregroundColor(.white)`
- `Color.white`
- `Color.black`
- `Color.gray`
- `.opacity(`
- `.lineWidth:`
- `.stroke(`
- `.frame(width:`
- `.frame(height:`
- `.font(.system(size:`
- `.shadow(`
- `.blur(`
- `.cornerRadius(`

分类结果：

| 分类 | 处理 |
| --- | --- |
| 应纳入 token | preview overlay 颜色、网格线宽、水平仪色彩和线宽、对焦框线宽、HUD surface、glyph 字号/线宽/点径 |
| 几何结构允许保留 | preview fitted rect、按钮布局 frame、ruler tick spacing、手势命中尺寸、焦段条宽度 |
| 相机业务逻辑不得修改 | 对焦坐标、水平仪阈值/滞回、ratio mapping、zoom/mf/参数写入节流、capture/save |
| 一次性装饰保留 | 少量 shape 内部 Path 几何、transparent hit target、ruler 动画过渡 |

命中变化：

- R82 前核心 UI 文件审计命中：`214` 行。
- R82 前 live preview overlay 审计命中：`48` 行。
- R82 后目标审计命中：`11` 行。
- 剩余命中均在 `SellerCameraDesignSystem.swift` 的底层 token / glyph modifier 内。

## 4. 新增或复用的 token

新增：

- `SellerCameraGlyphProminence`
- `SellerCameraGlyphMetrics`
- `SellerCameraGlyphStyleModifier`
- `View.sellerCameraGlyphStyle(state:prominence:)`
- `SellerCameraPreviewMetrics`
- `SellerCameraPreviewStyle`
- `SellerCameraTypography.previewCountdown`
- `SellerCameraTypography.glyphMicroLabel`
- `SellerCameraTypography.glyphNanoLabel`

复用：

- `SellerCameraColor`
- `SellerCameraTypography`
- `SellerCameraSpacing`
- `SellerCameraRadius`
- `SellerCameraControlState`
- `SellerCameraControlVisualStyle`
- `SellerCameraMotionToken`

## 5. Glyph 统一结果

SF Symbols：

- 顶部工具按钮接入 `.sellerCameraGlyphStyle(state:prominence:)`。
- 更多面板图标接入统一 glyph style。
- Preview hint 的 `sparkles` 接入统一 glyph style。
- 底部图片/照片入口图标接入统一 glyph style。
- 对焦锁定 / 解锁小图标接入统一 glyph style。

自绘 glyph：

- EV / WB / TINT / ISO / Shutter 参数 glyph 使用统一线宽、点径和微型文字 token。
- disabled 状态保留可见度，不完全消失。
- selected 状态仍通过 color / stroke / surface 表达，不依赖放大。

## 6. 对焦框状态映射

保持现有四角结构和状态机，只调整视觉：

| 状态 | 视觉 |
| --- | --- |
| `focusing` | Amber 对焦色，外层低透明暗描边，内层轻提示角 |
| `focused` | Success 确认色，短暂状态点 |
| `locked` | Success / locked 语义色，锁图标提供非颜色识别 |
| `unlocked` | Blue unlock 语义，开锁图标提供非颜色识别 |
| `warning` | Warning 色和 warning badge，不闪烁、不常驻 |

可读性策略：

- 主 stroke + 暗色 contrast outline。
- focused / warning / focusing 圆点位于方框中心。
- 不读取画面颜色。
- 不新增 blur。
- 不新增无限循环动画。
- Reduce Motion 下取消 scale 依赖，仅保留透明度过渡。

## 7. 水平仪和网格收口结果

水平仪：

- 统一 neutral / aligned 颜色。
- 统一 short tick、center tick、cross symbol 线宽和尺寸。
- 保留原阈值、滞回、平滑和模式切换逻辑。
- 装饰线条隐藏于 VoiceOver。

网格：

- 使用 `SellerCameraPreviewStyle.gridLine`。
- 使用 `SellerCameraPreviewMetrics.hairlineWidth`。
- 保持 overlay 与 preview 区域绑定，不改变比例裁切逻辑。
- 网格不进入 VoiceOver。

## 8. Preview HUD 统一结果

新增轻量展示组件：

- `CapturePreviewStatusBadge`

接入：

- AE/AF Lock
- AE Lock
- Burst progress
- Countdown
- Quick preview
- Assist hint

HUD 表面统一：

- 半透明深色 capsule / rounded panel。
- 统一 stroke。
- 统一 foreground。
- Reduce Transparency 时使用更实体的 control surface。
- 不新增全屏遮罩或大面积材料 blur。

## 9. 明暗场景可读性策略

采用：

- HUD 深色半透明底。
- 对焦框双层 stroke。
- 水平仪和网格使用稳定低透明 overlay token。
- 状态 icon + 文案组合，不仅依赖颜色。

未采用：

- 实时画面采样。
- 每帧亮度分析。
- 高频颜色自适应。
- 大面积 blur。
- 全屏遮罩。

## 10. Reduce Motion / Reduce Transparency

Reduce Motion：

- 对焦框动画改用 `SellerCameraMotionToken.resolved`。
- Reduce Motion 下取消对焦框 scale 依赖。
- 未对 sensor 高频值新增 spring。

Reduce Transparency：

- `CapturePreviewStatusBadge` 在 Reduce Transparency 下使用实体 `controlSurfaceSecondary`。
- HUD 不依赖纯透明背景表达状态。

## 11. 无障碍结果

已处理：

- 网格隐藏于 VoiceOver。
- 水平仪装饰线隐藏于 VoiceOver。
- 对焦框作为整体读取。
- 对焦锁定 / warning / focusing 提供状态 value。
- HUD badge 合并读取文本与状态。
- SF Symbol 图标不替代业务 label。

未量化但不阻断：

- VoiceOver 实机朗读顺序。
- Differentiate Without Color。
- Increase Contrast。
- Dynamic Type 极端字号下是否遮挡主操作。

## 12. 性能风险控制

已遵守：

- 未新增实时图像采样。
- 未新增每帧颜色分析。
- 未新增 blur。
- 未使用 `.drawingGroup()`。
- 未改变 preview session 容器。
- 未修改 grid / level / focus 的业务更新频率。
- 未引入新的 UUID identity。

## 13. Generic build 结果

命令：

```sh
DEVELOPER_DIR="/Applications/Xcode-27-beta.app/Contents/Developer" \
xcodebuild -project SellerCamera.xcodeproj \
  -scheme SellerCamera \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  build
```

结果：`BUILD SUCCEEDED`

证据：`/tmp/r82_generic_build_2.log`

## 14. Device build 结果

命令：

```sh
DEVELOPER_DIR="/Applications/Xcode-27-beta.app/Contents/Developer" \
xcodebuild -project SellerCamera.xcodeproj \
  -scheme SellerCamera \
  -configuration Debug \
  -destination 'platform=iOS,id=E7D43088-7946-5FDB-BB14-E38124BB37DB' \
  build
```

结果：`BUILD SUCCEEDED`

证据：`/tmp/r82_device_build_3.log`

工具链：

- Xcode：`27.0`
- Xcode build：`27A5194q`
- Swift：`Apple Swift version 6.4`
- iPhoneOS SDK：`27.0`
- macOS：`26.5.1 (25F80)`

## 15. 安装和启动结果

设备：

- `iPhone14 pro Max`
- `iPhone 14 Pro Max (iPhone15,3)`
- UDID：`E7D43088-7946-5FDB-BB14-E38124BB37DB`

安装：

- 结果：`App installed`
- 证据：`/tmp/r82_device_install_4.log`

启动：

- 结果：`Launched application with com.partyfist.SellerCamera bundle identifier.`
- PID：`10592`
- 5 秒后复查：`SellerCamera` 仍存在
- 证据：`/tmp/r82_device_launch_4.log`

## 16. 真机人工验收

已人工确认：

- 取景区域上方灰色边缘已修复。
- 对焦圆点已在方框中间。
- 文字亮度已调整到舒适可读。

已完成矩阵：

- Glyph：顶部按钮、激活/未激活、disabled、锁定、快速点击、暗场景文字可读性通过。
- 对焦框：点击对焦、focusing / focused 视觉、状态点位置、无对焦框残留通过。
- 水平仪：无颜色抖动通过。
- 网格：无越界通过。
- HUD：无预览闪烁、无 HUD 高频跳动通过。
- 回归：参数手感无回归，拍照和保存通过。

当前人工验收：

- 用户确认：`灰边已修复`。
- 用户确认：`对焦圆点已在方框中间`。
- 用户确认：`文字亮度舒服`。
- 用户最终确认：`R82 完成，无黑屏/崩溃/保存失败，无预览闪烁/HUD 跳动/对焦框残留/水平仪抖动/网格越界，参数手感无回归`。

## 17. 拍摄和保存结果

Codex 已确认：

- App 安装成功。
- App 启动成功。
- PID 创建成功。
- PID 5 秒短时保活成功。
- 取景区域上方灰边修复后重新安装启动成功。
- 对焦圆点和文字亮度修复后重新安装启动成功。

人工已确认：

- 无黑屏。
- 无崩溃。
- 无预览闪烁。
- 无 HUD 高频跳动。
- 无对焦框残留。
- 无水平仪颜色抖动。
- 网格无越界。
- 参数手感无回归。
- 拍摄成功。
- 保存成功。

## 18. 未修改范围

未修改：

- AVCaptureSession 生命周期。
- 相机设备选择。
- 虚拟多摄逻辑。
- 镜头切换和 Zoom runtime。
- 点击对焦坐标和对焦流程。
- AE、AF、AE/AF Lock 业务语义。
- ISO / Shutter / EV / WB / TINT / MF 映射。
- 参数灵敏度、惯性、吸附与节流参数。
- ProductAutoScene。
- 自动 EV 与自动 WB。
- 清晰度检测。
- 稳定器等待逻辑。
- RAW 与最佳质量链路。
- 拍摄和保存链路。
- 白底处理链路。
- R80D/R81 Reduce Motion 行为。
- 页面主要布局结构。

## 19. 已知限制

- 未新增独立 Swift 文件，避免触发 project.pbxproj 历史残留混入。
- 未完整拆分 `CaptureScreen.swift` 或 `CaptureLivePreviewView.swift`。
- `CaptureParameterGlyph` 内部仍保留少量 Path 几何尺寸，它们属于自绘图形结构而非视觉语义。
- Instruments hitch / GPU overdraw 未量化。
- 真机复杂光照、VoiceOver、Differentiate Without Color、Increase Contrast、Dynamic Type 待人工补验，当前不阻断 R82 主链路视觉收口。
- 内部 `CaptureAspectRatioGuideOverlay` 已停用调用；外层 `CaptureWorkspaceMaskOverlay` 继续负责取景区域边界，避免双层遮罩叠加灰边。

## 20. Git commit hash

本轮提交：

```text
R82 close preview HUD and glyph visual consistency
```

Commit hash：以最终回报和 `git log -1 --oneline` 为准

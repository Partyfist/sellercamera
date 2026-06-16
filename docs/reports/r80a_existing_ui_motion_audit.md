# R80A 现有拍摄 UI 与动效手感审计报告

日期：2026-06-16
基线 Commit：`5e49478 R79 smooth ratio and output quality controls`
任务性质：R80 iOS 27 专业相机 UI 设计系统升级前置审计

## 1. 起始保护

执行并保存：

- `git status --short --branch`
- `git log -5 --oneline`
- `git diff --stat`
- `git diff > /tmp/r80_prework.patch`
- `git status --short > /tmp/r80_prework_status.txt`

起始状态确认：

- 当前分支：`main...origin/main [ahead 19]`
- 已包含：`b4a6897 R78ABCD restore iOS27 camera runtime and manual controls`
- 已包含：`5e49478 R79 smooth ratio and output quality controls`
- 历史排除项仍存在：`SellerCamera.xcodeproj/project.pbxproj`
- 历史排除项仍存在：`SellerCamera/SellerCamera.xcodeproj/project.xcworkspace/contents.xcworkspacedata`

R80 不混入上述工程残留，不使用 `git add .` / `git add -A`。

## 2. 审计范围

重点文件：

- `SellerCamera/CaptureScreen.swift`
- `SellerCamera/CaptureBottomParameterBar.swift`
- `SellerCamera/CaptureProfessionalParameterPanel.swift`
- `SellerCamera/CaptureLivePreviewView.swift`

相关组件：

- `CaptureTopStatusBar`
- `CapturePreviewContainer`
- `CaptureLensControlStrip`
- `CaptureBottomParameterBar`
- `CaptureHorizontalParameterRulerPanel`
- `CaptureHorizontalParameterRuler`
- `CaptureManualFocusRulerPanel`
- `CaptureZoomDialView`
- `CaptureOptionControlPanel`
- `CaptureDiscreteOptionRuler`
- `CaptureBottomActionBar`
- `FocusMarkerOverlay`
- `LevelIndicatorOverlay`
- `CaptureAssistHintSlot`

## 3. 页面层级审计

| 层级 | 当前组件 | 状态 | 观察 |
| --- | --- | --- | --- |
| 顶部工具区 | `CaptureTopStatusBar` | 可用但样式散落 | flash、比例/像素、切换相机、更多使用胶囊，但色值、padding、active 语义写在组件内部 |
| 相机状态区 | `memoryStatusText`、hint/toast | 可用但层级弱 | 状态文字与临时提示的字体和颜色缺少统一 token |
| 取景框 | `CapturePreviewContainer` | 主链路稳定 | 比例切换复用 R79 状态，不应重建 preview；周边 canvas 色值直接写在 View 内 |
| 网格与水平仪 | `CaptureLivePreviewView` overlay | 可用 | 水平仪使用 green/white 动态色，与全局 accent 不一致 |
| 对焦框 | `FocusMarkerOverlay` | 可用 | focused / locked / warning 色彩多源，需统一为 accent / warning |
| 镜头条 | `CaptureLensControlStrip`、`CaptureZoomDialView` | 真机已验收 | 13/24/48/77 与 zoom ruler 可用，但 cyan、blue、amber 多色并存 |
| 参数条 | `CaptureBottomParameterBar` | 可用 | EV/WB/TINT/ISO/Shutter/MF 入口结构接近统一，但 active title 与 value 使用不同强调色 |
| 参数 ruler | `CaptureHorizontalParameterRuler`、`CaptureManualFocusRulerPanel` | 可用 | tick、badge、panel 外观相似但不共用样式 token |
| 比例与像素 | `CaptureOptionControlPanel`、`CaptureDiscreteOptionRuler` | R79 通过 | 手势稳定；R80 只应统一视觉和动效，不改 selection/runtime/fallback |
| 快门按钮 | `CaptureBottomActionBar` | 可用 | 白色圆形可识别，但 press / capture 动效 token 缺失 |
| 底部辅助按钮 | latest/gallery cards | 可用 | 透明白底、圆角 13，与其他控制圆角不一致 |
| 提示与 toast | `captureHintText`、assist hint | 可用 | 胶囊样式、位置、warning 与 disabled 表达未统一 |
| 锁定状态 | AE-L/MF/LOCK | 可用 | lock 使用 amber / white / cyan 混合，语义色需收敛 |
| 拍摄状态 | latest/save/status text | 可用 | 状态色散落，成功/失败/处理中缺少统一状态 token |

## 4. 当前视觉问题

| 项目 | 观察 | 风险 |
| --- | --- | --- |
| 颜色重复或冲突 | cyan accent、warm amber、manual blue、green level、orange RAW warning 同时存在 | 违背 R80 one accent 原则，用户难以形成稳定状态认知 |
| 十六进制 / RGB 散落 | `Color(red: 0.20, green: 0.88, blue: 0.76)` 在多个文件重复 | 后续改主题成本高，容易出现不一致 |
| 同类控件圆角不一致 | 10 / 12 / 13 / 14 / 16 / 17 / 18 同时存在 | 视觉碎片化，缺少 iOS 27 原生一致性 |
| 字号分散 | 5.5、7、8.5、9、10、11、13、15、17 等散落 | 参数数字和状态切换时容易抖动，层级不稳 |
| 背景透明度混乱 | black/white opacity 0.025～0.98 多处分散 | 预览亮背景下可读性不可预测 |
| 控件层级偏多 | 多个 RoundedRectangle + material + shadow 同时叠加 | 容易产生玻璃噪声和 GPU 负担 |
| 边框偏多 | 每个 chip / capsule / panel 都单独 stroke | 小屏密度高时视觉噪声增加 |
| 选中态不统一 | 参数条 active value 用 warmAccent，镜头用 cyan，手动用 blue | 状态语言不一致 |
| disabled 状态不统一 | white opacity 0.22 / 0.32 / 0.36 / 0.54 混用 | 不可用与未选中容易混淆 |
| 提示遮挡风险 | ratio/pixel 面板浮在预览顶部，hint/toast 也在取景附近 | 临时层需要统一 zIndex 和收口动画 |
| 图标风格不一致 | SF Symbols weight、尺寸、label 组合未统一 | 顶部和底部按钮不够原生 |

## 5. 当前动画问题

| 项目 | 观察 | 风险 |
| --- | --- | --- |
| 动画 token 缺失 | `.easeOut(0.12)`、`.easeOut(0.14)`、`.easeInOut(0.18)` 多处散落 | 同类状态速度不一致 |
| 多段动画叠加 | parameter panel、value text、active kind 同时 animation | 面板切换时可能产生小幅抖动 |
| transition 与 layout animation 混合 | panel 使用 move/scale/opacity，父层同时 opacity animation | 新手势可能撞上旧动画 |
| 手势结束吸附分散 | parameter / zoom / ratio 三套 snap 逻辑 | 原生级连续感难统一 |
| 新手势打断能力不统一 | R79 ratio/pixel 有 generation，旧参数 ruler 主要依赖本地 state | 快速连续操作时旧动画覆盖风险不同 |
| 比例变化预览跳动风险 | 当前由 aspect ratio 影响容器几何 | 应保持 preview 不重建，仅几何变化 |
| 镜头切换 UI 与 runtime | R78D 已修复 runtime，但 UI 动效仍是直接状态更新 | 后续需要 modeSwitch token，避免长 loading 或整体消失 |
| 快门动效不足 | 快门无 press token 与 capture pulse | 用户缺少拍照确认触感，但不能阻塞 capture |

## 6. 当前手势问题

| 参数 / 控件 | 当前实现 | 问题 / 待统一点 |
| --- | --- | --- |
| EV | `CaptureHorizontalParameterRuler`，drag threshold + inertia | fine mode、inertia、haptic 与其它参数不共用 profile |
| WB | `CaptureHorizontalParameterRuler`，支持 fine | DEBUG 日志较多；selection haptic 使用 impact，需要统一节流 |
| TINT | `CaptureHorizontalParameterRuler` | 惯性较轻，但 profile 写在 switch 内 |
| ISO | `CaptureHorizontalParameterRuler` | 离散技术参数，maximum fling 与 tick spacing 应纳入 discrete profile |
| Shutter | `CaptureHorizontalParameterRuler` | step cooldown 与 pending 逻辑重要，不可破坏；视觉 profile 需统一 |
| MF | `CaptureManualFocusRulerPanel` | 与通用 parameter ruler 视觉相似但实现独立 |
| Zoom | `CaptureZoomDialView` | 另有 smoothing / soft snap / anchor haptic；应与 R80C profile 对齐 |
| Ratio | `CaptureDiscreteOptionRuler` | R79 已通过，R80 只统一视觉、motion、haptic token |
| Output Quality | `CaptureDiscreteOptionRuler` | RAW fallback 已通过，不改 selection/runtime/fallback |

跨控件共性问题：

- `DragGesture(minimumDistance:)` 取值分散：3 / 4 / 12。
- `maximumFlingSteps` 与 `inertiaScale` 分散在多个组件。
- haptic 使用 `UIImpactFeedbackGenerator` 与 `UISelectionFeedbackGenerator` 混合。
- boundary resistance、fine sensitivity、snap animation 没有统一语义命名。
- 部分手势期间仍对 tick selection 使用 `.animation`，后续需避免每帧隐式动画。

## 7. R80A 结论

R79 后拍摄主链路和比例/像素手势稳定，R80 不应重写相机 runtime 或已有 selection 逻辑。当前最大问题不是单个控件不可用，而是视觉、motion、haptic、ruler profile 缺少统一设计 token。

R80A 应先建立：

- `SellerCameraColorToken`
- `SellerCameraTypographyToken`
- `SellerCameraSpacingToken`
- `SellerCameraShapeToken`
- `SellerCameraMotionToken`
- `SellerCameraHaptic`
- `SellerCameraRulerStyle`
- `SellerCameraRulerInteractionProfile`
- Liquid Glass / material 回退修饰器

R80B 再逐步替换顶部、镜头、参数、快门、比例/像素面板的散落样式。R80C 再统一手势 profile，避免在 R80A 就重写稳定的参数写入链路。

## 8. 本轮不进入项

R80A 审计阶段不修改：

- `AVCaptureSession` 架构
- Auto 虚拟多摄策略
- Manual 物理镜头策略
- 13 / 24 / 48 / 77 映射
- WB / TINT / ISO / Shutter runtime 写入
- stale completion token
- Auto EV / Auto WB
- MF runtime throttle
- Photo capture
- RAW fallback
- 保存链路
- 白底处理
- AI 套图规划
- Deployment Target

# R80C 专业参数 Ruler 交互统一报告

日期：2026-06-16
基线 Commit：`e44bb39 R80B refine iOS27 capture interface`
任务性质：参数、镜头、比例与输出像素 ruler 手感 profile 收口

## 1. 设计原则

本轮不重写已通过真机验收的 R78 / R79 runtime 与 selection 链路，只把分散在多个 UI 组件里的手势参数收敛到 R80A 的设计系统内。

- Touch-first：拖动期间继续保持即时视觉反馈，不给每帧套隐式动画。
- Native-feel：慢滑跟手、快滑有限惯性、松手轻吸附。
- One model：EV / WB / TINT / ISO / Shutter / MF / Zoom / Ratio / Output Quality 使用同一 profile 语义。
- Runtime truth：视觉候选值仍通过现有回调提交，最终显示仍服从 runtime readback。
- Low risk：不改相机设备、曝光、白平衡、保存、RAW fallback 或 R79 选择逻辑。

## 2. 覆盖范围

| 控件 | 文件 | 本轮处理 |
| --- | --- | --- |
| EV / WB / TINT / ISO / Shutter 参数 ruler | `SellerCamera/CaptureBottomParameterBar.swift` | 使用 `professionalParameter(_:)` 统一 sensitivity、fine mode、inertia、maximum fling |
| MF ruler | `SellerCamera/CaptureScreen.swift` | 接入 `manualFocusPrecision`，保留现有 `onStep` 与 throttle 路径 |
| Zoom ruler | `SellerCamera/CaptureScreen.swift` | 接入 `zoomPrecision`，保留现有 anchor、soft snap 与 zoom commit 路径 |
| Ratio / Output Quality ruler | `SellerCamera/CaptureScreen.swift` | 接入 `ratioOutputQuality`，保留 R79 selection/runtime/fallback |
| Ruler profile | `SellerCamera/SellerCameraDesignSystem.swift` | 增加 `inertiaScale` 与参数类型映射 |

## 3. Ruler Interaction Profile

`SellerCameraRulerInteractionProfile` 当前统一描述：

- `pointsPerStep`
- `sensitivity`
- `fineSensitivity`
- `ultraFineSensitivity`
- `maximumFlingSteps`
- `velocityThreshold`
- `boundaryResistance`
- `snapAnimation`
- `allowsContinuousValue`
- `inertiaScale`

新增配置：

| Profile | 适用 | 手感目标 |
| --- | --- | --- |
| `shutterTechnical` | Shutter | 离散档位明确，允许较大但受限的快滑推进 |
| `discreteTechnical` | ISO / WB | 档位式参数，惯性最多少量推进 |
| `tintPrecision` | TINT | 连续微调，惯性轻，避免色偏跳变 |
| `exposurePrecision` | EV | 高精度、低惯性，避免曝光补偿飞格 |
| `manualFocusPrecision` | MF | 大范围覆盖与精密微调兼顾 |
| `zoomPrecision` | Zoom | 低惯性，保护焦段锚点与高倍精度 |
| `ratioOutputQuality` | Ratio / Output Quality | 保持 R79 双行刻度的有限 fling 和边界阻尼 |

## 4. 参数入口统一

`CaptureHorizontalParameterRuler` 不再用本地 `switch` 分散决定：

- `inertiaScale`
- `inertiaMaximumStepCount`
- normal / fine / ultra fine sensitivity

现在统一从：

```swift
SellerCameraRulerInteractionProfile.professionalParameter(item.parameter.kind)
```

获取配置。这样 EV、WB、TINT、ISO、Shutter 的手势语义集中在设计系统内，后续微调不用进入每个 View 分支反复改 magic number。

## 5. MF / Zoom / Ratio / Pixel 收口

MF：

- 使用 `manualFocusPrecision` 替换局部 hard-coded inertia 与 sensitivity。
- 保留 `ManualFocusRulerTuning` 中与现有视觉密度和步进相关的稳定设置。
- 不修改 lens position 写入、AF/MF 状态、runtime throttle。

Zoom：

- 使用 `zoomPrecision` 统一常用区 `pointsPerStep`、fine mode 与 inertia scale。
- 保留高倍区独立 `pointsPerZoomHigh`，避免 77mm / 高倍端突然过快。
- 不修改焦段锚点、soft snap、13 / 24 / 48 / 77 映射。

Ratio / Output Quality：

- 使用 `ratioOutputQuality` 提供惯性和边界阻尼。
- 保留 R79 的可选项过滤、RAW fallback、runtime 同步和 `snapGeneration`。
- 快滑最大推进继续受调用方与 profile 双重限制。

## 6. 惯性与吸附

本轮统一后的原则：

- 惯性由 `predictedTranslation` 经过 `inertiaScale` 转换，不允许无限推进。
- 每类 ruler 使用 `maximumFlingSteps` 限制快滑推进。
- Ratio / Pixel 额外使用调用方 `maximumFlingSteps` 与 profile 上限取最小值。
- MF / Zoom 在 fine mode 下不放大惯性，保护精密控制。
- Snap 动画继续使用 `SellerCameraMotionToken.snap` 的短、高阻尼模型。

## 7. Fine Mode

保留现有“手指上移进入精细模式”的交互，并统一为三段：

| 垂直位移 | 模式 | 配置来源 |
| --- | --- | --- |
| `<= 40pt` | Normal | `sensitivity` |
| `40pt ~ 90pt` | Fine | `fineSensitivity` |
| `> 90pt` | Ultra fine | `ultraFineSensitivity` |

本轮没有新增大提示、解释性浮层或阻塞 UI；fine mode 仍是专业用户可发现的轻手势。

## 8. 触觉与动画

- 参数跨档、MF、Zoom、Ratio / Pixel 继续使用 R80B 接入的 `SellerCameraHaptic.play(.selection)`。
- 本轮未增加每帧 haptic，也未在 `onChanged` 中新增大量 `withAnimation`。
- 视觉吸附和面板状态仍绑定具体 state，不对整个 `CaptureScreen` 使用全局 animation。
- 新手势打断能力继续依赖现有 `snapGeneration` / 本地 dragging state，不引入第二套异步状态。

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
- Deployment Target

## 10. 验证

| 验证项 | 结果 | 证据 |
| --- | --- | --- |
| Generic iOS build | `BUILD SUCCEEDED` | `/tmp/r80c_ruler_profile_build_1.log` |
| R80A / R80B 中间提交可构建 | 已通过 | `/tmp/r80a_design_system_build_2.log`、`/tmp/r80b_interface_build_1.log` |
| 历史工程残留排除 | 未 stage | `git status --short` |

本轮属于 UI 手势 profile 收口，真机慢滑、快滑、连续切换、无明显 hitch 仍需 R80D 在 iPhone 14 Pro Max / iOS 27 Beta 上补齐。

## 11. 风险与边界

已解决：

- 参数 ruler、MF、Zoom、Ratio / Pixel 的惯性、fine mode、边界阻尼开始共用统一语义。
- 参数类型和手感配置集中到 `SellerCameraDesignSystem.swift`，减少后续散落改数。
- 保留 R78/R79 已验证的 runtime、selection、fallback 与保存链路。

仍需 R80D 继续：

- 真机验证所有参数慢滑 / 快滑 / 打断 / 边界反向。
- 检查连续切换 WB → ISO → Shutter → MF → Zoom → Ratio → Pixel 是否有旧动画残留。
- 使用真机观察是否存在 SwiftUI body 重算导致的明显 hitch。
- 补齐 VoiceOver、Reduced Motion、Dynamic Type 的最终验收记录。

本轮刻意未做：

- 未创建独立 `ProfessionalRulerInteractionEngine` 文件，避免在 R80C 中重写稳定手势。
- 未拆分 `CaptureScreen.swift` 大文件，避免把 UI 组织调整和手感修复混成高风险改动。
- 未修改任何相机设备、曝光、白平衡、RAW 或保存业务逻辑。

## 12. Commit 计划

本轮提交：

```text
R80C unify professional ruler interactions
```

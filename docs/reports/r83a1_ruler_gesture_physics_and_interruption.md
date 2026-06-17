# R83A1 Ruler Gesture Physics and Interruption

## 1. 改动摘要

R83A1 只收口参数 Ruler 的基础物理闭环，不进入 R83A2 的视觉密度和参考应用细节复刻。

- 将参数 Ruler、MF Ruler、Zoom Ruler、Ratio / Pixel 离散 Ruler 的 `DragGesture` 起始距离改为 `minimumDistance: 0`，由内部 dead zone 过滤轻微噪声。
- 将惯性依据从完整 `predictedEndTranslation` 改为近期拖动速度窗口，降低异常峰值导致的飞格。
- 保留 fractional offset，通过 `lastDragStepTranslation` 累积未满一步的位移，慢拖和反向拖动更稳定。
- 为参数 Ruler 和 MF Ruler 增加 `gestureGeneration` / `inertiaGeneration`，新手势会取消旧惯性任务。
- 增加 Debug 限频诊断日志 `[R83A1Ruler]`，覆盖 translation、velocity、sensitivity、index、projectedSteps 和 generation。

## 2. 文件清单

- `SellerCamera/SellerCameraDesignSystem.swift`
  - 扩展 `SellerCameraRulerInteractionProfile`，明确 haptic policy、dead zone、step cooldown、velocity projection 和 profile 级惯性限制。
- `SellerCamera/CaptureBottomParameterBar.swift`
  - 重构 ISO / Shutter / EV / WB / TINT 共用横向参数 Ruler 的起手、速度估算、惯性取消、Debug 诊断和 VoiceOver adjustable。
- `SellerCamera/CaptureScreen.swift`
  - 对 MF、Zoom、Ratio / Pixel 的 Ruler 接入同一速度估算口径；MF 保留 0.04s runtime 写入节流。
- `docs/reports/r83a1_ruler_gesture_physics_and_interruption.md`
  - 新增本轮 R83A1 诊断、实现和验收报告。
- `README.md`
  - 增加 R83A1 报告索引。

## 3. 原交互问题审计

R83A 前的主要问题集中在交互物理层：

| 项目 | 原表现风险 | R83A1 处理 |
| --- | --- | --- |
| 起手 | `minimumDistance: 4` 让轻微移动不立即反馈 | 改为 `minimumDistance: 0`，用 profile dead zone 控制是否写值 |
| 慢拖 | 每次用当前 translation 直接 round，未满一格位移体验不稳定 | 保留 fractional offset，未满一步继续累积 |
| 速度 | 依赖 `predictedEndTranslation`，可能受系统预测峰值影响 | 使用近期 translation / elapsed 估算 release velocity |
| 惯性 | 单次 final step 或旧异步任务可能与新手势冲突 | 使用 generation gate，新手势立刻取消旧惯性 |
| 反向 | 旧方向 cooldown 或 velocity 可能残留 | 方向切换清 cooldown，速度符号变化立即重置滤波 |
| 边界 | clamp 后不可见 offset 可能累积 | rejected / boundary movement 仍消费 offset，方便立即反向 |
| 可观测性 | 缺少统一手势诊断 | Debug 下限频输出 `[R83A1Ruler]` |

## 4. R83A1 变量影响说明

| 变量 / 机制 | 修改前 | 修改后 | 影响阶段 |
| --- | --- | --- | --- |
| `DragGesture(minimumDistance:)` | 参数 / MF / Zoom 为 4pt，Ratio / Pixel 为 3pt | 全部改为 0pt | 起手、慢拖 |
| `minimumDragDeadZone` | 无统一 profile 字段 | profile 内按参数配置 4–6pt | 起手噪声过滤 |
| `filteredDragVelocity` | 无近期速度窗口 | 按 translation delta / elapsed 估算并轻滤波 | 快滑、惯性 |
| `inertiaProjectionDuration` | 无 | profile 默认 0.12s | 惯性预测 |
| `inertiaGeneration` | 无统一取消标记 | 新手势和消失时递增 generation | 惯性中接管 |
| `lastDragStepTranslation` | 已存在但与固定阈值绑定 | 与 velocity-aware threshold 结合，保留 fractional offset | 慢拖、反向 |
| `[R83A1Ruler]` | 无 | Debug 限频输出 | 可观测诊断 |

## 5. 速度曲线与惯性

- 低速：profile dead zone 过滤轻触噪声，未满一步不会写入 runtime。
- 正常拖动：视觉 offset 与手指 translation 直接关联，runtime 写入只在有效 step 后发生。
- 快速滑动：根据近期 release velocity 投影短距离，不直接使用完整 `predictedEndTranslation`。
- 惯性：只做短步进，step 数受 profile 的 `maximumFlingSteps` 限制。
- 接管：新手势第一帧递增 `inertiaGeneration`，旧异步惯性回调写入前必须验证 generation。

## 6. UI / Runtime 闭环

- UI 层继续使用现有 selected index / pending value / formatted value。
- Runtime 合法范围来源未改动，ISO / Shutter / EV / WB / TINT / MF 均沿用既有写入函数。
- MF 保留 `ManualFocusRulerTuning.writeMinInterval = 0.04`，避免对焦写入过密。
- 参数切换、Auto 恢复、R77C 以来的 Zoom runtime 切镜逻辑均未改动。
- Debug 日志中 `runtimeCommittedValue` 指向既有参数写入日志，避免重复引入 runtime 状态源。

## 7. 未修改范围

本轮未修改：

- AVCaptureSession 生命周期；
- 相机设备发现；
- 虚拟多摄和自动镜头选择；
- Zoom runtime 核心切镜逻辑；
- ISO / Shutter / EV / WB / TINT / MF 的设备合法范围；
- Auto EV / Auto WB / ProductAutoScene；
- 点击对焦、对焦状态机；
- RAW、拍照、保存、白底处理；
- 顶部、预览 HUD、快门区业务布局。

## 8. 构建、安装与真机验证

| 项目 | 结果 | 证据 |
| --- | --- | --- |
| `git diff --check` | 通过 | 无输出 |
| Build iOS Apps `build_sim` | 通过 | `build_sim_2026-06-17T09-36-02-461Z_pid68560_ecbfebaa.log` |
| generic iOS build | 通过 | `/tmp/sellercamera-r83a1/generic_build.log` |
| iPhone 14 Pro Max device build | 通过 | `/tmp/sellercamera-r83a1/device_build.log` |
| install | 通过 | `/tmp/sellercamera-r83a1/install.log` |
| launch | 通过 | `/tmp/sellercamera-r83a1/launch_retry.log` |
| PID | `12170` | `/tmp/sellercamera-r83a1/processes_after_launch.log` |
| 用户真机手感确认 | 满意 | 用户回复“以满意” |

首次 launch 因设备锁屏被 CoreDevice 拒绝，解锁后重试成功。

## 9. R83A1 真机固定动作结果

用户完成 R83A1 真机操作后反馈“以满意”。本报告只据此确认 R83A1 基础物理链路达到用户可接受状态，不声明 R83A2 视觉/参考应用对照已完成。

已确认范围：

- 起手反馈；
- 慢拖；
- 正常拖动；
- flick / 短惯性；
- 惯性中接管；
- 快速反向；
- 边界反向；
- 拍摄保存主链路未被本轮改动破坏。

## 10. 已知限制与下一步

- 用户提供的参考录屏位于 macOS `shared-pasteboard` 路径，当前 shell 读取返回 `Operation not permitted` / `No such file or directory`，R83A2 需要重新提供可访问文件或继续以真机反馈为依据。
- R83A1 未做 tick spacing、label stride、semantic anchor 强度和视觉密度二次校准。
- R83A2 建议在可访问参考视频后，按参数逐项处理 profile、视觉层级、锚点 hysteresis 与 haptic 细调。

# R78D iOS 27 双模式相机真机矩阵验收与兼容链路收口报告

日期：2026-06-16
基线 Commit：`2713e28 R78 iOS27 beta runtime compatibility diagnosis`
任务性质：iOS 27 双模式相机真机矩阵验收、最小兼容修复、纯净提交前收口

## 1. 工具链与设备

| 项目 | 结果 | 状态 |
| --- | --- | --- |
| Xcode | `Xcode 27.0` / `Build version 27A5194q` | PASS |
| Swift | `Apple Swift version 6.4` | PASS |
| iPhoneOS SDK | `27.0` | PASS |
| xcode-select | `/Applications/Xcode-27-beta.app/Contents/Developer` | PASS |
| 设备 | `iPhone14 pro Max` / `iPhone 14 Pro Max (iPhone15,3)` | PASS |
| 连接 | USB / CoreDevice `connected` | PASS |
| 设备 UDID | `E7D43088-7946-5FDB-BB14-E38124BB37DB` | PASS |

证据文件：

- `/tmp/r78d_toolchain_device.txt`
- `/tmp/r78d_evidence_summary.txt`

## 2. 构建、安装、启动

| 项目 | 结果 | 证据 | 状态 |
| --- | --- | --- | --- |
| Generic iOS build | `BUILD SUCCEEDED` | `/tmp/r78d_generic_build.log` | PASS |
| 真机 build | `BUILD SUCCEEDED` | `/tmp/r78d_device_build.log` | PASS |
| 修复后最终 build | `BUILD SUCCEEDED` | `/tmp/r78d_fix6_generic_build.log` | PASS |
| Install | App installed | `/tmp/r78d_fix6_install.log` | PASS |
| Launch | App launched | `/tmp/r78d_launch.log`、`/tmp/r78d_fix6_console_live.log` | PASS |
| Process | `SellerCamera` PID 存在，最终观测 PID `8638` | `xcrun devicectl device info processes` | PASS |

## 3. Auto 矩阵

所有 Auto 项均保持虚拟 `Back Triple Camera` 主线，不切入 Manual 物理 profile。画角、黑屏、崩溃、保存结果由用户在真机上确认；设备与 zoom 由 console 日志确认。

| 焦段 | 虚拟设备 | 画角 | Zoom | Capture | Save | 结果 |
| --- | --- | --- | --- | --- | --- | --- |
| 13mm Auto | `Back Triple Camera` | 用户确认完成 | `semanticFocal:13mm` | 用户确认成功 | 用户确认成功 | PASS |
| 24mm Auto | `Back Triple Camera` | 用户确认完成 | `semanticFocal:24mm` | 用户确认成功 | 用户确认成功 | PASS |
| 48mm Auto | `Back Triple Camera` | 用户确认完成 | `semanticFocal:48mm` | 用户确认成功 | 用户确认成功 | PASS |
| 77mm Auto | `Back Triple Camera` | 用户确认完成 | `semanticFocal:77mm` | 用户确认成功 | 用户确认成功 | PASS |

关键证据：

- `/tmp/r78d_fix3_console_live.log`：13 / 24 / 48 / 77mm 均出现 `device=Back Triple Camera` 与对应 `semanticFocal`。
- `/tmp/r78d_fix6_console_live.log`：Auto 恢复后仍可回到 `Back Triple Camera`，并保持 `virtualSwitchOver=[2.00,6.00]`。

## 4. Manual 矩阵

Manual 进入 WB / TINT / ISO / Shutter 任一手动参数前，按当前语义焦段切换物理镜头；48mm 使用 Wide 物理镜头承接 2x 语义 crop，不声明存在独立 48mm 物理镜头。

| 焦段 | 物理 Profile | ISO | Shutter | WB | Tint | Capture | Save | 结果 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 13mm Manual | `ultraWide` / `Back Ultra Wide Camera` | runtime readback | runtime readback | runtime readback | runtime readback | 用户确认成功 | 用户确认成功 | PASS |
| 24mm Manual | `wide` / `Back Camera` | runtime readback | runtime readback | runtime readback | runtime readback | 用户确认成功 | 用户确认成功 | PASS |
| 48mm Manual | `wide` / `Back Camera` + 48mm 语义 crop | runtime readback | runtime readback | runtime readback | runtime readback | 用户确认成功 | 用户确认成功 | PASS_WITH_DEGRADATION |
| 77mm Manual | `telephoto` / `Back Telephoto Camera` | runtime readback | runtime readback | runtime readback | runtime readback | 用户确认成功 | 用户确认成功 | PASS |

`48mm Manual` 的 `PASS_WITH_DEGRADATION` 是产品与硬件语义降级：iPhone 14 Pro Max 没有独立 48mm 物理 input，本轮按 R78C 约定使用 Wide profile 承接 48mm crop，不阻断预览、拍摄或保存。

关键证据：

- `/tmp/r78d_fix3_console_live.log`：13mm Manual 切到 `Back Ultra Wide Camera`。
- `/tmp/r78d_fix3_console_live.log`：24 / 48mm Manual 使用 `Back Camera`。
- `/tmp/r78d_fix3_console_live.log`：77mm Manual 切到 `Back Telephoto Camera`。

## 5. 模式切换

| 路径 | Input 切换 | 参数重应用 | 黑屏 | 最终状态 | 结果 |
| --- | --- | --- | --- | --- | --- |
| Auto 13 → Manual | `Back Triple Camera` → `Back Ultra Wide Camera` | WB/ISO/Shutter/Tint 可写 | 无 | `manualPhysical(ultraWide)` | PASS |
| Auto 24 → Manual | `Back Triple Camera` → `Back Camera` | WB/ISO/Shutter/Tint 可写 | 无 | `manualPhysical(wide)` | PASS |
| Auto 48 → Manual | `Back Triple Camera` → `Back Camera` | WB/ISO/Shutter/Tint 可写 | 无 | `manualPhysical(wide)` | PASS_WITH_DEGRADATION |
| Auto 77 → Manual | `Back Triple Camera` → `Back Telephoto Camera` | WB/ISO/Shutter/Tint 可写 | 无 | `manualPhysical(telephoto)` | PASS |
| 77 Manual → WB Auto | 初次恢复会回到 24mm，修复后 `Back Telephoto Camera` → `Back Triple Camera` | stale completion 被忽略 | 无 | `automaticVirtual` + 77mm | PASS |
| ISO/Shutter Auto 恢复 | 物理 Wide → `Back Triple Camera` | exposure scope token 生效 | 无 | `automaticVirtual` | PASS |
| Manual 跨焦段 13/24/48/77 | 按最终焦段稳定落到对应物理 profile | generation guard 生效 | 无 | 最终设备正确 | PASS |

本轮发现并修复的真实问题：

- `WB Auto` 从 77mm Manual 恢复时，旧白平衡 completion 与旧 `manualPhysical` mode 会阻止或污染 Auto 虚拟恢复。
- 修复后日志显示 `whiteBalanceAutoIntent` 将 input 切回 `Back Triple Camera`，并保持 `semanticFocal:77mm` / `target=3.00`。

## 6. 半自动真实性

| UI 模式 | ISO runtime | Shutter runtime | 场景变化行为 | 真实语义 |
| --- | --- | --- | --- | --- |
| ISO Manual / Shutter Auto | ISO 使用 runtime readback 与安全夹取 | Shutter 取当前 runtime duration 承接 | Product Auto Exposure 暂停，未出现黑屏/崩溃/保存失败 | PASS_WITH_DEGRADATION |
| Shutter Manual / ISO Auto | ISO runtime 随写入前 readback 更新 | Shutter 写入目标如 `1/96`、`1/100`、`1/120` | 快速拖动期间 pending，最终 fallback 到 runtime | PASS_WITH_DEGRADATION |
| 全 Auto 恢复 | 交回系统自动曝光 | 交回系统自动曝光 | input 回到虚拟 Triple | PASS |

说明：

- iOS / AVFoundation 底层仍通过 `setExposureModeCustom(duration:iso:)` 完成写入，不是独立原生 ISO-priority 或 Shutter-priority API。
- R78D 已查明并采用的真实语义是：手动项由用户控制，另一项使用当前 runtime readback 承接，UI 不再假称两个维度都处于完全独立自动优先模式。
- 日志中可见 `CaptureExposureTriangle action=shutterDrag isoMode=auto shutterMode=manual`、`CaptureExposureWrite`、`CaptureExposureReadback`，以及 `Product Auto 暂停 · 手动曝光`。

## 7. Tint 量化与 Shutter pending

| 项目 | 观察 | 结果 |
| --- | --- | --- |
| Tint 量化 | 用户确认左右拖动 1-2 格有量化变化，预览不断；日志出现 `panelOpen:tint` 和 `商品 WB 暂停 · 手动WB` | PASS |
| Shutter pending | 快速拖动时出现 `pendingTickIndex`、`deferredDuringDrag`；旧 completion 被 token guard 忽略 | PASS |
| Shutter pending timeout | 出现 `pending timeout for shutter 1/120, fallback to runtime 1/120`，无黑屏/崩溃/保存失败 | PASS_WITH_DEGRADATION |

`PASS_WITH_DEGRADATION` 表示 pending 超时会安全回退到 runtime 显示值，而不是强行维持未确认值；该行为不阻断 Preview / Focus / Capture / Save。

## 8. 前后台恢复

| 初始模式 | 返回后的设备 | 参数恢复 | Preview | Capture | 结果 |
| --- | --- | --- | --- | --- | --- |
| 24mm Auto | `Back Triple Camera` | Auto 主线保持 | 用户确认恢复 | 用户确认保存成功 | PASS |
| 77mm Auto | `Back Triple Camera` | 77mm Auto 保持 | 用户确认恢复 | 用户确认保存成功 | PASS |

用户确认：前后台切换约 5 秒后回到 App，无黑屏、无崩溃、无保存失败。进程列表仍显示 `SellerCamera` PID 存在。

## 9. 拍照保存矩阵

| 场景 | Capture | Save | 黑屏 | 崩溃 | 结果 |
| --- | --- | --- | --- | --- | --- |
| 13mm Auto | 成功 | 成功 | 无 | 无 | PASS |
| 24mm Auto | 成功 | 成功 | 无 | 无 | PASS |
| 48mm Auto | 成功 | 成功 | 无 | 无 | PASS |
| 77mm Auto | 成功 | 成功 | 无 | 无 | PASS |
| 13mm Manual | 成功 | 成功 | 无 | 无 | PASS |
| 24mm Manual | 成功 | 成功 | 无 | 无 | PASS |
| 48mm Manual | 成功 | 成功 | 无 | 无 | PASS |
| 77mm Manual | 成功 | 成功 | 无 | 无 | PASS |
| Auto 恢复后拍照 | 成功 | 成功 | 无 | 无 | PASS |
| ISO/Shutter 半自动后拍照 | 成功 | 成功 | 无 | 无 | PASS |
| Tint/Shutter pending 后拍照 | 成功 | 成功 | 无 | 无 | PASS |
| 前后台恢复后拍照 | 成功 | 成功 | 无 | 无 | PASS |

## 10. 最小修复文件

R78D 真机验收阶段只在确认真实 runtime 问题后做最小修复。

| 文件 | 根因 | 修改 | fallback / 旧系统影响 |
| --- | --- | --- | --- |
| `SellerCamera/CaptureLivePreviewView.swift` | WB Auto 与曝光写入共用旧 generation，导致 stale completion 可覆盖新状态 | 引入 exposure / whiteBalance 分 scope token 与失效逻辑 | 旧 completion 只打日志并忽略，不阻断当前设备 |
| `SellerCamera/CaptureLivePreviewView.swift` | WB Auto 从物理镜头恢复时，旧 `manualPhysical` mode 会阻止虚拟 Triple 恢复 | WB Auto intent 立即标记 Auto、重置 TINT、请求 `restoreAutomaticVirtualModeIfReady` | 若设备切换失败，保留 runtime hint，不崩溃 |
| `SellerCamera/CaptureLivePreviewView.swift` | 77mm Manual → Auto 恢复会默认选回 24mm virtual profile | 刷新 lens profiles 时保留上一次语义焦段，并优先匹配 virtual profile | 无独立 77mm virtual profile 时仍回落到默认 profile |
| `SellerCamera/CaptureLivePreviewView.swift` | Auto 恢复判断过度依赖旧 `shouldUsePhysicalLensProfiles` | resolve / switch 判断改为依据用户是否仍请求 Manual 参数 | 避免旧 mode 阻断全 Auto 主线 |

本轮未修改白底链路、拍后链路、AI 套图规划、Auto EV / Auto WB 算法主体，也未提升 Deployment Target。

## 11. 未通过与降级项

| 项目 | 状态 | 说明 |
| --- | --- | --- |
| 48mm Manual 独立物理镜头 | PASS_WITH_DEGRADATION | 使用 Wide 物理 profile + 48mm 语义 crop；这是硬件/产品语义限制，不阻断拍照 |
| ISO/Shutter 半自动 | PASS_WITH_DEGRADATION | 已查明为 runtime counterpart readback + custom exposure 写入，不声明独立原生 priority API |
| Shutter pending timeout | PASS_WITH_DEGRADATION | pending 超时安全回退到 runtime 值，不阻断主链路 |
| 快速跨镜头 hysteresis | PASS | 本轮覆盖 13/24/48/77 连续切换与最终设备正确性；未新增复杂 hysteresis 算法 |
| Crash log | PASS | 未出现 SellerCamera crash log，进程持续存在 |

## 12. Staging 范围

本轮代码 hunk 已跨 R78A / R78B / R78C / R78D 交织，无法安全用 `git add -p` 拆成互不影响的独立提交；按任务书允许的 fallback，采用一个合并提交，但仍显式列出文件，未使用 `git add .` 或 `git add -A`。

实际 staging 范围：

- `SellerCamera/CaptureBottomParameterBar.swift`
- `SellerCamera/CaptureLivePreviewView.swift`
- `SellerCamera/CaptureScreen.swift`
- `docs/reports/r78a_xcode27_beta_device_runtime_recovery.md`
- `docs/reports/r78b_ios27_manual_parameter_runtime_write_recovery.md`
- `docs/reports/r78c_ios27_dual_camera_mode_coordination.md`
- `docs/reports/r78d_ios27_dual_camera_mode_device_acceptance.md`
- `README.md`

明确排除：

- `SellerCamera.xcodeproj/project.pbxproj` 中嵌套空 project reference 清理。
- `SellerCamera/SellerCamera.xcodeproj/project.xcworkspace/contents.xcworkspacedata` 删除。

## 13. Commit 信息

实际 commit message：

```text
R78ABCD restore iOS27 camera runtime and manual controls
```

选择合并提交原因：

- `CaptureLivePreviewView.swift` 中 runtime capability、manual parameter readback、双模式 input 协调、generation/token 与 R78D 修复处于同一函数群，拆 hunk 容易得到不可构建或不可运行的中间提交。
- R78D 完成标准要求纯净 staging 与提交；本轮以显式路径 staging 方式保证没有把工程清理残留、DerivedData 或临时日志带入提交。

## 14. 未提交工作树内容

提交后预期仍保留以下未提交项，作为独立工程清理残留，不属于 R78D 真机矩阵提交：

- `SellerCamera.xcodeproj/project.pbxproj`
- `SellerCamera/SellerCamera.xcodeproj/project.xcworkspace/contents.xcworkspacedata`

最终提交前执行：

- `git diff --cached --check`
- `git diff --cached --stat`
- `git diff --cached`
- `git status --short`

## 15. 当前结论

R78D 真机矩阵在 iPhone 14 Pro Max / iOS 27 Beta / Xcode 27 Beta 下完成：

- Auto 虚拟多摄 13 / 24 / 48 / 77mm：PASS。
- Manual 物理镜头 13 / 24 / 48 / 77mm：PASS，其中 48mm 为 Wide crop 语义降级。
- 77mm Manual → Auto 恢复保持 77mm：修复后 PASS。
- ISO / Shutter 半自动真实性：已查明并按 runtime readback 语义通过，带降级说明。
- Tint 量化与 Shutter pending：PASS，pending timeout 安全回退。
- 前后台恢复、拍照保存、无黑屏、无崩溃：PASS。

本轮可以进入最终构建核查与纯净 staging / commit 阶段。

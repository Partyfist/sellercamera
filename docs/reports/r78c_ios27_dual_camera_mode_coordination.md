# R78C iOS 27 双模式相机设备协调报告

## 1. 根因与架构决策

R78B 证明 iPhone 14 Pro Max / iOS 27 Beta 下不能用单一 AVCaptureDevice 同时满足两条主线：

- `Back Triple Camera` 虚拟多摄可以保留连续 zoom 与 `virtualSwitchOver=[2.00,6.00]`，但不支持可信的 WB/TINT 虚拟输出 readback，ISO/Shutter 也不能作为完整四参数手动入口。
- 物理 `Back Camera` 已验证 24mm 下 WB/TINT/ISO/Shutter 可真实写入与回读，但长期固定物理 Wide 会削弱 13/77 真实镜头语义和虚拟多摄连续 zoom。

R78C 因此采用最小双模式协调：

- Auto 主线：默认使用虚拟 `Back Triple Camera`。
- Manual 主线：任一核心手动参数进入 manual 前，按当前语义焦段切换物理镜头。
- 四参数全部恢复 Auto 后，请求切回虚拟多摄。
- 写入 completion 使用 device generation + parameter generation + deviceID guard，旧 completion 不再覆盖新设备状态。

## 2. Auto 虚拟模式

已验证：

- 默认启动后 session input 为 `Back Triple Camera`。
- 日志显示 `deviceType=AVCaptureDeviceTypeBuiltInTripleCamera`。
- 日志显示 `virtualSwitchOver=[2.00,6.00]`。
- 默认 24mm 语义 zoom 仍作用在 `Back Triple Camera`。

证据：

- `/tmp/r78c_console_launch.log`：`[CaptureLensDevice] reason=configureSession activeDevice=Back Triple Camera ... virtualSwitchOver=[2.00,6.00]`。
- `/tmp/r78c_console_launch.log`：`[CaptureLensZoom] reason=semanticFocal:24mm device=Back Triple Camera ... target=1.00`。

未完成：

- Auto 模式 13mm / 48mm / 77mm 和连续 ruler 需要用户在真机 UI 上补验。
- Auto 模式拍照保存、本轮未重新人工确认。

## 3. Manual 物理模式

代码策略：

- 13mm → `PhysicalCameraProfile.ultraWide` → `.builtInUltraWideCamera`。
- 24mm / 48mm → `PhysicalCameraProfile.wide` → `.builtInWideAngleCamera`。
- 77mm → `PhysicalCameraProfile.telephoto` → `.builtInTelephotoCamera`。
- 48mm 不创建独立物理设备，保持 Wide input，并沿用现有 2x crop/zoom 语义。

能力策略：

- 进入 WB/TINT/ISO/Shutter manual 前先请求物理 input。
- 切换期间四参数 availability 统一标记为 temporarily unavailable。
- 目标物理镜头切换完成后重新探测 exposure / WB / focus / RAW 能力。
- 目标镜头不支持时保留 ruler 和低干扰提示，不做假写入。

未完成：

- Ultra Wide / Wide / Telephoto 三个物理 profile 的完整能力表仍需真机逐项日志确认。
- 13 / 24 / 48 / 77 各焦段四参数 readback 和拍照保存矩阵仍需用户补验。

## 4. 模式切换

已实现：

- `CaptureDeviceOperatingMode.automaticVirtual`。
- `CaptureDeviceOperatingMode.manualPhysical(profile:)`。
- `CaptureDeviceOperatingMode.switching(from:to:reason:)`。
- `CaptureDeviceOperatingMode.unavailable(reason:)`。
- `switchToCamera` 支持 reason、completion 与 generation。
- Auto 恢复虚拟时允许同为 back position 但从物理 input 切回虚拟 input。
- Manual 预切物理时跳过旧的内部 Auto 重应用，避免刚切到物理又切回虚拟。

已验证：

- CLI 真机构建通过。
- devicectl 安装通过。
- devicectl launch 通过。
- 进程列表确认 `SellerCamera` PID 存在。
- 短 console launch 确认默认 Auto 使用虚拟 `Back Triple Camera`。

未完成：

- Manual 触发 Auto → Manual 切换的 UI 真机日志仍需补验。
- Manual 全 Auto 后返回虚拟 Triple 的 UI 真机日志仍需补验。
- Manual 跨焦段快速拖动合并策略仍是最小保护，未完成完整 hysteresis 矩阵。

## 5. 参数语义

ISO / Shutter：

- 仍使用现有 `setExposureModeCustom(duration:iso:)` 写入。
- R78C 仅保证写入前目标设备切到物理镜头，并增加 stale completion guard。
- AVFoundation 底层通常会同时锁定 duration 和 ISO；本轮尚未证明真正单项 Auto 在 custom exposure 下成立。
- 因此 ISO priority / Shutter priority 真实半自动语义仍标记为未完成，需要后续专门真机观察未手动项是否随场景变化。

WB / TINT：

- 不再把虚拟多摄当作危险 WB/TINT 写入目标。
- 进入 manual 时先切到物理 profile。
- 写入前继续要求 `.locked` 与 `isLockingWhiteBalanceWithCustomDeviceGainsSupported`，防止虚拟设备触发 Objective-C exception。

Auto 恢复：

- WB Auto、ISO Auto、Shutter Auto completion 后都会检查四参数是否全部 Auto。
- 全部 Auto 时请求切回虚拟 Back Triple。

## 6. Pending 收口

已实现：

- `ManualParameterWriteToken(deviceGeneration:parameterGeneration:deviceID:)`。
- WB/TINT completion 检查 token，旧 completion 只打 `[ManualParamWrite] stale ... ignored`，不更新 UI。
- ISO completion 检查 token。
- Shutter completion 检查 token。
- 设备切换 generation 变化后，旧参数 completion 不再覆盖当前设备 UI。

未完成：

- Tint 量化到相同 runtime gains 时的触觉去重仍未补。
- Shutter timeout 与 quantized readback 的用户可见文案仍沿用 R78B 行为，未做专门 UI 收口。

## 7. 真机验收矩阵

| 项目 | 状态 | 备注 |
| --- | --- | --- |
| Generic iOS build | 通过 | `/tmp/r78c_build_2.log` 显示 `BUILD SUCCEEDED` |
| iPhone 14 Pro Max device build | 通过 | `/tmp/r78c_device_build.log` 显示 `BUILD SUCCEEDED` |
| Install | 通过 | `/tmp/r78c_install.log` 显示 app installed |
| Launch | 通过 | `/tmp/r78c_launch.log` 显示 launched |
| Process exists | 通过 | `/tmp/r78c_processes.log` 显示 PID `8291` |
| Auto default virtual Triple | 通过 | `/tmp/r78c_console_launch.log` 显示 `Back Triple Camera` |
| Auto 13/48/77 | 未验证 | 需要真机 UI 操作 |
| Auto continuous zoom | 未验证 | 需要真机 UI 操作 |
| 24mm Manual Wide | 未验证 | 代码已接入，需 UI 日志与 readback |
| 13mm Manual Ultra Wide | 未验证 | 代码已映射，需 UI 日志与 readback |
| 48mm Manual Wide crop | 未验证 | 代码已映射，需画角和 readback |
| 77mm Manual Telephoto | 未验证 | 代码已映射，需 UI 日志与 readback |
| Manual 跨焦段 | 未验证 | 需要慢速/快速拖动矩阵 |
| 全 Auto 返回虚拟 | 未验证 | 代码已接入，需 UI 日志确认 |
| 前后台恢复 | 未验证 | 本轮未做 interruption / reset 验证 |
| 拍照保存 | 未验证 | 本轮未重新人工确认 |

## 8. 残留风险

- iOS 27 Beta 的虚拟多摄与 active constituent 行为仍可能变化。
- Ultra Wide / Telephoto 的四参数能力不能从 Wide 推断，必须真机逐项确认。
- 物理 Manual 模式跨镜头无法完全等价虚拟连续 zoom，当前只是最小受控 input 切换基础。
- ISO/Shutter 半自动语义尚未完成底层真实性证明。
- 当前工作树包含 R78A/R78B/R78C 混合修改，本轮未执行 staging 或 commit。

## 9. 当前结论

R78C 代码基础已完成最小可构建、可安装、可启动版本，并确认 Auto 默认重新回到虚拟 `Back Triple Camera`。

但 R78C 完成标准要求 13/24/48/77、Manual 跨焦段、前后台和拍照保存完整真机矩阵；这些仍未完成，因此本轮不得宣布 R78C 完成，也不得提交。

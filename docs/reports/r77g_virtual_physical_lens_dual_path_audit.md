# R77G 虚拟 / 物理镜头双通道架构审计报告

日期：2026-06-18
范围：代码审查、真机启动日志核查、风险记录
结论类型：审计报告；本轮不修改相机业务逻辑

## 1. 最终结论

- 虚拟多摄主通道：存在。
- 物理镜头 fallback 通道：存在。
- 双通道完整性：完整；代码层仍保留 `virtual multi-camera + videoZoomFactor` 主通道，以及 `physical AVCaptureDevice + session input replacement` fallback / manual 通道。
- 真机启动路径：iPhone 14 Pro Max 上启动时 active device 为 `builtInTripleCamera`，日志确认走虚拟多摄主通道。
- 运行交互覆盖：本轮 CLI 可确认启动与默认 24mm 语义焦段写入；13 / 48 / 77 点击、焦段 ruler 拖动、macro fallback 没有可用的远程触摸注入命令，未做交互日志冒充。代码路径显示虚拟设备下这些操作应只写 `videoZoomFactor`，不应重建 session。
- 代码改动声明：本轮没有修改 SellerCamera 相机业务代码；仅新增本报告并更新 README 索引。

## 2. 审计方法

- 静态代码审查：围绕 `CaptureLivePreviewView.swift` 检查 device discovery、rear camera selection、session input replacement、lens profile generation、13 / 24 / 48 / 77mm mapping、virtual zoom、physical fallback、macro fallback。
- 真机设备核查：使用 `xcrun devicectl list devices` 确认当前真机。
- 真机启动日志：使用 `xcrun devicectl device process launch --device E7D43088-7946-5FDB-BB14-E38124BB37DB --terminate-existing --console com.partyfist.SellerCamera` 采集 `[CaptureLensDevice]`、`[CaptureLensTarget]`、`[CaptureLensZoom]`、`[CaptureLensZoomReadback]`。
- 构建说明：本轮不改 Swift / project 逻辑，未运行 `xcodebuild`；验收重点为代码证据与 runtime 日志。

## 3. 虚拟镜头主通道调用链

完整路径：

1. `startRunningSessionIfNeeded()` 请求权限后调用 `configureSessionIfNeeded()` 与 `startSession()`：`SellerCamera/CaptureLivePreviewView.swift:843`、`SellerCamera/CaptureLivePreviewView.swift:854`、`SellerCamera/CaptureLivePreviewView.swift:855`。
2. `configureSessionIfNeeded()` 调用 `resolveCamera(position: .back)`，创建 `AVCaptureDeviceInput`，`session.addInput(input)`，并记录 `currentVideoInput`：`SellerCamera/CaptureLivePreviewView.swift:3573`、`SellerCamera/CaptureLivePreviewView.swift:3576`、`SellerCamera/CaptureLivePreviewView.swift:3583`、`SellerCamera/CaptureLivePreviewView.swift:3588`。
3. `discoverCameras(position:)` 的 deviceTypes 顺序优先包含 `.builtInTripleCamera`、`.builtInDualWideCamera`、`.builtInDualCamera`，再列出物理 wide / ultra-wide / tele：`SellerCamera/CaptureLivePreviewView.swift:4778`。
4. `preferredVirtualBackCamera(in:)` 的优先级为 triple → dualWide → dual：`SellerCamera/CaptureLivePreviewView.swift:4982`。
5. `resolveCamera(position:preferredDeviceType:)` 在后摄、无 preferredDeviceType、非手动参数模式时优先返回 virtual back：`SellerCamera/CaptureLivePreviewView.swift:5114`。
6. `refreshLensProfiles(position:activeDevice:preferredLensID:)` 调用 `buildLensProfiles(position:)`，在 virtual active device 下优先选择上一次 semantic focal 或默认 `24mm` virtual profile：`SellerCamera/CaptureLivePreviewView.swift:4305`、`SellerCamera/CaptureLivePreviewView.swift:4324`、`SellerCamera/CaptureLivePreviewView.swift:4328`。
7. `buildLensProfiles(position:)` 在存在 virtual back 且未请求 physical profiles 时，为 `CaptureSemanticFocal.allCases` 生成 `virtual-13` / `virtual-24` / `virtual-48` / `virtual-77`：`SellerCamera/CaptureLivePreviewView.swift:4480`、`SellerCamera/CaptureLivePreviewView.swift:4483`、`SellerCamera/CaptureLivePreviewView.swift:4500`、`SellerCamera/CaptureLivePreviewView.swift:4513`。
8. `resolveVirtualLensZoomFactor(...)` 使用 constituent devices 和 `virtualDeviceSwitchOverVideoZoomFactors` 计算 13 / 24 / 48 / 77mm zoom target：`SellerCamera/CaptureLivePreviewView.swift:4654`、`SellerCamera/CaptureLivePreviewView.swift:4671`、`SellerCamera/CaptureLivePreviewView.swift:4688`。
9. 虚拟 profile 被点击时，`selectLensProfile(_:)` 在 `profile.source == .virtual && isActiveBackVirtualCamera` 时直接 `applyLensSelection`，不调用 `switchToCamera`：`SellerCamera/CaptureLivePreviewView.swift:2486`、`SellerCamera/CaptureLivePreviewView.swift:2498`。
10. `applyLensSelection(_:)` 对 virtual profile 计算 lower / upper / target，然后调用 `setZoomFactor(... reason: "semanticFocal:<焦段>")`：`SellerCamera/CaptureLivePreviewView.swift:4346`、`SellerCamera/CaptureLivePreviewView.swift:4351`、`SellerCamera/CaptureLivePreviewView.swift:4353`。
11. 焦段 ruler 入口 `setLensZoomDialValueFromRuler(_:)` 在 virtual profile 下把 dial value 作为 absolute zoom，交给 `submitLensRulerZoomTarget`：`SellerCamera/CaptureLivePreviewView.swift:2302`、`SellerCamera/CaptureLivePreviewView.swift:2308`、`SellerCamera/CaptureLivePreviewView.swift:2314`。
12. `setZoomFactor(...)` 最终对当前 `currentVideoInput.device` 执行 `ramp(toVideoZoomFactor:)` 或直接写 `device.videoZoomFactor`，并输出 `[CaptureLensZoom]`：`SellerCamera/CaptureLivePreviewView.swift:2585`、`SellerCamera/CaptureLivePreviewView.swift:2605`、`SellerCamera/CaptureLivePreviewView.swift:2608`、`SellerCamera/CaptureLivePreviewView.swift:2615`。

结论：主通道是 virtual multi-camera 的单 input 路径，焦段切换和 ruler 调节通过 `videoZoomFactor` / ramp 完成。

## 4. 物理镜头 fallback 调用链

完整路径：

1. `CaptureLensProfile.Source` 明确定义 `.virtual`、`.physical`、`.derived` 三类来源：`SellerCamera/CaptureLivePreviewView.swift:419`。
2. `PhysicalCameraProfile` 将 ultraWide / wide / telephoto 映射到 `.builtInUltraWideCamera`、`.builtInWideAngleCamera`、`.builtInTelephotoCamera`：`SellerCamera/CaptureLivePreviewView.swift:477`、`SellerCamera/CaptureLivePreviewView.swift:482`。
3. `CaptureDeviceOperatingMode.shouldUsePhysicalLensProfiles` 在 `.manualPhysical` 或 switching 到物理后摄时返回 true：`SellerCamera/CaptureLivePreviewView.swift:523`、`SellerCamera/CaptureLivePreviewView.swift:529`。
4. `shouldUsePhysicalLensProfiles` 还会在 ISO / Shutter / WB 任一参数离开 auto 时变为 true：`SellerCamera/CaptureLivePreviewView.swift:2364`、`SellerCamera/CaptureLivePreviewView.swift:2370`。
5. 当不能或不应使用 virtual profiles 时，`buildLensProfiles(position:)` 追加物理 `ultra-13`、`wide-24`、`wide-48-derived`、`tele-77`；如果没有任何 profile，则生成 `back-default`：`SellerCamera/CaptureLivePreviewView.swift:4522`、`SellerCamera/CaptureLivePreviewView.swift:4539`、`SellerCamera/CaptureLivePreviewView.swift:4555`、`SellerCamera/CaptureLivePreviewView.swift:4573`、`SellerCamera/CaptureLivePreviewView.swift:4590`。
6. `resolveCamera(position:preferredDeviceType:)` 在没有可用 virtual 或已进入 manual physical 倾向时 fallback 到物理 wide → ultra-wide → telephoto → virtual → first：`SellerCamera/CaptureLivePreviewView.swift:5120`。
7. `requestManualPhysicalModeIfNeeded(reason:completion:)` 根据当前 semantic focal 选择 physical profile，并调用 `switchToCamera(... preferredDeviceType: targetDeviceType, preferredLensID: preferredLensID)`：`SellerCamera/CaptureLivePreviewView.swift:2443`、`SellerCamera/CaptureLivePreviewView.swift:2450`、`SellerCamera/CaptureLivePreviewView.swift:2459`。
8. `selectLensProfile(_:)` 在非 virtual fast path 且目标 deviceType 不同时调用 `switchToCamera`：`SellerCamera/CaptureLivePreviewView.swift:2503`、`SellerCamera/CaptureLivePreviewView.swift:2507`。
9. `switchToCamera(...)` 创建新 `AVCaptureDeviceInput`，`session.removeInput(currentInput)`，`session.addInput(newInput)`，并更新 `currentVideoInput`：`SellerCamera/CaptureLivePreviewView.swift:3656`、`SellerCamera/CaptureLivePreviewView.swift:3690`、`SellerCamera/CaptureLivePreviewView.swift:3710`、`SellerCamera/CaptureLivePreviewView.swift:3714`。
10. input replacement 成功后重置 zoom、设置 operating mode、刷新 lens profiles、更新 EV / ISO / Shutter / WB / Focus capability，并重新应用 stabilizer 与参数 preset：`SellerCamera/CaptureLivePreviewView.swift:3733`、`SellerCamera/CaptureLivePreviewView.swift:3748`、`SellerCamera/CaptureLivePreviewView.swift:3764`、`SellerCamera/CaptureLivePreviewView.swift:3769`、`SellerCamera/CaptureLivePreviewView.swift:3775`、`SellerCamera/CaptureLivePreviewView.swift:3784`。
11. `restoreAutomaticVirtualModeIfReady(reason:)` 在手动参数全部回到 auto 且当前不是 virtual back 时切回 automatic virtual：`SellerCamera/CaptureLivePreviewView.swift:2469`、`SellerCamera/CaptureLivePreviewView.swift:2478`。

结论：物理 fallback 不只是结构残留；它仍被 manual physical、无 virtual 设备 fallback、物理 profile 选择、前后摄切换恢复路径引用。

## 5. 13 / 24 / 48 / 77mm 映射表

| 焦段 | virtual device 下 target | iPhone 14 Pro Max 启动日志 | physical fallback 下 device / target | clamp / 降级说明 |
| --- | --- | --- | --- | --- |
| 13mm | `resolveVirtualLensZoomFactor` 在有 ultra-wide 时返回 `lower`。 | `requested=1.000 clamped=1.000 device=Back Triple Camera` | `ultra-13` → `.builtInUltraWideCamera`，`baseZoomFactor=1.0`。 | `lower = max(1.0, minAvailableVideoZoomFactor)`，所以会被 `minAvailableVideoZoomFactor` clamp。 |
| 24mm | virtual wideAnchor；在本机 switch-over `[2.00, 6.00]` 下为 `2.0`。 | `requested=2.000 clamped=2.000 device=Back Triple Camera` | `wide-24` → `.builtInWideAngleCamera`，`baseZoomFactor=1.0`。 | virtual profile 默认启动选择 24mm。 |
| 48mm | virtual wideAnchor * 2；本机为 `4.0`，属于主摄语义裁切 / virtual zoom。 | `requested=4.000 clamped=4.000 device=Back Triple Camera` | `wide-48-derived` → `.builtInWideAngleCamera`，`source=.derived`，`baseZoomFactor=2.0`。 | physical fallback 没有独立 48mm 物理设备；依赖 wide 的 2x derived profile。 |
| 77mm | virtual teleAnchor；本机取第二个 switch-over，为 `6.0`。 | `requested=6.000 clamped=6.000 device=Back Triple Camera` | `tele-77` → `.builtInTelephotoCamera`，`baseZoomFactor=1.0`。 | 如果没有 telephoto，physical profile 不生成；`selectSemanticFocal` 会因无 profile 返回不可用提示。 |

映射一致性判断：

- virtual 与 physical 两套 profile 都覆盖 13 / 24 / 48 / 77 的语义焦段。
- absolute zoom 语义不同：virtual 的 `baseZoomFactor` 是 virtual device 上的 absolute zoom；physical 的 `baseZoomFactor` 是该物理镜头 input 内的 local baseline。
- 48mm 在 physical 通道中是 `.derived`，不是独立 `.physical`。

## 6. 真机 active device 与启动日志

设备核查：

```text
xcrun devicectl list devices

iPhone14 pro Max
Identifier: E7D43088-7946-5FDB-BB14-E38124BB37DB
State: connected
Model: iPhone 14 Pro Max (iPhone15,3)
Reality: physical
```

启动日志摘要：

```text
[CaptureLensDevice] reason=configureSession
activeDevice=Back Triple Camera
deviceType=AVCaptureDeviceTypeBuiltInTripleCamera
isVirtual=true
constituents=[
  Back Ultra Wide Camera|AVCaptureDeviceTypeBuiltInUltraWideCamera,
  Back Camera|AVCaptureDeviceTypeBuiltInWideAngleCamera,
  Back Telephoto Camera|AVCaptureDeviceTypeBuiltInTelephotoCamera
]
virtualSwitchOver=[2.00,6.00]
minZoom=1.00 maxZoom=189.00 videoZoom=1.00
```

虚拟 profile 生成日志摘要：

```text
[CaptureLensTarget] reason=buildVirtualProfile focal=13mm requested=1.000 clamped=1.000 device=Back Triple Camera type=AVCaptureDeviceTypeBuiltInTripleCamera isVirtual=true switchOver=[2.00,6.00]
[CaptureLensTarget] reason=buildVirtualProfile focal=24mm requested=2.000 clamped=2.000 device=Back Triple Camera type=AVCaptureDeviceTypeBuiltInTripleCamera isVirtual=true switchOver=[2.00,6.00]
[CaptureLensTarget] reason=buildVirtualProfile focal=48mm requested=4.000 clamped=4.000 device=Back Triple Camera type=AVCaptureDeviceTypeBuiltInTripleCamera isVirtual=true switchOver=[2.00,6.00]
[CaptureLensTarget] reason=buildVirtualProfile focal=77mm requested=6.000 clamped=6.000 device=Back Triple Camera type=AVCaptureDeviceTypeBuiltInTripleCamera isVirtual=true switchOver=[2.00,6.00]
```

默认 24mm 写入日志摘要：

```text
[CaptureLensZoom] reason=semanticFocal:24mm
device=Back Triple Camera
type=AVCaptureDeviceTypeBuiltInTripleCamera
requested=2.00 target=2.00 actual=2.00
ramped=false
selectedLens=24mm
switchOver=[2.00,6.00]

[CaptureLensZoomReadback] reason=semanticFocal:24mm
selectedLens=24mm
requested=2.000 clamped=2.000
device=Back Triple Camera
type=AVCaptureDeviceTypeBuiltInTripleCamera
videoZoom=2.000
activePrimary=Back Camera|AVCaptureDeviceTypeBuiltInWideAngleCamera
```

交互日志说明：

- 13 / 48 / 77mm 点击：本轮没有可用的 `devicectl` 触摸注入能力，未采集到真实点击日志；代码路径显示 active virtual device 下 `selectLensProfile` 会直接 `applyLensSelection`，不做 input replacement。
- 焦段 ruler 拖动：本轮没有可用的 `devicectl` 触摸注入能力，未采集到真实拖动日志；代码路径显示 ruler 只通过 `setZoomFactor` 写 `videoZoomFactor`。
- macro fallback：启动阶段未触发 `[CaptureLensMacroFallback]`；代码路径显示该 fallback 对当前 device 调用 `setZoomFactor(... reason: "closeFocusFallback")`，不调用 `switchToCamera`。

## 7. 哪些场景会触发物理通道

| 场景 | 是否触发物理通道 | 依据 |
| --- | --- | --- |
| 设备支持 `builtInTripleCamera` | 否，默认走 virtual。 | `preferredVirtualBackCamera` 优先 triple，`resolveCamera` 默认返回 virtual：`SellerCamera/CaptureLivePreviewView.swift:4982`、`SellerCamera/CaptureLivePreviewView.swift:5114`。 |
| 设备不支持 triple 但支持 dualWide / dual | 通常否，仍走可用 virtual。 | virtual 优先级 triple → dualWide → dual：`SellerCamera/CaptureLivePreviewView.swift:4982`。 |
| 设备不支持任何 virtual multi-camera | 是，fallback 到 physical wide / ultra-wide / tele。 | `resolveCamera` fallback 顺序：`SellerCamera/CaptureLivePreviewView.swift:5120`。 |
| 用户进入 ISO / Shutter / WB 手动参数模式 | 是，进入 physical profile 倾向，必要时切 physical input。 | `isManualParameterModeRequested` 与 `requestManualPhysicalModeIfNeeded`：`SellerCamera/CaptureLivePreviewView.swift:2364`、`SellerCamera/CaptureLivePreviewView.swift:2443`。 |
| 用户在 virtual 主通道点击 13 / 24 / 48 / 77mm | 否，预期只写 virtual `videoZoomFactor`。 | virtual fast path：`SellerCamera/CaptureLivePreviewView.swift:2498`。 |
| 用户在 physical profile 模式点击不同物理镜头焦段 | 是，deviceType 不同时 `switchToCamera`。 | `needsDeviceSwitch`：`SellerCamera/CaptureLivePreviewView.swift:2503`。 |
| 焦段 ruler 拖动 | 否，预期只写 zoom。 | `setLensZoomDialValueFromRuler` → `setZoomFactor`：`SellerCamera/CaptureLivePreviewView.swift:2302`、`SellerCamera/CaptureLivePreviewView.swift:2585`。 |
| 特定焦段不在 virtual zoom 范围 | 不自动触发 physical；该 virtual profile 会被省略。 | `resolveLensTarget` 返回 nil 后 `compactMap` 不生成 profile：`SellerCamera/CaptureLivePreviewView.swift:4483`、`SellerCamera/CaptureLivePreviewView.swift:4484`。 |
| macro fallback | 不触发 input replacement；只对当前 device 写 stable zoom。 | `triggerCloseFocusFallbackIfNeeded` → `setZoomFactor`：`SellerCamera/CaptureLivePreviewView.swift:6158`、`SellerCamera/CaptureLivePreviewView.swift:6186`。 |
| 前后摄切换 | 会走 `switchToCamera`；切回后摄时默认恢复 virtual，除非处于手动参数模式。 | `toggleCameraPosition` 与 `switchToCamera`：`SellerCamera/CaptureLivePreviewView.swift:2770`、`SellerCamera/CaptureLivePreviewView.swift:3748`。 |
| session input 创建失败 | 当前不会迭代尝试下一物理设备；初始化直接返回或切换置 unavailable。 | `configureSessionIfNeeded` guard 与 `switchToCamera` guard：`SellerCamera/CaptureLivePreviewView.swift:3573`、`SellerCamera/CaptureLivePreviewView.swift:3690`。 |
| runtime error / session rebuild | 未发现显式 runtime error observer 或重建 fallback 路径。 | 代码搜索仅发现启动 `startSession`，未发现 `AVCaptureSessionRuntimeError` 处理。 |
| 旧设备缺少 tele / ultra-wide | 不崩溃倾向；缺失 profile 不生成，最差生成 `back-default`。 | physical profile append 与 `profiles.isEmpty` fallback：`SellerCamera/CaptureLivePreviewView.swift:4522`、`SellerCamera/CaptureLivePreviewView.swift:4573`、`SellerCamera/CaptureLivePreviewView.swift:4590`。 |

## 8. 双通道完整性判断

完整性判断：完整，但有需要后续补强的边界。

已确认：

- 主通道确实是 virtual multi-camera：iPhone 14 Pro Max 启动日志确认 `Back Triple Camera`、`isVirtual=true`、constituents 覆盖 ultra-wide / wide / telephoto。
- 虚拟焦段 profile 真实生成：13 / 24 / 48 / 77 都生成 `buildVirtualProfile` 日志。
- 默认 24mm 真实写入 `videoZoomFactor=2.000`，且 active primary 为 physical wide constituent。
- 物理 fallback 代码链可达：manual parameter mode、no virtual device、physical profile selection 都能进入 physical input replacement 路径。

未完全自动化确认：

- 本轮没有通过 CLI 注入 13 / 48 / 77mm 点击，因此没有真实点击日志证明每个按钮均未触发 `switchCamera`。
- 本轮没有通过 CLI 注入焦段 ruler 拖动，因此没有真实拖动日志证明 ruler 过程中没有重建 session。
- 本轮没有人为制造 close focus timeout，因此没有真实 macro fallback runtime 日志。

审计态度：

- 不把“代码路径推导”写成“真机交互已确认”。
- 现有证据足以确认双通道没有退化为单通道；但若要满足逐项交互 runtime 证据，需要人工操作配合 log stream。

## 9. 死代码 / 断链 / 不一致风险

1. physical fallback 不是死代码，但当前 iPhone 14 Pro Max 自动启动不会触发它；它主要依赖手动参数模式、无 virtual 设备、physical profile 选择等入口。
2. session input 创建失败时没有“同一场景内继续尝试下一候选 physical device”的迭代 fallback；这是最明确的环境/旧设备兼容风险。
3. runtime error / media services reset 没有明确 observer 和 session rebuild fallback；若运行期 session 失效，可能只停留在当前状态。
4. 13 / 24 / 48 / 77 在 virtual 与 physical 通道中语义一致，但 zoom 坐标系不同：virtual 使用 single virtual device absolute zoom，physical 使用每个 physical input 的 local baseline。
5. 48mm 在 virtual 下是 virtual zoom，在 physical 下是 `.derived` wide 2x；UI 能表达 48mm，但不是独立物理镜头。
6. macro fallback 没有切 physical ultra-wide，而是让当前 virtual / physical device 在稳定 zoom 附近重试对焦；这不绕过主链路，但也不是物理 fallback。
7. input replacement 后会刷新 exposure / ISO / shutter / WB / focus capability 并应用 stabilizer / presets；但 tap focus 状态、具体 focus mode 的恢复主要依赖现有 focus 流程，没有独立的“切镜头后恢复上一次焦点”审计证据。
8. virtual device 存在但某 focal target 因范围不满足而 nil 时，profile 会缺席；代码不会自动切到 physical mirror focal。当前行为更接近“不可用则隐藏/提示”，不是“强制 physical 兜底”。

## 10. 后续建议

建议只做审计补强，不在本轮修改：

1. 增加一次人工真机日志矩阵：保持 console 运行，由用户依次点击 13 / 24 / 48 / 77、拖动 ruler、制造近距对焦 fallback，记录是否出现 `[CaptureLensDevice] reason=switchCamera`。
2. 后续如果要提升旧设备鲁棒性，可考虑在 `configureSessionIfNeeded` / `switchToCamera` 的 input 创建失败处加入候选设备迭代 fallback，但这属于功能修改，不在本轮范围内。
3. 后续如果要补强 runtime resiliency，可增加 `AVCaptureSessionRuntimeError` observer，并明确 rebuild 时 virtual-first / physical-fallback 的恢复策略。
4. 若继续打磨报告证据，可新增 debug-only lens audit action，主动打印当前 active device、profile table、selected semantic focal、zoom target，不改变生产行为。

## 11. 本轮未修改代码声明

- 未修改 `CaptureLivePreviewView.swift`。
- 未修改镜头选择逻辑。
- 未调整 zoom target。
- 未修改 ramp rate。
- 未修改 ruler 手感。
- 未修改 macro fallback。
- 未修改稳定器。
- 未重构 session。
- 未新增自动镜头选择。
- 未删除任何 fallback 代码。

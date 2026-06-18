# R77H 虚拟 / 物理镜头双通道运行时证据补齐报告

日期：2026-06-18
类型：真机运行时证据补齐；不修改相机业务逻辑
日志文件：`/tmp/SellerCameraR77H_runtime.log`
构建日志：`/tmp/SellerCameraR77H_build.log`

## 1. 最终结论

- 焦段按钮：13 / 24 / 48 / 77mm 在 iPhone 14 Pro Max 上均保持 `Back Triple Camera`，通过 `semanticFocal:*` 写 `videoZoomFactor` / ramp；未出现 `switchCamera`、`CaptureDeviceMode`、`AVCaptureDeviceInput` 替换证据。
- 焦段 ruler：本轮产生 1121 条 `reason=virtualLensRuler` zoom 写入，设备始终为 `Back Triple Camera`；未出现 session input replacement。
- virtual constituent switch：日志中 `activePrimary` 在 `Back Camera` 与 `Back Ultra Wide Camera` 间变化；这是 virtual device 内部 constituent 选择，不等于 `AVCaptureSession` input replacement。
- macro fallback：本轮 C / C2 均未触发 `[CaptureLensMacroFallback]`，因此没有 runtime 证据证明 fallback 实际进入；代码路径显示若触发，会在当前 virtual device 上执行 `setZoomFactor(... reason: "closeFocusFallback")`，不会切 physical ultra-wide input。
- physical fallback：正常焦段按钮、ruler、近距对焦场景均未触发；代码入口仍明确存在，主要由手动 ISO / Shutter / WB、无 virtual 设备、前后摄/恢复等条件触发。
- 双通道最终状态：条件双通道。virtual 主通道运行时成立；physical fallback 入口明确且代码可达，但本轮正常焦段与 macro 场景未触发 physical input replacement。
- 代码改动声明：本轮未修改 SellerCamera 相机业务代码。

## 2. 环境与仓库状态

测试环境：

```text
Xcode 27.0
Build version 27A5194q
iPhoneOS SDK 27.0
Device: iPhone14 pro Max
UDID: E7D43088-7946-5FDB-BB14-E38124BB37DB
Model: iPhone 14 Pro Max (iPhone15,3)
State: connected
Reality: physical
Bundle ID: com.partyfist.SellerCamera
```

仓库状态：

```text
Branch: main...origin/main [ahead 29]
HEAD: df2ef8e116e42f9e61c9aacec3bde933e916e02a
HEAD short: df2ef8e R83A2 polish parameter controls and rulers
```

执行前已有残留：

```text
M  README.md
M  SellerCamera.xcodeproj/project.pbxproj
D  SellerCamera/SellerCamera.xcodeproj/project.xcworkspace/contents.xcworkspacedata
?? docs/reports/r77g_virtual_physical_lens_dual_path_audit.md
```

说明：

- `README.md` 与 `docs/reports/r77g_virtual_physical_lens_dual_path_audit.md` 为上一轮 R77G 文档残留。
- `SellerCamera.xcodeproj/...` 两项为本轮前既存工程文件残留。
- R77H 本轮仅新增本报告并更新 README 索引，不触碰 Swift 业务代码。

## 3. 构建、安装、启动

构建命令：

```text
xcodebuild \
  -project SellerCamera.xcodeproj \
  -scheme SellerCamera \
  -configuration Debug \
  -destination 'platform=iOS,id=E7D43088-7946-5FDB-BB14-E38124BB37DB' \
  -derivedDataPath /tmp/SellerCameraR77H_DerivedData \
  build
```

结果：

```text
** BUILD SUCCEEDED **
App path: /tmp/SellerCameraR77H_DerivedData/Build/Products/Debug-iphoneos/SellerCamera.app
```

安装结果：

```text
xcrun devicectl device uninstall app --device E7D43088-7946-5FDB-BB14-E38124BB37DB com.partyfist.SellerCamera
App uninstalled.

xcrun devicectl device install app --device E7D43088-7946-5FDB-BB14-E38124BB37DB /tmp/SellerCameraR77H_DerivedData/Build/Products/Debug-iphoneos/SellerCamera.app
App installed:
bundleID: com.partyfist.SellerCamera
```

启动与日志采集：

```text
xcrun devicectl device process launch \
  --device E7D43088-7946-5FDB-BB14-E38124BB37DB \
  --terminate-existing \
  --console \
  com.partyfist.SellerCamera
```

日志文件：

```text
/tmp/SellerCameraR77H_runtime.log
```

## 4. 启动证据

启动关键日志：

```text
[CaptureLensDevice] reason=configureSession
uniqueID=com.apple.avfoundation.avcapturedevice.built-in_video:7
activeDevice=Back Triple Camera
deviceType=AVCaptureDeviceTypeBuiltInTripleCamera
isVirtual=true
constituents=[
  Back Ultra Wide Camera|AVCaptureDeviceTypeBuiltInUltraWideCamera|...:5,
  Back Camera|AVCaptureDeviceTypeBuiltInWideAngleCamera|...:0,
  Back Telephoto Camera|AVCaptureDeviceTypeBuiltInTelephotoCamera|...:2
]
virtualSwitchOver=[2.00,6.00]
minZoom=1.00 maxZoom=189.00 videoZoom=1.00
```

默认 24mm：

```text
[CaptureLensZoom] reason=semanticFocal:24mm
device=Back Triple Camera
type=AVCaptureDeviceTypeBuiltInTripleCamera
requested=2.00 target=2.00 actual=2.00
ramped=false selectedLens=24mm switchOver=[2.00,6.00]

[CaptureLensZoomReadback] reason=semanticFocal:24mm
videoZoom=2.000
activePrimary=Back Camera|AVCaptureDeviceTypeBuiltInWideAngleCamera|...
```

启动结论：

- active device 是 `builtInTripleCamera`。
- session input uniqueID 是 `com.apple.avfoundation.avcapturedevice.built-in_video:7`。
- 默认 selected focal 是 24mm。
- 默认 24mm 通过 virtual device 的 zoom target `2.00` 建立。

## 5. 场景 A：焦段按钮运行时路径

操作序列：

```text
24mm → 48mm
48mm → 77mm
77mm → 24mm
24mm → 13mm
13mm → 24mm
```

场景统计：

```text
[CaptureLensDevice]: 1
[CaptureDeviceMode]: 0
reason=switchCamera: 0
switch committed: 0
[CaptureLensZoom] reason=semanticFocal: 6
```

逐项证据表：

| 操作 | active device before | active device after | zoom before | zoom after / target | input replacement | 实际路径 |
| --- | --- | --- | --- | --- | --- | --- |
| 24→48 | Back Triple Camera | Back Triple Camera | 2.00 | target 4.00, readback 4.000 | 否 | virtual zoom |
| 48→77 | Back Triple Camera | Back Triple Camera | 4.00 | target 6.00, readback 6.000 | 否 | virtual zoom |
| 77→24 | Back Triple Camera | Back Triple Camera | 6.00 | target 2.00，readback 捕获到 ramp 中间值 3.362 | 否 | virtual zoom |
| 24→13 | Back Triple Camera | Back Triple Camera | 2.00 | target 1.00，readback 1.013 | 否 | virtual zoom，接近 min clamp |
| 13→24 | Back Triple Camera | Back Triple Camera | 1.00 | target 2.00，readback 2.000 | 否 | virtual zoom |

关键日志摘录：

```text
[CaptureLensZoom] reason=semanticFocal:48mm device=Back Triple Camera type=AVCaptureDeviceTypeBuiltInTripleCamera requested=4.00 target=4.00 selectedLens=48mm
[CaptureLensZoomReadback] reason=semanticFocal:48mm videoZoom=4.000 activePrimary=Back Camera|AVCaptureDeviceTypeBuiltInWideAngleCamera

[CaptureLensZoom] reason=semanticFocal:77mm device=Back Triple Camera type=AVCaptureDeviceTypeBuiltInTripleCamera requested=6.00 target=6.00 selectedLens=77mm
[CaptureLensZoomReadback] reason=semanticFocal:77mm videoZoom=6.000 activePrimary=Back Camera|AVCaptureDeviceTypeBuiltInWideAngleCamera

[CaptureLensZoom] reason=semanticFocal:13mm device=Back Triple Camera type=AVCaptureDeviceTypeBuiltInTripleCamera requested=1.00 target=1.00 selectedLens=13mm
[CaptureLensZoomReadback] reason=semanticFocal:13mm videoZoom=1.013 activePrimary=Back Ultra Wide Camera|AVCaptureDeviceTypeBuiltInUltraWideCamera
```

结论：

- 13 / 24 / 48 / 77mm 点击均只改变 virtual device 的 `videoZoomFactor`。
- 没有任何焦段点击触发 physical input replacement。
- `activePrimary` 的变化属于 virtual device 内部 constituent 选择，不是 session input replacement。

## 6. 场景 B：焦段 ruler 运行时路径

操作覆盖：

- 慢拖 24→48。
- 慢拖 48→77。
- 慢拖 77→24。
- 普通速度 13→77。
- 普通速度 77→13。
- 2x 附近来回拖动。

场景统计：

```text
[CaptureLensDevice]: 1
[CaptureDeviceMode]: 0
reason=switchCamera: 0
switch committed: 0
[CaptureLensZoom] reason=virtualLensRuler: 1121
[CaptureLensZoomReadback] reason=virtualLensRuler: 9
switchOverHysteresis=true: 0
unstableLensState:recentZoom: 30
unstableLensState:zoomRamping: 18
```

ruler zoom 范围：

```text
requested min/max: 1.00 / 38.81
target min/max: 1.00 / 38.81
readback activePrimary:
  6 x Back Camera|AVCaptureDeviceTypeBuiltInWideAngleCamera
  3 x Back Ultra Wide Camera|AVCaptureDeviceTypeBuiltInUltraWideCamera
```

输出表：

| 操作 | active device 是否变化 | input replacement | switch-over evidence | 黑屏/跳变 | 结论 |
| --- | --- | --- | --- | --- | --- |
| 慢拖 24→48 | 否，始终 Back Triple Camera | 否 | zoom 从 2.x 连续写入 4.x，activePrimary 可保持 wide | 未见 session rebuild 日志；人工未报告黑屏 | virtual ruler zoom |
| 慢拖 48→77 | 否，始终 Back Triple Camera | 否 | zoom 跨过 6x switch-over 区间，仍无 `switchCamera` | 未见 session rebuild 日志 | virtual ruler zoom |
| 慢拖 77→24 | 否，始终 Back Triple Camera | 否 | zoom 回落，ramp 中间值被 readback 捕获 | 未见 session rebuild 日志 | virtual ruler zoom |
| 快拖 13→77 | 否，始终 Back Triple Camera | 否 | requested 最大到 38.81，仍写同一 virtual device | 未见 session rebuild 日志 | virtual ruler zoom |
| 快拖 77→13 | 否，始终 Back Triple Camera | 否 | activePrimary 可切回 ultra-wide constituent | 未见 session rebuild 日志 | virtual ruler zoom |
| 2x 附近往返 | 否，始终 Back Triple Camera | 否 | `switchOver=[2.00,6.00]`；未出现 input replacement | 未见 session rebuild 日志 | virtual constituent switch only |

关键日志摘录：

```text
[CaptureLensZoom] reason=virtualLensRuler device=Back Triple Camera type=AVCaptureDeviceTypeBuiltInTripleCamera requested=2.24 target=2.24 actual=2.00 selectedLens=24mm switchOver=[2.00,6.00]
[CaptureLensZoom] reason=virtualLensRuler device=Back Triple Camera type=AVCaptureDeviceTypeBuiltInTripleCamera requested=5.30 target=5.30 actual=5.18 selectedLens=24mm switchOver=[2.00,6.00]
[CaptureLensZoom] reason=virtualLensRuler device=Back Triple Camera type=AVCaptureDeviceTypeBuiltInTripleCamera requested=10.57 target=10.57 actual=6.77 selectedLens=24mm switchOver=[2.00,6.00]
[CaptureLensZoom] reason=virtualLensRuler device=Back Triple Camera type=AVCaptureDeviceTypeBuiltInTripleCamera requested=1.00 target=1.00 actual=1.15 selectedLens=13mm switchOver=[2.00,6.00]

[CaptureLensZoomReadback] reason=virtualLensRuler device=Back Triple Camera type=AVCaptureDeviceTypeBuiltInTripleCamera videoZoom=1.150 activePrimary=Back Ultra Wide Camera|AVCaptureDeviceTypeBuiltInUltraWideCamera
```

结论：

- ruler 拖动期间 active device 保持 `Back Triple Camera`。
- ruler 拖动只写 `videoZoomFactor`。
- 跨 switch-over 区间未出现 session rebuild / input replacement。
- ProductAutoScene 在 zoom 近期与 ramping 窗口内会 skip，符合非阻塞保护预期。

## 7. 场景 C：macro fallback 运行时路径

操作覆盖：

- 24mm 近距点对焦。
- 48mm 近距点对焦。
- 77mm 近距点对焦。
- AE-L locked 后近距点对焦。
- MF 尝试：用户反馈 `当前镜头不支持手动对焦`，无法进入 MF 测试。
- C2：24mm、AE-L 关闭、不进入 MF，再次非常近距离连续点对焦。

场景统计：

```text
C:
[CaptureLensDevice]: 1
[CaptureDeviceMode]: 0
reason=switchCamera: 0
[CaptureLensMacroFallback]: 0
closeFocusFallback: 0
[CaptureTapFocus]: 30
timeout=true: 4
restoreContinuousAutoFocus=true: 11
商品 Auto 暂停 · AE-L: 96

C2:
[CaptureLensDevice]: 1
[CaptureDeviceMode]: 0
reason=switchCamera: 0
[CaptureLensMacroFallback]: 0
closeFocusFallback: 0
[CaptureTapFocus]: 10
timeout=true: 0
restoreContinuousAutoFocus=true: 5
```

输出表：

| 当前焦段 / 状态 | fallback 是否触发 | active device before/after | input replacement | 实际路径 | 清晰度变化 |
| --- | --- | --- | --- | --- | --- |
| 24mm | 否 | Back Triple Camera / Back Triple Camera | 否 | tap focus + restore continuous AF | ProductSharpness 多次恢复 sharp |
| 48mm | 否 | Back Triple Camera / Back Triple Camera | 否 | tap focus + restore continuous AF | ProductSharpness 多次恢复 sharp |
| 77mm | 否 | Back Triple Camera / Back Triple Camera | 否 | timeout 发生但代码 guard 阻止 77mm fallback | 未进入 fallback |
| MF | 未进入 | 未改变 | 否 | 用户反馈当前镜头不支持手动对焦 | 无 fallback |
| AE-L locked | 否 | Back Triple Camera / Back Triple Camera | 否 | AE-L 下 ProductAuto 暂停，timeout 不触发 fallback | 未进入 fallback |
| C2 24mm retry | 否 | Back Triple Camera / Back Triple Camera | 否 | 10 次 tap focus，无 timeout | ProductSharpness 多次 sharp |

关键日志摘录：

```text
[CaptureTapFocus] source=tap ... aeLocked=false isoMode=auto shutterMode=auto
[CaptureTapFocus] restoreContinuousAutoFocus=true lens=0.361 isAdjustingFocus=false

[CaptureTapFocus] source=tap ... selected 77mm period ...
[CaptureTapFocus] timeout=true normalized=(...) timeout=1.15

[ProductAutoExposure] ... status=商品 Auto 暂停 · AE-L
```

代码依据：

- timeout 时仅在 `source == .tap` 调用 `triggerCloseFocusFallbackIfNeeded`：`SellerCamera/CaptureLivePreviewView.swift:6099`。
- fallback guard 阻止 manual focus、AE/AF lock、preview restriction、switching、77mm：`SellerCamera/CaptureLivePreviewView.swift:6158`。
- 如果触发，fallback 打印 `[CaptureLensMacroFallback]`，随后调用 `setZoomFactor(stableZoom, ramped: true, reason: "closeFocusFallback")`：`SellerCamera/CaptureLivePreviewView.swift:6173`、`SellerCamera/CaptureLivePreviewView.swift:6186`。
- `closeFocusFallbackZoomTarget` 返回当前 device 的稳定 zoom，并注释 virtual multi-camera 可自行选择 constituent：`SellerCamera/CaptureLivePreviewView.swift:6201`。

结论：

- 本轮没有 runtime 触发 macro fallback，因此不能宣称“已实测 fallback 走 virtual close-focus”。
- 本轮可确认：近距对焦场景没有发生 physical ultra-wide input replacement。
- 代码路径可判断：若 macro fallback 被触发，其实现是当前 device 上的 `closeFocusFallback` zoom 写入，不是 `switchToCamera`，不会主动替换成 physical ultra-wide input。

## 8. 场景 D：物理 fallback 可达性

| 场景 | 本轮 runtime 结果 | 分类 | 依据 |
| --- | --- | --- | --- |
| virtual device discovery 失败 | 本机未触发 | 代码可达但本机未触发 | `resolveCamera` 无 virtual 时 fallback physical wide / ultra-wide / tele：`SellerCamera/CaptureLivePreviewView.swift:5120`。 |
| virtual device input 创建失败 | 本机未触发 | 入口不完整 / 风险 | 初始化 guard 失败直接 return；未见候选 physical 迭代。 |
| 设备不支持 triple / dual virtual | 本机未触发 | 代码可达但本机未触发 | `preferredVirtualBackCamera` 为空后进入 physical fallback：`SellerCamera/CaptureLivePreviewView.swift:4982`、`SellerCamera/CaptureLivePreviewView.swift:5120`。 |
| runtime session rebuild | 本机未触发 | 运行入口不明确 | 未发现显式 `AVCaptureSessionRuntimeError` rebuild fallback。 |
| camera permission/session recovery | 启动成功，未触发 fallback | 条件可达 | 权限成功后正常 configure session。 |
| front/back camera 切换 | 本轮未测 | 代码可达 | `toggleCameraPosition` 调用 `switchToCamera`：`SellerCamera/CaptureLivePreviewView.swift:2770`。 |
| macro fallback | 本轮未触发 | 不是 physical fallback | 代码是 `setZoomFactor(... closeFocusFallback)`，不是 `switchToCamera`。 |
| 特定焦段超出 virtual zoom 范围 | 本机未触发 | 条件可达 / profile 缺席 | `resolveLensTarget` nil 时不生成对应 virtual profile。 |
| physical tele / ultra-wide 缺失 | 本机未触发 | 代码可达但本机未触发 | physical profiles 按存在性 append，缺失则不生成；最终可 `back-default`。 |
| 旧设备兼容路径 | 本机未触发 | 代码可达但需旧设备验证 | discovery 顺序包含 physical device types。 |
| ISO 手动 | 本轮未手动触发 | 代码可达 | non-auto ISO 调用 `requestManualPhysicalModeIfNeeded(reason: "manualISO")`：`SellerCamera/CaptureLivePreviewView.swift:1451`。 |
| Shutter 手动 | 本轮未手动触发 | 代码可达 | non-auto Shutter 调用 `requestManualPhysicalModeIfNeeded(reason: "manualShutter")`：`SellerCamera/CaptureLivePreviewView.swift:1863`。 |
| WB 手动 | 本轮未手动触发 | 代码可达 | WB manual path 调用 `requestManualPhysicalModeIfNeeded`：`SellerCamera/CaptureLivePreviewView.swift:1299`。 |

physical fallback 入口代码：

```text
requestManualPhysicalModeIfNeeded(...)
→ physicalProfile(for: selectedSemanticFocal)
→ physicalLensID(for: profile)
→ switchToCamera(position: .back, preferredDeviceType: targetDeviceType, preferredLensID: preferredLensID)
→ remove current input / add new AVCaptureDeviceInput
```

关键代码：

- `isManualParameterModeRequested`：ISO / Shutter / WB 任一非 auto 即为手动参数模式：`SellerCamera/CaptureLivePreviewView.swift:2364`。
- `requestManualPhysicalModeIfNeeded`：根据当前焦段选择 physical profile 并调用 `switchToCamera`：`SellerCamera/CaptureLivePreviewView.swift:2443`。
- `switchToCamera` 创建新 input、remove / add input：`SellerCamera/CaptureLivePreviewView.swift:3656`、`SellerCamera/CaptureLivePreviewView.swift:3690`、`SellerCamera/CaptureLivePreviewView.swift:3710`。

结论：

- physical fallback 不是死代码；它有明确调用入口。
- 本轮正常焦段按钮、ruler、macro 场景没有触发 physical fallback。
- 若要补齐 physical runtime 直接证据，需要单独做“手动 ISO / Shutter / WB 触发 physical input replacement”专项验证；本轮未扩展到该动作，避免混入参数链路任务。

## 9. 必答问题

### 9.1 焦段按钮

13 / 24 / 48 / 77mm 点击时是否只走 virtual zoom？

- 是。A 场景 6 条 `semanticFocal` zoom 日志均为 `device=Back Triple Camera`、`type=AVCaptureDeviceTypeBuiltInTripleCamera`。

是否有任何焦段会替换 physical input？

- 否。本轮未出现 `reason=switchCamera`、`[CaptureDeviceMode]`、active device type 改变或 `CaptureLensDevice reason=switchCamera`。

### 9.2 ruler 拖动

是否保持同一 virtual device？

- 是。B 场景 1121 条 `virtualLensRuler` 写入均为 `Back Triple Camera`。

是否只写 `videoZoomFactor`？

- 是。日志均为 `[CaptureLensZoom] reason=virtualLensRuler`，无 input replacement 证据。

是否发生 session rebuild？

- 否。本轮未见 `switchCamera`、`CaptureDeviceMode`、session rebuild 相关日志。

### 9.3 macro fallback

实际走 virtual close-focus 还是 physical ultra-wide？

- 本轮未触发 `[CaptureLensMacroFallback]`，所以 runtime 未确认实际 fallback 路径。
- 代码路径显示如果触发，会走当前 device 的 `closeFocusFallback` zoom 写入，不会主动切 physical ultra-wide。

是否发生 input replacement？

- 否。本轮 C / C2 均未见 input replacement。

### 9.4 物理 fallback

是实际可达路径、条件可达路径，还是疑似死代码？

- 条件可达路径。代码入口明确存在；本轮正常焦段按钮、ruler、macro 未触发。

### 9.5 双通道最终状态

结论：条件双通道。

- virtual 主通道运行时成立。
- physical fallback 代码入口明确且可达。
- 本机正常焦段按钮、ruler、macro 场景未触发 physical fallback。
- 本轮没有证据显示架构退化为单通道。

## 10. 风险与后续建议

风险：

1. macro fallback 在本轮两次近距测试中未触发，说明该路径依赖 `isAdjustingFocus` timeout，普通近距点击不一定能稳定复现。
2. physical fallback 的“真实 input replacement”本轮没有通过手动 ISO / Shutter / WB 单独采集到 runtime 证据。
3. input 创建失败后没有候选 physical 迭代 fallback，是旧设备/异常设备的潜在鲁棒性风险。
4. runtime session error / media services reset 没有明确 rebuild fallback 证据。

后续建议：

1. 若要补齐 physical runtime 直接证据，单独做 R77H1：只测 ISO / Shutter / WB 从 auto → manual 是否触发 `switchCamera` 到 physical input，再 auto 恢复 virtual。
2. 若要补齐 macro fallback 直接证据，考虑 debug-only 临时降低 timeout 或增加只读触发日志，但这属于新任务，且必须不改变 Release 行为。
3. 旧设备兼容最好用无 triple / dual virtual 的设备单独验证，不应在 iPhone 14 Pro Max 上人为伪造 device failure。

## 11. 本轮未修改代码声明

- 未修改镜头优先级。
- 未修改 virtual device discovery 顺序。
- 未修改 physical fallback。
- 未修改焦段 zoom target。
- 未修改 ramp rate。
- 未修改 ruler sensitivity。
- 未修改 macro fallback 条件。
- 未修改 stabilizer。
- 未修改对焦或曝光。
- 未修复发现的问题。
- 未删除疑似死代码。
- 未 push 远端。

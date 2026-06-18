# R77I 虚拟多摄 MF 能力误判修复报告

日期：2026-06-18
类型：iOS 27 真机兼容修复；虚拟多摄 MF 能力判断与降级路径
设备：iPhone14 pro Max / iPhone 14 Pro Max (iPhone15,3)
UDID：`E7D43088-7946-5FDB-BB14-E38124BB37DB`

## 1. 最终结论

- 修复前 MF 入口将 `cameraRuntime.isManualFocusSupported` 作为唯一门槛；该状态只表示“是否支持 custom lens position”，导致 `Back Triple Camera` 这种支持 `.locked` 但不支持 `setFocusModeLocked(lensPosition:)` 的 active device 被提示为“当前镜头不支持手动对焦”。
- 修复后 MF 能力拆为三态：`full`、`lockCurrentOnly`、`unsupported`。
- iPhone 14 Pro Max 当前 virtual active device 真实能力为：`focusLocked=true`、`focusCustomLens=false`，因此不是 full MF；本轮按任务边界不强制切物理镜头，改为在 virtual device 上进入“锁定当前焦点”降级。
- `lockCurrentOnly` 下不会显示可拖动 MF ruler；full-capable 设备仍显示 MF ruler 并写入 custom lens position。
- 本轮未修改镜头发现顺序、virtual/physical 双通道、13/24/48/77mm zoom target、macro fallback、稳定器、Auto EV/WB/Sharpness、拍后链路。

## 2. 原问题来源

修复前用户提示来源：

```text
SellerCamera/CaptureScreen.swift:366 toggleManualFocusMode()
→ guard cameraRuntime.isManualFocusSupported
→ cameraRuntime.captureHintText = "当前镜头不支持手动对焦"

SellerCamera/CaptureScreen.swift:3931 stepManualFocusRuler(by:)
→ guard cameraRuntime.isManualFocusSupported
→ cameraRuntime.captureHintText = "当前镜头不支持手动对焦"
```

修复前状态来源：

```text
SellerCamera/CaptureLivePreviewView.swift:729
@Published var isManualFocusSupported = false

SellerCamera/CaptureLivePreviewView.swift:3999 updateFocusCapabilityState(with:)
isManualFocusSupported = device.isLockingFocusWithCustomLensPositionSupported
```

问题本质：

- 点击 MF 检查的是 runtime 缓存布尔值，不区分“完全 unsupported”和“只能锁当前焦点”。
- 该布尔值来自 active session device 的 `isLockingFocusWithCustomLensPositionSupported`，不是 selected lens profile；判断对象方向正确，但能力粒度太粗。

## 3. 当前实现路径

能力模型：

```text
SellerCamera/CaptureLivePreviewView.swift:477
ManualFocusCapability
→ full
→ lockCurrentOnly(reason:)
→ unsupported(reason:)
```

状态同步：

```text
SellerCamera/CaptureLivePreviewView.swift:783
isManualFocusEntrySupported

SellerCamera/CaptureLivePreviewView.swift:784
isManualFocusSupported

SellerCamera/CaptureLivePreviewView.swift:4268
updateFocusCapabilityState(with:reason:resetsFocusMode:)
→ 使用 current active AVCaptureDevice
→ entry = full 或 lockCurrentOnly
→ supported = full
```

入口路径：

```text
SellerCamera/CaptureScreen.swift:366 toggleManualFocusMode()
→ SellerCamera/CaptureLivePreviewView.swift:2111 manualFocusEntryCapability(reason:)
→ active currentVideoInput?.device
→ full: 展示 ruler + setManualFocusLensPosition
→ lockCurrentOnly: 隐藏 ruler + lockCurrentManualFocus
→ unsupported: 显示具体原因
```

写入路径：

```text
SellerCamera/CaptureLivePreviewView.swift:2229 setManualFocusLensPosition(_:)
→ 仅 full 能力允许 setFocusModeLocked(lensPosition:)

SellerCamera/CaptureLivePreviewView.swift:2155 lockCurrentManualFocus(reason:)
→ full 不强行使用
→ lockCurrentOnly 时 device.focusMode = .locked
→ focusControlMode = .manual
```

Zoom 后保持：

```text
SellerCamera/CaptureLivePreviewView.swift:2918 reapplyManualFocusAfterZoomIfNeeded(on:reason:)
→ full: 重新写 custom lens position
→ lockCurrentOnly: 保持 .locked
→ unsupported: 退出 MF 并提示
```

Debug 日志：

```text
SellerCamera/CaptureLivePreviewView.swift:5210 [CaptureMFSupport]
SellerCamera/CaptureLivePreviewView.swift:5227 [CaptureMFGuard]
SellerCamera/CaptureLivePreviewView.swift:5243 [CaptureMFWrite]
SellerCamera/CaptureLivePreviewView.swift:5264 [CaptureMFRestoreAF]
```

## 4. 真机能力证据

启动 active device：

```text
[CaptureLensDevice] reason=configureSession
activeDevice=Back Triple Camera
deviceType=AVCaptureDeviceTypeBuiltInTripleCamera
isVirtual=true
virtualSwitchOver=[2.00,6.00]
```

启动 MF 能力：

```text
[CaptureMFSupport] reason=capabilityUpdate
sessionRunning=false
capability=customLensPositionUnsupported
supported=false
device=Back Triple Camera
type=AVCaptureDeviceTypeBuiltInTripleCamera
isVirtual=true
focusLocked=true
focusAuto=true
focusContinuous=true
focusCustomLens=false
```

点击 MF 后：

```text
[CaptureMFSupport] reason=toggleMF
sessionRunning=true
capability=customLensPositionUnsupported
supported=false
device=Back Triple Camera
isVirtual=true
activePrimary=Back Ultra Wide Camera|AVCaptureDeviceTypeBuiltInUltraWideCamera|...
zoom=2.000
focusLocked=true
focusCustomLens=false
```

锁定当前焦点成功：

```text
[CaptureMFWrite] reason=lockCurrent:toggleMF
success=true
requested=0.840
applied=0.840
error=nil
device=Back Triple Camera
type=AVCaptureDeviceTypeBuiltInTripleCamera
isVirtual=true
focusMode=0
focusLocked=true
focusCustomLens=false
selectedLens=24mm
selectedLensID=virtual-24
```

退出 MF 恢复 AF：

```text
[CaptureMFRestoreAF] reason=user
success=true
mode=continuousAutoFocus
error=nil
device=Back Triple Camera
type=AVCaptureDeviceTypeBuiltInTripleCamera
isVirtual=true
focusMode=2
focusLocked=true
focusCustomLens=false
selectedLens=24mm
selectedLensID=virtual-24
```

结论：

- 本机 virtual active device 不支持 custom lens position，不能安全展示 full MF ruler。
- 本机 virtual active device 支持 `.locked`，因此可以进入 MF lock-current 降级。
- 运行时未出现 `switchCamera` 或 physical input replacement；修复没有用物理镜头绕过 virtual 能力。

## 5. 构建、安装、启动

工具链：

```text
xcode-select -p
/Applications/Xcode-27-beta.app/Contents/Developer

xcodebuild -version
Xcode 27.0
Build version 27A5194q

xcrun --sdk iphoneos --show-sdk-version
27.0

swift --version
Apple Swift version 6.4
```

构建命令：

```text
xcodebuild \
  -project SellerCamera.xcodeproj \
  -scheme SellerCamera \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  build
```

构建结果：

```text
** BUILD SUCCEEDED **
```

安装命令：

```text
xcrun devicectl device install app \
  --device E7D43088-7946-5FDB-BB14-E38124BB37DB \
  ~/Library/Developer/Xcode/DerivedData/SellerCamera-clujgyuzmlxdoudgpfvmcmdnnwma/Build/Products/Debug-iphoneos/SellerCamera.app
```

安装结果：

```text
App installed:
bundleID: com.partyfist.SellerCamera
```

启动命令：

```text
xcrun devicectl device process launch \
  --device E7D43088-7946-5FDB-BB14-E38124BB37DB \
  --terminate-existing \
  --console \
  com.partyfist.SellerCamera
```

启动结果：

```text
Launched application with com.partyfist.SellerCamera bundle identifier.
```

说明：为停止 console 采集，最后使用 `Ctrl-C` 结束 devicectl console，会显示 `App terminated due to signal 2`；这不是 App 崩溃证据。

## 6. 验收结果

已确认：

- Build：通过。
- Install：通过。
- Launch：通过。
- Active device：`Back Triple Camera` virtual device。
- MF 入口：点击后不再走“完全不支持”死路；进入 lock-current MF 降级。
- MF 写入：`device.focusMode = .locked` 成功。
- AF 恢复：再次点击 MF 后恢复 `continuousAutoFocus` 成功。
- 设备通道：MF 修复未触发 physical camera input replacement。

未在本轮确认：

- 13 / 48 / 77mm 下分别点击 MF 的完整真机矩阵。
- full MF ruler 在真实支持 `custom lens position` 的 active device 上的表现。
- lock-current MF 后拍照保存回归；本轮未执行拍照动作。

## 7. 风险与边界

- iPhone 14 Pro Max 的 `Back Triple Camera` 在当前 iOS 27 / Xcode 27 Beta 组合下返回 `focusCustomLens=false`，因此如果坚持 virtual 主通道，不应展示可拖动 lens position ruler。
- 本轮没有使用 `activePrimaryConstituent` 或 physical fallback profile 来推测 full MF 能力；只以 active `currentVideoInput?.device` 为判定依据。
- `lockCurrentOnly` 是明确降级，不等同于完整手动对焦。它解决“误报完全不支持”和“MF 模式不能进入”的问题，但不会提供连续手动拉焦。
- 如后续产品要求 iPhone 14 Pro Max 必须完整 MF ruler，需要单独任务评估是否允许 physical device 手动模式；本轮按 R77I 边界不做。

## 8. 代码改动声明

修改文件：

- `SellerCamera/CaptureLivePreviewView.swift`
  - 新增 `ManualFocusCapability` 三态模型。
  - 新增 active device MF preflight。
  - 新增 lock-current 降级写入。
  - 新增 zoom 后 MF 状态保持。
  - 新增 `[CaptureMFSupport]`、`[CaptureMFWrite]`、`[CaptureMFRestoreAF]`、`[CaptureMFGuard]` 日志。
- `SellerCamera/CaptureScreen.swift`
  - MF 入口改为读取 runtime capability。
  - full 时显示 ruler。
  - lock-current-only 时隐藏 ruler 并进入锁当前焦点。
  - MF 按钮灰态改为基于 entry support，而非 full ruler support。
- `README.md`
  - 增加 R77I 报告索引。
- `docs/reports/r77i_virtual_camera_manual_focus_capability_fix.md`
  - 新增本报告。

未修改：

- 镜头发现顺序。
- virtual / physical 双通道架构。
- 13 / 24 / 48 / 77mm 映射。
- macro fallback。
- 稳定器。
- Auto EV / Auto WB / ProductAutoScene / Sharpness。
- 拍照、保存、RAW、拍后链路。

## 9. 残留问题

- `Back Triple Camera` full MF ruler 不可用是 active device 能力返回限制，不是本轮继续强改的代码问题。
- `README.md`、R77G/R77H 报告和工程文件存在本轮前残留改动；本轮未清理、未提交。
- 仍建议后续用 13 / 48 / 77mm 分别补一次 MF lock-current 真机矩阵，确认提示、退出 AF、拍照保存均无回归。

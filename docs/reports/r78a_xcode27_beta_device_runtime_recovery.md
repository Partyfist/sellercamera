# R78A Xcode 27 Beta 真机运行恢复验收报告

日期：2026-06-15
基线 Commit：`2713e28 R78 iOS27 beta runtime compatibility diagnosis`
任务性质：工具链切换、真机构建安装启动恢复、P0/P1 最小验收

## 1. 工具链

### 1.1 Xcode 发现与确认

- 已发现 `/Applications/Xcode.app`：`Xcode 26.5`，Build `17F42`。
- 已发现 `/Applications/Xcode-27-beta.app`：`Xcode 27.0`，Build `27A5194q`。
- `mdls -name kMDItemVersion /Applications/Xcode-27-beta.app`：`27.0`。
- `defaults read /Applications/Xcode-27-beta.app/Contents/Info CFBundleShortVersionString`：`27.0`。
- 结论：`/Applications/Xcode-27-beta.app` 是真实 Xcode 27 Beta，不是 Xcode 26.x 重命名版本。

### 1.2 当前命令行工具链

- `xcode-select -p`：`/Applications/Xcode-27-beta.app/Contents/Developer`
- `xcodebuild -version`：`Xcode 27.0` / `Build version 27A5194q`
- `swift --version`：`Apple Swift version 6.4 (swiftlang-6.4.0.20.104 clang-2100.3.20.102)`
- `xcrun --sdk iphoneos --show-sdk-version`：`27.0`
- `xcrun --sdk iphoneos --show-sdk-path`：`/Applications/Xcode-27-beta.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS27.0.sdk`
- `xcrun devicectl --version`：`629.3`
- 环境覆盖检查：未发现 `DEVELOPER_DIR`、`SDKROOT`、`TOOLCHAINS` 将命令行错误指向旧工具链。

### 1.3 系统与设备

- macOS：`26.5.1`，Build `25F80`
- 测试设备：`iPhone 14 Pro Max`
- Product Type：`iPhone15,3`
- CoreDevice Identifier：`E7D43088-7946-5FDB-BB14-E38124BB37DB`
- UDID：`00008120-001655913E7BC01E`
- iOS：`27.0`
- iOS Build：`24A5355q`
- 连接状态：`wired`
- Pairing State：`paired`
- Boot State：`booted`
- Developer Mode：`Enabled (1)`

### 1.4 首次启动与组件状态

- `xcodebuild -license check`：当前用户上下文返回成功。
- `xcodebuild -runFirstLaunch`：当前用户上下文返回成功。
- `sudo -n` 方式因无免密 sudo 不可用；本轮未伪造 sudo 成功。
- `xcode-select --switch` 由用户手动执行完成，后续命令已验证切换结果。
- 未使用、未下载、未复制任何非官方 `DeviceSupport`、`DeveloperDiskImage`、`CoreDevice` 或 `MobileDevice` 组件。

## 2. R78 结论复核

### 2.1 R78 原问题

R78 记录的核心现象为：

- Xcode 26.5 / iPhoneOS 26.5 SDK 下 Build 与 Install 成功。
- CoreDevice 创建 App 进程阶段 timeout。
- 设备进程列表中没有 `SellerCamera`。
- 没有 `SellerCamera` crash log。
- App 尚未进入业务代码和 `AVCaptureSession` runtime。

### 2.2 R78A 复核结论

- 切换到 Xcode 27 Beta 与 iPhoneOS 27.0 SDK 后，`SellerCamera` 可以成功完成 Build、Install、Launch。
- 首次 Xcode 27 Beta launch 返回成功，创建 PID `2964`。
- 最小兼容补丁后重新安装启动，创建 PID `3025`。
- Xcode 26.5 下的 CoreDevice launch timeout 在 Xcode 27 Beta 下消失。
- 当前可确认：R78 的主阻塞属于 Xcode 26.5 / iOS 27 Beta 真机工具链代次不匹配导致的启动阶段环境问题。
- 新发现独立问题：iOS 27 Beta + 当前 `Back Triple Camera` 虚拟设备配置下，除 EV 外，WB / TINT / ISO / Shutter 在运行时报告不可手动写入，已按非阻塞降级处理。

## 3. 构建、安装、启动

### 3.1 缓存与工程结构

- 已清理旧构建缓存：`~/Library/Developer/Xcode/DerivedData/SellerCamera-*`
- 工程结构检查结果：使用根目录 `SellerCamera.xcodeproj`。
- 本轮未引入 workspace 构建猜测。

### 3.2 Git 状态

- 当前分支：`main...origin/main [ahead 17]`
- 当前基线：`2713e28 R78 iOS27 beta runtime compatibility diagnosis`
- 本轮验证基于当前工作树；工作树中存在 R78A 代码补丁，以及先前已存在的工程加载修复和 `CaptureLivePreviewView.swift` 本地改动。

### 3.3 Build

Generic iOS clean build：

```sh
DEVELOPER_DIR="/Applications/Xcode-27-beta.app/Contents/Developer" \
xcodebuild \
  -project SellerCamera.xcodeproj \
  -scheme SellerCamera \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  clean build
```

结果：

- `** BUILD SUCCEEDED **`
- Signing Identity：`Apple Development: Baochuan Liu (7KPC92849B)`
- Provisioning Profile：`iOS Team Provisioning Profile: *`
- Profile UUID：`69fcd6a1-6559-499a-8eae-50d4c3526882`
- 产物路径：`/Users/sungning/Library/Developer/Xcode/DerivedData/SellerCamera-clujgyuzmlxdoudgpfvmcmdnnwma/Build/Products/Debug-iphoneos/SellerCamera.app`

真机 destination build：

```sh
DEVELOPER_DIR="/Applications/Xcode-27-beta.app/Contents/Developer" \
xcodebuild \
  -project SellerCamera.xcodeproj \
  -scheme SellerCamera \
  -configuration Debug \
  -destination 'platform=iOS,id=00008120-001655913E7BC01E' \
  build
```

结果：

- `** BUILD SUCCEEDED **`
- SDK：`iPhoneOS27.0.sdk`
- Thinning 设备：`iPhone15,3`
- Minimum Deployment Target 保持 `16.6`，未提升到 iOS 27。

### 3.4 Install

旧版本卸载：

```sh
xcrun devicectl --timeout 60 device uninstall app \
  --device 00008120-001655913E7BC01E \
  com.partyfist.SellerCamera
```

结果：

- `App uninstalled.`

安装新构建：

```sh
xcrun devicectl --timeout 120 device install app \
  --device 00008120-001655913E7BC01E \
  /Users/sungning/Library/Developer/Xcode/DerivedData/SellerCamera-clujgyuzmlxdoudgpfvmcmdnnwma/Build/Products/Debug-iphoneos/SellerCamera.app
```

结果：

- `App installed`
- bundleID：`com.partyfist.SellerCamera`
- 初次安装 URL：`file:///private/var/containers/Bundle/Application/4115537A-1A39-4052-88FF-CF79C64D6105/SellerCamera.app/`
- 补丁后安装 URL：`file:///private/var/containers/Bundle/Application/A7BC4261-0EF6-42D1-B631-00B5C2CB9874/SellerCamera.app/`

### 3.5 Launch 与进程

启动命令：

```sh
xcrun devicectl --timeout 60 device process launch \
  --device 00008120-001655913E7BC01E \
  --terminate-existing \
  com.partyfist.SellerCamera
```

结果：

- Launch 返回成功。
- 初次 PID：`2964`
- 补丁后 PID：`3025`
- 进程创建后 10 秒仍可在进程列表中看到 `SellerCamera`。
- 未复现 CoreDevice process create timeout。
- 未观察到 `SellerCamera` crash log。
- Console 可进入 App runtime 日志，说明已越过 R78 的启动阻塞点。

## 4. P0 验收

### 4.1 冷启动与预览

- App 可由 `devicectl` 启动并前台激活。
- 截图证据显示拍摄 UI 与实时预览可见。
- 用户真机确认：保存成功，未崩溃，未黑屏。
- 未观察到永久黑屏。
- 未观察到 uncaught exception。
- 未观察到 watchdog termination。

### 4.2 进程与日志

- `SellerCamera` PID 创建成功：`2964` / `3025`。
- Console 日志进入业务 runtime。
- 日志显示相机设备激活：`activeDevice=Back Triple Camera deviceType=AVCaptureDeviceTypeBuiltInTripleCamera`。
- ProductAutoScene / Auto EV / Auto WB / sharpness 相关日志可见。
- 自动分析模块异常时进入 degraded mode，不阻断 Preview / Capture / Save。

### 4.3 普通拍照与保存

- 用户真机确认普通拍照后保存成功。
- 保存后未崩溃。
- 保存后未黑屏。
- 本轮 P0 主链路结论：Build → Install → Launch → Preview → Capture → Save 已恢复。

## 5. P1 验收

### 5.1 镜头与 Zoom

- 用户补充确认 P1 操作已完成。
- 镜头切换未反馈崩溃、黑屏或主链路中断。
- Zoom ruler 未反馈越界或崩溃。
- 本轮未对镜头系统做架构性修改。

### 5.2 参数

- EV：手动调整可用，Console 出现 EV wheel dispatch 与 applied 日志。
- WB：当前运行时报告不可写入手动白平衡；点击后可打开刻度面板，但拖动写入被禁用并显示不可调提示。
- TINT：依赖手动 WB Gains；当前 WB Gains 不可用时同步不可调，点击后可打开刻度面板并保持降级。
- ISO：当前运行时报告仅支持 ISO Auto；点击后可打开刻度面板，但拖动写入被禁用并显示不可调提示。
- Shutter：当前运行时报告仅支持 Shutter Auto；点击后可打开刻度面板，但拖动写入被禁用并显示不可调提示。
- MF / AF 恢复：未反馈崩溃或阻断主链路。

### 5.3 自动能力

- Auto EV：日志可见，未阻断预览、对焦、拍照、保存。
- Auto WB：日志可见，但当前设备路径出现 `商品 WB 不可用 · 设备Gains`，按 degraded mode 处理。
- Sharpness analysis：日志可见，未阻断主链路。
- ProductAutoScene：日志可见，未阻断主链路。
- Near-black guard / warmup / stabilizer：日志与 UI 行为未显示阻断性异常。

### 5.4 最佳质量与 RAW

- 普通高质量拍照保存由用户真机确认通过。
- RAW capability 本轮未做代码层扩展或强制启用。
- 未因 RAW 配置失败阻断普通拍照。
- RAW 支持/不支持时的完整拍摄结果仍建议在后续单独以固定样本复核。

## 6. 代码改动

### 6.1 本轮最小兼容修复

文件：`SellerCamera/CaptureScreen.swift`

- 根因：App 成功启动后，除 EV 外的参数在当前 iOS 27 Beta 真机运行时能力中返回不可手动写入，但 UI 仍允许进入看似可拖动的手动控制。
- 修改：在底部参数入口保留 `notAdjustable` 记录与 pending 清理，但不再阻断刻度面板展示；不可调时显示具体提示。
- Fallback：参数不可手动写入时不阻断 Preview / Focus / Capture / Save。
- 旧系统影响：仅在运行时 `state.isAdjustable == false` 时生效，不改变可调设备上的写入路径。

文件：`SellerCamera/CaptureBottomParameterBar.swift`

- 根因：不可调参数的 ruler 仍能响应拖动，造成“像是能调但没有生效”的错觉。
- 修改：对 `DragGesture.onChanged` 增加 `item.isRulerInteractive && item.parameter.isAvailable` guard。
- Fallback：不可调状态仍可查看刻度面板，但不产生虚假的拖动写入状态。
- 旧系统影响：可交互参数不受影响。

### 6.2 非本轮代码说明

- `SellerCamera/CaptureLivePreviewView.swift` 在 R78A 修复前已处于本地修改状态，本轮未修改该文件。
- 工程加载相关工作树改动来自 R78A 前的 Xcode project load 修复，本报告只记录其对当前验证环境的影响，不将其归为本轮参数 runtime 修复。

## 7. 残留问题

### 7.1 iOS 27 Beta / Xcode 27 Beta 环境问题

- R78 的 CoreDevice launch timeout 已随 Xcode 27 Beta 工具链切换消失。
- 未发现新的 CoreDevice 启动阻塞。

### 7.2 SellerCamera 代码问题

- 当前 `Back Triple Camera` 虚拟设备路径下，WB / TINT / ISO / Shutter 手动能力不可用，仅完成非阻塞降级。
- 若后续目标是恢复四个参数的真实手动写入，需要单独评估物理 constituent device、镜头切换策略与参数能力探测，不应在 R78A 中强行改写相机架构。

### 7.3 尚未完全验证

- RAW 支持时的完整 RAW 拍摄与保存结果仍需固定场景复核。
- 权限弹窗在本轮已授权设备上未必重新触发；本轮确认的是已授权状态下的启动、预览、拍照、保存。

### 7.4 不阻断 warning

- 当前残留 warning 未阻断 Build / Install / Launch / Preview / Capture / Save。
- 本轮未为消除 warning 做无关整理。

## 8. R78A 完成判定

- GUI 与命令行工具链已切换到 Xcode 27 Beta：通过。
- iOS SDK 为 27.x：通过。
- Xcode 可识别 iOS 27 Beta 真机：通过。
- SellerCamera Build：通过。
- SellerCamera Install：通过。
- SellerCamera 进程创建：通过。
- SellerCamera 正常启动：通过。
- 相机预览可见：通过。
- 普通拍照成功：通过。
- 图片保存成功：通过。
- 镜头和基础参数不导致崩溃：通过，但 WB / TINT / ISO / Shutter 当前为运行时不可调降级。
- 自动分析模块异常时不阻断主链路：通过。
- R78A 报告：已完成。

结论：R78A 主目标完成。Xcode 26.5 与 iOS 27 Beta 真机的 CoreDevice launch timeout 已确认由 Xcode 27 Beta 工具链恢复；剩余的 WB / TINT / ISO / Shutter 手动不可调属于 App 成功启动后的独立运行时能力问题，已做最小非阻塞降级，建议进入下一轮小任务包继续恢复真实手动参数能力。

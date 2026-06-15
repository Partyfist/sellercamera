# R78 iOS 27 Beta 真机运行恢复与兼容性诊断收口报告

## 1. 故障根因

本轮已完成工具链、设备、签名、构建、安装与启动链路分层诊断。当前根因收敛为：

- 故障层：工具链 / CoreDevice 启动调试链路与 iOS 27 Beta 设备组合异常。
- 证据：Xcode 26.5 / iPhoneOS 26.5 SDK 可以构建并安装到 iOS 27.0 Beta 设备，但 `devicectl device process launch` 在创建应用进程阶段持续 timeout，且设备进程列表中未出现 `SellerCamera`。
- 排除项：不是编译失败、不是签名失败、不是安装失败、不是 Developer Mode 关闭、不是 DDI 不可用、不是 App 代码启动后崩溃、不是 AVCaptureSession 已启动后黑屏。当前没有 SellerCamera 进程和 crash log，因此还没有进入 App 内相机 runtime。

结构化启动错误：

```text
commandType = devicectl.device.process.launch
outcome = timeout
details = Exceeded command timeout
version = 518.31
```

已重测以下启动方式，均在 CoreDevice launch 阶段 timeout：

- 默认前台启动：`launch com.partyfist.SellerCamera`
- 清理已有进程后启动：`launch --terminate-existing`
- 非激活启动：`launch --no-activate --terminate-existing`
- 挂起等待调试启动：`launch --start-stopped --terminate-existing`

结论：当前不能用业务代码层修改来恢复运行。需要先使用支持 iOS 27 Beta 的匹配 Xcode / CoreDevice 工具链继续验证。如果 Xcode Beta 可用，应切换 `xcode-select` 后重跑 Build / Install / Launch / Preview / Capture 矩阵。

## 2. 改动摘要

本轮没有修改 SellerCamera 业务代码。

完成内容：

- 核查当前 Xcode、Swift、SDK、xcode-select、macOS。
- 核查 iOS 27 Beta 真机连接、Developer Mode、DDI services、配对和锁屏状态。
- 清理旧 DerivedData 后执行 generic iOS build。
- 执行 iOS 27 Beta 真机签名构建。
- 执行真机安装。
- 多方式执行真机启动并记录 timeout 证据。
- 复核最终 App bundle Info.plist、签名、entitlements。
- 代码级复核 AVFoundation 关键链路，确认 R77E/R77F 的 ProductAutoScene guard 只跳过分析帧，不会阻断 session / preview / photo capture。
- 新增 R78 诊断报告并更新 README 索引。

未做内容：

- 未重构相机 runtime。
- 未修改 ProductAutoScene / Auto EV / Auto WB / Sharpness 阈值。
- 未删除或降级现有参数、镜头、稳定器、RAW 入口。
- 未提升 Deployment Target 到 iOS 27。
- 未接受 Xcode 自动工程升级。

## 3. 文件清单

- `docs/reports/r78_ios27_beta_device_runtime_compatibility_closure.md`
  - 新增 R78 iOS 27 Beta 兼容性诊断报告。
- `README.md`
  - 增加 R78 报告索引。

本轮未修改业务 Swift 文件、Info.plist、entitlements 或工程签名配置。

## 4. 工具链信息

命令行工具链：

```text
Xcode 26.5
Build version 17F42
xcode-select: /Applications/Xcode.app/Contents/Developer
Swift: Apple Swift version 6.3.2
iOS SDK: 26.5
iOS SDK path: /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.5.sdk
macOS: 26.5.1 (25F80)
```

本机 `/Applications` 下只发现：

```text
Xcode.app
```

未发现可切换的 Xcode Beta。

设备信息：

```text
Device: iPhone 14 Pro Max (iPhone15,3)
Identifier: E7D43088-7946-5FDB-BB14-E38124BB37DB
UDID: 00008120-001655913E7BC01E
iOS: 27.0 Beta
osBuildUpdate: 24A5355q
Developer Mode: enabled
Pairing: paired
Tunnel: connected
Lock state: unlockedSinceBoot=true
DDI contentIsCompatible: true
DDI isUsable: true
```

项目配置：

```text
Scheme: SellerCamera
Project: /Users/sungning/Projects/SellerCamera/SellerCamera.xcodeproj
Bundle ID: com.partyfist.SellerCamera
Development Team: XXFWYJU8YF
Signing: Automatic
Deployment Target: iOS 16.6
SDKROOT: iPhoneOS26.5.sdk
```

注意：根工程存在对嵌套空工程 `SellerCamera/SellerCamera.xcodeproj` 的引用，导致每次 `xcodebuild` 输出 warning：

```text
Project .../SellerCamera/SellerCamera/SellerCamera.xcodeproj cannot be opened because it is missing its project.pbxproj file.
```

该 warning 不阻断构建或安装，本轮不作为 iOS 27 Beta 运行故障根因处理，避免无关工程清理扩散。

## 5. 构建、安装与启动验证

### 5.1 Generic iOS build

执行：

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/SellerCamera-*
xcodebuild -project SellerCamera.xcodeproj \
  -scheme SellerCamera \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  clean build
```

结果：

```text
BUILD SUCCEEDED
```

### 5.2 真机签名构建

执行：

```bash
xcodebuild -project SellerCamera.xcodeproj \
  -scheme SellerCamera \
  -configuration Debug \
  -destination 'id=00008120-001655913E7BC01E' \
  -derivedDataPath /tmp/SellerCameraR78DeviceBuild \
  build
```

结果：

```text
BUILD SUCCEEDED
```

签名证据：

```text
Signing Identity: Apple Development: Baochuan Liu (7KPC92849B)
Provisioning Profile: iOS Team Provisioning Profile: *
application-identifier: XXFWYJU8YF.com.partyfist.SellerCamera
get-task-allow: true
```

### 5.3 真机安装

执行：

```bash
xcrun devicectl device install app \
  --device E7D43088-7946-5FDB-BB14-E38124BB37DB \
  /tmp/SellerCameraR78DeviceBuild/Build/Products/Debug-iphoneos/SellerCamera.app
```

结果：

```text
App installed:
bundleID: com.partyfist.SellerCamera
installationURL: file:///private/var/containers/Bundle/Application/.../SellerCamera.app/
```

设备 app 列表确认：

```text
SellerCamera     com.partyfist.SellerCamera   1.0   1
```

### 5.4 真机启动

执行过的启动命令：

```bash
xcrun devicectl device process launch --console --timeout 20 \
  --device E7D43088-7946-5FDB-BB14-E38124BB37DB \
  com.partyfist.SellerCamera
```

```bash
xcrun devicectl device process --timeout 20 \
  --json-output /tmp/r78-launch2.json \
  --log-output /tmp/r78-launch2.log \
  launch --terminate-existing \
  --device E7D43088-7946-5FDB-BB14-E38124BB37DB \
  com.partyfist.SellerCamera
```

```bash
xcrun devicectl device process --timeout 20 \
  --json-output /tmp/r78-launch-noactivate.json \
  --log-output /tmp/r78-launch-noactivate.log \
  launch --no-activate --terminate-existing \
  --device E7D43088-7946-5FDB-BB14-E38124BB37DB \
  com.partyfist.SellerCamera
```

```bash
xcrun devicectl device process --timeout 20 \
  --json-output /tmp/r78-launch-stopped.json \
  --log-output /tmp/r78-launch-stopped.log \
  launch --start-stopped --terminate-existing \
  --device E7D43088-7946-5FDB-BB14-E38124BB37DB \
  com.partyfist.SellerCamera
```

结果均为：

```text
ERROR: Command timeout of 20.0 seconds exceeded. Assuming command got stuck and aborting.
outcome: timeout
details: Exceeded command timeout
```

进程列表复核：

```text
xcrun devicectl device info processes --device E7D43088-7946-5FDB-BB14-E38124BB37DB
```

未发现：

```text
SellerCamera
com.partyfist.SellerCamera
```

因此没有进入 App 内日志阶段，也没有获得 SellerCamera crash backtrace。

## 6. AVCapture 与 iOS 27 兼容性代码复核

已复核 `CaptureLivePreviewView.swift` 关键路径：

- `startRunningSessionIfNeeded()` 先请求相机权限，再配置 session。
- `session.startRunning()` 在 `sessionQueue` 中执行，不在主线程同步执行。
- `configureSessionIfNeeded()` 使用 `beginConfiguration()` / `commitConfiguration()` 配对。
- 后置设备通过 `resolveCamera(position:)` 与虚拟多摄优先策略获取，设备发现包含 triple / dual wide / dual / wide / ultra wide / tele fallback。
- `photoOutput`、video analysis output 添加前均使用 `canAddOutput`。
- ProductAutoScene video output 设置 `alwaysDiscardsLateVideoFrames = true`，delegate 在 `videoAnalysisQueue`。
- ProductAutoScene frame guard 只跳过分析，不停止 preview session，不阻断 photo capture。
- BGRA 与 420YpCbCr 双路径解析均存在 unsupported pixel format guard。
- near-black probe 只跳过前两帧假黑分析，不会阻止 session running。

本轮没有证据显示 R77E/R77F 的 frame guard 造成启动失败。当前启动根本没有 SellerCamera 进程，因此无法到达 AVCaptureSession 配置阶段。

## 7. 验收结果

| 项目 | 结果 | 证据 |
| --- | --- | --- |
| 工具链信息 | 已确认 | Xcode 26.5 / SDK 26.5 / Swift 6.3.2 |
| iOS 27 Beta 设备识别 | 已确认 | devicectl details 显示 iOS 27.0 Beta |
| Developer Mode | 已确认 | enabled |
| 设备配对 | 已确认 | paired / tunnel connected |
| DDI services | 已确认 | contentIsCompatible=true / isUsable=true |
| Generic build | 通过 | `BUILD SUCCEEDED` |
| 真机 signed build | 通过 | `BUILD SUCCEEDED` |
| 签名 / profile | 通过 | Apple Development + Team Provisioning Profile |
| Install | 通过 | `App installed` |
| Launch | 未通过 | CoreDevice launch timeout，未创建 SellerCamera 进程 |
| App crash | 未发现 | 无 SellerCamera 进程，无 crash log |
| Preview | 未验证 | launch 未通过，未进入 App UI |
| Photo capture | 未验证 | launch 未通过 |
| Album save | 未验证 | launch 未通过 |
| Lens switch / zoom | 未验证 | launch 未通过 |
| ISO / Shutter / EV / WB / MF | 未验证 | launch 未通过 |
| Auto EV / Auto WB | 未验证 | launch 未通过 |
| RAW fallback | 未验证 | launch 未通过 |
| 后台恢复 | 未验证 | launch 未通过 |

## 8. 残留风险

- 当前设备是 iOS 27.0 Beta，但本机只有 Xcode 26.5 / iPhoneOS 26.5 SDK。尽管 DDI services 显示可用，CoreDevice launch 仍然超时；这属于 Beta 工具链组合风险。
- 因无法创建 SellerCamera 进程，本轮不能声称预览、拍照、镜头、参数和 Auto EV/WB 已在 iOS 27 Beta 恢复。
- 若 Xcode GUI 运行与 CLI `devicectl` 表现不同，需要在 Xcode Devices / Console 中补充第一条 GUI 错误；但当前 CLI 证据已经足够说明不是业务代码构建或签名层失败。
- 根工程引用了一个嵌套空 `SellerCamera/SellerCamera.xcodeproj`，当前只是 build warning。建议后续单独做工程卫生小包清理，不要混入 iOS 27 Beta 兼容任务。

## 9. 后续建议

最小下一步：

1. 安装支持 iOS 27 Beta 的匹配 Xcode Beta。
2. 切换：

```bash
sudo xcode-select -s /Applications/Xcode-beta.app/Contents/Developer
```

3. 重新执行：

```bash
xcodebuild -version
xcrun --sdk iphoneos --show-sdk-version
xcrun devicectl device info ddiServices --device E7D43088-7946-5FDB-BB14-E38124BB37DB
xcodebuild -project SellerCamera.xcodeproj -scheme SellerCamera -configuration Debug -destination 'id=00008120-001655913E7BC01E' -derivedDataPath /tmp/SellerCameraR78DeviceBuild build
xcrun devicectl device install app --device E7D43088-7946-5FDB-BB14-E38124BB37DB /tmp/SellerCameraR78DeviceBuild/Build/Products/Debug-iphoneos/SellerCamera.app
xcrun devicectl device process launch --console --timeout 30 --device E7D43088-7946-5FDB-BB14-E38124BB37DB com.partyfist.SellerCamera
```

4. 若 launch 成功，再继续 P0/P1 真机矩阵：
   - 冷启动授权。
   - preview 可见。
   - 普通拍照。
   - 镜头切换 / zoom ruler。
   - 参数入口。
   - Auto EV / Auto WB 降级验证。

在匹配工具链可启动前，不建议修改 SellerCamera 拍摄业务代码。

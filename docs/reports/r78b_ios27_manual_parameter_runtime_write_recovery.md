# R78B iOS 27 四参数真实手动写入恢复报告

## 1. 根因

R78A 后四个参数面板已可打开，但 WB / TINT / ISO / Shutter 不能拖动，真实根因不是 SwiftUI ruler 末端手势问题，而是运行时 capability 被 iOS 27 真机设备模型收窄后映射成了不可写状态。

- **ISO / Shutter**：当前优先选择的 `Back Triple Camera` 虚拟多摄设备在 iPhone 14 Pro Max / iOS 27 Beta 上返回 `isExposureModeSupported(.custom) == false`，因此 ISO 与 Shutter 被正确禁写；但物理 `Back Camera` 返回 `.custom == true` 且 ISO / exposure duration 范围有效，具备真实手动曝光写入能力。
- **WB / TINT**：旧链路把手动白平衡能力过度绑定到 `isLockingWhiteBalanceWithCustomDeviceGainsSupported`。iOS 27 工具链下虚拟多摄可暴露 `.locked` 白平衡能力，但 custom gains 不一定暴露；因此仅按 custom gains 判断会把可用的 Kelvin / Tint locked 写入误判为不可调。物理 `Back Camera` 同时支持 `.locked` 与 custom gains。
- **共同问题**：旧状态模型只有 Bool，无法区分 session 准备中、镜头切换中、API 不支持、lock 失败与真实可写，导致 UI 只能“显示 ruler 但禁写”，缺少可恢复的动态 capability。

## 2. 设备模型

本轮实际工具链与设备：

- Xcode：`27.0`，build `27A5194q`
- Swift：`6.4`
- iPhoneOS SDK：`27.0`
- macOS：`26.5.1 (25F80)`
- 测试设备：`iPhone 14 Pro Max (iPhone15,3)`，名称 `iPhone14 pro Max`
- Device ID：`E7D43088-7946-5FDB-BB14-E38124BB37DB`
- UDID：`00008120-001655913E7BC01E`

关键诊断日志：

- 虚拟多摄：`Back Triple Camera`，`AVCaptureDeviceTypeBuiltInTripleCamera`，constituents 为 Ultra Wide / Wide / Telephoto。
- 虚拟多摄能力：`expCustom=false`、`wbLocked=true`、`wbCustomGains=false`、`isoAvailability=ISO: customExposureUnsupported`、`shutterAvailability=Shutter: customExposureUnsupported`、`wbAvailability=available`。
- 实际 session input：`Back Camera`，`AVCaptureDeviceTypeBuiltInWideAngleCamera`，`activeFormat=4032x3024`，`formats=60`。
- 物理 Wide 能力：`expCustom=true`、`minISO=57.00`、`maxISO=12768.00`、`minDuration=0.00001500`、`maxDuration=1.00000000`、`wbLocked=true`、`wbCustomGains=true`。

结论：iOS 27 Beta 下不能把 Back Triple 虚拟设备视为 ISO / Shutter 手动写入入口；本轮改为优先选择具备四参数真实写入能力的物理 back camera，并保留虚拟设备作为无可用物理写入设备时的 fallback。

## 3. 修改文件

- `SellerCamera/CaptureLivePreviewView.swift`
  - 新增 `ManualParameterAvailability` 状态模型。
  - 用真实 AVCaptureDevice API 与 activeFormat 范围生成 WB / ISO / Shutter 可写状态。
  - ISO / Shutter 写入改为 `setExposureModeCustom(... completionHandler:)` 后回读设备值。
  - WB / TINT 在 iOS 26+ 优先使用 Kelvin / Tint locked API，旧系统保留 custom gains fallback。
  - 镜头选择优先使用支持四参数手动写入的物理 back device，并记录虚拟设备降级原因。
  - 增加 `[ManualParamCompat]` debug 诊断日志。
- `SellerCamera/CaptureScreen.swift`
  - 参数面板打开时触发当前设备 capability 诊断，便于真机现场确认 UI 状态与设备状态一致。
- `README.md`
  - 新增 R78B 报告索引。
- `docs/reports/r78b_ios27_manual_parameter_runtime_write_recovery.md`
  - 新增本报告。

## 4. 状态模型

新增最小状态模型：

- `pending(reason:)`：session、activeFormat 或镜头状态尚未稳定；显示 ruler，不允许写入。
- `available`：真实设备 API 支持且范围有效；显示 ruler，允许拖动和写入。
- `temporarilyUnavailable(reason:)`：镜头切换、zoom ramp 或设备忙；显示 ruler，暂时禁写，后续可恢复。
- `unsupported(reason:)`：当前设备/API 明确不支持；显示 ruler，不允许写入，并展示原因。
- `failed(reason:)`：lock 或写入失败；保留原因，避免 UI 假生效。

UI 仍保持 R78A 的非阻塞降级：参数面板可打开，但只有 `available` 允许手势写入；其它状态显示原因，不制造 `isAdjustable = true` 的假修复。

## 5. 写入闭环

- **WB**：拖动 Kelvin 时保留当前 Tint，生成 `WhiteBalanceTemperatureAndTintValues`，iOS 26+ 通过 `setWhiteBalanceModeLocked(whiteBalanceTemperatureAndTintValues:)` 写入，completion 后从 `deviceWhiteBalanceGains` 回读 Kelvin / Tint 更新 UI。
- **TINT**：拖动 Tint 时保留当前 Kelvin，走同一组 Kelvin / Tint locked 写入，避免只改 UI 或重置 WB。
- **ISO**：保留 R68 半自动语义，按当前 shutter mode 计算 duration，clamp ISO 后写入 session input device，completion 后回读 `device.iso` 与 `device.exposureDuration`。
- **Shutter**：保留 ISO auto/manual 语义，clamp exposure duration 后写入 custom exposure，completion 后回读实际 duration。
- **Auto 恢复**：WB/TINT auto 回到 `.continuousAutoWhiteBalance`；ISO/Shutter auto 回到曝光三角既有语义，两个都 Auto 时恢复 continuous auto exposure，手动曝光时 EV 维持 locked 语义。

## 6. 真机验收

已完成的自动与日志验收：

- `xcodebuild -project SellerCamera.xcodeproj -scheme SellerCamera -configuration Debug -destination 'generic/platform=iOS' build`：通过。
- `xcodebuild -project SellerCamera.xcodeproj -scheme SellerCamera -configuration Debug -destination 'platform=iOS,id=00008120-001655913E7BC01E' build`：通过。
- 使用 Xcode 27 Beta `devicectl` 安装：通过，bundle id `com.partyfist.SellerCamera`。
- 使用 Xcode 27 Beta `devicectl` 启动：通过，console 开始输出。
- 进程确认：`SellerCamera` PID `3068` 存在。
- 24mm / physical Wide 下打开四参数面板：`lockProbe=success`，WB / ISO / Shutter availability 均为 `available`。
- WB：日志出现 `dispatch WB write target=4250K...4450K` 与 `runtime confirmed WB ... pending cleared`。
- TINT：日志出现 `dispatch Tint write target M1...M6 / G1` 与 `runtime confirmed Tint ... pending cleared`；个别小步进被设备回读量化到 `0`，未导致 crash。
- ISO：日志出现 `dispatch ISO write target 1600 / 2000 / 1250 / 1000 / 800 / 640 / 500` 与 `runtime confirmed ISO ... pending cleared`。
- Shutter：日志出现 `dispatch shutter write target 1/60 / 1/50 / 1/30`；一次 pending timeout 回落到 runtime `1/60`，实际回读值已到目标。
- Auto 恢复：日志出现 `WB switched to AUTO`、`Tint pending cleared`、`ISO switched to AUTO`、`Shutter switched to AUTO`。
- Product Auto 降级：手动曝光时 ProductAutoExposure 暂停，手动 WB 时 ProductAutoWB 不阻断 Preview / Focus / Capture 主链路。

尚需人工补验后才能宣称 R78B 全量完成：

- 13mm / 48mm / 77mm 各焦段下四参数逐项拖动与回读。
- zoom ruler 慢速/快速跨物理镜头边界后的自动恢复。
- 前后台恢复后四参数 capability 重新计算。
- 每组手动参数下拍照、保存、metadata 与 session 持续运行复核。

## 7. 残留风险

- iOS 27 Beta 的虚拟多摄 capability 暴露与最终正式版可能继续变化；本轮日志会保留虚拟设备与物理设备差异，便于后续复核。
- 当前证据确认 physical Wide 具备四参数真实写入能力；Ultra Wide / Telephoto 的逐焦段写入仍需人工真机补验。
- Shutter 与 Tint 的少量 pending timeout 属于 readback 量化/同值更新窗口问题，当前 fallback 到 runtime 回读值，未发现 crash 或黑屏；若用户体感仍有“拖动后提示延迟”，下一轮应只收口 pending clear 语义，不改相机架构。
- 旧 iOS fallback 仍保留 custom gains 路径；未提升 Deployment Target，未删除 Auto EV / Auto WB、镜头系统、白底链路或拍后链路。

## 8. R78B 补验追加：虚拟多摄与 active constituent 探索

补验任务要求不要直接提交当前工作树，也不要混入 R78A。本轮已先冻结工作树，快照保存于 `/tmp/r78b_freeze_worktree.txt`。

### 8.1 当前工作树来源标记

- `SellerCamera/CaptureLivePreviewView.swift`：R78B 主修改文件；包含四参数 availability、readback、虚拟/物理设备策略探索。
- `SellerCamera/CaptureScreen.swift`：R78B 诊断入口；同时该文件已有 R78A 相关 UI 行为修改，属于混合文件，提交前必须 `git add -p`。
- `README.md`：R78A + R78B 报告索引混合修改，提交前必须只选择 R78B hunk。
- `docs/reports/r78b_ios27_manual_parameter_runtime_write_recovery.md`：R78B 新报告。
- `docs/reports/r78a_xcode27_beta_device_runtime_recovery.md`：R78A 报告，默认排除。
- `SellerCamera.xcodeproj/project.pbxproj`、嵌套 `SellerCamera.xcodeproj` workspace 删除：非 R78B，默认排除。
- `SellerCamera/CaptureBottomParameterBar.swift`：R78A 既有改动，R78B 当前不纳入提交。

### 8.2 方案 A：保留虚拟 Back Triple + 写 active constituent

实测步骤：

- 恢复默认 session input 为 `Back Triple Camera`。
- `Back Triple Camera` 保留 `virtualSwitchOver=[2.00,6.00]`，连续 zoom 可在虚拟设备内运行。
- 参数面板打开后，`activePrimary` 能从 `nil` 变为当前物理 constituent，例如 `Back Ultra Wide Camera` 或 `Back Camera`。
- 代码尝试将 ISO / Shutter / WB / TINT 的手动写入目标改为 `activePrimary`。

实测结果：

- ISO：active constituent 写入可 runtime confirmed，日志出现 `runtime confirmed ISO 64/80/100/125/...`。
- Shutter：可派发写入，但仍观察到 `pending timeout for shutter 1/50, fallback to runtime 1/30`，需要进一步 token / completion 收口。
- WB/TINT：不能宣布真实恢复。虚拟设备直接写 Kelvin/Tint 会触发 `NSInvalidArgumentException`，原因是虚拟 `Back Triple Camera` 的 `isLockingWhiteBalanceWithCustomDeviceGainsSupported == false`。改为写 active constituent 后不崩溃，但虚拟设备 runtime WB 长时间仍回读为原值 `3755K`，出现 pending timeout，不能证明影响虚拟输出。
- 结论：方案 A 暂不能作为最终策略；至少 WB/TINT 不满足“runtime readback 同步”的完成标准。

### 8.3 镜头系统补验证据

已确认：

- 默认 session input 已可回到 `Back Triple Camera`，不是单广角数字 zoom。
- 连续 zoom ruler 在虚拟设备上可输出 `zoom:rulerDrag`，并在日志中看到 `activePrimary` 在 `Back Ultra Wide Camera` 与 `Back Camera` 间变化。
- 48mm 语义可触发 `semanticFocal:48mm`，target zoom 进入 2x。

未完整确认：

- 13mm、24mm、48mm、77mm 每个焦段下四参数逐项 runtime readback。
- 77mm 是否真实进入 Telephoto active constituent。
- 前后台恢复后 active constituent 与手动参数 availability 是否稳定重算。
- 各焦段拍照保存与 metadata。

### 8.4 当前分流结论

本轮不能完成纯净提交：

- 物理 Back Camera fallback 能恢复 24mm 四参数，但仍需确认是否牺牲连续虚拟多摄体验。
- 虚拟 Back Triple + active constituent 方案保留 zoom，但 WB/TINT runtime readback 不成立。
- 因此 R78B 仍处于“发现能力冲突并完成部分验证”状态，不应提交为 `R78B restore iOS27 manual parameter runtime writes`。

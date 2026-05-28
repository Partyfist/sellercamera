# R31 EV / WB / ISO / Shutter 真机验证闭环 + 最小显示修正报告

## 1. 本包定位

- 包类型：验证收口包（非功能扩展包）。
- 范围：仅覆盖 EV / WB / ISO / Shutter 四条已接入参数链路验证。
- 边界：不接 Focus，不改白底处理链路，不改拍后流程，不重构曝光系统。

## 2. 本包最小修正

### 2.1 问题层级

- 当前主要问题不是“能否写入”，而是 `ISO 非 Auto` 时 `Shutter` 锁定状态在 UI 上不够直观，容易被误解为“快门值仍可调”。

### 2.2 最小修正内容

- 文件：`SellerCamera/CaptureScreen.swift`
  - `S` 参数在 `locked` 模式下，底部值与滚轮中心值统一显示为 `LOCK`。
  - `S` 列控制按钮在锁定态显示 `LOCK`（替代 `AUTO` 文案）。
- 文件：`SellerCamera/CaptureBottomParameterBar.swift`
  - `LOCK` 控制按钮禁用，避免误触发无效动作。

## 3. 执行动作与证据

1. Simulator Debug 构建：
   - 命令：`xcodebuild -project /Users/sungning/Projects/SellerCamera/SellerCamera.xcodeproj -scheme SellerCamera -configuration Debug -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO build`
   - 结果：通过（`BUILD SUCCEEDED`）。
2. iOS Device Debug 构建（签名产物）：
   - 命令：`xcodebuild -project /Users/sungning/Projects/SellerCamera/SellerCamera.xcodeproj -scheme SellerCamera -configuration Debug -destination 'id=E7D43088-7946-5FDB-BB14-E38124BB37DB' -derivedDataPath /tmp/SellerCameraR31DeviceBuild build`
   - 结果：通过（`BUILD SUCCEEDED`）。
3. 设备安装验证：
   - 命令：`xcrun devicectl device install app --device E7D43088-7946-5FDB-BB14-E38124BB37DB /tmp/SellerCameraR31DeviceBuild/Build/Products/Debug-iphoneos/SellerCamera.app`
   - 结果：通过（安装成功）。
4. 设备启动验证：
   - 命令：`xcrun devicectl device process launch --device E7D43088-7946-5FDB-BB14-E38124BB37DB --terminate-existing --console com.partyfist.SellerCamera`
   - 结果：可启动进程，但会话中出现 `signal 9` 终止，无法在 CLI 内完成“人工视觉/触觉”闭环确认。

## 4. 验证结果分层

### 4.1 已确认

- 四参数相关代码在当前主线可成功编译（Simulator + iOS Device）。
- 设备侧安装路径可用（`devicectl install app` 成功）。
- `ISO 非 Auto -> Shutter 锁定` 合同仍成立，且 UI 锁定语义更清晰（`LOCK`）。
- 本包未引入 Focus 写入，也未改动白底链路和拍后流程代码。

### 4.2 未确认（需真机人工操作）

- EV 上滑变亮、下滑变暗的主观视觉确认。
- WB 上滑变暖、下滑变冷的主观视觉确认。
- ISO 上下滑对亮度/噪声倾向的主观确认。
- Shutter 上滑更快、下滑更慢的主观确认。
- 四参数交替操作下的体感稳定性与触觉轻重评估。

### 4.3 环境边界/阻塞

- `devicectl` 会话能完成 install/launch，但当前 CLI 无法替代人工在真机屏幕上执行滑动与观察。
- 启动会话中出现 `signal 9`，不构成“完整人工交互已验证”的证据。

## 5. 当前结论

1. R31 已完成一项必要的最小显示修正：`Shutter` 在锁定态显式 `LOCK`，避免 ISO 手动状态下的误解。
2. 构建链路与设备安装链路可用。
3. 四参数“主观视觉/触觉闭环”仍需在真机人工操作中完成，当前不能夸大为“已全部真机验收通过”。

## 6. 下一步（相邻最小动作）

在可交互真机环境中执行一次人工闭环清单：

1. EV：上滑变亮、下滑变暗、`RESET -> 0.0`。
2. WB：上滑变暖、下滑变冷、`AUTO` 恢复自动语义。
3. ISO：上滑增加、下滑降低、`AUTO` 恢复自动语义。
4. Shutter：ISO Auto 时可调；ISO 非 Auto 时显示 `LOCK` 且不可调；ISO Auto 后恢复可调。
5. 四参数交替操作一致性与收起/再展开中心档一致性。

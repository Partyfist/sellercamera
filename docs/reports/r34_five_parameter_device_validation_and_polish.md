# R34 五参数综合真机验证闭环 + 专业手感最小打磨报告

## 1. 本包定位

- 包类型：验证收口包（非功能扩展包）。
- 范围：仅覆盖 FOCUS / EV / WB / ISO / Shutter 五项已接入参数链路的综合验证与最小收口。
- 边界：不新增参数能力，不改白底处理链路，不改拍后流程，不重构 camera runtime。

## 2. 本包执行摘要

1. 完成五参数链路代码合同复核：
   - Focus：`L > M > A`，`L` 下滚轮禁用，`AUTO` 走 `restoreAutofocusMode()`；
   - EV：滚轮写入 + `RESET`；
   - WB：Kelvin 写入 + `AUTO`；
   - ISO：写入 + `AUTO`；
   - Shutter：写入 + `AUTO`，并保留 `ISO 非 Auto -> LOCK`。
2. 完成最小构建与设备链路验证：
   - Simulator Debug build 通过；
   - iOS Device build 通过；
   - 设备 install 成功；
   - 设备 launch 成功。
3. 本轮未扩展新功能，仅做验证收口与文档落位。

## 3. 执行动作与证据

1. Simulator 构建：
   - 命令：`xcodebuild -project /Users/sungning/Projects/SellerCamera/SellerCamera.xcodeproj -scheme SellerCamera -configuration Debug -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO build`
   - 结果：`BUILD SUCCEEDED`。
2. Device 构建：
   - 命令：`xcodebuild -project /Users/sungning/Projects/SellerCamera/SellerCamera.xcodeproj -scheme SellerCamera -configuration Debug -destination 'id=E7D43088-7946-5FDB-BB14-E38124BB37DB' build`
   - 结果：`BUILD SUCCEEDED`。
3. 设备安装：
   - 命令：`xcrun devicectl device install app --device E7D43088-7946-5FDB-BB14-E38124BB37DB /Users/sungning/Library/Developer/Xcode/DerivedData/SellerCamera-clujgyuzmlxdoudgpfvmcmdnnwma/Build/Products/Debug-iphoneos/SellerCamera.app`
   - 结果：安装成功（`App installed`）。
4. 设备启动：
   - 命令：`xcrun devicectl device process launch --device E7D43088-7946-5FDB-BB14-E38124BB37DB com.partyfist.SellerCamera`
   - 结果：启动成功（`Launched application with com.partyfist.SellerCamera bundle identifier.`）。

## 4. 验证分层结果

### 4.1 已确认

1. 五参数相关代码在当前主线可成功构建（Simulator + Device）。
2. 设备安装与启动链路可用，App 可被远端启动。
3. Focus 手动/自动/锁定合同在代码层清晰：
   - 手动写入：`setManualFocusLensPosition(_:)`；
   - Auto：`restoreAutofocusMode()`；
   - 锁定态：`LOCK` + 滚轮禁用。
4. Shutter 与 ISO 边界合同未被破坏：
   - ISO 非 Auto 时，Shutter 维持 `LOCK` 语义并禁用；
   - ISO Auto 后，Shutter 可恢复可调。

### 4.2 未确认（需人工真机操作）

1. Focus 上下滑动在真实拍摄场景中的“远/近”主观手感是否最优。
2. EV 上滑变亮、下滑变暗的主观视觉确认。
3. WB 上滑变暖、下滑变冷的主观视觉确认。
4. ISO 上下滑对噪声倾向与亮度观感的主观确认。
5. Shutter 上滑更快、下滑更慢在真实场景中的主观确认。
6. 五参数触觉反馈轻重是否达到“专业但不扰人”。

### 4.3 环境边界/阻塞

1. 当前 CLI 会话可完成构建、安装、启动，但无法替代人工在真机屏幕上的滑动与肉眼观察。
2. `devicectl` 输出存在 `No provider was found` 预警，但未阻断 install / launch；因此不能把它等同于“完整真机交互验证通过”。

## 5. 本轮是否做代码修正

- 本轮以验证收口为主，未新增超出五参数合同的新功能。
- 代码层沿用 R33 之后的 Focus 接入实现与现有 EV/WB/ISO/Shutter 合同，未扩散到其它模块。

## 6. 当前结论

1. R34 已完成“五参数综合验证包”内可执行的构建与设备链路验证。
2. 当前可以确认：主线代码、设备构建、安装、启动均可用，且五参数合同未出现代码层冲突。
3. 当前不能夸大为“所有主观手感与视觉变化已真机闭环通过”；这部分仍需人工滑动验证补齐。

## 7. 下一步（相邻最小动作）

在可交互真机会话中，按固定清单补齐人工闭环：

1. Focus：验证上/下滑“远/近”直觉与 `A/M/L` 切换体感；
2. EV：验证亮暗方向与 `RESET -> 0.0`；
3. WB：验证冷暖方向与 `AUTO`；
4. ISO：验证数值方向与 `AUTO`；
5. Shutter：验证快慢方向与 `AUTO`，并复核 `ISO 非 Auto -> LOCK` 可理解性；
6. 验证拍摄按钮与拍后链路无回归。

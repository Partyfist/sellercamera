# R35 五参数人工真机闭环补验 + 最小问题修正报告

## 1. 本包定位

- 包类型：验证补验包（非功能扩展包）。
- 范围：FOCUS / EV / WB / ISO / Shutter 五参数的人工真机闭环补验准备、可执行验证与结果收口。
- 边界：不新增参数功能，不重构 runtime，不改白底链路，不改拍后流程。

## 2. 本包执行摘要

1. 完成五参数代码合同复核（Focus `L > M > A`、EV/WB/ISO/Shutter 写入与 Auto/Reset 路由、ISO/Shutter 锁定边界）。
2. 完成可执行验证：
   - Simulator Debug build 通过；
   - Device Debug build 通过；
   - 真机安装成功；
   - 真机启动成功。
3. 本轮未做无证据代码改动：
   - 因 CLI 无法替代人工视觉与触觉观察，本轮不对参数方向与手感做主观判断性修正，避免误修。

## 3. 执行动作与证据

1. Simulator 构建：
   - `xcodebuild -project /Users/sungning/Projects/SellerCamera/SellerCamera.xcodeproj -scheme SellerCamera -configuration Debug -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO build`
   - 结果：`BUILD SUCCEEDED`。
2. Device 构建：
   - `xcodebuild -project /Users/sungning/Projects/SellerCamera/SellerCamera.xcodeproj -scheme SellerCamera -configuration Debug -destination 'id=E7D43088-7946-5FDB-BB14-E38124BB37DB' build`
   - 结果：`BUILD SUCCEEDED`。
3. 真机安装：
   - `xcrun devicectl device install app --device E7D43088-7946-5FDB-BB14-E38124BB37DB /Users/sungning/Library/Developer/Xcode/DerivedData/SellerCamera-clujgyuzmlxdoudgpfvmcmdnnwma/Build/Products/Debug-iphoneos/SellerCamera.app`
   - 结果：成功（`App installed`）。
4. 真机启动：
   - `xcrun devicectl device process launch --device E7D43088-7946-5FDB-BB14-E38124BB37DB com.partyfist.SellerCamera`
   - 结果：成功（`Launched application ...`）。

## 4. 五参数人工闭环状态

### 4.1 已确认

1. 五参数相关代码可构建并能产出真机包。
2. App 可安装到目标设备并可远程启动。
3. 关键合同未破坏：
   - Focus：`setManualFocusLensPosition(_:)` / `restoreAutofocusMode()` + `L > M > A`；
   - EV：`setExposureBiasDialValue(_:)` / `resetExposureBias()`；
   - WB：`setWhiteBalanceDialValue(_:)` / `applyWhiteBalanceAuto()`；
   - ISO：`setISODialValue(_:)` / `applyISOAuto()`；
   - Shutter：`setShutterDialValue(_:)` / `applyShutterAuto()`；
   - ISO 非 Auto -> Shutter `LOCK` 禁用边界保持成立。

### 4.2 未确认（需人工真机滑动补验）

1. Focus 上下滑“远/近”体感是否符合预期。
2. Focus `M -> A` 与 `L` 禁用是否在交互层直观。
3. EV 上滑变亮、下滑变暗与 `RESET -> 0.0` 的主观确认。
4. WB 上滑变暖、下滑变冷与 `AUTO` 恢复主观确认。
5. ISO 上下滑变化、`AUTO` 恢复与噪声/亮度倾向主观确认。
6. Shutter 上滑更快、下滑更慢、`AUTO` 恢复主观确认。
7. 五参数交替切换后显示一致性与收起再展开中心档一致性。
8. 点击对焦、长按 AE/AF Lock 在引入 Focus 后的人工回归确认。
9. 拍摄按钮与拍后流程的人机路径回归确认。

### 4.3 环境边界

1. 当前 CLI 环境可覆盖 build/install/launch，但无法替代真实人眼观察画面亮暗/冷暖/景深变化，也无法替代触觉体感判断。
2. `devicectl` 输出存在 `No provider was found` 预警，但未阻断 install/launch，不可据此等价“人工闭环完成”。

## 5. 最小修正结果

- 本轮未新增代码修正。
- 原因：未拿到人工主观证据前，避免对方向和手感做猜测性调整，符合“最小风险增量”原则。

## 6. 当前结论

1. R35 已完成本包内可执行验证与合同复核，主链构建与设备侧安装/启动可用。
2. R35 未完成人工真机交互闭环，因此不能夸大为“五参数真机体验已完全验收通过”。
3. 当前状态适合进入一个“人工滑动操作记录 + 最小修正”极小轮次。

## 7. 下一步（相邻最小动作）

在可交互真机上按固定清单逐项执行：

1. Focus：上/下滑远近、`M/A/L` 转换、`L` 禁用。
2. EV：上亮下暗、`RESET` 归零。
3. WB：上暖下冷、`AUTO` 恢复。
4. ISO：上增下减、`AUTO` 恢复。
5. Shutter：上快下慢、`AUTO` 恢复、ISO 非 Auto 时 `LOCK` 可理解性。
6. 点击对焦、长按 AE/AF Lock、拍摄按钮、拍后流程回归。

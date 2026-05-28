# R28 EV / WB 真机验证闭环 + 最小显示修正报告

## 1. 本包定位

- 包类型：参数链路验证与最小修正包（非新功能包）。
- 范围：只覆盖 EV / WB 两条已接入参数链路。
- 边界：不接入 ISO / Shutter / Focus，不改白底处理和拍后流程。

## 2. 本包执行动作

1. 完成 EV / WB 交互方向最小修正：
   - 上滑增加档位（EV 增、WB 更暖）；
   - 下滑降低档位（EV 降、WB 更冷）。
2. 完成 WB `AUTO` 显示语义最小修正：
   - 自动模式下，滚轮中心档显示 `A`（无 pending 时），与底部栏语义一致。
3. 执行最小构建验证（Simulator Debug build）。
4. 执行真机侧可执行验证（设备构建与设备服务连通性检查）。

## 3. 关键修正点

### 3.1 滑动方向修正

- 文件：`SellerCamera/CaptureBottomParameterBar.swift`
- 改动：滚轮步进方向改为 `-rawStepCount`，统一为“上滑增、下滑减”。

### 3.2 WB AUTO 显示一致性修正

- 文件：`SellerCamera/CaptureScreen.swift`
- 改动：`whiteBalanceWheelTicks()` 中自动模式且无 pending 时，中心档显示 `A`。

## 4. 验证结果

### 4.1 构建验证

- 命令：
  `xcodebuild -project /Users/sungning/Projects/SellerCamera/SellerCamera.xcodeproj -scheme SellerCamera -configuration Debug -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO build`
- 结果：`BUILD SUCCEEDED`。

### 4.2 真机链路验证

- 设备构建：成功（签名成功，产物输出到 `/tmp/SellerCameraPkg6DeviceDerived/...`）。
- `devicectl device info apps`：可拿到设备应用列表，并可见 `com.partyfist.SellerCamera`。
- `devicectl device install/launch`：当前环境下多次失败，错误为 `CoreDeviceService` 初始化超时/连接失效。

## 5. 当前结论

1. 代码层 EV / WB 方向与 WB AUTO 显示语义已完成最小修正。
2. 构建链路与设备签名构建链路可用。
3. 当前执行环境的 `CoreDeviceService` 阻塞导致无法在本包内完成“可操作真机交互”闭环（亮暗/冷暖主观变化、触觉反馈、拍后链路实操）。

## 6. 下一步（仅相邻最小动作）

在可用真机调试环境中补做一次手工闭环：

1. EV 上滑变亮、下滑变暗、RESET 回 `0.0`。
2. WB 上滑变暖、下滑变冷、AUTO 回自动语义。
3. EV/WB 交替操作后一致性、收起再展开中心档一致性。
4. 拍摄按钮与拍后链路无回归。

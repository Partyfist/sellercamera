# R29 EV / WB / ISO 真机验证闭环 + 最小显示修正报告

## 1. 本包定位

- 包类型：参数链路验证与最小修正包（非新功能包）。
- 范围：只覆盖 EV / WB / ISO 三条已接入参数链路。
- 边界：不接入 Shutter / Focus，不改白底处理链路，不改拍后流程。

## 2. 问题与最小修正

### 2.1 问题层级

- 当前核心不是新增参数，而是 EV / WB / ISO 三条真实链路的“方向、显示、回写、AUTO/RESET、一致性”闭环验证。

### 2.2 本包最小修正

- 文件：`SellerCamera/CaptureScreen.swift`
- 修正项：ISO 在 `AUTO` 模式下，底部参数栏显示改为 `A`（无 pending 时）。
- 修正原因：
  - 展开面板中心档在 ISO 自动模式下已经显示 `A`；
  - 修正前底部栏可能显示实时数值，导致“收起/再展开一致性”语义不稳定；
  - 本修正让底部栏语义与展开中心档保持一致，降低验证误判风险。

## 3. 执行动作与证据

1. Simulator Debug 构建验证：通过。
2. iOS Device Debug 构建验证（含签名产物）：通过。
3. 设备可见性验证：通过（`devicectl device info apps` 可见 `com.partyfist.SellerCamera`）。
4. 设备 install / launch 验证：受环境阻塞（`CoreDeviceService` 初始化超时）。

## 4. 验证结果分层

### 4.1 已确认

- EV / WB / ISO 相关代码在当前主线可成功编译（Simulator + iOS Device）。
- ISO 自动显示语义与展开中心档一致（`A`）。
- 设备当前可被 `devicectl` 建立 tunnel 并读取已安装应用列表。

### 4.2 未确认（需真机交互）

- EV 上滑变亮、下滑变暗的实际视觉变化。
- WB 上滑变暖、下滑变冷的实际视觉变化。
- ISO 上滑增大、下滑减小时预览亮度/噪声倾向的主观变化。
- 触觉反馈密度与体感是否符合预期。
- EV/WB/ISO 交替操作下的完整手工闭环体验。

### 4.3 环境阻塞

- `xcrun devicectl device install app ...` 失败：
  - `Timed out waiting for CoreDeviceService to fully initialize`
- `xcrun devicectl device process launch ...` 同样失败：
  - `CoreDeviceService` 连接 invalidated / 初始化超时

## 5. 当前结论

1. 本包范围内已完成一个必要的最小显示修正（ISO `AUTO` 显示语义收口）。
2. 构建链路（Simulator / Device）可用。
3. 真机“交互闭环”在当前执行环境下仍被 `CoreDeviceService` 阻塞，不能夸大为“已完成真机视觉验证”。

## 6. 下一步（相邻最小动作）

在可用真机调试环境中补做一次手工闭环：

1. EV：上滑变亮、下滑变暗、RESET 回 `0.0`。
2. WB：上滑变暖、下滑变冷、AUTO 回自动语义。
3. ISO：上滑增、下滑减、AUTO 回自动语义。
4. EV/WB/ISO 交替操作一致性与收起/再展开中心档一致性。
5. 拍摄按钮与拍后链路无回归。

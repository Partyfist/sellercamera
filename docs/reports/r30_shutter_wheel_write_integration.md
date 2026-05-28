# R30 Shutter 短竖向滚轮交互化 + Auto / Manual Shutter 写入接入报告

## 1) 改动摘要

- 本包完成：
  - 在底部五参数短滚轮中接入 `S / Shutter` 真实交互（上滑更快、下滑更慢）。
  - 接入 Shutter `AUTO` 动作（调用现有 runtime 自动快门路径）。
  - 新增 Shutter pending / 去重 / 超时回收，与 EV/WB/ISO 收口方式保持一致。
  - 保持 EV/WB/ISO 已有交互与写入逻辑不回归。
- 本包未做：
  - Focus 真实写入；
  - ISO+Shutter 完整手动曝光系统重构；
  - 白底处理链路与拍后流程改动。

## 2) Shutter 能力核查（代码现状）

### 2.1 当前值来源

- 自动快门值：`cameraRuntime.currentShutterDurationSeconds`
- 手动快门值：`cameraRuntime.currentManualShutterDurationSeconds`
- 状态标识：`cameraRuntime.selectedShutterPreset`

### 2.2 写入路径

- 滚轮写入：`cameraRuntime.setShutterDialValue(normalizedTarget)`
  - runtime 内部进一步进入 `applyShutterPreset(.custom, shouldShowHint: true)`
  - 最终通过 `device.setExposureModeCustom(duration: ..., iso: device.iso)` 写入

### 2.3 Auto 路径

- `AUTO` 按钮：`cameraRuntime.applyShutterAuto()`
  - runtime 内部进入 `applyShutterPreset(.auto, shouldShowHint: true)`
  - 使用 `continuousAutoExposure`

### 2.4 与 ISO 的配合策略（本包保持保守）

- 当前正式策略沿用 runtime 既有合同：
  - `selectedISOPreset != .auto` 时，Shutter 侧在 UI 状态上视为锁定（不进入可调）。
  - 目的是避免在未做完整曝光系统重构前出现状态混乱。
- 即：本包不引入新的 ISO+Shutter 复杂联动，只保持现有可维护边界。

## 3) 交互与写入实现

### 3.1 档位生成

- 新增 `shutterWheelDurationValues()`：
  - 优先按设备 `minimumShutterDurationSeconds ... maximumShutterDurationSeconds` 裁剪；
  - 使用保守快门刻度集（`1/4000 ... 1"`）；
  - 合并 runtime 当前自动/手动值；
  - 去重后按“慢 -> 快”（秒值降序）排列，匹配“上滑更快”方向。

### 3.2 拖动方向与阈值

- 沿用现有滚轮统一阈值：
  - 单档阈值约 `22pt`；
  - 单次最多跨 `3` 档；
  - 上滑触发 `direction > 0`，移动到更快快门；
  - 下滑触发 `direction < 0`，移动到更慢快门。

### 3.3 去重与边界

- 同档位不重复写入：
  - pending 去重；
  - last-dispatched 去重；
  - 边界档位直接跳过写入。

### 3.4 pending / runtime 收口

- 新增状态：
  - `pendingShutterWheelDurationSeconds`
  - `pendingShutterUpdatedAt`
  - `lastDispatchedShutterDurationSeconds`
- runtime 回写确认：
  - 监听 `currentManualShutterDurationSeconds`
  - 采用相对容差（约 10%，下限 0.0003s）清理 pending
- 超时回收：
  - `shutterPendingTimeout = 1.5s`
  - 超时后回退到 runtime 显示，避免 pending 悬挂

## 4) UI 显示语义

- 底部栏 `S`：
  - pending 时显示 pending 快门；
  - `AUTO` 模式显示 `A`；
  - 手动模式显示快门文本（如 `1/125`）。
- 展开面板 Shutter 列：
  - `AUTO` 且无 pending：中心档显示 `A`；
  - 手动：中心档显示当前快门；
  - 相邻档显示上/下邻近快门值。

## 5) 验证结果

### 5.1 构建

- Simulator Debug 构建：通过
- iOS Device Debug 构建（签名产物）：通过

### 5.2 设备侧执行

- `devicectl device install app`：成功
- `devicectl device process launch --console`：成功（本次会话可启动并返回）

### 5.3 验证边界（不能夸大）

- 当前环境下未完成“人工真机主观操作”闭环记录（上/下滑对画面亮暗与动态模糊体感变化）。
- 因此本包结论是“Shutter 写入链路与设备启动链路已接通”，但“主观拍摄手感闭环”仍应在下一包补测。

## 6) 结论

本包已按边界完成 `Shutter` 的最小真实接入：

1. Shutter 滚轮可交互；
2. Shutter 写入走现有 runtime 正式路径；
3. Shutter AUTO 可恢复自动快门；
4. EV/WB/ISO 未扩散改造；
5. Focus 仍未接入真实写入。

可进入下一包（第 10 包）做 EV/WB/ISO/Shutter 四参数真机闭环与最小显示修正。

# R37 TINT 色偏真实写入 / White Balance Tint 接入报告

## 1. 本包定位

- 包类型：参数接入包（非扩展包）。
- 范围：将 `TINT` 从 UI 骨架接入真实白平衡色偏写入闭环。
- 边界：不改 Focus，不重构 EV/WB/ISO/Shutter，不改白底链路与拍后流程。

## 2. 本包执行摘要

1. 完成 TINT runtime 能力接入：
   - 新增 `currentWhiteBalanceTint` 状态；
   - 新增 `setWhiteBalanceTintDialValue(_:)` 写入入口；
   - 新增 `whiteBalanceTintDialRange / whiteBalanceTintDialValue / whiteBalanceTintDialStepValue`。
2. 完成 WB 手动写入修正：
   - 旧逻辑固定 `tint = 0`；
   - 新逻辑改为温度 + tint 同步写入，避免调 WB 时覆盖 Tint。
3. 完成 CaptureScreen 的 TINT 交互闭环：
   - TINT 列可拖动，触发真实写入；
   - TINT `AUTO` 接入（复用 `applyWhiteBalanceAuto()`）；
   - TINT pending / timeout / runtime confirmed 收口完成。
4. 完成底栏与展开面板一致显示：
   - Auto 显示 `A`；
   - Manual 显示 `Gxx/Mxx`。

## 3. 关键实现路径

### 3.1 runtime 侧（CaptureLivePreviewView.swift）

1. 新增白平衡 tint 常量与状态：
   - `whiteBalanceMinimumTint = -150`
   - `whiteBalanceMaximumTint = 150`
   - `whiteBalanceTintDialStep = 5`
   - `@Published currentWhiteBalanceTint`
2. 新增写入入口：
   - `setWhiteBalanceTintDialValue(_:)`
3. 白平衡手动写入统一为：
   - `applyWhiteBalanceManualValues(requestedTemperature:requestedTint:...)`
4. `applyWhiteBalanceAuto()` 与 capability 刷新时同步读取温度+tint，确保状态回写一致。

### 3.2 UI 路由侧（CaptureScreen.swift）

1. TINT 控制从 skeleton 改为真实交互：
   - `onWheelStep(.tint)` -> `stepTintWheel(by:)`
   - `onControlTap(.tint)` -> `applyTintAutoFromWheel()`
2. 新增 TINT pending 管理：
   - `pendingTintWheelValue`
   - `pendingTintUpdatedAt`
   - `lastDispatchedTintValue`
   - timeout 与 runtime confirmed 回收
3. 新增 TINT 刻度与显示：
   - `tintWheelValues()`
   - `tintWheelTicks()`
   - `formattedTintTick(_:)`（`Gxx/Mxx/0`）
4. `parameterState(for: .tint)` 改为真实模式映射：
   - `.auto` / `.manual` / `.disabled`
   - 可调与 AUTO 能力跟随 WB 支持状态。

## 4. 本包边界（刻意未做）

1. 未改 Focus 入口与 Focus 写入合同。
2. 未扩展 ISO/Shutter/Focus 的额外联动重构。
3. 未新增滤镜、Tone、调色盘等能力。
4. 未改白底处理链路与拍后流程。

## 5. 验证状态

1. 代码层已完成接入并做编译前静态核查。
2. 本包最小构建验证结果见回报（xcodebuild）。
3. 本包未执行真机主观方向验证，不夸大为“手感已验证完成”。

## 6. 当前结论

1. TINT 已从“仅 UI 骨架”升级为“真实写入链路接入”。
2. WB 与 TINT 关系从“WB 写入强制重置 tint=0”修正为“WB/TINT 同体系协同写入”。
3. 当前可进入下一包真机闭环：重点验证 TINT 上下滑方向、AUTO 恢复与多参数交替一致性。


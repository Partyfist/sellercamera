# R39 EV/WB/TINT/ISO/S 真机综合验证 + 参数精度与开关状态打磨报告

## 1. 本包定位

- 包类型：验证与最小打磨包（非新功能包）。
- 目标：在守住现有五参数合同前提下，完成可复核验证与最小交互打磨。
- 边界：不接 Focus，不改白底链路，不改拍后流程，不新增 Tone/滤镜/调色盘能力。

## 2. 本包执行摘要

1. 保持五参数合同不变：
   - `EV/WB/TINT/ISO/S` 结构保持；
   - `TINT=RESET`、`WB AUTO`、`ISO 非 Auto 时 Shutter LOCK` 合同保持。
2. 参数精度最小打磨：
   - WB 滚轮刻度改为更细的常用 Kelvin 档（3000~8000 分段），并按设备能力裁剪；
   - Shutter 滚轮刻度改为更细的 1/3 stop 级候选，并按设备能力裁剪。
3. 参数切换热区最小打磨：
   - 展开面板中每列增加整列点击激活（不再局限标题/值区域）。
4. AUTO/RESET/LOCK 状态识别最小打磨：
   - 控制按钮视觉按语义区分：AUTO 开启态、RESET 动作态、LOCK 禁用态。
5. 构建验证：
   - `xcodebuild` Debug iOS Simulator 构建通过。

## 3. 关键改动

### 3.1 参数精度

- `CaptureScreen.whiteBalanceWheelValues()`：
  - 从“按 runtime step 线性枚举”调整为“优先常用 Kelvin 档 + 设备范围裁剪 + 边界与当前值补齐”。
- `CaptureScreen.shutterWheelDurationValues()`：
  - 从较粗 canonical 列表调整为更细的 1/3 stop 近似列表（含 1/3200、1/2500、1/1600、1/800、1/640、1/400、1/320、1/200、1/160、1/100、1/80、1/50、1/40、1/25、1/20、1/10、1/6 等）。

### 3.2 点击热区

- `CaptureBottomParameterBar.CaptureCompactVerticalWheelColumn`：
  - 为整列增加 `onTapGesture` 选择 active 参数，保持拖动滚轮与控制按钮独立可用。

### 3.3 AUTO / RESET / LOCK 视觉语义

- 在列内控制按钮样式层增加语义区分：
  - `LOCK`：禁用弱化显示；
  - `AUTO` 且当前参数值为 `A`：显示为开启态强调；
  - `RESET`：保持动作按钮风格，不作为开关态。

## 4. 本包边界（刻意未做）

1. 未接 Focus 回五参数控制台。
2. 未改 EV/WB/ISO/Shutter runtime 写入链路。
3. 未改 WB/TINT 组合写入合同。
4. 未改拍后流程和白底处理链路。
5. 未新增任何新的色彩系统能力（Tone/Style/滤镜/调色盘）。

## 5. 验证结果

### 5.1 构建验证（已确认）

- 命令：
  - `xcodebuild -project /Users/sungning/Projects/SellerCamera/SellerCamera.xcodeproj -scheme SellerCamera -configuration Debug -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO build`
- 结果：`BUILD SUCCEEDED`。

### 5.2 真机综合验证（本轮未在当前会话内完成）

- 当前会话完成了构建闭环与代码合同核查；
- 但未在本会话内执行你任务书要求的完整人工真机逐项验证（EV/WB/TINT/ISO/S 方向与体感）。
- 因此以下项仍归类为“待真机确认”：
  - TINT 正负方向视觉体感（M/G）；
  - WB/TINT 组合在不同光线场景的主观稳定性；
  - 五参数交替切换下触觉与状态一致性体感。

## 6. 当前结论

1. 五参数控制台合同维持稳定，且参数精度与状态识别完成了最小打磨。
2. 本轮已达到“可继续真机综合验证”的工程状态。
3. 若真机补验通过，可进入下一包 UI 视觉统一打磨（不扩展新能力）。


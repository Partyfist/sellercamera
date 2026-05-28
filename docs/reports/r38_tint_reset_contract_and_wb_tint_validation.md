# R38 TINT 合同修正为 RESET + WB/TINT 真机色彩验证报告

## 1. 本包定位

- 包类型：合同修正与验证包（非功能扩展包）。
- 范围：将 `TINT` 从 `AUTO` 语义修正为 `RESET` 语义，并确认 `WB/TINT` 组合写入合同不回退。
- 边界：不改 EV/ISO/Shutter/Focus，不改白底链路，不改拍后流程，不引入 Tone/滤镜/调色盘。

## 2. 问题层级与修正目标

上一包 R37 已完成 TINT 真实写入，但出现产品语义偏差：

- `TINT` 入口被实现为 `AUTO` 并复用 `applyWhiteBalanceAuto()`。

这会混淆职责：

- `WB AUTO` 负责自动白平衡；
- `TINT` 应仅负责手动色偏（Green/Magenta）修正与归零。

本包将合同修正为：

- `TINT = RESET`
- `WB AUTO = 自动白平衡`

## 3. 本包关键改动

### 3.1 CaptureScreen（交互与显示语义）

1. `TINT` 底部控制文案改为 `RESET`（不再显示 `AUTO`）。
2. TINT 控制点击路由改为 `applyTintResetFromWheel()`。
3. `applyTintResetFromWheel()` 行为：
   - WB 为 Auto：仅清理 pending 并调用 `resetWhiteBalanceTint()`；
   - WB 为 Manual：设置 pending 目标 0 并调用 `resetWhiteBalanceTint()`。
4. TINT 状态映射改为手动色偏语义：
   - 底部值显示 `0 / Gxx / Mxx`；
   - 不再使用 TINT Auto 展示语义。
5. TINT 刻度范围与步进跟随 runtime：
   - `-50 ... +50`
   - step `5`

### 3.2 CaptureLivePreviewView（runtime 合同）

1. `whiteBalanceMinimumTint/MaximumTint` 收敛到 `-50 ... +50`。
2. 新增 `resetWhiteBalanceTint()`：
   - WB Auto：只把 tint 状态归零并提示 `色偏：0`，不强制二次触发 WB Auto；
   - WB Manual：写入 `currentTemperature + tint 0`。
3. `applyWhiteBalanceAuto()` 统一回收 tint 到 `0`，避免“Auto 状态残留手动色偏”误解。
4. 保持 R37 关键合同不回退：
   - `setWhiteBalanceDialValue(_:)` 用 `requestedTemperature + currentTint`；
   - `setWhiteBalanceTintDialValue(_:)` 用 `currentTemperature + requestedTint`。

## 4. WB / TINT 联动合同（R38 版）

1. WB 手动 Kelvin 调节：保留当前 TINT。
2. TINT 调节：保留当前 WB Kelvin。
3. TINT RESET：
   - Manual：写入 `currentKelvin + tint 0`；
   - Auto：保持 WB Auto，仅把 TINT 状态归零。
4. WB AUTO：
   - 调用 `applyWhiteBalanceAuto()`；
   - TINT 同步归零。

## 5. 本包边界（刻意未做）

1. 未新增 TINT AUTO 语义（明确移除）。
2. 未新增 Tone / Style / 滤镜 / 调色盘能力。
3. 未改 EV/ISO/Shutter/Focus 交互和写入逻辑。
4. 未改白底图处理链路和拍后流程。

## 6. 验证结果

### 6.1 构建验证

- 已执行：
  - `xcodebuild -project /Users/sungning/Projects/SellerCamera/SellerCamera.xcodeproj -scheme SellerCamera -configuration Debug -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO build`
- 结果：通过（见本轮执行回报）。

### 6.2 真机色彩验证

- 本轮执行环境未直接完成真机色彩方向验证（无法在当前会话内替代真实拍摄色温/色偏主观观察）。
- 因此本包只确认“代码合同 + 构建闭环”。
- `TINT 正值偏品红 / 负值偏绿` 需由下一步真机拍摄场景补验并记录。

## 7. 结论

1. TINT 合同已从错误的 `AUTO` 语义修正为 `RESET` 语义。
2. `WB AUTO` 与 `TINT RESET` 职责边界已恢复清晰：
   - WB AUTO = 自动白平衡；
   - TINT RESET = 色偏归零。
3. `WB/TINT` 组合写入链路保持成立且未回退到 `tint=0` 覆盖式旧行为。
4. 可以进入下一包做 `EV/WB/TINT/ISO/S` 真机综合方向与显示一致性补验。


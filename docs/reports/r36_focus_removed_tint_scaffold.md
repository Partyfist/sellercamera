# R36 Focus 移出五参数栏 + TINT 骨架接入报告

## 1. 本包定位

- 包类型：主线参数结构收口包（非新参数写入包）。
- 范围：将底部五参数主入口从 `FOCUS/EV/WB/ISO/S` 收口为 `EV/WB/TINT/ISO/S`，并接入 TINT 的最小 UI 骨架。
- 边界：不接 TINT runtime 写入，不改 Focus 运行时链路，不改 EV/WB/ISO/Shutter 既有写入合同，不改白底与拍后流程。

## 2. 本包执行摘要

1. 完成底部主参数集合调整：
   - 从 `focus` 移出；
   - 新增 `tint` 作为第五参数位。
2. 完成 TINT UI 骨架接入：
   - 底部常驻栏可显示 `TINT`；
   - 展开面板提供 TINT 列位和静态刻度语义（`G/A/M`）；
   - 当前保持 skeleton（不写入 runtime）。
3. 保留 Focus 已有运行时能力：
   - `setManualFocusLensPosition(_:)` 与 `restoreAutofocusMode()` 不删除；
   - 仅从底部主参数入口移出，避免与曝光/色彩参数混用。

## 3. 关键实现与合同

### 3.1 主参数集合收口

- `CaptureScreen.primaryParameterKinds` 已调整为：
  - `.exposureCompensation`
  - `.whiteBalance`
  - `.tint`
  - `.iso`
  - `.shutter`

### 3.2 TINT 骨架状态

- 新增 `CaptureProfessionalParameterKind.tint` 与标题映射 `TINT`。
- `parameterState(for: .tint)` 当前定义：
  - `mode = .auto`
  - `isAdjustable = false`
  - `canUseAuto = false`
  - `canReset = false`
  - `dialRange = -150...150`（仅预留）
  - `dialValue = 0`（仅预留）
- 展开滚轮显示使用静态占位语义，控制台可见但不可真实写入。

### 3.3 Focus 保留但不再主暴露

- Focus 运行时函数与状态逻辑保持在位，未做删除性变更。
- 底部主参数 UI 不再包含 Focus，减少参数语义耦合，符合“Focus 独立对焦系统”方向。

## 4. 本包未做内容（刻意边界）

1. 未接入 TINT 的真实相机写入路径。
2. 未改点击对焦/长按 AEAF Lock 逻辑。
3. 未重构 EV/WB/ISO/Shutter 的交互与写入。
4. 未改白底处理链路与拍后流程。
5. 未做新的实验入口或多模型能力扩展。

## 5. 验证结果

1. 已执行构建验证：
   - `xcodebuild -project /Users/sungning/Projects/SellerCamera/SellerCamera.xcodeproj -scheme SellerCamera -configuration Debug -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO build`
   - 结果：`BUILD SUCCEEDED`
2. 本包未要求真机主观验证，未宣称 TINT 已具备真实调节能力。

## 6. 当前结论

1. 正式主线底部参数口径已收口为：`EV/WB/TINT/ISO/S`。
2. Focus 已从底部五参数主入口移出，但运行时能力保留。
3. TINT 已完成最小骨架接入，可作为后续真实写入包的稳定落点。

## 7. 下一步（相邻最小增量）

如进入 TINT 真实接入包，建议先完成三件事：
1. 核查 runtime 是否具备 tint 读写能力与设备支持边界；
2. 定义 `WB(Kelvin)` 与 `TINT` 的联动合同（Auto/Manual 的状态优先级）；
3. 在不扩大面板和不改主链路前提下，接入 TINT 单参数真实写入闭环。


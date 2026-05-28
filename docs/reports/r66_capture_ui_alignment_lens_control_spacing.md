# R66 Capture UI Alignment and Lens Control Spacing

## 1. 改动摘要

- 将顶部状态栏中的比例 / 像素按钮从中间位置移到闪光灯按钮右侧，形成统一的左侧工具起点。
- 优化 AE-L / 焦段 / MF 取景控制组的拥挤感：四焦段设备下缩小 AE-L / MF 与焦段按钮宽度，保留焦段为主控、AE-L / MF 为辅助控件的层级。
- 本包只做拍摄页 UI 微调，未改参数系统、MF runtime、AE-L runtime、镜头 zoom、白底和拍后流程。

## 2. 文件清单

- `SellerCamera/CaptureScreen.swift`
  - 调整 `CaptureTopStatusBar` 顶部按钮顺序。
  - 调整 `CaptureLensControlStrip` 的焦段控制组 spacing 和 dense mode 尺寸。
- `docs/reports/r66_capture_ui_alignment_lens_control_spacing.md`
  - 新增本报告。
- `docs/reports/r66_capture_ui_alignment_lens_control_spacing.json`
  - 新增结构化报告。
- `README.md`
  - 更新 R66 报告索引。

## 3. 顶部比例按钮对齐说明

- 原布局为：闪光灯 / spacer / 比例像素 / spacer / 后摄 / 更多。
- 新布局为：闪光灯 / 比例像素 / spacer / 后摄 / 更多。
- 这样比例按钮与闪光灯按钮形成同一个左侧工具组，不再漂浮在顶部中间。
- 顶部外层 padding 未改，仍保留原有安全区和边缘留白。

## 4. 焦段区拥挤原因判断

- 当前取景控制组为 AE-L + 动态焦段 + MF。
- 在四焦段设备上，默认宽度约为 `AE-L + 13/24/48/77 + MF`，所有胶囊在同一 HStack 内时容易显得连续堆叠。
- 拥挤核心不是功能冲突，而是四焦段状态下辅助控件和焦段主控缺少层级分离。

## 5. 焦段区布局优化方案

- 保持同一行，不新增第二层或大面板。
- 将焦段按钮包入内部 HStack，AE-L / MF 作为左右辅助控件。
- 四焦段及以上时启用 dense mode：
  - AE-L / MF 最小宽度由 48pt 调整为 42pt。
  - 焦段按钮最小宽度由 58pt 调整为 50pt。
  - 焦段内部 spacing 由 7pt 调整为 5pt。
  - AE-L / MF 与焦段主组保留 10pt 外侧间距，视觉上从连续堆叠变为辅助-主控-辅助。
- 少焦段设备保持更宽松尺寸，避免显得过散。

## 6. 小屏 / 多焦段适配说明

- 四焦段设备使用 dense mode，降低总宽度压力。
- 两到三焦段设备保留原有较宽按钮，避免空旷。
- 不隐藏任何焦段，不删除 AE-L 或 MF。
- 未改变焦段显示的设备能力驱动逻辑。

## 7. 功能合同保护说明

- AE-L 点击行为未改。
- MF 进入 / 退出、MF ruler 展开逻辑未改。
- 焦段切换与 lens zoom ruler 未改。
- EV / WB / TINT / ISO / Shutter 参数逻辑未改。
- R61-R65 参数修复逻辑未改。
- 白底 pipeline 与拍后流程未改。

## 8. 构建结果

- `xcodebuild -project /Users/sungning/Projects/SellerCamera/SellerCamera.xcodeproj -scheme SellerCamera -configuration Debug -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO build`：通过。
- 构建期间仍有既有 `IDEFileReferenceDebug` 工程引用警告，但最终 `BUILD SUCCEEDED`。
- 另使用 clean DerivedData 重新构建并安装到 booted 模拟器，截图路径：`Reference/R66/r66_capture_ui_alignment_simulator_clean.png`。
- 模拟器观察：顶部比例 / 像素按钮已移动到闪光灯按钮右侧，形成同一左侧工具组；模拟器无真实镜头焦段，焦段区显示为 AE-L / 当前机型无可用镜头焦段 / MF，两侧辅助控件与中间区域已拉开。

## 9. 真机验证结果

- 本轮未运行真机。
- 仍需在真机确认：
  - 顶部比例按钮是否与闪光灯按钮视觉靠齐。
  - 四焦段 + AE-L + MF 是否不再拥挤。
  - AE-L / MF / 焦段按钮点击热区是否仍顺手。
  - MF ruler 和 lens zoom ruler 是否不受布局影响。

## 10. 风险与后续建议

- 风险：不同机型、不同焦段数量下仍需真机观察 dense mode 是否过紧或过松。
- 建议下一步只做真机视觉复验；如果仍拥挤，再考虑方案 C 的更明确三段定位，不建议直接上双层布局。

# R54 右上角“更多”面板内部操作保持打开与外部点击关闭报告

日期：2026-05-24

## 1. 背景

R53 真机验证确认 Shutter 调参后卡顿问题已修复，五参数切换恢复稳定。新的真机反馈指出：右上角“更多”里的参数在修改后会自动关闭，用户无法连续调整网格、水平仪、定时、连拍等低频设置。

本轮只修“更多”面板关闭策略，不新增功能，不改五参数、不改镜头、不改白底、不改拍后流程、不做 Focus。

## 2. 自动关闭原因

原实现使用 SwiftUI 系统 `Menu` 承载“更多”选项：

- `Menu` 的默认行为是用户点击任意菜单项后自动收起。
- 内部按钮执行 `onToggleGrid()`、`onToggleLevelIndicator()`、`onCycleTimerOption()`、`onCycleBurstOption()` 后，系统菜单会立即关闭。
- 这不是 runtime 问题，也不是五参数 inline controls 的问题，而是系统 `Menu` 组件的交互合同不符合当前产品要求。

因此本轮将右上角“更多”从系统 `Menu` 改为 Seller Camera 自有轻量 overlay 面板。

## 3. 内部点击保持打开

新增 `CaptureMoreOptionsPanel`：

- 面板内部按钮仍执行原有动作：
  - 网格开关。
  - 水平仪开关。
  - 定时档位切换。
  - 连拍档位切换。
  - 导入单张图片入口。
- 面板内部按钮不再触发 dismiss。
- 面板容器使用 `contentShape` 和空 `onTapGesture` 吃掉内部空白点击，避免冒泡到外部关闭层。

当前策略：

- 点击面板内部参数：参数生效，面板保持打开。
- 点击面板内部 toggle / option：动作生效，面板保持打开。
- 点击导入入口：仍打开系统照片选择；本轮不额外改变导入流程。

## 4. 外部点击关闭

在 `CaptureScreen` 根 `ZStack` 中增加仅在“更多”打开时出现的透明 dismiss layer：

- 位于页面内容之上。
- 位于 `CaptureMoreOptionsPanel` 之下。
- 点击面板外任意区域关闭更多面板。
- 面板关闭后 dismiss layer 不再存在，不会挡住其它控件。

关闭区域包括：

- 取景区。
- 顶部其它工具区域。
- 意图切换区域。
- 底部动作区。
- 五参数和镜头区域。

点击“更多”按钮区域在面板展开时也会落到外部 dismiss layer，因此可关闭面板。

## 5. 与五参数 / 镜头 inline controls 的互斥

本轮保持并明确互斥策略：

- 打开更多面板时，收起五参数 inline ruler。
- 打开更多面板时，收起镜头 inline ruler。
- 点击五参数入口时，关闭更多面板并进入五参数逻辑。
- 打开镜头 inline controls 时，关闭更多面板。

这样避免更多面板、五参数 ruler、镜头 ruler 三者叠层互相遮挡。

## 6. 与点击取景区 / 对焦的关系

当前推荐策略与 inline controls 一致：

- 更多面板打开时，第一次点击取景区只关闭更多面板。
- 面板关闭后，再次点击取景区执行正常点击对焦 / 测光。

本轮未改 `CaptureLivePreviewView`，未改点击对焦、长按 AE/AF Lock、双指缩放。

## 7. 修改文件

- `SellerCamera/CaptureScreen.swift`
  - 新增 `isMoreOptionsPanelPresented` 状态。
  - 将右上“更多”从系统 `Menu` 改为自有 overlay 面板入口。
  - 新增 `CaptureMoreOptionsPanel`。
  - 新增外部透明 dismiss layer。
  - 打开更多时收起五参数和镜头 inline controls。
  - 打开五参数 / 镜头 inline controls 时关闭更多面板。

- `README.md`
  - 增加 R54 报告索引。

- `docs/reports/r54_more_panel_persistent_interaction_and_outside_dismiss.md`
  - 本报告。

- `docs/reports/r54_more_panel_persistent_interaction_and_outside_dismiss.json`
  - 本轮结构化记录。

## 8. 验证

- `xcodebuild -project /Users/sungning/Projects/SellerCamera/SellerCamera.xcodeproj -scheme SellerCamera -configuration Debug -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO build`
  - 结果：通过。

- `python3 -m json.tool /Users/sungning/Projects/SellerCamera/docs/reports/r54_more_panel_persistent_interaction_and_outside_dismiss.json`
  - 结果：通过。

真机仍需确认：

- 更多面板内连续切换网格、水平仪、定时、连拍时是否保持打开。
- 点击面板外是否关闭。
- 点击面板内部空白是否不会关闭。
- 点击取景区关闭后是否不误触对焦。
- 五参数 inline controls 和镜头 inline controls 是否未回归。

## 9. 边界

本轮没有：

- 新增 Focus 或让 Focus 回到底部栏。
- 修改 EV / WB / TINT / ISO / Shutter runtime 合同。
- 修改镜头 zoom runtime 合同。
- 修改白底图处理 pipeline。
- 修改拍后 Review / Save / Generate 流程。
- 重构 CaptureScreen。
- 大改更多面板视觉体系。

## 10. 遗留风险

- 当前更多面板为自有 overlay，不再使用系统 `Menu`；需要真机确认 panel 位置、遮挡和手势优先级是否符合预期。
- 打开更多时点击拍摄按钮区域会先关闭面板，不直接拍摄；这是为了避免设置面板打开时误触拍摄。
- 导入入口会触发系统照片选择，是否需要点击后主动关闭更多面板，可在后续真机体验中决定。

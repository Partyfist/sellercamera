# R56 独立 Focus 状态胶囊 + AF / MF / LOCK 最小 UI 骨架报告

日期：2026-05-24

## 1. 背景

R55 已完成独立 Focus 前置核查，明确 Focus 不回到底部五参数栏，后续应作为围绕取景区工作的独立对焦系统。

当前正式底部五参数仍为：

```text
EV / WB / TINT / ISO / S
```

本轮进入最小 UI 骨架阶段，只新增 Focus 状态胶囊和只读 Focus 面板骨架：

- 不新增 Manual Focus ruler。
- 不新增新的 lensPosition 写入。
- 不调用新的 `setManualFocusLensPosition(_:)` 路径。
- 不改变 `restoreAutofocusMode()`。
- 不改变点击对焦和长按 AE/AF Lock。
- 不改变五参数、镜头、更多、白底、拍后流程。

## 2. 实现范围

本轮新增：

- 取景区边缘 Focus 状态胶囊。
- Focus 胶囊状态映射：`LOCK > MF > AF`。
- Focus 小面板骨架。
- Focus 面板与五参数 / 镜头 / 更多面板互斥。
- 点击取景区关闭 Focus 面板。

本轮没有：

- 不做真实 MF 交互。
- 不做 MF 横向 ruler。
- 不新增 Focus runtime 写入。
- 不把 Focus 放回底部五参数栏。

## 3. Focus 胶囊位置

Focus 胶囊接入在 `CapturePreviewContainer` 内，位于取景区边缘、镜头焦段入口上方附近。

当前策略：

- 以取景 workspace 为参考定位。
- 优先放在左下边缘区域。
- 避开底部五参数栏。
- 避开镜头焦段入口中心区域。
- 不进入 `EV / WB / TINT / ISO / S`。

遗留：

- 胶囊是否遮挡具体商品主体，需要真机截图继续确认。
- 小屏和商品靠左下摆放时，可能需要进一步微调位置。

## 4. Focus 状态映射

新增 `CaptureFocusStatusPresentation`，只读取现有 runtime 状态。

状态优先级：

```text
LOCK > MF > AF
```

映射规则：

- `cameraRuntime.isFocusExposureLocked == true`
  - 显示 `LOCK`
  - 面板标题显示 `AE/AF-L`
  - 强调色使用克制琥珀色
- `cameraRuntime.focusControlMode == .manual`
  - 显示 `MF`
  - 面板标题显示 `Manual Focus`
  - 显示当前为手动对焦状态，但不提供本轮写入
- 其它情况
  - 显示 `AF`
  - 面板标题显示 `Auto Focus`

注意：

- 当前 `AE-L` 独立曝光锁不被映射为 Focus `LOCK`，因为本轮 Focus LOCK 语义指向 AE/AF Lock。
- 本轮没有新增轮询，也没有新增 runtime 状态。

## 5. Focus 面板骨架

新增 `CaptureFocusStatusPanel`。

面板内容：

- 标题：`Focus`
- 当前状态：`Auto Focus` / `Manual Focus` / `AE/AF-L`
- 三个状态项：
  - `AF`：轻触画面对焦与测光
  - `MF`：手动微调后续接入 / 当前镜头不支持手动对焦
  - `LOCK`：长按取景区锁定 AE/AF
- 当前状态说明文案

交互策略：

- 点击 Focus 胶囊打开 / 关闭面板。
- 面板内部点击不关闭，也不写 runtime。
- 面板只是只读骨架，不做 AF / MF / LOCK 按钮切换。

## 6. 互斥关系

本轮新增 `isFocusPanelPresented`，并接入现有关闭路径。

### 与五参数控制台

- 打开 Focus 面板时，关闭五参数 inline controls。
- 点击五参数时，关闭 Focus 面板并进入对应参数。
- Focus 不进入底部五参数栏。

### 与镜头 zoom ruler

- 打开 Focus 面板时，关闭镜头 zoom ruler。
- 打开镜头 zoom ruler 时，关闭 Focus 面板。
- Focus 面板不写 zoom。
- 镜头调节不写 Focus。

### 与更多面板

- 打开 Focus 面板时，关闭更多面板。
- 打开更多面板时，关闭 Focus 面板。
- R54 更多面板“内部操作保持打开”合同未改变。

### 与取景区点击

- Focus 面板打开时，点击取景区先关闭 Focus 面板。
- 同一次点击不执行对焦，保持当前 inline controls 的退出策略。
- Focus 面板关闭后，再点击取景区执行原有点击对焦 / 测光。

## 7. 手势保护

本轮未改 `CaptureLivePreviewView` 的手势逻辑。

保持：

- 点击取景区仍走原有 `handlePreviewTap(...)`。
- 长按取景区仍走原有 `handlePreviewLongPress(...)`。
- 双指缩放仍走原有 `MagnificationGesture` 与 zoom runtime。

Focus 胶囊只是一层取景区边缘按钮，不接管长按或双指手势。

## 8. 修改文件

- `SellerCamera/CaptureScreen.swift`
  - 新增 `isFocusPanelPresented`。
  - 新增 Focus 胶囊与 Focus 面板骨架。
  - 新增 Focus 状态展示映射。
  - 接入 Focus 面板与五参数 / 镜头 / 更多互斥。
  - 接入点击取景区关闭 Focus 面板。

- `README.md`
  - 增加 R56 报告索引。

- `docs/reports/r56_independent_focus_status_capsule_and_panel_skeleton.md`
  - 本报告。

- `docs/reports/r56_independent_focus_status_capsule_and_panel_skeleton.json`
  - 本轮结构化记录。

## 9. 构建验证

已执行：

```bash
xcodebuild -project /Users/sungning/Projects/SellerCamera/SellerCamera.xcodeproj -scheme SellerCamera -configuration Debug -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO build
```

结果：通过。

已执行：

```bash
python3 -m json.tool /Users/sungning/Projects/SellerCamera/docs/reports/r56_independent_focus_status_capsule_and_panel_skeleton.json
```

结果：通过。

## 10. 真机验证情况

本轮尚未运行真机。

仍需真机确认：

- Focus 胶囊是否遮挡商品主体。
- AF / MF / LOCK 显示是否符合真实状态。
- Focus 面板打开 / 关闭是否顺手。
- 与五参数 / 镜头 / 更多互斥是否符合预期。
- 点击对焦、长按锁定、双指缩放是否无回归。

## 11. 边界确认

本轮没有：

- 把 Focus 加回 `EV / WB / TINT / ISO / S`。
- 新增 Manual Focus ruler。
- 新增真实 MF 写入。
- 调用新的 `setManualFocusLensPosition(_:)` 路径。
- 改变 `restoreAutofocusMode()`。
- 改变 EV / WB / TINT / ISO / Shutter 合同。
- 改变镜头 zoom runtime。
- 改变更多面板持久交互。
- 改变白底与拍后流程。

## 12. 遗留风险

- 胶囊位置需要真机微调，尤其是小屏和商品主体靠左下的构图。
- 当前面板是只读骨架，用户可能期待 MF 可点击；下一包需要进一步明确 AF / MF / LOCK 的交互语义。
- LOCK 状态依赖 `isFocusExposureLocked`，不包含单独 AE-L；这是本轮有意保持的 Focus 语义边界。

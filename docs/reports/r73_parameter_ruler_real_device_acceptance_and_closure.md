# R73 参数表盘真机体验验收与收口修复报告

## 1. 改动摘要

R73 在 R72 专业刻度密度与齿轮手感升级基础上，做了一次代码级验收与最小收口修复。五参数通用横向 ruler 已具备密刻度、边界消费、方向切换、慢速微调、Shutter 惯性与 haptic 节流，本轮没有重写该主线。

本轮实际修复集中在仍使用独立手势实现的 Lens zoom ruler 与 Manual Focus ruler：补齐上拉慢速微调灵敏度、方向切换 cooldown 重置、边界 / cooldown 位移消费、触感反馈节流。这样可以降低 Lens / MF 与五参数通用 ruler 的手感差异，避免密刻度下出现反向回退阻力或连续震动。

本轮未改白底、拍后、保存、Review / Compare、相册、AI 修图、镜头 zoom runtime、曝光写入主链路、WB / ISO / Shutter / EV / TINT 功能合同。

## 2. 文件清单

- `SellerCamera/CaptureScreen.swift`
  - 调整 `CaptureManualFocusRulerPanel` 的 drag consumption、fine scrubbing 与 haptic 节流。
  - 调整 `CaptureZoomDialView` 的 drag consumption、方向切换、fine scrubbing 与 haptic 节流。
- `docs/reports/r73_parameter_ruler_real_device_acceptance_and_closure.md`
  - 新增 R73 验收与收口报告。
- `README.md`
  - 增加 R73 报告索引。

## 3. R72 后现状核查

五参数通用 ruler 已具备以下能力：

- WB：50K tick、500K 主刻度、AUTO takeover 与 pending manual 优先显示已在前序包收口。
- TINT：内部 1 单位 tick，视觉主刻度仍按 5 倍数表达。
- EV：保持曝光补偿语义，受 ISO / Shutter 手动状态限制，不进入 ISO / Shutter runtime。
- ISO：保持设备能力范围与 R66 safe clamp 保护。
- Shutter：保留 activeFormat 全范围能力、商品拍摄常用快门锚点、selected / pending / committed / readback 分离、双向拖拽与惯性逻辑。
- Lens：R72 已有 0.1x tick，但手势层仍是独立实现，本轮补齐微调与 haptic 节流。
- MF：R60 后为 0.025 tick，R72 后为 0.01 显示 / 调节粒度；本轮补齐微调与 haptic 节流。

## 4. 本次修复内容

本轮只做两类最小修复：

1. 独立 ruler 微调统一：Lens 与 MF 支持上拉降低灵敏度，40pt 以上进入 fine，90pt 以上进入 ultra fine，与五参数通用 ruler 保持一致。
2. 独立 ruler 触感与残留收口：Lens 与 MF 在 cooldown / 边界场景下先消费手势位移，方向切换时重置 cooldown，并对 light haptic 做签名与时间节流。

## 5. 参数逐项验收

### 5.1 WB

代码级验收：WB 仍走 `CaptureHorizontalParameterRuler` 通用路径，保留 50K tick、500K 主刻度、AUTO takeover 与 pending manual 优先显示。R73 未改 WB runtime、AUTO、RESET 或拖拽逻辑。

需要真机复核：从低 K 到高 K 再回退、AUTO 首滑、慢速微调落点。

### 5.2 Lens

代码级验收：Lens zoom 仍按 0.1x 生成 tick，major anchors 仍保留 0.5x / 1x / 2x / 3x / 5x / 10x / 15x 语义。本轮补齐 fine scrubbing 与 haptic throttling，避免密 tick 下回退阻力和连续触感。

需要真机复核：快速滑动、常用倍率附近吸附感、预览是否稳定。

### 5.3 ISO

代码级验收：ISO 未改动，继续保留设备合法范围和 R66 safe clamp 保护。R73 未改 ISO Auto / Manual、半自动曝光规则或写入节流。

需要真机复核：低到高再回退、高 ISO 边界、R66 崩溃保护。

### 5.4 Shutter

代码级验收：Shutter 未改动，继续保留 R69 全范围能力、R70 常用快门锚点、R71A 双向拖拽 / selected 分离 / 惯性逻辑。R73 未改 AVFoundation 写入、quantize 或 clamp。

需要真机复核：1/30 到 1/250 来回、快速跨档、惯性结束吸附、readback 是否不抢拖拽。

### 5.5 EV

代码级验收：EV 未改动，继续保持曝光补偿语义；ISO 或 Shutter 手动时 EV 受半自动曝光规则限制，不静默写入 runtime。

需要真机复核：ISO / S Auto 时 EV 正负调节，ISO 或 S Manual 时 EV LOCK 表达。

### 5.6 Focus / MF

代码级验收：MF 不回到底部五参数栏，仍使用 `setManualFocusLensPosition(_:)` 与 `restoreAutofocusMode()` 既有路径。本轮只调整 MF ruler 的手势灵敏度与 haptic 节流，不改 AF / MF / LOCK 状态机。

需要真机复核：MF 0 到 100 来回、上拉微调、退出 MF 后 AF 恢复、LOCK 下不可写。

## 6. 刻度密度验收

代码级验收结果：

- 五参数通用 ruler 主 / 次刻度层级保留，当前值浮窗与中心指针未改。
- Lens tick 继续 0.1x，视觉标签仅显示常用 anchor，不显示每个 tick 文案。
- MF tick 保持细粒度，视觉标签仅显示 0 / 25 / 50 / 75 / 100，避免标签拥挤。

本轮没有继续加密刻度，避免 R72 后因密度继续提高造成不可控。

## 7. 惯性滑动验收

代码级验收结果：

- Shutter 继续使用 R71A 的 inertia final commit 逻辑。
- 五参数通用 ruler 的 Shutter 惯性未改。
- Lens / MF 本轮没有新增复杂惯性，避免在 zoom / focus runtime 上引入写入风暴；仅收口手势消费与微调。

真机仍需验证 Shutter 快速滑动的自然减速与最终吸附。

## 8. 磁吸 / Snap 验收

代码级验收结果：

- WB / TINT / Shutter / ISO / EV 的 snap 语义沿用现有 tick 与 anchor 策略。
- Lens 用 0.1x tick 和常用 anchor 标签表达轻量停靠。
- MF 保持连续微调优先，不强制吸附到少数位置。

本轮没有新增强制 snap，避免密刻度下出现来回抖动。

## 9. 慢速微调验收

已实现收口：

- 五参数通用 ruler 已支持上拉 40pt / 90pt 的 fine / ultra fine 灵敏度。
- Lens zoom 本轮补齐相同规则。
- MF ruler 本轮补齐相同规则。

预期效果：普通贴近轨道拖动保持快速，手指上拉后降低横向步进速度，便于密刻度下逐格微调。

## 10. Haptic 触感反馈验收

已实现收口：

- 五参数通用 ruler 已按参数、selected index、step 签名节流。
- Lens zoom 本轮改为 light impact，并加入签名与 0.08s 时间节流。
- MF ruler 本轮改为 light impact，并加入签名与 0.09s 时间节流。

这样可以避免快速滑动时连续密集震动，同时保留关键 tick 变化的齿轮感。

## 11. Auto / Manual / Lock 状态验收

代码级验收结果：

- R73 未改变 Auto / Manual / Lock 派生规则。
- LOCK / disabled 状态下，Lens / MF drag 仍由 `isEnabled` guard 阻断。
- MF 的 AF / MF / LOCK 状态机、EV 的半自动曝光限制、ISO / Shutter 的 Auto / Manual 关系均未改动。
- 表盘消失时 Lens / MF 都会清理 drag offset 与方向状态，避免旧手势残留。

## 12. 构建与运行验证

已执行：

```bash
xcodebuild -scheme SellerCamera -project SellerCamera.xcodeproj -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/SellerCameraR73Build CODE_SIGNING_ALLOWED=NO clean build
```

结果：`BUILD SUCCEEDED`。

备注：构建开始阶段 Xcode 输出了一个历史嵌套工程引用警告，路径为 `SellerCamera/SellerCamera.xcodeproj` 且缺少 `project.pbxproj`，但根工程 `SellerCamera.xcodeproj` 正常完成 clean build。

真机运行：本轮 Codex 环境未确认可连接真机，R73 报告中不宣称真机已跑通。真机体验项仍需在实际设备上复核。

## 13. 风险与未完成项

- R73 对 Lens / MF 做了代码级手感收口，但真实触感强弱、上拉微调阈值是否最优仍需真机验证。
- Shutter 惯性、selected/readback 对齐未在本轮改动，仍依赖 R71A 的实现；若真机仍有回退卡顿，需要单独根据日志定位。
- Lens zoom 没有新增复杂惯性，避免 zoom 写入风暴；如果真机反馈需要“更像飞轮”，建议另包只针对 Lens 做低风险惯性提交策略。
- MF 没有新增 snap 到关键位置，保留连续对焦优先；如果用户需要实体齿轮感更明显，可后续增加可配置主刻度 haptic。

## 14. 后续建议

下一包建议只做真机反馈型微调：

1. 用真机逐项验证 WB / Lens / ISO / Shutter / EV / MF 的双向拖动与触感。
2. 如果 Lens 或 MF 微调阈值过强或过弱，只调整 `40pt / 90pt` 阈值或 haptic 节流时间。
3. 如果 Shutter 仍有惯性或 readback 抢焦点问题，基于 `[CaptureShutterWheel]` / `[CaptureExposureReadback]` 日志单独修复，不扩大到其它参数。

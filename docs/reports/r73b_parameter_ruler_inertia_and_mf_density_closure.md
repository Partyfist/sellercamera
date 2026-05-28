# R73B 参数表盘惯性统一与 MF 精细化收口报告

## 1. 改动摘要

R73B 在 R73A 已验证的拖动灵敏度基础上做小步增强：提高 MF 表盘密度、让 MF 未进入手动写入前以 0.5 作为视觉中点，并为五参数通用 ruler、Lens ruler、MF ruler 增加轻量惯性收尾。

本包没有改动 runtime 写入接口语义，没有改白底、拍后、保存、Review / Compare、镜头 zoom 底层或曝光三角规则。

## 2. 文件清单

- `SellerCamera/CaptureScreen.swift`
  - MF ruler tick 从 0.01 收细到 0.005。
  - MF 非 manual 且无 pending 时使用 0.5 作为 UI 默认中点，不在打开时写入 runtime。
  - Lens / MF 独立 ruler 增加轻量 predicted-end 惯性收尾。
  - 保留 R73A normal / fine / ultraFine 灵敏度分层。

- `SellerCamera/CaptureBottomParameterBar.swift`
  - 五参数通用横向 ruler 增加按参数分级的轻量惯性。
  - 保留 fine / ultraFine 下的精准微调，避免上拉微调时额外惯性。
  - 保留 haptic 节流、边界消费、方向切换 baseline 重置。

- `docs/reports/r73b_parameter_ruler_inertia_and_mf_density_closure.md`
  - 新增本报告。

- `README.md`
  - 增加 R73B 报告索引。

## 3. 真机反馈问题

真机反馈显示 R73A 后默认拖动速度已经改善，但仍有三点需要收口：

- MF 表盘密度仍偏粗，不利于商品细节对焦。
- MF ruler 打开时需要默认视觉停在中间，避免用户一打开就感觉偏向一端。
- 所有参数滑动都需要有轻量惯性，而不是只有 Shutter 更接近专业滚轮。

## 4. MF 密刻度调整

MF 仍保持 `lensPosition` 的 `0.0...1.0` 正式语义，未改变 `setManualFocusLensPosition(_:)` 的调用路径。

本次将 MF ruler 内部 tick 从 `0.01` 收细到 `0.005`，让手动对焦的可控空间更密。视觉标签仍保持克制，继续以关键刻度表达，不把每个细 tick 都显示为文字，避免 UI 变成密集标尺墙。

## 5. MF 默认居中策略

MF 显示值优先级调整为：

1. `pendingManualFocusPosition`
2. runtime 已处于 manual focus 时的 `currentManualFocusPosition`
3. 否则使用 `0.5` 作为 UI 默认中点

这个 `0.5` 只用于视觉初始锚点。打开 MF ruler 时不会自动调用 `setManualFocusLensPosition(0.5)`，避免一打开 MF 就造成焦点跳变。用户第一次拖动后才进入既有 manual focus 写入路径。

## 6. 全参数惯性方案

五参数通用 ruler 现在在普通拖动结束时根据 `predictedEndTranslation` 做一次轻量惯性收尾。

惯性强度按参数分级：

- Shutter：保留较明显惯性，最大 5 step。
- WB / ISO：medium-light，最大 3 step。
- TINT：较轻，最大 2 step。
- EV：最克制，最大 1 step。

Lens 独立 ruler 增加轻量惯性，最大 2 step。MF 独立 ruler 增加 very light 惯性，最大 1 step。

fine / ultraFine 模式下不触发惯性，确保上拉微调仍用于精准落点，而不是产生额外飞轮。

## 7. 惯性取消与 runtime 节流

本次没有新增连续物理飞轮，也没有新增高频定时写入。惯性只在 drag ended 时做一次受限 step commit，继续复用现有 `onWheelStep` / `onStep`、pending、clamp、runtime 去重与节流路径。

风险控制：

- 面板消失时调用 `finishDrag(..., animateOffset: false)`，清理 drag offset 与本地拖动状态。
- fine / ultraFine 不触发惯性。
- 边界处 `onStep` 返回失败时不触发 haptic。
- haptic 仍使用已有签名与时间节流，避免密集震动。
- LOCK / disabled 继续依赖现有 `isEnabled` / `state.isAdjustable` 保护，不新增绕过路径。

## 8. 参数逐项验收

### 8.1 WB

WB 开启轻量惯性，最大 3 step。Kelvin tick、AUTO takeover、WB/TINT 合同未改。惯性只走现有 step 写入，边界 clamp 与 R65/R61 后的输入保护不回退。

### 8.2 ISO

ISO 开启轻量惯性，最大 3 step。仍由 R66 的 ISO safe clamp 保护，不扩大 activeFormat 能力范围，不改 ISO Auto / Manual 语义。

### 8.3 Shutter

Shutter 保留已有惯性主线与 R69/R70/R71A 的全范围、锚点、双向拖拽修复。本次只统一到 common ruler 的分级惯性配置，最大 5 step，不改 custom exposure 写入主链路。

### 8.4 EV

EV 仅开启最克制的惯性，最大 1 step。R68 半自动曝光下的 EV LOCK / 禁写规则未改，手动 ISO / Shutter 下不会通过惯性绕过锁定。

### 8.5 Lens

Lens 独立 ruler 增加 light 惯性，最大 2 step。保留 R73A normal 2.2x、fine / ultraFine 微调与镜头 zoom 写入路径，不做连续飞轮，避免预览抖动。

### 8.6 MF

MF tick 收细到 0.005，并在非 manual / 无 pending 时默认视觉居中到 0.5。MF 惯性最大 1 step，只作为 very light 收尾；打开 ruler 不写入 0.5，恢复 AF 仍由既有 MF 胶囊路径处理。

## 9. R73A 灵敏度保留情况

R73A 的灵敏度分层保留：

- 五参数 normal 仍为 1.8x。
- Lens normal 仍为 2.2x。
- MF normal 仍为 2.0x。
- 上拉 40pt 进入 fine、90pt 进入 ultraFine 的微调语义保留。

R73B 只在 drag ended 后追加轻量惯性收尾，没有把 normal 拖动速度调回变慢。

## 10. 构建与运行验证

已执行：

```bash
xcodebuild -scheme SellerCamera -project SellerCamera.xcodeproj -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/SellerCameraR73BBuild CODE_SIGNING_ALLOWED=NO clean build
```

结果：`BUILD SUCCEEDED`

构建过程中仍出现项目既有的 nested project reference 警告：

- `SellerCamera/SellerCamera.xcodeproj` 缺少 `project.pbxproj`

该警告未阻塞根工程构建，本包未修改该历史引用。

本轮未执行真机安装运行，MF 居中、MF 密刻度和全参数轻量惯性仍需真机手感复核。

## 11. 风险与真机待复核项

待真机重点复核：

- MF 打开时是否视觉居中且不跳焦。
- MF 0.005 tick 是否足够细，同时不产生对焦抖动。
- WB / ISO / EV 的轻量惯性是否自然，不过度。
- Lens 惯性是否不引发预览抖动。
- Shutter 既有双向拖拽和惯性是否不回退。
- 参数切换、Auto、Reset、LOCK 后是否无残留惯性写入。

如真机反馈某类参数惯性过强，建议下一包只按参数调整 `inertiaScale` / `inertiaMaximumStepCount`，不要扩成新的手势系统。

# R77C 焦段手动调节流畅度收口与拍摄稳定器设置报告

## 1. 改动摘要

R77C 在 R77B 的 virtual multi-camera 与 zoom target 基础上，继续收口焦段手动 ruler 的拖动手感，并在“更多设置”中接入第一版稳定器设置：

- 焦段按钮继续使用 `ramp(toVideoZoomFactor:withRate:)`，保持点击 13 / 24 / 48 / 77mm 的平滑过渡。
- 焦段 ruler 拖动改为 UI 即时响应 + device direct zoom throttling，不再把每个拖动 tick 都作为 ramp 请求。
- 焦段 ruler 增加连续 zoom mapping、轻量 smoothing、锚点吸附、松手 settle 与轻量惯性。
- virtual switch-over factor 附近增加 hysteresis，降低 1.99x / 2.01x 一类反复写入导致的组成镜头来回切换风险。
- “更多设置”新增“稳定器”设置，提供关闭 / 标准 / 增强三档并持久化。
- 稳定器按公开 `AVCaptureConnection.preferredVideoStabilizationMode` 接入，设备不支持时静默降级。
- 稳定器开启时，拍照前根据 zoom / focus / lens switching 状态做短暂 settle wait，超时后继续拍摄，避免快门无响应。

本轮未改 ISO / Shutter / WB / EV / MF 参数语义，未改白底、拍后 Review / Save，也未进入 RAW 保存闭环。

## 2. 文件清单

- `SellerCamera/CaptureLivePreviewView.swift`
  - 新增 `CaptureStabilizerMode`。
  - 新增焦段 ruler direct zoom 写入、30Hz 节流、switch-over hysteresis 与 Debug 日志。
  - 新增稳定器持久化、connection stabilization 应用与拍照前稳定等待。
  - 预览 layer connection 同步应用稳定器模式。
- `SellerCamera/CaptureScreen.swift`
  - 将焦段 zoom dial 从 step-based 调节改为连续 value-based 调节。
  - 增加 zoom mapping smoothing、锚点吸附、轻量惯性和 haptic 节流。
  - 在更多设置面板增加“稳定器”入口。
- `README.md`
  - 增加 R77C 报告索引。

## 3. 焦段 ruler 手动调节收口

R77B 后，焦段按钮和 ruler 都走 ramp，按钮体验更接近原生相机，但手动拖 ruler 时仍容易出现“拖一格、等一格”的迟滞感。

R77C 后：

- `CaptureZoomDialView` 从离散 `onStep` 改为连续 `onValueChanged` / `onValueSettled`。
- 拖动开始时调用 `beginLensZoomRulerInteraction()`，取消未完成 zoom ramp，避免 ramp 与手指拖动抢控制权。
- 拖动过程中 UI 使用连续 value 立即更新。
- runtime 写入通过 `setLensZoomDialValueFromRuler(_:isFinal:)` 进入 direct `videoZoomFactor` 写入路径。
- device 写入频率限制在约 30Hz，避免每个 tiny drag delta 都 lock device。
- 松手时通过 `endLensZoomRulerInteraction(finalDialValue:)` 提交最终 zoom target。

## 4. zoom 映射与手感

本轮保留 13 / 24 / 48 / 77mm UI 语义，但将 ruler 手感改为更连续的 zoom factor 语义：

- 0.5x / 1x / 2x / 3x 作为商品拍摄常用锚点。
- 0.5x 到 3x 区间保持更细腻的拖动映射。
- 3x 以上降低灵敏度，避免高倍区轻微拖动就过度放大。
- 拖动中使用轻量 smoothing，减少手指微抖直接传递到 device zoom。
- `roundedLensZoomTarget` 使用 0.02x 目标粒度，显示仍保留简洁 0.1x 文案。

## 5. 锚点吸附、惯性与 haptic

R77C 增加的是轻量“滚轮手感”，不是失控飞轮：

- 拖动经过 0.5x / 1x / 2x / 3x 附近时做轻微 soft snap。
- 松手时如果接近锚点，final settle 到锚点。
- 快速拖动松手时使用 capped predicted translation，额外惯性距离受限。
- fine / ultra-fine 手势灵敏度下不启用明显惯性。
- haptic 只在锚点附近触发，并带时间和签名节流，避免连续震动。

## 6. virtual switch-over 保护

本轮继续尊重 R77B 的 virtual multi-camera 优先策略，不手动强切 physical device。

新增保护：

- 读取当前 device 的 `virtualDeviceSwitchOverVideoZoomFactors`。
- 拖动中如果 target zoom 靠近 switch-over factor，且当前 zoom 已在该区间附近，则临时 hold 当前 zoom。
- final settle 不使用 hysteresis hold，避免松手后无法到达用户目标。
- Debug-only 日志输出 `switchOverHysteresis=true`、requested zoom、held zoom 与 switch factor。

目标是降低 switch-over 临界区反复写入导致的组成镜头来回跳动，而不是屏蔽系统自己的 virtual device 切换能力。

## 7. 稳定器设置

“更多设置”新增：

- 稳定器 关闭
- 稳定器 标准
- 稳定器 增强

默认值为“标准”，使用 `UserDefaults` 持久化。

映射策略：

- 关闭：`.off`
- 标准：`.auto`
- 增强：优先请求 `.cinematic`

如果 connection 不支持 video stabilization，仅 Debug 记录并静默降级，不影响预览或拍照。

## 8. 拍照前稳定等待

稳定器开启时，`captureSinglePhoto()` 在实际 capture 前执行短暂 settle wait：

- 关闭：不等待。
- 标准：最多约 200ms。
- 增强：最多约 450ms。

等待条件：

- 最近刚写入 zoom。
- 当前 device 正在 zoom ramp。
- 当前 device 正在 adjusting focus。
- 当前处于镜头切换稳定窗口。

等待循环每约 45ms 重新检查一次，超过最大等待时间立即继续拍摄，避免快门长时间无响应。本轮不修改最终保存流程、不恢复快速预览、不影响左下最近照片入口。

## 9. R77 / R77A / R77B 回归保护

本轮未改：

- WB / TINT / ISO / Shutter 底部实时显示。
- R77A 点击对焦状态机与四角对焦框。
- R77B virtual multi-camera 优先设备选择。
- 焦段按钮 ramp 行为。
- 近距 focus fallback 主链路。
- ISO / Shutter / WB / EV / MF 参数写入语义。
- 取消拍后快速预览。
- 左下最近照片入口。
- Review / Compare / Save。
- 白底处理链路。
- 最佳 / RAW 像素入口。

## 10. 构建与运行验证

已执行：

```bash
xcodebuild -scheme SellerCamera -project SellerCamera.xcodeproj -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/SellerCameraR77CBuild CODE_SIGNING_ALLOWED=NO clean build
```

结果：

- `BUILD SUCCEEDED`

真机验证：

- 本轮未执行真机安装与焦段拖动实测。
- 仍需在多摄真机上验证 ruler 拖动是否更连续、switch-over 附近是否减少跳动、稳定器 active mode 是否符合设备支持能力，以及拍照前 settle wait 是否无感。

## 11. 风险与后续建议

风险：

- `preferredVideoStabilizationMode` 对预览 connection 与 photo connection 的实际效果由设备和系统决定，部分设备可能仅支持 `.auto` 或实际 active mode 与 requested mode 不一致。
- switch-over hysteresis 是保守保护，真机上仍需根据 `[CaptureLensZoom]` 日志校准 hysteresis 宽度。
- direct zoom 写入比 ramp 更跟手，但如果真机 device lock 成本偏高，可能需要继续调低写入频率或进一步合并 pending target。

建议：

- R77D 用 iPhone 14 Pro Max 或更新多摄设备采集 0.5x / 1x / 2x / 3x 附近拖动日志，校准 anchor threshold 与 switch-over hysteresis。
- 在稳定器标准 / 增强下做同一商品的手持对比拍摄，观察包装文字边缘清晰度与快门响应延迟。
- 后续如要做“防抖优先曝光策略”，应单独任务包处理，不与本轮稳定器 UI 混在一起。

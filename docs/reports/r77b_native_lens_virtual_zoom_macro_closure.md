# R77B 原生式镜头系统收口报告

## 1. 改动摘要

R77B 将后置镜头链路从“优先物理镜头切换”收口为“虚拟多摄优先 + 连续 zoom 优先”的最小实现：

- 后摄设备选择优先 `builtInTripleCamera` / `builtInDualWideCamera` / `builtInDualCamera`，不可用时回退物理 wide / ultra-wide / tele。
- 保留 13mm / 24mm / 48mm / 77mm UI 入口，但在虚拟多摄设备上将其解释为 zoom target，而不是优先重建 session input。
- 焦段按钮与焦段 ruler 通过 `ramp(toVideoZoomFactor:withRate:)` 平滑过渡。
- 点击对焦 timeout 后新增一次性近距辅助 fallback：在非 MF、非 AE/AF lock、非拍摄受限状态下，回到稳定 1x/虚拟近距路径并重新 AF。
- “最佳质量”拍摄使用当前 `photoOutput.maxPhotoQualityPrioritization` 允许的最高质量优先级。
- 增加 Debug-only 镜头设备、zoom、macro fallback 日志。

## 2. 文件清单

- `SellerCamera/CaptureLivePreviewView.swift`
  - 调整后置设备 discovery / resolve 顺序。
  - 新增 virtual lens profile 语义。
  - 将虚拟焦段选择改为 zoom target + ramp。
  - 新增近距对焦 fallback 与镜头 Debug 日志。
  - 补齐最佳质量 photo priority 上限保护。
- `README.md`
  - 增加 R77B 报告索引。

## 3. 当前镜头策略判断

R77A 前代码已枚举 virtual multi-camera device，但默认后置初始化仍传入 `.builtInWideAngleCamera`，焦段 profile 也以 physical / derived 为主。

R77B 后：

- `resolveCamera(position: .back)` 优先选择 virtual multi-camera。
- `buildLensProfiles(position: .back)` 在 virtual device 存在时生成 `virtual-13` / `virtual-24` / `virtual-48` / `virtual-77`。
- virtual profile 的 `baseZoomFactor` 分别对应约 0.5x / 1x / 2x / 3x target。
- virtual 不可用时保留原 physical / derived profile fallback。

## 4. 虚拟多摄优先说明

优先级：

1. `builtInTripleCamera`
2. `builtInDualWideCamera`
3. `builtInDualCamera`
4. `builtInWideAngleCamera`
5. `builtInUltraWideCamera`
6. `builtInTelephotoCamera`

Debug 日志：

- `[CaptureLensDevice]` 输出 active device、device type、switch-over factors、min/max zoom、当前 zoom、UI focal。
- `[CaptureLensZoom]` 输出 zoom reason、target、actual、ramped、switch-over factors。

## 5. 焦段按钮与连续 zoom

点击 13mm / 24mm / 48mm / 77mm：

- virtual device 可用时，不重建 session input。
- 更新 selected semantic focal。
- 使用 `setZoomFactor(..., ramped: true)` 平滑过渡。
- 让系统 virtual device 在 switch-over 区间自行选择组成镜头。

焦段 ruler：

- virtual device 下 ruler 使用绝对 `videoZoomFactor` 范围。
- 物理 fallback 下仍沿用原本局部 lens multiplier。

## 6. 近距商品微距 fallback

触发条件：

- 点击对焦 timeout / warning。
- 当前为后摄。
- 非 MF。
- 非 AE-L / AEAF-L。
- 非拍摄中 / 倒计时 / 连拍 / 快速预览限制。
- 非 77mm 手动长焦入口。
- 支持 virtual multi-camera 或存在 ultra wide。
- cooldown 满足 5 秒。

行为：

- 内部轻量提示“近距辅助对焦”。
- ramp 到稳定 1x / virtual close-focus path。
- 约 0.22 秒后对原点击位置重新触发 AF / AE。
- 不连续抽焦，不在锁定或手动对焦时抢控制权。

## 7. 暗光与对焦不稳定保护

本轮没有新增用户可见镜头推荐，也没有强制弹窗。

已做的保护：

- 对焦 timeout 时，如果处于高 zoom / 不稳定路径，近距 fallback 回到更稳定的 virtual 1x 区间。
- `setZoomFactor` 仍尊重拍摄中、倒计时、连拍、快速预览等限制。
- 77mm 用户明确入口下不自动改为近距 fallback。

后续如需更主动的暗光选镜，可基于 ISO / shutter / sharpness 指标做 R77C 小包。

## 8. 最佳质量策略

`captureSinglePhoto()` 不再直接假设 `.quality` 可用，而是根据 `photoOutput.maxPhotoQualityPrioritization` 选择：

- `.quality`
- `.balanced`
- `.speed`

本轮不做 RAW 文件保存闭环，不影响普通 800 / 1200 / 1600 / 2400 输出。

## 9. R77 / R77A 回归保护

本轮未改：

- 底部 WB / TINT / ISO / Shutter 实时显示逻辑。
- R77A 四角点击对焦框视觉。
- 取消拍后快速预览。
- 左下最近照片入口。
- Review / Compare / Save。
- 白底处理链路。
- RAW UI 入口。
- ISO / Shutter / WB / MF / EV 参数写入语义。

## 10. 构建与运行验证

已执行：

```bash
xcodebuild -scheme SellerCamera -project SellerCamera.xcodeproj -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/SellerCameraR77BBuild CODE_SIGNING_ALLOWED=NO clean build
```

结果：

- `BUILD SUCCEEDED`

真机验证：

- 本轮未执行真机安装与镜头切换实测。
- 需要在 iPhone 14 Pro Max 或多摄真机上验证 switch-over factors、13/24/48/77mm 平滑性、近距 fallback 是否改善包装文字/边缘清晰度。

## 11. 风险与后续建议

风险：

- AVFoundation virtual device 的 zoom factor 语义与 Apple 原生 Camera App 私有成像管线并不完全一致，13mm 的实际 target 会被设备 `minAvailableVideoZoomFactor` clamp。
- 微距 fallback 第一版以稳定 1x/virtual path 为主，不等同于系统 Camera App 的完整 macro pipeline。
- 暗光保护本轮只在对焦不稳定路径介入，没有做主动高 zoom 降级策略。

建议：

- R77C 用真机日志校准 `[CaptureLensDevice]` / `[CaptureLensZoom]` 输出，确认各机型 switch-over factors。
- 对近距样本做固定拍摄对比：R77A vs R77B vs 原生相机。
- 如 13mm 在 virtual device 上被 clamp 后观感不符合预期，再按机型区分 display zoom 与 actual zoom。

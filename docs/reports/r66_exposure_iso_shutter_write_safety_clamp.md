# R66 Exposure ISO / Shutter Write Safety Clamp

## 1. 改动摘要

- 修复真机 `NSRangeException` 崩溃风险：所有 `setExposureModeCustom(duration:iso:)` 调用前统一经过当前 `AVCaptureDevice.activeFormat` 的 ISO / duration 安全夹取。
- 新增 Debug-only `[CaptureExposureWrite]` 日志，记录 raw ISO、safe ISO、activeFormat min/max ISO、raw duration、safe duration 和修正原因。
- 本包只改自定义曝光写入安全闸门，未改 UI 布局、WB 修复逻辑、MF / AF / LOCK、镜头 zoom、白底和拍后流程。

## 2. 文件清单

- `SellerCamera/CaptureLivePreviewView.swift`
  - 新增 `sanitizedCustomExposureWrite(...)`。
  - 新增 ISO / duration 有效性检查和 Debug 日志。
  - 将所有 custom exposure 写入点改为先 sanitize 再写入。
- `docs/reports/r66_exposure_iso_shutter_write_safety_clamp.md`
  - 新增本报告。
- `docs/reports/r66_exposure_iso_shutter_write_safety_clamp.json`
  - 新增结构化报告。
- `README.md`
  - 更新 R66 崩溃保护报告索引。

## 3. 崩溃原因判断

- 崩溃来自 `AVCaptureDevice.setExposureModeCustom(duration:iso:)` 收到超出当前 `activeFormat.minISO ... activeFormat.maxISO` 的 ISO。
- 代码里部分路径虽然先做了 clamp，但随后又做 ISO 量化，量化后的值仍可能越过 `maxISO`。
- Shutter 路径和点击对焦保持手动曝光路径直接带入 `device.iso`，当切镜头或 activeFormat 变化后，`device.iso` 也可能不适配当前 activeFormat。
- 因此必须在真正调用 AVCaptureDevice 前统一做最终安全夹取，不能只依赖 UI tick 或上游状态。

## 4. custom exposure 写入点列表

- ISO preset 写入：`applyISOPreset(.low/.medium/.high)`。
- ISO custom 写入：`applyISOPreset(.custom)`。
- Shutter preset 写入：`applyShutterPreset(.s1_30/.s1_60/.s1_120/.s1_250/.s1_500)`。
- Shutter custom 写入：`applyShutterPreset(.custom)`。
- 点击对焦时保留手动 Shutter：`tapFocusPreserveShutter`。
- 点击对焦时保留手动 ISO：`tapFocusPreserveISO`。

## 5. ISO clamp 说明

- 写入前读取当前设备 `device.activeFormat.minISO` 与 `device.activeFormat.maxISO`。
- `rawISO` 若为 `NaN`、infinite 或 `<= 0`，回退到当前 `device.iso`，仍无效则回退到 `minISO`。
- 最终 `safeISO = min(max(rawISO, minISO), maxISO)`。
- 如果 ISO range 本身无效，则跳过 custom exposure 写入并输出 Debug 日志，避免崩溃。

## 6. Shutter duration clamp 说明

- 写入前读取当前 `device.activeFormat.minExposureDuration` 与 `maxExposureDuration`。
- `rawDuration` 若无效、非正或非 finite，回退到当前 `device.exposureDuration`，仍无效则回退到 `minExposureDuration`。
- 最终 duration 会夹取在当前 activeFormat 支持范围内。
- 量化后的 duration 也会再次通过最终 sanitize 闸门，避免量化带出边界。

## 7. 镜头切换 activeFormat 保护说明

- 所有写入都在 sessionQueue 中拿当前 `currentVideoInput?.device` 并读取当前 `device.activeFormat`。
- 不再信任旧 UI tick、旧 published min/max、旧 pending 或旧 `device.iso` 直接写入。
- 切镜头或切 activeFormat 后，即使上游仍带旧 ISO，最终写入也会按当前 activeFormat 重新夹取。

## 8. ISO / Shutter 联动保护说明

- 调 ISO 时携带的当前 duration 会被 sanitize。
- 调 Shutter 时携带的当前 ISO 会被 sanitize。
- 点击对焦保持手动 Shutter / ISO 时，随带的另一个曝光参数也会被 sanitize。
- 不再只保护用户正在调的参数，而是保护最终组合写入。

## 9. Debug 日志说明

Debug 构建会输出：

`[CaptureExposureWrite] context=... rawISO=... safeISO=... minISO=... maxISO=... rawDuration=... safeDuration=... reason=...`

常见 reason：

- `normal`
- `invalidISO`
- `clampedISO`
- `invalidDuration`
- `clampedDuration`
- `skippedInvalidISORange`
- `skippedInvalidDurationRange`

Release 行为不受日志影响。

## 10. 功能合同保护说明

- EV / WB / TINT / ISO / Shutter 合同未改。
- WB AUTO 首滑修复逻辑未改。
- MF / AF / LOCK 未改。
- 镜头 zoom runtime 未改。
- 白底 pipeline 和拍后流程未改。
- 本包只保证 AVCaptureDevice 自定义曝光写入永远先通过当前硬件能力边界。

## 11. 构建结果

- `xcodebuild -project /Users/sungning/Projects/SellerCamera/SellerCamera.xcodeproj -scheme SellerCamera -configuration Debug -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO build`：通过。
- 构建期间仍有既有 `IDEFileReferenceDebug` 工程引用警告，但最终 `BUILD SUCCEEDED`。

## 12. 真机验证结果

- 本轮未运行真机。
- 仍需真机验证：
  - ISO 从 Auto 到手动并滑到高 ISO 边界不崩溃。
  - Shutter 从 Auto 到手动并滑到两端不崩溃。
  - 切换 13mm / 24mm / 48mm / 77mm 后立刻调 ISO / Shutter 不崩溃。
  - Debug 日志中超范围 rawISO 会被 safeISO 夹取。

## 13. 风险与后续建议

- 风险：如果某些设备 activeFormat 在切换瞬间返回短暂异常范围，当前策略会跳过 custom exposure 写入并给出日志；需要真机日志确认是否发生。
- 建议下一步优先真机跑 ISO / Shutter / 焦段切换组合压测，确认没有 `NSRangeException` 且日志显示夹取正常。

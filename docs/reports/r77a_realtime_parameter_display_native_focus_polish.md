# R77A 拍摄参数实时显示与原生级点击对焦优化报告

## 1. 改动摘要

R77A 在 R77 基础上继续收口拍摄基础体验：

- 底部参数入口补齐 WB / TINT / ISO / Shutter 的实时值显示，使其不再只显示 `A`。
- 点击对焦 timeout 从 1.45s 收紧到 1.15s，文案改为更短的“对焦中 / AF 稳定 / 对焦偏慢”。
- 点击 AF 成功稳定后，安全状态下回到 `continuousAutoFocus`，更接近原生相机的持续微调体验。
- 对焦框从普通完整圆角矩形 + 大勾，升级为四角短线式专业对焦框。
- 增加 Debug-only `[CaptureTapFocus]` 日志，便于真机排查点按对焦响应。

## 2. 文件清单

- `SellerCamera/CaptureScreen.swift`
  - 更新底部 WB / TINT / ISO / Shutter 实时值显示。
  - 更新参数面板入口显示文本，使 Auto 状态也展示当前 runtime 数值。
- `SellerCamera/CaptureLivePreviewView.swift`
  - 调整点击对焦 settle / timeout。
  - 对焦稳定后安全恢复 continuous AF。
  - 增加 `[CaptureTapFocus]` Debug 日志。
  - 重做 `CaptureFocusMarkerOverlay` 为四角对焦框。
- `docs/reports/r77a_realtime_parameter_display_native_focus_polish.md`
  - 本报告。
- `README.md`
  - 增加 R77A 报告索引。

## 3. 底部参数实时显示

底部五参数入口现在按以下规则显示：

- EV：保持现有 `A+0.5` / `+0.5` 风格。
- WB Auto：显示 `A 5200K` 这类实时色温。
- WB Manual：显示 `5200K`。
- TINT：显示 `0` / `+3` / `-2` 这类偏移值。
- ISO Auto：显示 `A 125` 这类 runtime ISO。
- ISO Manual：显示 `125`。
- Shutter Auto：显示 `A 1/120`。
- Shutter Manual：显示 `1/120`。

如果 runtime 值不可用，仍按 `A` / `--` / 最近值回退，不引入崩溃路径。

本轮没有新增大块 UI，也没有重构底部参数栏，只更新现有 `valueText` 派生。

## 4. 点击对焦优化

点击取景区后仍立即进入 `focusing`，但 R77A 做了三点收口：

- `tapFocusSettleDelay` 调整为 0.32s；
- `tapFocusTimeout` 调整为 1.15s；
- 对焦稳定后，在非 MF / 非 LOCK 状态下恢复 `.continuousAutoFocus`，保留点按对焦后的原生相机微调体验。

点击对焦继续保护：

- MF 模式；
- AE-L；
- AEAF-L；
- 手动 ISO；
- 手动 Shutter；
- ISO + Shutter 全手动。

## 5. 对焦框视觉升级

新对焦框采用四角短线式设计：

- `focusing`：琥珀黄色四角框 + 内层轻提示点；
- `focused`：青绿色四角框 + 极小状态点；
- `warning`：琥珀色四角框 + 小空心点；
- `locked`：四角框 + 小锁图标；
- `unlocked`：蓝色四角框 + 小开锁图标。

对焦框尺寸保持约 84pt，角线长度 18pt，线宽约 1.6-1.9pt。取消大勾与完整矩形，降低对商品主体遮挡。

## 6. Debug 日志

新增 Debug-only `[CaptureTapFocus]` 日志，记录：

- source；
- devicePoint；
- normalizedPoint；
- focusMode；
- isAdjustingFocus；
- lensPosition；
- ISO；
- shutter；
- AE-L 状态；
- ISO / Shutter auto-manual 状态；
- timeout；
- continuous AF 恢复结果。

Release 不输出这些日志。

## 7. R77 回归保护

本轮没有改变：

- 拍后快速预览取消逻辑；
- 左下最近照片入口；
- Review / Generate / Save；
- “最佳 / RAW”入口；
- RAW 文件保存边界；
- Auto EV / Auto WB；
- ISO / Shutter / WB / MF / EV 参数写入；
- 白底处理链路。

## 8. 构建与运行验证

已执行：

```bash
xcodebuild -scheme SellerCamera -project SellerCamera.xcodeproj -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/SellerCameraR77ABuild CODE_SIGNING_ALLOWED=NO clean build
```

结果：

- `BUILD SUCCEEDED`
- 构建期间仍有既有的嵌套 `SellerCamera/SellerCamera.xcodeproj` 缺少 `project.pbxproj` 提示，但根工程 target 构建成功。

真机运行：

- 本轮未执行真机安装 / 实拍验证。
- 底部实时参数显示、点击对焦速度、包装文字清晰度和四角对焦框视觉仍需真机复核。

## 9. 风险与后续建议

风险：

- 对焦稳定判断仍基于 `AVCaptureDevice.isAdjustingFocus`，接近原生相机但不是系统相机内部同款算法。
- Auto 状态实时值依赖 runtime 回写；个别设备如短时读不到 ISO / shutter，会回退为 `A` 或 `--`。
- 对焦稳定后恢复 continuous AF 需要真机观察近距商品场景是否有轻微二次微调。

建议下一轮最小验证：

- R77B：真机拍摄固定商品，验证底部参数实时显示、对焦框视觉、点击对焦清晰度和 continuous AF 回稳体验。

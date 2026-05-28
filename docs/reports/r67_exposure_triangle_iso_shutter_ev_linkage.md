# R67 Exposure Triangle Linkage: ISO / Shutter / EV

## 1. Background

R66 closed the runtime crash risk around ISO and shutter custom exposure writes by clamping values before `AVCaptureDevice.setExposureModeCustom`. R67 focuses on the semantic relationship between EV, ISO, and Shutter:

- EV is exposure compensation under the auto-exposure path.
- ISO and Shutter are manual exposure controls.
- When ISO or Shutter is manual, EV should no longer appear as an active brightness control.

## 2. Scope

This package only changes exposure-control state handling and guards:

- EV availability when ISO / Shutter are Auto or Manual.
- EV UI state when manual exposure is active.
- EV action/runtime guards to prevent exposure-bias writes during manual exposure.
- Debug-only exposure-triangle logs.

No WB, TINT, Focus/MF, lens zoom, white-background, or post-capture behavior was intentionally changed.

## 3. Current Exposure State Audit

### Existing behavior before R67

- ISO manual write already blocks Shutter manual adjustment through the existing ISO/Shutter lock contract.
- Shutter manual write already blocks ISO manual adjustment through the existing ISO/Shutter lock contract.
- EV could still present as adjustable even when ISO or Shutter had moved into a manual/custom exposure path.
- Runtime EV writes call the auto-exposure bias path and can switch ISO/Shutter presets back to Auto, which is semantically confusing after a user takes manual exposure control.

### Necessary states

- `selectedISOPreset`
- `selectedShutterPreset`
- `pendingISOWheelValue`
- `pendingShutterWheelDurationSeconds`
- `pendingExposureBiasWheelValue`
- `isExposureBiasAutoMode`

### R67 derived state

`isExposureCompensationLimitedByManualExposure` is derived from manual or pending ISO/Shutter state. It is not a new runtime mode; it only gates EV UI and actions.

## 4. Linkage Rules

| ISO | Shutter | EV |
| --- | --- | --- |
| Auto | Auto | Enabled |
| Manual or pending manual | Auto | LOCK / Limited |
| Auto | Manual or pending manual | LOCK / Limited |
| Manual | Manual / locked by existing contract | LOCK |

When ISO and Shutter both return to Auto and no manual pending state remains, EV automatically becomes available again. R67 does not reset the existing EV value during this recovery.

## 5. EV LOCK / Limited Behavior

When manual exposure limits EV:

- Bottom EV value displays `LOCK`.
- EV selection shows a short hint instead of opening the ruler.
- EV ruler drag is ignored and does not create pending EV state.
- EV RESET / Auto control is blocked.
- Ruler control kind switches to `LOCK` when EV is locked.

Hints distinguish the primary cause:

- Manual ISO active: restore ISO Auto before adjusting EV.
- Manual Shutter active: restore Shutter Auto before adjusting EV.
- General manual exposure active: restore ISO / Shutter Auto before adjusting EV.

## 6. Runtime Write Protection

`CaptureCameraRuntime` now blocks exposure-bias writes while ISO or Shutter is manual:

- `cycleExposureBias()` returns with a hint.
- `setExposureBiasDialValue(_:)` returns with a hint.
- `applyExposureBiasAuto()` returns with a hint.
- Private `setExposureBias(_:switchesToManual:)` also contains the same guard as a defensive runtime-side safety net.

This prevents `setExposureTargetBias` from being called while manual ISO/Shutter exposure is active.

## 7. R66 Clamp Regression Protection

R67 does not modify `sanitizedCustomExposureWrite(...)` or the custom exposure write paths added in R66. ISO/Shutter writes still pass through active-format ISO and duration sanitization before `setExposureModeCustom`.

## 8. Debug Logging

R67 adds Debug-only `[CaptureExposureTriangle]` logs for relevant EV block and mode-change events:

- ISO manual / Auto transitions.
- Shutter manual / Auto transitions.
- EV selection / drag / reset blocking.
- Runtime EV write blocking.

Logs are gated by `#if DEBUG` and are not emitted in Release builds.

## 9. Modified Files

- `SellerCamera/CaptureScreen.swift`
  - Added EV manual-exposure limitation state.
  - Added EV LOCK UI/action behavior.
  - Added Debug exposure-triangle logs.

- `SellerCamera/CaptureLivePreviewView.swift`
  - Added runtime EV write guards when manual ISO/Shutter is active.
  - Added Debug exposure-triangle logs.

- `README.md`
  - Added R67 report index entry.

- `docs/reports/r67_exposure_triangle_iso_shutter_ev_linkage.md`
- `docs/reports/r67_exposure_triangle_iso_shutter_ev_linkage.json`

## 10. Functional Contract Protection

- EV remains present in the five-parameter bar.
- EV remains adjustable when ISO and Shutter are both Auto.
- WB / TINT behavior is unchanged.
- ISO / Shutter existing lock relationship is preserved.
- R66 ISO/Shutter clamp path is preserved.
- Focus/MF, lens zoom, white-background, and post-capture flows are not changed.

## 11. Validation

- JSON report parse: passed with `python3 -m json.tool`.
- xcodebuild: passed with the required Debug iOS Simulator build command.
- True-device validation: not run by Codex in this pass.

## 12. Risks and Follow-up

- The UI now intentionally makes EV unavailable during manual exposure. True-device validation should confirm the hint copy and LOCK visual are clear enough during ISO/Shutter manual tests.
- If later product direction allows EV-style compensation in a semi-auto exposure mode, that should be introduced as a separate explicit mode instead of reusing EV silently during custom exposure.

# R69 Shutter Full Range Mapping Closure

## 1. Background

After R68, true-device validation showed that Shutter could move in the UI but did not cover the full exposure duration range supported by the current `AVCaptureDevice.activeFormat`.

The issue was in the Shutter capability chain rather than the drag gesture:

- UI ticks were mostly generated from a fixed canonical shutter list.
- `activeFormat.minExposureDuration` and `activeFormat.maxExposureDuration` were appended, but the intermediate range still depended on the fixed list.
- Runtime quantization used a fixed `1/10000s` step, which could truncate very fast durations and force the final write back into a smaller range.

## 2. Scope

Implemented:

- Replaced fixed Shutter tick mapping with dynamic activeFormat-based log-scale ticks.
- Kept min/max exposure durations as explicit tick endpoints.
- Updated runtime Shutter quantization to preserve activeFormat boundaries instead of using a fixed `1/10000s` floor.
- Kept R66 `sanitizedCustomExposureWrite(...)` as the final ISO/duration safety clamp.
- Added Debug-only `[CaptureShutterRange]` logs for UI tick dispatch and runtime quantization.
- Updated README report index.

Not implemented:

- No WB, TINT, EV linkage, ISO mode, Focus/MF, lens zoom, white-background, or post-capture changes.
- No new exposure mode system.
- No UI layout change.

## 3. Current Shutter Range Diagnosis

The Shutter range was limited by two separate pieces of logic:

1. `CaptureScreen.shutterWheelDurationValues()` used a fixed canonical list from `1/8000` to `1s`, then appended device min/max. This did not create a complete tick path across device-specific ranges.
2. `CaptureLivePreviewView.quantizedShutterDuration(...)` rounded every requested duration to `1/10000s`. On devices whose fastest duration is faster than `1/10000s`, the runtime write could be quantized away from the actual minimum.

The R66 clamp prevented crashes, but clamp alone cannot make the UI/ruler mapping cover the full device range.

## 4. activeFormat Dynamic Range

The runtime already refreshes Shutter capability from:

- `device.activeFormat.minExposureDuration`
- `device.activeFormat.maxExposureDuration`

R69 keeps these values as the single source of truth for the Shutter UI range. When camera/lens/format capability state refreshes, the published min/max seconds update and the Shutter ruler regenerates from those values.

## 5. Tick Mapping

Shutter ticks now use a log-scale 1/3-stop generator:

- Starts at the current activeFormat maximum duration.
- Steps down by `pow(2, 1/3)`.
- Ends at the current activeFormat minimum duration.
- Explicitly keeps min/max as endpoints.
- Adds current runtime/manual durations for stable selection alignment.

This keeps the ruler usable across wide ranges such as `1/8000` to `1s+` without compressing most ticks into one end.

## 6. Duration Quantize Fix

Runtime quantization no longer uses a fixed `1/10000s` step.

The new runtime path:

- Clamps the requested duration to the current device activeFormat range.
- Rebuilds the duration with a high precision timescale.
- Leaves final safety validation to R66 `sanitizedCustomExposureWrite(...)`.

This avoids quantization eating the fastest supported duration while preserving crash protection.

## 7. UI Display

Existing Shutter display formatting remains:

- `< 1s`: `1/xxx`
- `>= 1s`: `1.0s`, `2.0s`, etc.

Because tick values and runtime writes now share the same activeFormat-backed duration range, the displayed tick is aligned with the runtime target.

## 8. Lens / activeFormat Updates

When the current camera device or activeFormat updates, `updateShutterCapabilityState(with:)` refreshes:

- `minimumShutterDurationSeconds`
- `maximumShutterDurationSeconds`
- current runtime duration
- current manual duration fallback

The UI ruler derives ticks from those published values, so switching lenses/formats no longer depends on stale fixed preset ranges.

## 9. Debug Logging

Added Debug-only `[CaptureShutterRange]` logs:

- UI dispatch log includes min/max, mapped tick index, target duration, and display text.
- Runtime quantization log includes min/max, requested duration, and quantized duration.

Logs are guarded by `#if DEBUG` and do not affect Release behavior.

## 10. R66 / R68 Regression Protection

- R66 ISO/duration safety clamp remains in place.
- R68 EV/ISO/Shutter semi-auto linkage was not modified.
- WB AUTO first-drag, Focus/MF, lens zoom, white-background, and post-capture paths were not changed.

## 11. Modified Files

- `SellerCamera/CaptureScreen.swift`
  - Replaced fixed Shutter tick list with dynamic log-scale activeFormat tick generation.
  - Added UI-level `[CaptureShutterRange]` dispatch logging.

- `SellerCamera/CaptureLivePreviewView.swift`
  - Updated Shutter duration quantization to preserve activeFormat boundaries.
  - Added runtime `[CaptureShutterRange]` quantization logging.

- `README.md`
  - Added R69 report index entry.

## 12. Validation

- JSON report parse: passed with `python3 -m json.tool`.
- xcodebuild: passed with the required Debug iOS Simulator build command.
- True-device validation: not run by Codex in this pass.

## 13. Risks and Follow-up

True-device validation is required to confirm that each device/lens activeFormat exposes the expected min/max range and that `AVCaptureDevice` accepts the full range without additional hardware-side rounding. If the device runtime still limits duration after custom exposure writes, the next step should be a log-backed true-device range readback pass, not another UI-only change.

# R70 Shutter Ruler Interaction Mapping Fix

## 1. Background

R69 restored activeFormat-based Shutter min/max mapping and removed fixed `1/10000s` runtime quantization. True-device logs then showed that hardware range and runtime writes were basically working, but the ruler still felt unstable:

- Tick density was too low across large activeFormat ranges.
- Common product-photography shutter values were not reliable stopping points.
- Adjacent internal durations could share the same display string such as `1/16`.
- Duplicate guards used broad duration tolerance and could skip legitimate neighboring ticks.
- Selected value and runtime readback needed clearer Debug tracing.

## 2. Scope

Implemented:

- Increased Shutter ruler generation from 1/3-stop to 1/6-stop log ticks.
- Injected product-photography shutter anchors inside the activeFormat range.
- Preserved activeFormat min/max endpoints, pending duration, runtime duration, and manual duration.
- Replaced broad duplicate duration skip with tick-index plus high-precision duration identity checks.
- Added readback Debug logs for target/readback delta.
- Updated README report index.

Not implemented:

- No WB, ISO, EV, Focus/MF, lens zoom, white-background, post-capture, or page layout changes.
- No new exposure engine or parameter framework.

## 3. Tick Mapping Fix

The Shutter ruler still uses current activeFormat min/max as the capability boundary.

R70 changes the interior tick distribution:

- Before: 1/3-stop log ticks.
- After: 1/6-stop log ticks.

Ticks are filtered for finite positive durations, clamped to the current activeFormat range, deduplicated by nanosecond identity, and sorted from slow to fast for the existing ruler direction.

## 4. Product Shutter Anchors

R70 injects these common product-photography anchors when they are inside the activeFormat range:

- `1/30`
- `1/33`
- `1/48`
- `1/50`
- `1/60`
- `1/96`
- `1/100`
- `1/120`
- `1/125`
- `1/200`
- `1/240`
- `1/250`
- `1/500`
- `1/1000`
- `1/2000`
- `1/4000`
- `1/8000`

These are stopping anchors only. They do not replace activeFormat min/max and do not define the hardware range.

## 5. Duplicated Tick Fix

The previous Shutter duplicate guard could skip writes when two neighboring durations displayed the same rounded string or were within a broad duration tolerance.

R70 only skips a duplicated Shutter write when all are true:

- The last dispatched tick index matches the target tick index.
- The target duration delta is below a small identity epsilon.
- There is no pending Shutter write.

This allows adjacent internal ticks with the same visible label to still dispatch, reducing the "dragged but value did not move" feeling.

## 6. Readback Logging

R70 adds/expands Debug-only logs:

- `[CaptureShutterRange]` now includes `tickCount`, `mappedTick`, `targetDuration`, and display text when dispatching UI writes.
- `[CaptureExposureReadback]` logs target duration, device readback duration, delta, display, and confirmation reason.
- Existing `[CaptureExposureWrite]` continues to log raw and safe duration through the R66 clamp path.

All logs are gated by `#if DEBUG`.

## 7. R66 / R68 / R69 Regression Protection

- R66 `sanitizedCustomExposureWrite(...)` remains the final ISO/duration safety guard.
- R68 exposure triangle semi-auto rules were not changed.
- R69 activeFormat min/max boundary mapping remains in place.
- WB AUTO first-drag, MF/AF/LOCK, lens zoom, white-background, and post-capture paths were not modified.

## 8. Modified Files

- `SellerCamera/CaptureScreen.swift`
  - Increased Shutter tick density to 1/6 stop.
  - Injected common product-photography Shutter anchors.
  - Tightened duplicate tick skip logic.
  - Added readback Debug logging.

- `README.md`
  - Added R70 report index entry.

## 9. Validation

- JSON report parse: passed with `python3 -m json.tool`.
- xcodebuild: passed with the required clean Debug generic iOS command.
- True-device validation: not run by Codex in this pass.

## 10. Risks and Follow-up

The device may still round applied exposure duration internally. If true-device readback remains visually sticky, compare `[CaptureShutterRange]`, `[CaptureExposureWrite]`, and `[CaptureExposureReadback]` logs to determine whether the remaining mismatch is UI selection, runtime write, or device-side rounding.

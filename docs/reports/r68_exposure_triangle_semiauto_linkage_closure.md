# R68 Exposure Triangle Semi-Auto Linkage Closure

## 1. Background

R67 made EV unavailable while ISO or Shutter was manual, but the existing ISO/Shutter mutual locks made the exposure triangle feel over-constrained:

- Manual ISO locked Shutter.
- Manual Shutter locked ISO.
- EV remained locked whenever ISO or Shutter was manual.

R68 changes the linkage to a simpler semi-auto exposure model:

- EV is available only when ISO and Shutter are both Auto.
- Manual ISO locks EV but does not lock Shutter.
- Manual Shutter locks EV but does not lock ISO.
- Manual ISO + Manual Shutter is full manual exposure and EV remains locked.

## 2. Scope

Implemented:

- Removed UI-level ISO lock caused by manual Shutter.
- Removed UI-level Shutter lock caused by manual ISO.
- Removed runtime guard that blocked ISO writes while Shutter was manual.
- Removed runtime guard that blocked Shutter writes while ISO was manual.
- Kept R67 EV lock while ISO or Shutter is manual.
- Kept R66 ISO/Shutter custom exposure clamp.
- Added Debug-only exposure triangle logs for ISO/Shutter drag and Auto restore.

Not implemented:

- No M/A/S/P mode system.
- No exposure mode picker.
- No WB/TINT, Focus/MF, lens zoom, white-background, or post-capture changes.

## 3. R67 Over-Mutual-Exclusion Cause

The over-lock came from two layers:

1. `CaptureScreen.swift` derived `isoBlockedByShutter` and `shutterBlockedByISO`, then used them to set ISO or Shutter to `.locked`.
2. `CaptureLivePreviewView.swift` rejected ISO writes when Shutter was not Auto, and rejected manual Shutter writes when ISO was not Auto.

This made the UI behave like only one of ISO or Shutter could be manually adjusted, which is too restrictive for the intended Seller Camera semi-auto workflow.

## 4. R68 Semi-Auto Rules

| ISO | Shutter | EV |
| --- | --- | --- |
| Auto | Auto | Enabled |
| Manual | Auto | LOCK |
| Auto | Manual | LOCK |
| Manual | Manual | LOCK |

ISO and Shutter no longer lock each other in the UI. Exposure lock states still lock both controls when AE-L / AEAF-L is active.

## 5. EV LOCK Rules

R67 EV protection remains:

- EV displays `LOCK` when ISO or Shutter is manual or pending manual.
- EV selection shows a short hint instead of opening the ruler.
- EV drag does not write runtime while ISO or Shutter is manual.
- Runtime `setExposureTargetBias` is blocked while ISO or Shutter is manual.

## 6. ISO Behavior

R68 allows ISO to remain adjustable even when Shutter is manual.

- ISO can enter Manual from Auto.
- ISO can return to Auto.
- Shutter no longer causes ISO to display LOCK.
- AE-L / AEAF-L still locks ISO.

## 7. Shutter Behavior

R68 allows Shutter to remain adjustable even when ISO is manual.

- Shutter can enter Manual from Auto.
- Shutter can return to Auto.
- ISO no longer causes Shutter to display LOCK.
- AE-L / AEAF-L still locks Shutter.

## 8. Runtime EV Write Protection

The EV runtime guard remains intentionally narrow:

- If ISO or Shutter is manual, EV writes are blocked.
- If ISO and Shutter are both Auto, EV writes are allowed.
- EV itself does not lock ISO or Shutter.

## 9. Debug Logging

`[CaptureExposureTriangle]` Debug-only logs now include ISO/Shutter actions:

- `action=isoDrag`
- `action=isoAuto`
- `action=shutterDrag`
- `action=shutterAuto`
- `isoMode=auto/manual`
- `shutterMode=auto/manual`
- `evState=enabled/locked`

The logs are gated by `#if DEBUG` and do not affect Release behavior.

## 10. R65 / R66 Regression Protection

- R65 WB AUTO first-drag logic was not modified.
- R66 `sanitizedCustomExposureWrite(...)` and all custom exposure clamp paths were not modified.
- No lens zoom, Focus/MF, white-background, or post-capture paths were changed.

## 11. Modified Files

- `SellerCamera/CaptureScreen.swift`
  - Removed ISO/Shutter mutual UI locks.
  - Updated ISO/Shutter hint function inputs.
  - Added semi-auto exposure Debug logs.

- `SellerCamera/CaptureLivePreviewView.swift`
  - Removed runtime ISO/Shutter mutual block guards.
  - Kept EV runtime lock under manual ISO/Shutter.

- `README.md`
  - Added R68 report index entry.

## 12. Validation

- JSON report parse: passed with `python3 -m json.tool`.
- xcodebuild: passed with the required Debug iOS Simulator build command.
- True-device validation: not run by Codex in this pass.

## 13. Risks and Follow-up

AVFoundation custom exposure writes require both duration and ISO. R68 removes the product-level lock so users can continue adjusting ISO and Shutter, but true independent ISO-manual-with-shutter-auto or shutter-manual-with-ISO-auto behavior may still be constrained by the device runtime. True-device validation should confirm whether the current user-facing semi-auto model matches hardware behavior closely enough.

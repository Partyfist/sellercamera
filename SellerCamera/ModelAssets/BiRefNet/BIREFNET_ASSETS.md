# BiRefNet Model Assets (Feasibility Boundary)

This folder is used only for **BiRefNet feasibility preparation** in Seller Camera.  
It is **not** admission-level evaluation data.

## Current landed asset

- Source: `onnx-community/BiRefNet_lite-ONNX`
- File: `onnx/BiRefNet_lite_model_fp16.onnx`
- Size: `114,538,221` bytes
- SHA-256: `d39b897ceb16ae654c1731f3dba0cf9b368d9cae74b5a57459b455cc8bfec402`

## Intended runtime target

- Preferred Core ML compiled resource for Seller Camera bridge:
  - `BiRefNetSegmentation.mlmodelc`

## R03 status

- ONNX asset is landed.
- CoreML conversion path is not yet successful in current local toolchain.
- Single-point closure check remains blocked at model-load stage (`mlmodelc_not_found`).

## R04 status

- Re-ran minimal CoreML conversion attempts on both ONNX assets:
  - `coremltools.convert(source='onnx')` (unsupported in current version)
  - `onnx-coreml` legacy path (dependency mismatch)
  - `onnx2torch -> coremltools` path (LayerNorm shape failure)
- Temporary probe used in R04:
  - `BiRefNet-general-resolution_512x512-fp16-epoch_216.onnx` was downloaded for one-shot conversion verification and then removed to keep repo-side asset footprint minimal.
- `BiRefNetSegmentation.mlmodelc` is still unavailable.
- Current status remains: **not admission-ready**.

## R06 status (RMBG-2 CoreML candidate track)

- External source (Hugging Face repo): `sihai0506/rmbg2.0-coreml`
- Landed local files:
  - `coreml/RMBG-2-native.mlpackage.zip`
  - runtime extraction path used by single-point closure: `/tmp/sellercamera_rmbg2_r06_runtime/RMBG-2-native.mlpackage`
  - runtime alias: `/tmp/sellercamera_rmbg2_r06_runtime/RMBG-2-native-int8.mlpackage -> RMBG-2-native.mlpackage`
- Notes:
  - HF current tree at commit `47999ecf...` only exposes `RMBG-2-native.mlpackage.zip`; no separate `RMBG-2-native-int8.mlpackage.zip` entry is published in repository tree API.
  - This track is treated as **BiRefNet-architecture-family CoreML candidate** for engineering closure only, not as “original BiRefNet CoreML route solved”.
- Single-point closure result:
  - status: `single_point_closure_passed`
  - pipeline: `load -> infer -> output_3 -> mask`
  - output sample: `/tmp/sellercamera_rmbg2_r06_runtime/mask.png`
- License boundary:
  - Model card declares `CC BY-NC 4.0` and requires separate authorization for commercial use.
  - Current use is strictly feasibility/runtime validation within project boundary.

## R08 status (tiny self-weight alternative track preparation)

- Candidate weight (landed):
  - `pytorch/BiRefNet-general-bb_swin_v1_tiny-epoch_232.pth`
  - size: `177,791,685` bytes
  - SHA-256: `6a1e050c6ec2697e5ed268455df544782b023acf8643ab771250979094875ab1`
- License note:
  - current repo-side record only confirms source URL and checksum; commercial/license compliance still needs explicit follow-up record before any product-level adoption claim.
- Positioning:
  - This is a **commercial-controllable alternative route candidate weight**, not an admission-ready runtime asset.
  - It does not imply “original BiRefNet CoreML route solved”.
- Preflight check:
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-birefnet-r08-tiny-preflight.json`
  - confirms weight landed + checksum matched
  - confirms current blockers for next closure package:
    - missing `pth -> onnx` export entry script
    - missing local python modules (`torch`, `onnx`, `coremltools`, `onnxruntime`)

## R09 status (tiny single-point closure)

- Export entry status:
  - `WhiteBackgroundBaseline/scripts/export_birefnet_tiny_pth_to_onnx.py` is now landed.
  - Local isolated toolchain for export was prepared in `/tmp/sellercamera_birefnet_tiny_venv`.
- Export result:
  - check: `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-birefnet-r09-tiny-export.json`
  - status: failed at `export`
  - blocker: `TypeError ... (Occurred when translating deform_conv2d)`
  - tiny ONNX artifact is still not generated.
- Single-point closure check status:
  - script: `WhiteBackgroundBaseline/scripts/birefnet_tiny_single_point_closure_check.py`
  - check: `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-birefnet-r09-tiny-single-point.json`
  - status: `model_missing` (`tiny_onnx_asset_not_found`)
- Current conclusion:
  - tiny route is **not admission-ready yet** in R09 boundary.
  - Next step (if continued) should focus on deform-conv ONNX export-layer fix only, not admission sample execution.

## R10 status (tiny export blocker fix)

- R10 target:
  - fix the single export blocker at `deform_conv2d` translation layer.
  - generate verifiable tiny ONNX artifact.
  - rerun one-shot `load -> infer -> mask` closure.
- Chosen single fix route:
  - export-time fallback: replace `DeformableConv2d.forward` with `regular_conv` only during ONNX export.
  - no main-chain runtime integration change in this package.
- Export result:
  - check: `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-birefnet-r10-tiny-export-fix.json`
  - output: `onnx/BiRefNet-general-bb_swin_v1_tiny-epoch_232.onnx`
  - size: `171,076,568` bytes
  - SHA-256: `97b75d75719ad00c295e644b76f2a2d0c7dc6bad60043154d76a25d58931a678`
- Single-point closure rerun result:
  - check: `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-birefnet-r10-tiny-single-point.json`
  - status: `single_point_closure_passed`
  - runtime output feature used: `output_image`
- Current conclusion:
  - tiny route is **ready to enter tiny admission R01 package** (pre-admission runtime qualification met).
  - this does **not** imply admission passed or replacement readiness.

## R11 status (tiny admission R01)

- Admission R01 result:
  - Vision: `26/26 failed`
  - tiny candidate: `26/26 failed`
  - dominant tiny failure: `CaptureWhiteBackgroundProcessorError code=3` (`segmentationModelUnavailable`)
- Status:
  - `stop_current_candidate` (within R11 admission boundary)
- Interpretation:
  - failure was at runtime consumption contract level, not at sample-quality comparison level.

## R12 status (tiny runtime contract reassessment, non-admission)

- Runtime contract check:
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-birefnet-r12-tiny-runtime-contract.json`
  - result: `runtime_contract_mismatch`
  - detail: runtime expects CoreML asset, current tiny artifact is `.onnx`
- Path diff check:
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-birefnet-r12-tiny-runtime-path-diff.json`
  - confirms: single-point passes on `onnxruntime`, but admission runtime uses CoreML contract (`VNCoreMLRequest`)
- Current status:
  - tiny route remains **not ready to reopen admission R01** until runtime contract is explicitly bridged.

## R13 status (tiny ORT provider minimal feasibility, non-admission)

- Scope:
  - add the smallest tiny-only ORT provider branch at `SegmentationProvider` boundary.
  - do one non-admission runtime probe close to formal provider entry.
- Runtime probe:
  - `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-birefnet-r13-tiny-ort-runtime-provider.json`
  - provider resolution: `candidate_birefnet_tiny_ort -> birefnet_tiny_ort_provider` (matched)
  - tiny ONNX asset discovery: matched
  - ORT probe inference path (`load -> infer -> mask`): passed
  - formal runtime dependency gate: `onnxruntime_objc` unavailable
- Current status:
  - tiny ORT route is still **not ready to reopen admission R01** in current project environment.
  - blocker level is runtime dependency/contract closure, not model-quality comparison.

## R14 status (tiny ORT iOS dependency closure, non-admission)

- Scope:
  - land tiny-required ORT iOS dependency in SellerCamera project.
  - verify one non-admission formal runtime provider entry (`load -> infer -> mask`).
- Runtime probe evidence:
  - records: `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/baseline-20260422-birefnet-r14-tiny-ort-runtime-probe-sim-ios26_4.jsonl`
  - check: `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-birefnet-r14-tiny-ort-runtime-probe-sim-ios26_4.txt`
  - provider check: `WhiteBackgroundBaseline/runs/whitebg-backbone-admission-v1/check-20260422-birefnet-r14-tiny-ort-ios-runtime-provider.json`
- Key runtime fields observed:
  - `segmentation_provider = birefnet_tiny_ort`
  - `segmentation_request = ORTSession(BiRefNetTinyONNX)`
  - `quality_level = ready`
- Current status:
  - tiny ORT provider route is **opened at formal iOS runtime entry** (non-admission boundary).
  - tiny route is **eligible to reopen admission R01**, pending next package execution.

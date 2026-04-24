#!/usr/bin/env python3
"""
BiRefNet tiny ORT provider runtime probe (non-admission).

This probe is intentionally minimal and boundary-safe:
- validates provider-level route assumptions
- validates tiny ONNX asset discovery contract
- reuses tiny ORT single-point inference for load->infer->mask evidence
- does NOT run admission samples
"""

from __future__ import annotations

import argparse
import json
import subprocess
import tempfile
from pathlib import Path
from typing import Any, Dict


def _resolve_provider(raw: str) -> str:
    normalized = raw.strip().lower()
    if normalized in {"birefnet_tiny_ort", "candidate_birefnet_tiny_ort", "candidate_birefnet_tiny"}:
        return "birefnet_tiny_ort_provider"
    if normalized in {"birefnet", "candidate_birefnet", "vision-birefnet"}:
        return "birefnet_coreml_provider"
    return "non_birefnet_provider"


def _probe_ort_objc_module() -> tuple[bool, str]:
    script_body = """#if canImport(onnxruntime_objc)
print("true")
#else
print("false")
#endif
"""
    with tempfile.NamedTemporaryFile(mode="w", suffix=".swift", delete=False) as handle:
        handle.write(script_body)
        script_path = Path(handle.name)
    try:
        completed = subprocess.run(
            ["xcrun", "swift", str(script_path)],
            capture_output=True,
            text=True,
            check=False,
        )
        output = (completed.stdout or "").strip().lower()
        if completed.returncode != 0:
            stderr = (completed.stderr or "").strip()
            return False, f"swift_probe_failed: {stderr or 'unknown'}"
        if output not in {"true", "false"}:
            return False, f"swift_probe_unexpected_output:{output}"
        return output == "true", "ok"
    finally:
        try:
            script_path.unlink(missing_ok=True)
        except OSError:
            pass


def _load_json(path: Path) -> Dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def _safe_load_json(path: Path) -> Dict[str, Any] | None:
    try:
        if not path.exists():
            return None
        content = path.read_text(encoding="utf-8")
        if not content.strip():
            return None
        return json.loads(content)
    except Exception:
        return None


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--provider", default="candidate_birefnet_tiny_ort")
    parser.add_argument("--model", required=True)
    parser.add_argument("--image", required=True)
    parser.add_argument("--mask-output", required=True)
    parser.add_argument("--report", required=True)
    parser.add_argument(
        "--single-point-script",
        default="WhiteBackgroundBaseline/scripts/birefnet_tiny_single_point_closure_check.py",
    )
    parser.add_argument(
        "--python-bin",
        default="python3",
        help="Python interpreter used to run single-point ORT probe",
    )
    args = parser.parse_args()

    provider_hint = args.provider
    resolved_provider = _resolve_provider(provider_hint)
    model_path = Path(args.model).resolve()
    image_path = Path(args.image).resolve()
    mask_output_path = Path(args.mask_output).resolve()
    report_path = Path(args.report).resolve()
    report_path.parent.mkdir(parents=True, exist_ok=True)

    result: Dict[str, Any] = {
        "stage": "birefnet_tiny_ort_provider_runtime_check",
        "providerHint": provider_hint,
        "resolvedProvider": resolved_provider,
        "runtimeEngine": "onnxruntime_provider_minimal",
        "singlePointEngine": "python_onnxruntime",
        "modelPath": str(model_path),
        "imagePath": str(image_path),
        "maskOutputPath": str(mask_output_path),
        "modelExists": model_path.exists(),
        "imageExists": image_path.exists(),
        "modelExtension": model_path.suffix.lower().lstrip("."),
        "expectedModelExtensions": ["onnx"],
        "providerSelected": resolved_provider == "birefnet_tiny_ort_provider",
        "assetDiscoveryOK": False,
        "ortObjCModuleAvailable": False,
        "ortObjCProbeStatus": "unknown",
        "loadAttempted": False,
        "loadSucceeded": False,
        "inferenceTriggered": False,
        "maskProduced": False,
        "status": "unknown",
        "errorStage": None,
        "error": None,
        "contractOpened": False,
        "fallbackReady": True,
        "singlePointReport": None,
    }

    if not result["providerSelected"]:
        result["status"] = "unexpected_provider"
        result["errorStage"] = "provider"
        result["error"] = "provider_not_mapped_to_birefnet_tiny_ort"
        report_path.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
        return 2

    if not model_path.exists():
        result["status"] = "model_missing"
        result["errorStage"] = "asset"
        result["error"] = "tiny_onnx_asset_not_found"
        report_path.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
        return 3

    if result["modelExtension"] not in result["expectedModelExtensions"]:
        result["status"] = "runtime_contract_mismatch"
        result["errorStage"] = "contract"
        result["error"] = f"runtime_expects_onnx_but_got_{result['modelExtension']}"
        report_path.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
        return 4

    result["assetDiscoveryOK"] = True

    ort_objc_available, ort_probe_status = _probe_ort_objc_module()
    result["ortObjCModuleAvailable"] = ort_objc_available
    result["ortObjCProbeStatus"] = ort_probe_status

    with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as handle:
        single_point_report_path = Path(handle.name)
    result["singlePointReport"] = str(single_point_report_path)

    single_point_script = Path(args.single_point_script).resolve()
    single_point_cmd = [
        args.python_bin,
        str(single_point_script),
        "--model",
        str(model_path),
        "--image",
        str(image_path),
        "--mask-output",
        str(mask_output_path),
        "--report",
        str(single_point_report_path),
    ]

    completed = subprocess.run(single_point_cmd, capture_output=True, text=True, check=False)
    single_point = _safe_load_json(single_point_report_path)
    if single_point is None:
        result["status"] = "runtime_probe_invalid"
        result["errorStage"] = "runtime_probe"
        stderr = (completed.stderr or "").strip()
        stdout = (completed.stdout or "").strip()
        result["error"] = f"single_point_report_unavailable(stderr={stderr}, stdout={stdout})"
        report_path.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
        return 5

    result["loadAttempted"] = bool(single_point.get("load_succeeded"))
    result["loadSucceeded"] = bool(single_point.get("load_succeeded"))
    result["inferenceTriggered"] = bool(single_point.get("inference_triggered"))
    result["maskProduced"] = bool(single_point.get("mask_produced"))

    if completed.returncode != 0 or single_point.get("status") != "single_point_closure_passed":
        result["status"] = "runtime_inference_failed"
        result["errorStage"] = single_point.get("error_stage") or "inference"
        result["error"] = single_point.get("error") or (completed.stderr or "single_point_runtime_failed").strip()
        report_path.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
        return 5

    if not ort_objc_available:
        result["status"] = "runtime_dependency_unavailable"
        result["errorStage"] = "runtime_dependency"
        result["error"] = "onnxruntime_objc_module_not_available_in_formal_runtime"
        result["contractOpened"] = False
        report_path.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
        return 6

    result["status"] = "runtime_contract_opened"
    result["contractOpened"] = True
    report_path.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

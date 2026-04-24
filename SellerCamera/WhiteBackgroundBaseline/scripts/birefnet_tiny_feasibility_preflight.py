#!/usr/bin/env python3
"""
BiRefNet tiny feasibility preflight checker.

Purpose:
- validate whether tiny weight asset is truly landed
- check local toolchain readiness for next single-point closure package
- output a structured JSON report (no admission execution)
"""

from __future__ import annotations

import argparse
import hashlib
import importlib
import json
from pathlib import Path
from typing import Any, Dict


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while True:
            chunk = handle.read(1024 * 1024)
            if not chunk:
                break
            digest.update(chunk)
    return digest.hexdigest()


def probe_module(name: str) -> Dict[str, Any]:
    try:
        module = importlib.import_module(name)
        return {"available": True, "version": getattr(module, "__version__", "unknown")}
    except Exception as exc:  # noqa: BLE001
        return {"available": False, "error": f"{type(exc).__name__}: {exc}"}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--weight", required=True, help="Path to tiny .pth weight")
    parser.add_argument("--report", required=True, help="Output JSON report path")
    parser.add_argument(
        "--expected-sha256",
        default="",
        help="Optional expected SHA256 for landed weight",
    )
    args = parser.parse_args()

    weight_path = Path(args.weight)
    report_path = Path(args.report)
    report_path.parent.mkdir(parents=True, exist_ok=True)

    result: Dict[str, Any] = {
        "stage": "birefnet_tiny_feasibility_preflight",
        "weight_path": str(weight_path),
        "weight_exists": weight_path.exists(),
        "weight_size_bytes": 0,
        "weight_sha256": None,
        "expected_sha256": args.expected_sha256 or None,
        "sha_match": None,
        "entrypoints": {
            "onnx_to_coreml_script_exists": False,
            "pth_to_onnx_export_script_exists": False,
        },
        "python_modules": {},
        "decision_hint": "",
        "blocking_items": [],
    }

    onnx_to_coreml_script = (
        Path(__file__).resolve().parent / "convert_birefnet_onnx_to_coreml.py"
    )
    result["entrypoints"]["onnx_to_coreml_script_exists"] = onnx_to_coreml_script.exists()

    pth_to_onnx_export_script = (
        Path(__file__).resolve().parent / "export_birefnet_tiny_pth_to_onnx.py"
    )
    result["entrypoints"]["pth_to_onnx_export_script_exists"] = pth_to_onnx_export_script.exists()

    for module_name in ("torch", "onnx", "coremltools", "onnxruntime"):
        result["python_modules"][module_name] = probe_module(module_name)

    if weight_path.exists():
        result["weight_size_bytes"] = weight_path.stat().st_size
        actual_sha = sha256_file(weight_path)
        result["weight_sha256"] = actual_sha
        if args.expected_sha256:
            result["sha_match"] = actual_sha == args.expected_sha256
    else:
        result["blocking_items"].append("weight_missing")

    if not result["entrypoints"]["onnx_to_coreml_script_exists"]:
        result["blocking_items"].append("onnx_to_coreml_entry_missing")
    if not result["entrypoints"]["pth_to_onnx_export_script_exists"]:
        result["blocking_items"].append("pth_to_onnx_entry_missing")

    for mod_name, mod_state in result["python_modules"].items():
        if not mod_state["available"]:
            result["blocking_items"].append(f"python_module_missing:{mod_name}")

    if result["weight_exists"] and not result["blocking_items"]:
        result["decision_hint"] = "ready_for_tiny_single_point_closure_package"
    else:
        result["decision_hint"] = "not_ready_yet_but_candidate_still_worth_preparing"

    report_path.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

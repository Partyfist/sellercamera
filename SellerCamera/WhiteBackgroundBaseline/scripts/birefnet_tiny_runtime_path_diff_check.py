#!/usr/bin/env python3
"""
Compare tiny single-point closure path vs admission/runtime path evidence.

This script is intentionally read-only and non-admission:
- does not run samples
- does not trigger inference
- only merges existing check/review artifacts into one diff report
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


def _load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--single-point", required=True, help="R10 tiny single-point check json")
    parser.add_argument("--admission-review", required=True, help="R11 tiny admission review json")
    parser.add_argument("--runtime-contract", required=True, help="R12 runtime contract check json")
    parser.add_argument("--report", required=True, help="Output json report")
    args = parser.parse_args()

    single_point = _load_json(Path(args.single_point).resolve())
    admission_review = _load_json(Path(args.admission_review).resolve())
    runtime_contract = _load_json(Path(args.runtime_contract).resolve())

    candidate_failure = admission_review.get("summary", {}).get("candidate", {}).get("dominant_failure", {})
    diff = {
        "stage": "birefnet_tiny_runtime_path_diff_check",
        "single_point_path": {
            "engine": "onnxruntime",
            "status": single_point.get("status"),
            "load_succeeded": single_point.get("load_succeeded"),
            "inference_triggered": single_point.get("inference_triggered"),
            "mask_produced": single_point.get("mask_produced"),
            "chosen_output_name": single_point.get("runtime", {}).get("chosen_output_name"),
        },
        "admission_runtime_path": {
            "provider": "candidate_birefnet",
            "engine": "coreml_vncoremlrequest",
            "candidate_dominant_failure_domain": candidate_failure.get("domain"),
            "candidate_dominant_failure_code": candidate_failure.get("code"),
            "candidate_dominant_failure_description": candidate_failure.get("description"),
        },
        "runtime_contract_check": {
            "status": runtime_contract.get("status"),
            "error_stage": runtime_contract.get("errorStage"),
            "error": runtime_contract.get("error"),
            "model_extension": runtime_contract.get("modelExtension"),
            "expected_model_extensions": runtime_contract.get("expectedModelExtensions"),
            "contract_opened": runtime_contract.get("contractOpened"),
        },
        "conclusion": {
            "why_single_point_passed_but_admission_failed": (
                "single-point uses ONNXRuntime and directly consumes .onnx; "
                "admission runtime uses candidate_birefnet(CoreML/VNCoreMLRequest) contract which only accepts CoreML assets."
            ),
            "runtime_contract_opened": bool(runtime_contract.get("contractOpened")),
        },
    }

    report_path = Path(args.report).resolve()
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(diff, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps(diff, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

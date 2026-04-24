#!/usr/bin/env python3
"""
Minimal conversion attempt for BiRefNet ONNX -> CoreML.

This script is intentionally small and only used for feasibility boundary checks.
It does not imply admission-level quality validation.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
from typing import Any, Dict


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--onnx", required=True, help="Path to ONNX model file")
    parser.add_argument("--out-mlpackage", required=True, help="Output CoreML .mlpackage path")
    parser.add_argument("--report", required=True, help="Output JSON report path")
    args = parser.parse_args()

    onnx_path = Path(args.onnx)
    out_mlpackage = Path(args.out_mlpackage)
    report_path = Path(args.report)
    report_path.parent.mkdir(parents=True, exist_ok=True)

    result: Dict[str, Any] = {
        "stage": "birefnet_asset_conversion_attempt",
        "onnx_path": str(onnx_path),
        "out_mlpackage": str(out_mlpackage),
        "onnx_exists": onnx_path.exists(),
        "onnx_size_bytes": onnx_path.stat().st_size if onnx_path.exists() else 0,
        "conversion_success": False,
        "converter": None,
        "error": None,
        "notes": [],
        "attempts": [],
    }

    if not onnx_path.exists():
        result["error"] = "onnx_missing"
        report_path.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
        return 2

    # Attempt 1: coremltools native convert (known to be unsupported for ONNX source in current version).
    try:
        import coremltools as ct  # type: ignore

        result["notes"].append(f"coremltools_version={ct.__version__}")
        _ = ct.converters.convert(  # type: ignore[attr-defined]
            str(onnx_path),
            source="onnx",
            convert_to="mlprogram",
            minimum_deployment_target=ct.target.iOS17,
        )
        # If this unexpectedly succeeds in future versions:
        result["conversion_success"] = True
        result["converter"] = "coremltools.convert(source=onnx)"
        result["attempts"].append({"name": "coremltools_convert", "success": True, "error": None})
    except Exception as e:  # noqa: BLE001
        result["notes"].append("coremltools_convert_failed")
        result["error"] = f"{type(e).__name__}: {e}"
        result["attempts"].append({"name": "coremltools_convert", "success": False, "error": result["error"]})

    # Attempt 2: onnx-coreml converter fallback.
    if not result["conversion_success"]:
        try:
            import onnx  # type: ignore
            from onnx_coreml import convert as onnx_coreml_convert  # type: ignore

            model = onnx.load(str(onnx_path))
            coreml_model = onnx_coreml_convert(model, minimum_ios_deployment_target="16")
            out_mlpackage.parent.mkdir(parents=True, exist_ok=True)
            coreml_model.save(str(out_mlpackage))
            result["conversion_success"] = True
            result["converter"] = "onnx-coreml"
            result["error"] = None
            result["attempts"].append({"name": "onnx_coreml_convert", "success": True, "error": None})
        except Exception as e:  # noqa: BLE001
            result["notes"].append("onnx_coreml_convert_failed")
            result["error"] = f"{type(e).__name__}: {e}"
            result["attempts"].append({"name": "onnx_coreml_convert", "success": False, "error": result["error"]})

    # Attempt 3: onnx2torch -> TorchScript -> coremltools.
    # This is still a minimal feasibility attempt and may fail on unsupported graph semantics.
    if not result["conversion_success"]:
        try:
            import onnx  # type: ignore
            import torch  # type: ignore
            import coremltools as ct  # type: ignore
            from onnx2torch import convert as onnx2torch_convert  # type: ignore

            model_proto = onnx.load(str(onnx_path))
            torch_model = onnx2torch_convert(model_proto)
            torch_model.eval()

            input_tensor = model_proto.graph.input[0]
            input_shape = []
            for dim in input_tensor.type.tensor_type.shape.dim:
                value = dim.dim_value
                input_shape.append(value if value and value > 0 else 1)
            if not input_shape:
                raise RuntimeError("onnx_input_shape_missing")
            example = torch.randn(*input_shape)

            with torch.no_grad():
                _ = torch_model(example)

            traced = torch.jit.trace(torch_model, example)
            mlmodel = ct.convert(
                traced,
                convert_to="mlprogram",
                minimum_deployment_target=ct.target.iOS17,
                inputs=[ct.TensorType(shape=example.shape)],
            )
            out_mlpackage.parent.mkdir(parents=True, exist_ok=True)
            mlmodel.save(str(out_mlpackage))

            result["conversion_success"] = True
            result["converter"] = "onnx2torch->torchscript->coremltools"
            result["error"] = None
            result["attempts"].append({
                "name": "onnx2torch_coremltools",
                "success": True,
                "error": None,
                "input_shape": input_shape,
            })
        except Exception as e:  # noqa: BLE001
            result["notes"].append("onnx2torch_coremltools_failed")
            result["error"] = f"{type(e).__name__}: {e}"
            result["attempts"].append({"name": "onnx2torch_coremltools", "success": False, "error": result["error"]})

    if result["conversion_success"]:
        result["out_exists"] = out_mlpackage.exists()
        if out_mlpackage.exists():
            if out_mlpackage.is_dir():
                total_size = 0
                for root, _, files in os.walk(out_mlpackage):
                    for file_name in files:
                        total_size += (Path(root) / file_name).stat().st_size
                result["out_size_bytes"] = total_size
            else:
                result["out_size_bytes"] = out_mlpackage.stat().st_size
    else:
        result["out_exists"] = out_mlpackage.exists()
        result["out_size_bytes"] = 0

    report_path.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
    return 0 if result["conversion_success"] else 3


if __name__ == "__main__":
    raise SystemExit(main())

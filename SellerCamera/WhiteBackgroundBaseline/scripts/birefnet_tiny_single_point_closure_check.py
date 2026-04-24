#!/usr/bin/env python3
"""
Tiny BiRefNet single-point closure checker (ONNX Runtime path).

Scope is intentionally minimal:
- one model path
- one image input
- one mask output
- one structured JSON report

This script does not run admission samples and does not imply quality conclusions.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any, Dict, Tuple

import numpy as np
from PIL import Image


def _sigmoid(x: np.ndarray) -> np.ndarray:
    return 1.0 / (1.0 + np.exp(-x))


def _to_nchw_rgb_normalized(image_path: Path, width: int, height: int) -> np.ndarray:
    image = Image.open(image_path).convert("RGB")
    image = image.resize((width, height), Image.BILINEAR)
    array = np.asarray(image, dtype=np.float32) / 255.0
    mean = np.array([0.485, 0.456, 0.406], dtype=np.float32)
    std = np.array([0.229, 0.224, 0.225], dtype=np.float32)
    array = (array - mean) / std
    nchw = np.transpose(array, (2, 0, 1))[None, ...]
    return nchw.astype(np.float32)


def _extract_mask(output_tensor: np.ndarray) -> np.ndarray:
    tensor = output_tensor
    while tensor.ndim > 2:
        tensor = tensor[0]
    if tensor.ndim != 2:
        raise ValueError(f"unexpected_output_rank:{output_tensor.shape}")
    mask = _sigmoid(tensor)
    mask = np.clip(mask, 0.0, 1.0)
    return (mask * 255.0).astype(np.uint8)


def _resolve_output_name(
    session: Any,
    preferred_output_name: str,
) -> Tuple[str, list[str]]:
    output_names = [item.name for item in session.get_outputs()]
    if preferred_output_name in output_names:
        return preferred_output_name, output_names
    if "output_3" in output_names:
        return "output_3", output_names
    return output_names[-1], output_names


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", required=True, help="Path to tiny ONNX model")
    parser.add_argument("--image", required=True, help="Path to source image")
    parser.add_argument("--mask-output", required=True, help="Path to output mask png")
    parser.add_argument("--report", required=True, help="Path to JSON report")
    parser.add_argument("--input-width", type=int, default=1024)
    parser.add_argument("--input-height", type=int, default=1024)
    parser.add_argument("--output-feature", default="output_3")
    args = parser.parse_args()

    model_path = Path(args.model).resolve()
    image_path = Path(args.image).resolve()
    mask_path = Path(args.mask_output).resolve()
    report_path = Path(args.report).resolve()
    report_path.parent.mkdir(parents=True, exist_ok=True)

    result: Dict[str, Any] = {
        "stage": "birefnet_tiny_single_point_closure_check",
        "model_path": str(model_path),
        "image_path": str(image_path),
        "mask_output_path": str(mask_path),
        "input_size": f"{args.input_width}x{args.input_height}",
        "requested_output_feature": args.output_feature,
        "model_exists": model_path.exists(),
        "image_exists": image_path.exists(),
        "load_succeeded": False,
        "inference_triggered": False,
        "mask_produced": False,
        "fallback_ready": True,
        "status": "unknown",
        "error_stage": None,
        "error": None,
        "runtime": {},
    }

    if not model_path.exists():
        result["status"] = "model_missing"
        result["error_stage"] = "asset"
        result["error"] = "tiny_onnx_asset_not_found"
        report_path.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
        return 2
    if not image_path.exists():
        result["status"] = "image_missing"
        result["error_stage"] = "input"
        result["error"] = "single_point_source_image_not_found"
        report_path.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
        return 3

    try:
        import onnxruntime as ort  # type: ignore

        result["runtime"]["onnxruntime_version"] = ort.__version__
    except Exception as exc:  # noqa: BLE001
        result["status"] = "runtime_missing"
        result["error_stage"] = "runtime"
        result["error"] = f"{type(exc).__name__}: {exc}"
        report_path.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
        return 4

    try:
        import onnxruntime as ort  # type: ignore

        session_options = ort.SessionOptions()
        session = ort.InferenceSession(str(model_path), sess_options=session_options, providers=["CPUExecutionProvider"])
        result["load_succeeded"] = True
        input_name = session.get_inputs()[0].name
        chosen_output_name, output_names = _resolve_output_name(session, args.output_feature)
        result["runtime"]["input_name"] = input_name
        result["runtime"]["output_names"] = output_names
        result["runtime"]["chosen_output_name"] = chosen_output_name

        model_input = _to_nchw_rgb_normalized(image_path, args.input_width, args.input_height)
        outputs = session.run([chosen_output_name], {input_name: model_input})
        result["inference_triggered"] = True
        if not outputs:
            raise RuntimeError("onnxruntime_output_empty")
        mask = _extract_mask(outputs[0])
        mask_path.parent.mkdir(parents=True, exist_ok=True)
        Image.fromarray(mask, mode="L").save(mask_path)
        result["mask_produced"] = True
        result["status"] = "single_point_closure_passed"
    except Exception as exc:  # noqa: BLE001
        result["status"] = "single_point_closure_failed"
        result["error_stage"] = (
            "load"
            if not result["load_succeeded"]
            else ("inference" if result["load_succeeded"] and not result["inference_triggered"] else "mask_write")
        )
        result["error"] = f"{type(exc).__name__}: {exc}"

    report_path.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
    return 0 if result["status"] == "single_point_closure_passed" else 5


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""
Export BiRefNet tiny `.pth` to ONNX for SellerCamera tiny single-point closure.

This script is intentionally scoped to minimal feasibility verification:
- one input shape (default 1024x1024)
- one output artifact
- one JSON report

R10 chosen fix route (single path):
- Replace DeformableConv2d forward with regular conv at export time only.
- Goal is to bypass `deform_conv2d` ONNX translation blocker and generate a
  verifiable ONNX artifact for runtime closure checks.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib
import json
import sys
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


def safe_import(module_name: str) -> tuple[bool, str]:
    try:
        module = importlib.import_module(module_name)
        return True, getattr(module, "__version__", "unknown")
    except Exception as exc:  # noqa: BLE001
        return False, f"{type(exc).__name__}: {exc}"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--upstream-root", required=True, help="Path to cloned ZhengPeng7/BiRefNet repo")
    parser.add_argument("--weights", required=True, help="Path to tiny .pth")
    parser.add_argument("--out-onnx", required=True, help="Output ONNX path")
    parser.add_argument("--report", required=True, help="Output report path")
    parser.add_argument("--input-size", default="1024x1024", help="HxW, default 1024x1024")
    parser.add_argument(
        "--deform-conv-export-mode",
        choices=["regular_conv_fallback"],
        default="regular_conv_fallback",
        help="Export-time deform conv handling mode (single allowed route).",
    )
    args = parser.parse_args()

    upstream_root = Path(args.upstream_root).resolve()
    weights_path = Path(args.weights).resolve()
    out_onnx = Path(args.out_onnx).resolve()
    report_path = Path(args.report).resolve()
    out_onnx.parent.mkdir(parents=True, exist_ok=True)
    report_path.parent.mkdir(parents=True, exist_ok=True)

    result: Dict[str, Any] = {
        "stage": "birefnet_tiny_pth_to_onnx_export",
        "upstream_root": str(upstream_root),
        "weights_path": str(weights_path),
        "out_onnx": str(out_onnx),
        "input_size": args.input_size,
        "deform_conv_export_mode": args.deform_conv_export_mode,
        "prechecks": {},
        "dependency": {},
        "success": False,
        "error_stage": None,
        "error": None,
        "onnx_size_bytes": 0,
        "onnx_sha256": None,
        "notes": [],
    }

    # precheck
    result["prechecks"]["upstream_exists"] = upstream_root.exists()
    result["prechecks"]["weights_exists"] = weights_path.exists()
    if weights_path.exists():
        result["prechecks"]["weights_size_bytes"] = weights_path.stat().st_size
        result["prechecks"]["weights_sha256"] = sha256_file(weights_path)

    if not upstream_root.exists():
        result["error_stage"] = "precheck"
        result["error"] = "upstream_repo_missing"
        report_path.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
        return 2

    if not weights_path.exists():
        result["error_stage"] = "precheck"
        result["error"] = "tiny_weight_missing"
        report_path.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
        return 2

    for module_name in ("torch", "torchvision", "onnx"):
        ok, info = safe_import(module_name)
        result["dependency"][module_name] = {"available": ok, "info": info}
    if not all(item["available"] for item in result["dependency"].values()):
        result["error_stage"] = "dependency"
        result["error"] = "python_dependencies_missing"
        report_path.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
        return 3

    try:
        h_raw, w_raw = args.input_size.lower().split("x", 1)
        height = int(h_raw)
        width = int(w_raw)
    except Exception as exc:  # noqa: BLE001
        result["error_stage"] = "args"
        result["error"] = f"invalid_input_size:{exc}"
        report_path.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
        return 4

    try:
        # Ensure upstream import precedence.
        if str(upstream_root) not in sys.path:
            sys.path.insert(0, str(upstream_root))

        # Patch Config to force tiny backbone and cpu device.
        import config as config_module  # type: ignore

        original_init = config_module.Config.__init__

        def patched_init(self: Any) -> None:
            original_init(self)
            self.bb = "swin_v1_t"
            self.device = "cpu"
            self.precisionHigh = False
            self.compile = False
            # Rebuild backbone-dependent channels after overriding `bb`.
            # `Config.__init__` computes these fields eagerly using the default backbone.
            # Without recomputation, strict state_dict loading mismatches on tiny weights.
            self.freeze_bb = False
            self.lateral_channels_in_collection = [768, 384, 192, 96]
            if self.mul_scl_ipt == "cat":
                self.lateral_channels_in_collection = [
                    channel * 2 for channel in self.lateral_channels_in_collection
                ]
            self.cxt = (
                self.lateral_channels_in_collection[1:][::-1][-self.cxt_num:]
                if self.cxt_num
                else []
            )

        config_module.Config.__init__ = patched_init  # type: ignore[assignment]

        if str(upstream_root) not in sys.path:
            sys.path.insert(0, str(upstream_root))
        from models.birefnet import BiRefNet  # type: ignore
        from models.modules.deform_conv import DeformableConv2d  # type: ignore
        import torch  # type: ignore
        from utils import check_state_dict  # type: ignore

        if args.deform_conv_export_mode == "regular_conv_fallback":
            # Single chosen route: bypass unsupported deform_conv2d export by
            # swapping forward to regular_conv only for ONNX export runtime.
            def export_safe_forward(self: Any, x: Any) -> Any:
                return self.regular_conv(x)

            DeformableConv2d.forward = export_safe_forward  # type: ignore[assignment]
            result["notes"].append("deform_conv2d_export_replaced_with_regular_conv_fallback")
        else:
            raise RuntimeError("unsupported_deform_conv_export_mode")

        model = BiRefNet(bb_pretrained=False)
        state_dict = torch.load(str(weights_path), map_location="cpu", weights_only=True)
        state_dict = check_state_dict(state_dict)
        model.load_state_dict(state_dict, strict=True)
        model.eval()

        dummy = torch.randn(1, 3, height, width, dtype=torch.float32)
        with torch.no_grad():
            _ = model(dummy)

        torch.onnx.export(
            model,
            dummy,
            str(out_onnx),
            verbose=False,
            opset_version=17,
            input_names=["input_image"],
            output_names=["output_image"],
            do_constant_folding=True,
        )
    except Exception as exc:  # noqa: BLE001
        result["error_stage"] = "export"
        result["error"] = f"{type(exc).__name__}: {exc}"
        report_path.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
        return 5

    if out_onnx.exists():
        result["success"] = True
        result["onnx_size_bytes"] = out_onnx.stat().st_size
        result["onnx_sha256"] = sha256_file(out_onnx)
    else:
        result["error_stage"] = "export"
        result["error"] = "onnx_not_generated"
        report_path.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
        return 6

    report_path.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

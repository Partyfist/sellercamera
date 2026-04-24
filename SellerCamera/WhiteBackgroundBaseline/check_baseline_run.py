#!/usr/bin/env python3
import argparse
import json
from collections import Counter, defaultdict
from pathlib import Path


def load_manifest(path: Path):
    data = json.loads(path.read_text(encoding="utf-8"))
    samples = data.get("samples", [])
    index = {}
    for sample in samples:
        sample_id = sample.get("sample_id")
        if sample_id:
            index[sample_id] = sample
    return data.get("suite_name", "unknown"), index


def load_records(path: Path):
    rows = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        rows.append(json.loads(line))
    return rows


def main():
    parser = argparse.ArgumentParser(description="Validate Seller Camera white background baseline runs")
    parser.add_argument("--manifest", required=True, type=Path, help="Path to sample manifest JSON")
    parser.add_argument("--records", required=True, type=Path, help="Path to baseline run JSONL")
    args = parser.parse_args()

    suite_name, samples = load_manifest(args.manifest)
    records = load_records(args.records)

    sample_hits = Counter()
    quality_hits = Counter()
    hard_case_hits = Counter()
    by_sample = defaultdict(list)
    envs = set()

    for row in records:
        sample_id = row.get("sampleID", "unknown")
        sample_hits[sample_id] += 1
        metadata = row.get("metadata", {})
        quality_hits[metadata.get("quality_level", "unknown")] += 1
        hard_case_hits[metadata.get("hard_case_signal", "unknown")] += 1
        by_sample[sample_id].append(row)
        env = row.get("environment", {})
        envs.add(
            (
                env.get("deviceModel", "unknown"),
                env.get("systemVersion", "unknown"),
                metadata.get("segmentation_revision_resolved", "unknown"),
            )
        )

    missing = [sid for sid in samples.keys() if sid not in sample_hits]

    print(f"[Suite] {suite_name}")
    print(f"[Records] {len(records)}")
    print(f"[Samples in manifest] {len(samples)}")
    print(f"[Samples covered] {len(sample_hits)}")
    print()

    if missing:
        print("[Missing Samples]")
        for sid in missing:
            print(f"- {sid}")
        print()

    print("[Quality Distribution]")
    for key, count in quality_hits.most_common():
        print(f"- {key}: {count}")
    print()

    print("[Hard Case Distribution]")
    for key, count in hard_case_hits.most_common():
        print(f"- {key}: {count}")
    print()

    print("[Environment Snapshots]")
    for model, os_version, revision in sorted(envs):
        print(f"- model={model}, iOS={os_version}, visionRevision={revision}")
    print()

    print("[Per Sample Latest]")
    for sample_id in sorted(sample_hits.keys()):
        latest = sorted(
            by_sample[sample_id],
            key=lambda row: row.get("recordedAtISO8601", "")
        )[-1]
        metadata = latest.get("metadata", {})
        print(
            f"- {sample_id}: quality={metadata.get('quality_level', 'unknown')}, "
            f"hard_case={metadata.get('hard_case_signal', 'unknown')}, "
            f"processed_id={latest.get('processedPhotoID', 'unknown')}"
        )


if __name__ == "__main__":
    main()

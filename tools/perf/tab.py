"""Tabulate unrounded game rates alongside the page's diagnostic rate and intervals.

Usage: python3 tools/perf/tab.py <results.jsonl>...
"""

import json
import sys

for path in sys.argv[1:]:
    with open(path, encoding="utf-8") as source:
        for line in source:
            row = json.loads(line)
            print(
                f"{row['browser']:7} {row['build']:12} {row['area']:8} "
                f"h{row['hour']:<2} {row['size']:12} "
                f"game {row['fps']:.6f} fps, "
                f"page diagnostics: {row['page_fps']:.2f} fps, P95 {row['page_p95_ms']:.2f} ms, "
                f"early/s {row['early_per_s']:.3f}, "
                f"draws {row['perf']['draws']:.1f}, "
                f"errors {len(row['errs'])}, warnings {row['warns']}"
            )

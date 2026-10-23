#!/usr/bin/env python3
"""Fail closed when a PHP base image is outside SuiteCRM's documented support.

Reference: https://docs.suitecrm.com/8.x/admin/compatibility-matrix/
Review this mapping when changing the SuiteCRM minor series.
"""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parent.parent
SUPPORTED = {
    "8.10": frozenset(("8.2", "8.3", "8.4")),
}


def check_versions(suitecrm: str, dockerfile: str) -> str | None:
    suitecrm = suitecrm.strip()
    match_suite = re.fullmatch(r"v?(\d+)\.(\d+)\.(\d+)", suitecrm)
    if not match_suite:
        return f"Invalid SUITECRM_VERSION: {suitecrm!r}"

    series = ".".join(match_suite.group(1, 2))
    supported = SUPPORTED.get(series)
    if supported is None:
        return f"No reviewed PHP compatibility policy for SuiteCRM {series}; update this mapping first"

    base = re.search(r"^FROM php:(\d+)\.(\d+)\.(\d+)-apache@sha256:([a-f0-9]{64})\s*$",
                     dockerfile, re.MULTILINE)
    if not base:
        return "Dockerfile must pin a PHP patch release and a sha256 base-image digest"
    php_series = ".".join(base.group(1, 2))
    if php_series not in supported:
        return (f"PHP {php_series} is not listed for SuiteCRM {series}; "
                f"documented versions: {', '.join(sorted(supported))}")
    return None


def main() -> int:
    suitecrm = (ROOT / "SUITECRM_VERSION").read_text(encoding="utf-8")
    dockerfile = (ROOT / ".docker/php/Dockerfile").read_text(encoding="utf-8")
    failure = check_versions(suitecrm, dockerfile)
    if failure:
        print(f"Compatibility check failed: {failure}", file=sys.stderr)
        return 1
    print("SuiteCRM/PHP compatibility policy: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

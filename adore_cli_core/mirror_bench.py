# ********************************************************************************
# Copyright (c) 2026 Contributors to the Eclipse Foundation
#
# See the NOTICE file(s) distributed with this work for additional
# information regarding copyright ownership.
#
# This program and the accompanying materials are made available under the
# terms of the Eclipse Public License 2.0 which is available at
# https://www.eclipse.org/legal/epl-2.0
#
# SPDX-License-Identifier: EPL-2.0
# ********************************************************************************

#!/usr/bin/env python3
"""
Benchmark Ubuntu archive mirrors from the Launchpad mirror list.

Usage:
    python3 mirror_bench.py [--suite SUITE] [--filter SUBSTR] [--sample N]

Examples:
    python3 mirror_bench.py --filter de --sample 10
    python3 mirror_bench.py --filter de
    python3 mirror_bench.py --sample 20
    python3 mirror_bench.py
"""

import argparse
import random
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from urllib.request import Request, urlopen

DEFAULT_MAIN  = "http://archive.ubuntu.com/ubuntu"
DEFAULT_PORTS = "http://ports.ubuntu.com/ubuntu-ports"

PAGE_URL = "https://launchpad.net/ubuntu/+archivemirrors"
TIMEOUT  = "5"

p = argparse.ArgumentParser(description=__doc__,
                             formatter_class=argparse.RawDescriptionHelpFormatter)
p.add_argument("--suite",   "-s", default="noble", metavar="SUITE",
               help="Ubuntu suite  (default: noble)")
p.add_argument("--filter",  "-f", default="",      metavar="SUBSTR",
               help="Substring filter on mirror URL, e.g. 'de'")
p.add_argument("--sample",  "-n", type=int, default=0, metavar="N",
               help="Randomly sample N non-default mirrors (0 = all)")
args = p.parse_args()

SUITE  = args.suite
FILTER = args.filter.lower()
SAMPLE = args.sample

# ── fetch mirror list ────────────────────────────────────────────────────────
print(f"Fetching {PAGE_URL} ...", flush=True)
req = Request(PAGE_URL, headers={"User-Agent": "mirror-bench/1.0"})
with urlopen(req, timeout=15) as r:
    html = r.read().decode("utf-8", errors="replace")

raw = re.findall(r'href="(https?://[^"]+?/ubuntu(?:-ports)?/?)"', html, re.IGNORECASE)
from_page: set[str] = {u.rstrip("/") for u in raw}

if FILTER:
    from_page = {u for u in from_page if FILTER in u.lower()}

# ── build probe list ─────────────────────────────────────────────────────────
# Returns [(kind, url)] deduplicating by url.
def build_probes(urls: set[str]) -> list[tuple[str, str]]:
    probes: list[tuple[str, str]] = []
    seen: set[str] = set()
    for url in sorted(urls):
        kind = "ports" if url.endswith("/ubuntu-ports") else "main "
        if url not in seen:
            probes.append((kind, url))
            seen.add(url)
        if kind == "main ":
            sibling = url[:url.rfind("/ubuntu")] + "/ubuntu-ports"
            if sibling not in seen:
                probes.append(("ports", sibling))
                seen.add(sibling)
    return probes

# Always-included defaults (tested first regardless of filter / sample)
defaults: set[str] = {DEFAULT_MAIN, DEFAULT_PORTS}
default_probes = build_probes(defaults)

# Non-default remainder after applying filter
others = sorted(from_page - defaults)
if SAMPLE > 0 and others:
    k = min(SAMPLE, len(others))
    others = random.sample(others, k)
    print(f"Sampled {k} of {len(from_page - defaults)} filtered mirrors.", flush=True)

other_probes = build_probes(set(others))

# ── probe function ───────────────────────────────────────────────────────────
def probe(kind: str, mirror: str) -> tuple[float, str, str, bool]:
    url = f"{mirror}/dists/{SUITE}/Release"
    r = subprocess.run(
        ["curl", "-s", "-o", "/dev/null", "-w", "%{http_code} %{time_total}",
         "--max-time", TIMEOUT, url],
        capture_output=True, text=True,
    )
    parts = r.stdout.strip().split()
    ok = len(parts) == 2 and parts[0] == "200"
    return (float(parts[1]) if ok else 999.0, kind, mirror, ok)

def run_batch(probes: list[tuple[str, str]],
              label: str) -> list[tuple[float, str, str, bool]]:
    results: list[tuple[float, str, str, bool]] = []
    workers = min(len(probes), 32)
    with ThreadPoolExecutor(max_workers=workers) as pool:
        futures = {pool.submit(probe, k, m): (k, m) for k, m in probes}
        done = 0
        for fut in as_completed(futures):
            results.append(fut.result())
            done += 1
            print(f"\r  {label}: {done}/{len(probes)}", end="", flush=True)
    print()
    return results

# ── run defaults first, print immediately ───────────────────────────────────
all_results: list[tuple[float, str, str, bool]] = []

if default_probes:
    print(f"\nTesting {len(default_probes)} default mirrors ...", flush=True)
    def_results = sorted(run_batch(default_probes, "defaults"))
    all_results.extend(def_results)

    def_ok = [(t, k.strip(), m) for t, k, m, ok in def_results if ok]
    if def_ok:
        print("\n  -- defaults --")
        for t, k, m in def_ok:
            print(f"  {t:.3f}s  [{k}]  {m}")

# ── run sampled / full list ──────────────────────────────────────────────────
if other_probes:
    print(f"\nTesting {len(other_probes)} additional endpoints ...", flush=True)
    all_results.extend(run_batch(other_probes, "mirrors"))

# ── final sorted output ──────────────────────────────────────────────────────
all_results.sort()
main_ok  = [(t, m) for t, k, m, ok in all_results if k == "main " and ok]
ports_ok = [(t, m) for t, k, m, ok in all_results if k == "ports" and ok]
failed   = [(k.strip(), m) for t, k, m, ok in all_results if not ok]

def show(rows: list[tuple[float, str]], default_url: str) -> None:
    if not rows:
        print("  (none)")
        return
    for t, m in rows:
        tag = "  [default]" if m == default_url else ""
        print(f"  {t:.3f}s  {m}{tag}")

print(f"\n=== amd64  (APT_MIRROR) ===")
show(main_ok, DEFAULT_MAIN)

print(f"\n=== arm64  (APT_MIRROR_PORTS) ===")
show(ports_ok, DEFAULT_PORTS)

if failed:
    print(f"\n=== Failed ({len(failed)}) ===")
    for k, m in failed[:10]:
        print(f"  [{k}]  {m}")
    if len(failed) > 10:
        print(f"  ... and {len(failed) - 10} more")

if main_ok or ports_ok:
    print("\n--- suggested build args ---")
    if main_ok:
        print(f"APT_MIRROR={main_ok[0][1]}")
    if ports_ok:
        print(f"APT_MIRROR_PORTS={ports_ok[0][1]}")

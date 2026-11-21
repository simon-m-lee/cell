#!/usr/bin/env python3
"""Generate TEST_VERIFICATION.md for the cell_flutter package.

Usage (from packages/cell_flutter):

  python3 tool/generate_test_verification.py
  python3 tool/generate_test_verification.py --run-tests
  python3 tool/generate_test_verification.py --coverage
  python3 tool/generate_test_verification.py --run-tests --coverage
  python3 tool/generate_test_verification.py --package-name cell_flutter --version 1.0.2

What is automatic
  - test file inventory (lines, size, test() / testWidgets() / group() /
    async counts)
  - recursive discovery: `*_test.dart` anywhere under `test/` — the
    widget, hooks, forms, devtools, golden, fuzz, soak, migration,
    restoration, list-view, and testing-surface suites — plus shared
    helpers that declare `test(` / `group(`
  - a source-under-test inventory of `lib/` — the top-level barrels,
    `lib/src/` (widget layer), `lib/src/devtools/`, `lib/src/forms/`,
    `lib/src/hooks/`, and `lib/src/testing/`
  - group and test names listed under each file
  - optional `{tc}` pass/fail
  - optional lcov line table if coverage/lcov.info exists or --coverage is set

What stays editorial
  - narrative "strengths / recommendations / API checklist"
    (emitted as stubs you can keep editing)

Requires: Python 3.9+. flutter on PATH if --run-tests / --coverage.
"""

from __future__ import annotations

import argparse
import datetime as dt
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path


def resolve_cmd(name: str) -> str:
    """Windows: flutter/dart are often *.bat, which CreateProcess will not
    find under the bare name."""
    found = shutil.which(name)
    if found:
        return found
    if os.name == "nt":
        for extra in (f"{name}.bat", f"{name}.cmd", f"{name}.exe"):
            found = shutil.which(extra)
            if found:
                return found
        flutter = os.environ.get("FLUTTER_ROOT") or os.environ.get("FLUTTER_HOME")
        if flutter:
            for extra in (f"{name}.bat", f"{name}.cmd", f"{name}.exe"):
                p = Path(flutter) / "bin" / extra
                if p.exists():
                    return str(p)
    raise FileNotFoundError(
        f"Cannot find {name!r} on PATH. In PowerShell run `Get-Command {name}` "
        "and add that directory (and Pub\\Cache\\bin) to Path."
    )


TEST_RE = re.compile(
    r"""^\s*(?:test|testWidgets)\s*\(\s*(['"])(?P<name>.*?)\1""", re.M
)
GROUP_RE = re.compile(r"""^\s*group\s*\(\s*(['"])(?P<name>.*?)\1""", re.M)


def analyze_test_file(path: Path) -> dict:
    text = path.read_text(encoding="utf-8", errors="replace")
    lines = text.count("\n") + (0 if text.endswith("\n") or not text else 1)
    test_names = re.findall(
        r"""^\s*(?:test|testWidgets)\s*\(\s*['\"](.*?)['\"]""", text, re.M
    )
    group_names = re.findall(r"""^\s*group\s*\(\s*['\"](.*?)['\"]""", text, re.M)
    async_n = len(
        re.findall(r"(?:test|testWidgets)\s*\([\s\S]{0,200}?\(\s*\)\s*async", text)
    )
    skip_n = len(
        re.findall(
            r"""(?:test|testWidgets)\s*\([\s\S]{0,300}?skip:\s*(true|['\"])""",
            text,
        )
    )
    return {
        "path": path,
        "name": path.name,
        "lines": lines,
        "bytes": path.stat().st_size,
        "tests": len(test_names),
        "groups": len(group_names),
        "async": async_n,
        "skip": skip_n,
        "test_names": test_names,
        "group_names": group_names,
        "focus": guess_focus(path.name, group_names),
    }


def guess_focus(filename: str, groups: list[str]) -> str:
    stem = filename.replace("_test", "").replace(".dart", "").replace("_", " ")
    stem = re.sub(r"\s+", " ", stem).strip()
    if groups:
        return f"{stem}; groups: {', '.join(groups[:6])}" + (
            "…" if len(groups) > 6 else ""
        )
    return stem


def package_display_root(name: str) -> str:
    return f"packages/{name}"


def redact_host_paths(text: str, package: Path) -> str:
    """Drop machine-local prefixes from logs that go into the committed report."""
    resolved = str(package.resolve())
    posix = resolved.replace("\\", "/")
    text = text.replace(resolved, ".")
    text = text.replace(posix, ".")
    text = text.replace(resolved.replace("\\", "\\\\"), ".")
    text = re.sub(r"[A-Za-z]:\\Users\\[^\\\s]+\\[^\s]*", ".", text)
    text = re.sub(r"/home/[^/\s]+/[^\s]*", ".", text)
    text = re.sub(r"/Users/[^/\s]+/[^\s]*", ".", text)
    return text


def lib_rel(path: str) -> str:
    norm = path.replace("\\", "/")
    if "lib/" in norm:
        return "lib/" + norm.split("lib/", 1)[-1]
    return norm


def source_area(rel: str) -> str:
    """Classify a lib/ file into one of the package's areas."""
    if rel.startswith("lib/src/"):
        return "src"
    return "top-level"



SOURCE_AREA_LABELS = [
    ("top-level", "top-level entry points"),
    ("src", "`lib/src/` — implementation"),
]
def discover_sources(root: Path) -> list[dict]:
    """Inventory the library under test (`lib/**/*.dart`)."""
    sources = []
    lib_dir = root / "lib"
    if not lib_dir.is_dir():
        return sources
    for p in sorted(lib_dir.rglob("*.dart")):
        if not p.is_file():
            continue
        rel = str(p.relative_to(root)).replace("\\", "/")
        text = p.read_text(encoding="utf-8", errors="replace")
        lines = text.count("\n") + (0 if text.endswith("\n") or not text else 1)
        sources.append(
            {
                "rel": rel,
                "name": p.name,
                "area": source_area(rel),
                "lines": lines,
                "bytes": p.stat().st_size,
            }
        )
    return sources


def has_main(path: Path) -> bool:
    """Shared helpers declare `test(` but no `main(` — they cannot be run
    as an entry point and must be excluded from `{tc}`. Match a
    real `main()` declaration at line start, not a doc-comment mention."""
    text = path.read_text(encoding="utf-8", errors="replace")
    return re.search(
        r"^\s*(?:void\s+|Future<void>\s+|FutureOr<void>\s+)?main\s*\(\s*\)",
        text,
        re.M,
    ) is not None


def parse_lcov(lcov: Path) -> list[dict]:
    rows = []
    if not lcov.exists():
        return rows
    current = None
    for line in lcov.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.startswith("SF:"):
            current = {"file": line[3:].strip(), "hit": 0, "found": 0}
        elif line.startswith("LH:") and current:
            current["hit"] = int(line[3:])
        elif line.startswith("LF:") and current:
            current["found"] = int(line[3:])
        elif line.startswith("end_of_record") and current:
            rows.append(current)
            current = None
    return dedupe_lcov(rows)


def dedupe_lcov(rows: list[dict]) -> list[dict]:
    """One row per lib-relative path. Keep the record with the most hits."""
    best: dict[str, dict] = {}
    for r in rows:
        key = lib_rel(r["file"])
        prev = best.get(key)
        if prev is None or r["hit"] > prev["hit"] or (
            r["hit"] == prev["hit"] and r["found"] <= prev["found"]
        ):
            best[key] = {"file": key, "hit": r["hit"], "found": r["found"]}
    return list(best.values())


# compact: "00:14 +364 ~1: All tests passed!"  or  "00:13 +944 -1: Some tests failed."
_SUMMARY_RE = re.compile(
    r"\+(?P<passed>\d+)(?:\s+-(?P<failed>\d+))?(?:\s+~(?P<skipped>\d+))?:\s+"
    r"(All tests passed|Some tests failed)",
    re.I,
)
_PLUS_LINE_RE = re.compile(
    r"\+(?P<passed>\d+)(?:\s+-(?P<failed>\d+))?(?:\s+~(?P<skipped>\d+))?:",
)


def run_tests(package: Path, files: list[Path], coverage: bool, runner: str) -> dict:
    exe = resolve_cmd(runner)
    cmd = [exe, "test"]
    if runner == "flutter":
        cmd += ["--reporter", "compact"]
    if coverage:
        cmd += ["--coverage"]
    cmd += [
        str(f.relative_to(package)) if f.is_relative_to(package) else str(f)
        for f in files
    ]
    print("+", " ".join(cmd), file=sys.stderr)
    proc = subprocess.run(cmd, cwd=package, capture_output=True, text=True, shell=False)
    out = proc.stdout + "\n" + proc.stderr
    passed = failed = skipped = 0
    summaries = list(_SUMMARY_RE.finditer(out))
    if summaries:
        m = summaries[-1]
        passed = int(m.group("passed"))
        failed = int(m.group("failed") or 0)
        skipped = int(m.group("skipped") or 0)
        if m.group(4) and m.group(4).lower().startswith("all tests passed"):
            failed = 0
    else:
        ticks = list(_PLUS_LINE_RE.finditer(out))
        if ticks:
            m = ticks[-1]
            passed = int(m.group("passed"))
            failed = int(m.group("failed") or 0)
            skipped = int(m.group("skipped") or 0)
        elif "All tests passed" in out:
            passed = 0
            failed = 0
    if proc.returncode == 0 and failed and "All tests passed" in out:
        failed = 0
    return {
        "passed": passed,
        "failed": failed,
        "skipped": skipped,
        "code": proc.returncode,
        "ok": proc.returncode == 0 and failed == 0,
        "log": redact_host_paths(out[-4000:], package),
    }


def format_kb(n: int) -> str:
    return f"{n / 1024:.1f} KB"


def gh_anchor(title: str) -> str:
    """GitHub / many Markdown previewers: lowercase, spaces→-, drop most punctuation."""
    s = title.strip().lower()
    s = re.sub(r"[^\w\s\-./]", "", s)
    s = s.replace("/", "")
    s = re.sub(r"\s+", "-", s)
    s = re.sub(r"-{2,}", "-", s)
    return s


def render(md: dict) -> str:
    pkg = md["package"]
    files = md["files"]
    total_tests = sum(f["tests"] for f in files)
    total_skip = sum(f["skip"] for f in files)
    total_groups = sum(f["groups"] for f in files)
    total_async = sum(f["async"] for f in files)
    total_lines = sum(f["lines"] for f in files)
    total_bytes = sum(f["bytes"] for f in files)
    run = md.get("run")
    cov = md.get("coverage") or []
    sources = md.get("sources") or []

    lines = []
    a = lines.append
    tc = pkg["test_cmd"]
    tca = tc.replace(" ", "-")
    a(f"# {pkg['title']} - Test Verification Report")
    a("")
    a(f"**Generated:** {md['generated']}")
    a(f"**Package:** {pkg['name']} (v{pkg['version']})")
    a(f"**Test Files Analyzed:** {len(files)}")
    a(f"**Total Tests:** {total_tests} ({total_skip} skipped)")
    a("")
    a("---")
    a("")
    a("## Table of contents")
    a("")
    a("- [Executive Summary](#executive-summary)")
    a("  - [Snapshot](#snapshot)")
    a("  - [Quick Stats](#quick-stats)")
    a("- [Test File Inventory](#test-file-inventory)")
    a("- [Source Under Test (`lib/`)](#source-under-test-lib)")
    a("- [Detailed Test Coverage](#detailed-test-coverage)")
    for i, f in enumerate(files, 1):
        heading = f"File {i}: {f['name']} ({f['tests']} tests)"
        a(f"  - [{f['name']}](#{gh_anchor(heading)})")
    a("- [Runtime Verification Status](#runtime-verification-status)")
    if run:
        a(f"  - [Last `{tc}`](#last-{tca})")
    if cov:
        a("  - [Line Coverage (`lib/`)](#line-coverage-lib)")
    a("- [Recommendations](#recommendations)")
    a("- [Appendix: File Locations](#appendix-file-locations)")
    a("")
    a("---")
    a("")
    a("## Executive Summary")
    a("")
    a(
        f"The {pkg['name']} test suite contains **{total_tests} unit tests** "
        f"across **{len(files)} files** in `{pkg['test_dir']}/`. "
        "Counts are `test(` / `testWidgets(` declarations."
    )
    a("")
    if sources:
        by_area = {}
        for s in sources:
            by_area.setdefault(s["area"], []).append(s)
        parts = []
        for area, label in SOURCE_AREA_LABELS:
            if area in by_area:
                parts.append(f"**{len(by_area[area])}** in {label}")
        a(
            f"The library under test is **{len(sources)} source files** in "
            f"`lib/`: " + "; ".join(parts) + "."
        )
        a("")
    a("This file is **generated**. Edit the script flags or the stub sections "
      "at the bottom; do not hand-count `test(` / `testWidgets(`.")
    a("")
    if run or cov:
        a("### Snapshot")
        a("")
        bits = []
        if run:
            if run.get("ok") or (run["code"] == 0 and run["failed"] == 0):
                bits.append(
                    f"Last `{tc}` is **green**: "
                    f"**{run['passed']} passed**, {run['failed']} failed "
                    f"(exit {run['code']})."
                )
            else:
                bits.append(
                    f"Last `{tc}` is **red**: "
                    f"{run['passed']} passed, **{run['failed']} failed** "
                    f"(exit {run['code']})."
                )
        if cov:
            hit = sum(r["hit"] for r in cov)
            found = sum(r["found"] for r in cov)
            pct = (100.0 * hit / found) if found else 0
            low = [
                r for r in cov
                if r["found"] and (100.0 * r["hit"] / r["found"]) < 70
            ]
            low.sort(key=lambda r: r["hit"] / r["found"] if r["found"] else 0)
            bits.append(f"`lib/` line coverage is **{pct:.1f}%** ({hit} / {found}).")
            if low:
                names = ", ".join(f"`{lib_rel(r['file'])}`" for r in low[:4])
                bits.append(f"Below 70%: {names}" + ("…" if len(low) > 4 else "."))
            else:
                bits.append("No `lib/` file is below 70% in this lcov.")
        for b in bits:
            a(b)
            a("")
    a("### Quick Stats")
    a("")
    a("| Metric | Value |")
    a("|--------|-------|")
    a(f"| **Total Test Files** | {len(files)} |")
    a(f"| **Total Tests** | {total_tests} |")
    a(f"| **Skipped** | {total_skip} |")
    if run:
        a(
            f"| **Last full run** | {run['passed']} passed, {run['failed']} failed, "
            f"{run['skipped']} skipped (exit {run['code']}) |"
        )
    else:
        a("| **Last full run** | *(pass `--run-tests` to fill)* |")
    a(f"| **Test Groups** | {total_groups} (`group(` declarations) |")
    a(f"| **Async-ish tests** | ~{total_async} (heuristic) |")
    if cov:
        hit = sum(r["hit"] for r in cov)
        found = sum(r["found"] for r in cov)
        pct = (100.0 * hit / found) if found else 0
        a(f"| **Line coverage (`lib/`)** | **{pct:.1f}%** ({hit} / {found}) |")
    else:
        a("| **Line coverage (`lib/`)** | *(pass `--coverage` or provide lcov.info)* |")
    a("")
    a("---")
    a("")
    a("## Test File Inventory")
    a("")
    a("| # | File | Lines | Tests | Size | Focus |")
    a("|---|------|------:|------:|------:|-------|")
    for i, f in enumerate(files, 1):
        a(
            f"| {i} | {f['name']} | {f['lines']:,} | {f['tests']} | "
            f"{format_kb(f['bytes'])} | {f['focus']} |"
        )
    a(
        f"| **Total** | | **{total_lines:,}** | **{total_tests}** | "
        f"**{format_kb(total_bytes)}** | |"
    )
    a("")
    a("---")
    a("")
    if sources:
        a("## Source Under Test (`lib/`)")
        a("")
        a(
            "The provider surface is inventoried: the top-level barrel "
            "(`cell_flutter_devtools.dart`) and `lib/src/`."
        )
        a("")
        a("| Area | Files | Lines | Size |")
        a("|------|------:|------:|-----:|")
        for area, label in SOURCE_AREA_LABELS:
            in_area = [s for s in sources if s["area"] == area]
            if not in_area:
                continue
            a(
                f"| {label} | {len(in_area)} | "
                f"{sum(s['lines'] for s in in_area):,} | "
                f"{format_kb(sum(s['bytes'] for s in in_area))} |"
            )
        a("")
        a("| File | Lines | Size |")
        a("|------|------:|-----:|")
        for s in sources:
            a(f"| `{s['rel']}` | {s['lines']:,} | {format_kb(s['bytes'])} |")
        a("")
        a("---")
        a("")
    a("## Detailed Test Coverage")
    a("")
    a("Generated from `group(` / `test(` names. Tighten the prose by hand if needed.")
    a("")
    for i, f in enumerate(files, 1):
        a(f"### File {i}: {f['name']} ({f['tests']} tests)")
        a("")
        a("| Category (group) | Tests in file |")
        a("|------------------|--------------:|")
        a(f"| *(all groups)* | {f['tests']} |")
        for g in f["group_names"]:
            a(f"| {g} | |")
        a("")
        a("**Tests**")
        a("")
        for name in f["test_names"]:
            a(f"- {name}")
        a("")
    a("---")
    a("")
    a("## Runtime Verification Status")
    a("")
    a(f"Working directory: `{pkg['root']}` (package-relative; host paths omitted).")
    a("")
    a(f"`{tc}` discovers `*_test.dart` automatically; the explicit list is "
      "kept for the report and for CI (it excludes shared helpers such as "
      "`test/fuzz/fuzz_harness.dart` that have no `main()`).")
    a("")
    a("```bash")
    a("flutter pub get")
    names = " \\\n  ".join(f"{pkg['test_dir']}/{f['rel']}" for f in files)
    a(f"{tc} \\\n  {names}")
    a("```")
    a("")
    if run:
        a(f"### Last `{tc}`")
        a("")
        a(f"| Passed | Failed | Skipped | Exit |")
        a(f"|-------:|-------:|--------:|-----:|")
        status = "green" if run.get("ok") or (run["code"] == 0 and run["failed"] == 0) else "red"
        a(f"| {run['passed']} | {run['failed']} | {run['skipped']} | {run['code']} |")
        a("")
        a(f"Status: **{status}**.")
        a("")
        a("<details><summary>tail of test log</summary>")
        a("")
        a("```")
        a(run["log"].rstrip())
        a("```")
        a("")
        a("</details>")
        a("")
    if cov:
        a("### Line Coverage (`lib/`)")
        a("")
        hit = sum(r["hit"] for r in cov)
        found = sum(r["found"] for r in cov)
        pct = (100.0 * hit / found) if found else 0
        a(f"**Overall: {hit} / {found} lines = {pct:.1f}%**")
        a("")
        a("| File | Hit | Found | Line % |")
        a("|------|----:|------:|-------:|")
        for r in sorted(cov, key=lambda x: (-(x["hit"] / x["found"] if x["found"] else 0), x["file"])):
            rel = lib_rel(r["file"])
            lp = 100.0 * r["hit"] / r["found"] if r["found"] else 0
            a(f"| `{rel}` | {r['hit']} | {r['found']} | {lp:.1f} |")
        a("")
    a("---")
    a("")
    a("## Recommendations")
    a("")
    a("1. Keep this report generated — do not hand-count `test(` / `testWidgets(`.")
    a("2. CI should run `{tc}` from the package root; the serialization")
    a("   contract is the wire format the extension UI parses.")
    a("3. `registerCellDevTools` must stay assert-guarded — any change that")
    a("   would ship the registration in release builds is a bug.")
    a("4. When the extension UI changes, rebuild with")
    a("   `dart run devtools_extensions build_and_copy` and re-run")
    a("   `validate` before publishing.")
    a("5. The pre-compiled web app under `extension/devtools/build/` is part")
    a("   of the published package — do not gitignore it.")
    a("")
    a("---")
    a("")
    a("## Appendix: File Locations")
    a("")
    a("```")
    a(f"{pkg['test_dir']}/")
    for f in files:
        a(
            f"├── {f['rel']}  "
            f"({f['tests']} tests, {format_kb(f['bytes'])}, {f['lines']:,} lines)"
        )
    a("```")
    a("")
    a(f"**Total lines of test code:** {total_lines:,}")
    a("")
    a(f"*Generated {md['generated']} by generate_test_verification.py*")
    a("")
    return "\n".join(lines)



def uses_flutter(root: Path) -> bool:
    """True when the package depends on the Flutter SDK (widget tests)."""
    pubspec = root / "pubspec.yaml"
    if not pubspec.exists():
        return False
    text = pubspec.read_text(encoding="utf-8", errors="replace")
    return re.search(r"^\s*flutter:\s*$.*?^\s*sdk:\s*flutter\s*$", text, re.M | re.S) is not None


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--package-root", default=".", help="Package root (default: cwd)")
    ap.add_argument("--package-name", default=None)
    ap.add_argument("--version", default=None)
    ap.add_argument("--test-dir", default="test")
    ap.add_argument(
        "--pattern",
        default="*_test.dart",
        help="Glob under test-dir, matched recursively (cell_flutter: *_test.dart)",
    )
    ap.add_argument(
        "--also-test-star",
        action="store_true",
        help="Deprecated: test_*.dart files are included by default too. "
        "Kept for compatibility.",
    )
    ap.add_argument("--out", default="TEST_VERIFICATION.md")
    ap.add_argument("--run-tests", action="store_true")
    ap.add_argument("--coverage", action="store_true", help="{tc} --coverage (writes coverage/lcov.info)")
    ap.add_argument("--lcov", default="coverage/lcov.info")
    ap.add_argument(
        "--runner",
        choices=("flutter", "dart"),
        default=None,
        help="Test runner (default: auto-detect from pubspec)",
    )
    args = ap.parse_args()
    args = ap.parse_args()

    root = Path(args.package_root).resolve()
    test_dir = root / args.test_dir
    # Recursive discovery. cell_flutter uses `*_test.dart` naming across
    # widget/hooks/forms/golden/fuzz/soak/migration subdirectories; the
    # cell-naming fallback and the shared-helper sweep keep the report
    # complete if either convention appears later.
    files = {p for p in test_dir.rglob(args.pattern) if p.is_file()}
    files.update(p for p in test_dir.rglob("test_*.dart") if p.is_file())
    for p in test_dir.rglob("*.dart"):
        if p in files or not p.is_file():
            continue
        text = p.read_text(encoding="utf-8", errors="replace")
        if TEST_RE.search(text) or GROUP_RE.search(text):
            files.add(p)
    files = sorted(files, key=lambda p: str(p.relative_to(test_dir)))
    if not files:
        print(f"No tests matching {args.pattern} in {test_dir}", file=sys.stderr)
        return 2

    name = args.package_name
    version = args.version or "0.0.0"
    if name is None:
        pub = root / "pubspec.yaml"
        if pub.exists():
            text = pub.read_text(encoding="utf-8")
            m = re.search(r"^name:\s*(\S+)", text, re.M)
            if m:
                name = m.group(1)
            m = re.search(r"^version:\s*(\S+)", text, re.M)
            if m:
                version = m.group(1)
        name = name or root.name

    analyzed = [analyze_test_file(p) for p in files]
    for entry in analyzed:
        entry["rel"] = str(entry["path"].relative_to(test_dir)).replace("\\", "/")

    sources = discover_sources(root)

    run = None
    if args.run_tests or args.coverage:
        # Shared helpers declare no `main()` and cannot run as entry
        # points.
        runnable = [f for f in files if has_main(f)]
        runner = args.runner or ("dart" if not uses_flutter(root) else "flutter")
        run = run_tests(root, runnable, args.coverage, runner)
    else:
        runner = args.runner or ("dart" if not uses_flutter(root) else "flutter")


    cov_rows = parse_lcov(root / args.lcov)

    md = {
        "generated": dt.date.today().isoformat(),
        "package": {
            "title": f"{name} package",
            "name": name,
            "version": version,
            "test_dir": args.test_dir,
            "root": package_display_root(name),
            "test_cmd": "flutter test" if runner == "flutter" else "dart test",
        },
        "files": analyzed,
        "sources": sources,
        "run": run,
        "coverage": cov_rows,
    }
    out = root / args.out if not Path(args.out).is_absolute() else Path(args.out)
    out.write_text(render(md), encoding="utf-8")
    print(f"wrote {out} ({sum(f['tests'] for f in analyzed)} tests, {len(analyzed)} files)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

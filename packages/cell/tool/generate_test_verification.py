#!/usr/bin/env python3
"""Generate TEST_VERIFICATION.md for the core `cell` package.

Usage (from packages/cell):

  python3 tool/generate_test_verification.py
  python3 tool/generate_test_verification.py --run-tests
  python3 tool/generate_test_verification.py --coverage
  python3 tool/generate_test_verification.py --run-tests --coverage
  python3 tool/generate_test_verification.py --package-name cell --version 1.0.0-rc.3

What is automatic
  - test file inventory (lines, size, test() / group() / async counts)
  - group and test names listed under each file
  - optional `dart test` pass/fail
  - optional lcov line table if coverage/lcov.info exists or --coverage is set

What stays editorial
  - narrative "strengths / recommendations / API checklist"
    (emitted as stubs you can keep editing)

Requires: Python 3.9+. dart on PATH if --run-tests / --coverage.
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
    """Windows: dart is often *.bat, which CreateProcess will not find as 'dart'."""
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


TEST_RE = re.compile(r"""^\s*test\s*\(\s*(['"])(?P<name>.*?)\1""", re.M)
GROUP_RE = re.compile(r"""^\s*group\s*\(\s*(['"])(?P<name>.*?)\1""", re.M)
ASYNC_TEST_RE = re.compile(
    r"""^\s*test\s*\([^;]*?,\s*\(\s*\)\s*async""", re.M | re.S
)
SKIP_RE = re.compile(r"""skip:\s*true|skip:\s*['\"]""", re.M)


def count_matches(text: str, pattern: re.Pattern) -> int:
    return len(pattern.findall(text))


def analyze_test_file(path: Path) -> dict:
    text = path.read_text(encoding="utf-8", errors="replace")
    lines = text.count("\n") + (0 if text.endswith("\n") or not text else 1)
    test_names = re.findall(r"""^\s*test\s*\(\s*['\"](.*?)['\"]""", text, re.M)
    group_names = re.findall(r"""^\s*group\s*\(\s*['\"](.*?)['\"]""", text, re.M)
    async_n = len(re.findall(r"""test\s*\([^)]*\)\s*async""", text))
    async_n = len(re.findall(r"test\s*\([\s\S]{0,200}?\(\s*\)\s*async", text))
    skip_n = len(re.findall(r"""test\s*\([\s\S]{0,300}?skip:\s*(true|['\"])""", text))
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
    stem = filename.replace("test_", "").replace(".dart", "").replace("_", " ")
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
    # D:\\Users\\Name\\... or /home/name/...
    text = re.sub(r"[A-Za-z]:\\Users\\[^\\\s]+\\[^\s]*", ".", text)
    text = re.sub(r"/home/[^/\s]+/[^\s]*", ".", text)
    text = re.sub(r"/Users/[^/\s]+/[^\s]*", ".", text)
    return text


def lib_rel(path: str) -> str:
    norm = path.replace("\\", "/")
    if "lib/" in norm:
        return "lib/" + norm.split("lib/", 1)[-1]
    return norm


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


# compact: "00:14 +1012: All tests passed!"  or  "00:13 +944 -1: Some tests failed."
_SUMMARY_RE = re.compile(
    r"\+(?P<passed>\d+)(?:\s+-(?P<failed>\d+))?(?:\s+~(?P<skipped>\d+))?:\s+"
    r"(All tests passed|Some tests failed)",
    re.I,
)
_PLUS_LINE_RE = re.compile(
    r"\+(?P<passed>\d+)(?:\s+-(?P<failed>\d+))?(?:\s+~(?P<skipped>\d+))?:",
)


def run_dart_test(package: Path, files: list[Path], coverage_dir: Path | None) -> dict:
    dart = resolve_cmd("dart")
    cmd = [dart, "test", "--reporter", "compact"]
    if coverage_dir:
        coverage_dir.mkdir(parents=True, exist_ok=True)
        cmd += [f"--coverage={coverage_dir}"]
    cmd += [str(f.relative_to(package)) if f.is_relative_to(package) else str(f) for f in files]
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

    lines = []
    a = lines.append
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
    a("- [Detailed Test Coverage](#detailed-test-coverage)")
    for i, f in enumerate(files, 1):
        heading = f"File {i}: {f['name']} ({f['tests']} tests)"
        a(f"  - [{f['name']}](#{gh_anchor(heading)})")
    a("- [Runtime Verification Status](#runtime-verification-status)")
    if run:
        a("  - [Last `dart test`](#last-dart-test)")
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
        "Counts are `test(` declarations."
    )
    a("")
    a("This file is **generated**. Edit the script flags or the stub sections "
      "at the bottom; do not hand-count `test(`.")
    a("")
    if run or cov:
        a("### Snapshot")
        a("")
        bits = []
        if run:
            if run.get("ok") or (run["code"] == 0 and run["failed"] == 0):
                bits.append(
                    f"Last `dart test` is **green**: "
                    f"**{run['passed']} passed**, {run['failed']} failed "
                    f"(exit {run['code']})."
                )
            else:
                bits.append(
                    f"Last `dart test` is **red**: "
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
    a("If tests are named `test_*.dart` instead of `*_test.dart`, `dart test` with")
    a("no path finds nothing. Pass explicit files:")
    a("")
    a("```bash")
    a("dart pub get")
    names = " \\\n  ".join(f"{pkg['test_dir']}/{f['name']}" for f in files)
    a(f"dart test \\\n  {names}")
    a("```")
    a("")
    if run:
        a("### Last `dart test`")
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
        for r in sorted(cov, key=lambda x: (-(x['hit']/x['found'] if x['found'] else 0), x['file'])):
            rel = lib_rel(r["file"])
            lp = 100.0 * r["hit"] / r["found"] if r["found"] else 0
            a(f"| `{rel}` | {r['hit']} | {r['found']} | {lp:.1f} |")
        a("")
    a("---")
    a("")
    a("## Recommendations")
    a("")
    a("1. Keep this report generated — do not hand-count `test(`.")
    a("2. CI should pass the explicit file list below (or a `dart_test.yaml`) "
      "because `cell` uses `test_*.dart` naming.")
    a("3. The operator phase files (`test_operators_phase*.dart`) exercise the "
      "instruction pipeline; keep them in sync with `lib/src/internal/operator/`.")
    a("4. Cross-package dependents (`cell_tissue`, `cell_flow`) rely on these "
      "contracts — add integration tests when the core APIs change.")
    a("5. Track coverage per public/internal pair (`lib/src/*.dart` vs "
      "`lib/src/internal/*.dart`), not just the whole `lib/` average.")
    a("")
    a("---")
    a("")
    a("## Appendix: File Locations")
    a("")
    a("```")
    a(f"{pkg['test_dir']}/")
    for f in files:
        a(f"├── {f['name']}  ({f['tests']} tests, {format_kb(f['bytes'])}, {f['lines']:,} lines)")
    a("```")
    a("")
    a(f"**Total lines of test code:** {total_lines:,}")
    a("")
    a(f"*Generated {md['generated']} by generate_test_verification.py*")
    a("")
    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--package-root", default=".", help="Dart package root (default: cwd)")
    ap.add_argument("--package-name", default=None)
    ap.add_argument("--version", default=None)
    ap.add_argument("--test-dir", default="test")
    ap.add_argument(
        "--pattern",
        default="test_*.dart",
        help="Glob under test-dir (cell: test_*.dart)",
    )
    ap.add_argument(
        "--also-test-star",
        action="store_true",
        help="Also include *_test.dart (packages/cell_tissue naming)",
    )
    ap.add_argument("--out", default="TEST_VERIFICATION.md")
    ap.add_argument("--run-tests", action="store_true")
    ap.add_argument("--coverage", action="store_true", help="dart test --coverage + format_coverage if available")
    ap.add_argument("--lcov", default="coverage/lcov.info")
    args = ap.parse_args()

    root = Path(args.package_root).resolve()
    test_dir = root / args.test_dir
    files = sorted(test_dir.glob(args.pattern))
    extra = list(test_dir.glob("test_*.dart")) + list(test_dir.glob("*_test.dart"))
    for p in extra:
        if p not in files:
            files.append(p)
    files = sorted(set(files), key=lambda p: p.name)
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

    run = None
    if args.run_tests or args.coverage:
        cov_dir = root / "coverage" if args.coverage else None
        run = run_dart_test(root, files, cov_dir)
        if args.coverage:
            lcov_path = root / args.lcov
            if not lcov_path.exists():
                dart = resolve_cmd("dart")
                fmt = [
                    dart,
                    "pub",
                    "global",
                    "run",
                    "coverage:format_coverage",
                    "--lcov",
                    "--in=coverage",
                    f"--out={args.lcov}",
                    "--report-on=lib",
                ]
                print("+", " ".join(fmt), file=sys.stderr)
                subprocess.run(fmt, cwd=root)

    cov_rows = parse_lcov(root / args.lcov)

    md = {
        "generated": dt.date.today().isoformat(),
        "package": {
            "title": f"{name} package",
            "name": name,
            "version": version,
            "test_dir": args.test_dir,
            "root": package_display_root(name),
        },
        "files": analyzed,
        "run": run,
        "coverage": cov_rows,
    }
    out = root / args.out if not Path(args.out).is_absolute() else Path(args.out)
    out.write_text(render(md), encoding="utf-8")
    print(f"wrote {out} ({sum(f['tests'] for f in analyzed)} tests, {len(analyzed)} files)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Publishes the Mitosis workspace to pub.dev in dependency order:
#
#   cell -> cell_flow -> cell_tissue -> mitosis (umbrella)
#
# Why this script exists:
#   pub evaluates `.pubignore` patterns against git-relative paths, so the
#   workspace-root `.pubignore` rule `/packages/**` (which keeps the umbrella
#   package archive lean) also hides every workspace member. Publishing a
#   member therefore requires the rule to be neutralised temporarily; it is
#   restored automatically afterwards, before the umbrella package itself is
#   published.
#
# Usage:
#   tool/release-publish.sh --dry-run   # validate all four packages
#   tool/release-publish.sh             # publish all four (interactive)
# ------------------------------------------------------------------------------
set -euo pipefail
cd "$(dirname "$0")/.."

ROOT_IGNORE=.pubignore
BACKUP="$ROOT_IGNORE.release-bak"

restore() {
  if [[ -f "$BACKUP" ]]; then
    mv -f "$BACKUP" "$ROOT_IGNORE"
    echo "restored $ROOT_IGNORE"
  fi
}
trap restore EXIT

dry_run=false
for arg in "$@"; do
  [[ "$arg" == "--dry-run" ]] && dry_run=true
done

if [[ "$dry_run" != true ]]; then
  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "error: working tree has uncommitted tracked changes;" >&2
    echo "       commit or stash before publishing" >&2
    exit 1
  fi
fi

cp "$ROOT_IGNORE" "$BACKUP"
sed -i 's|^/packages/\*\*|/packages/_none_/**|' "$ROOT_IGNORE"
echo "neutralised the root /packages/** rule for member publishing"

for pkg in packages/cell packages/cell_flow packages/cell_tissue; do
  echo "── publishing $pkg ──"
  if [[ "$dry_run" == true ]]; then
    (cd "$pkg" && dart pub publish --dry-run) || echo "(dry-run reported issues for $pkg)"
  else
    (cd "$pkg" && dart pub publish)
  fi
done

restore
trap - EXIT
echo "── publishing mitosis (umbrella) ──"
if [[ "$dry_run" == true ]]; then
  dart pub publish --dry-run || echo "(dry-run reported issues for mitosis)"
else
  dart pub publish
fi

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/omarchy"
DEST_REPO="${FLUENT_OMARCHY_REPO:-https://github.com/alfonsobries/fluent-omarchy.git}"
WORKDIR="${FLUENT_OMARCHY_WORKDIR:-$(mktemp -d)}"
CLEANUP=1
if [[ -n "${FLUENT_OMARCHY_WORKDIR:-}" ]]; then
  CLEANUP=0
fi

if [[ ! -f "$SRC/manifest.json" ]]; then
  echo "publish-omarchy-plugin: missing $SRC/manifest.json" >&2
  exit 1
fi

git clone --depth 1 "$DEST_REPO" "$WORKDIR"
rsync -a --delete \
  --exclude '.git' \
  --exclude '__pycache__' \
  --exclude '*.pyc' \
  "$SRC/" "$WORKDIR/"

cd "$WORKDIR"
if [[ -z "$(git status --porcelain)" ]]; then
  echo "fluent-omarchy is already up to date."
  [[ $CLEANUP -eq 1 ]] && rm -rf "$WORKDIR"
  exit 0
fi

git add -A
VERSION="$(python3 -c 'import json; print(json.load(open("manifest.json"))["version"])')"
git -c user.name="${GIT_AUTHOR_NAME:-github-actions[bot]}" \
    -c user.email="${GIT_AUTHOR_EMAIL:-github-actions[bot]@users.noreply.github.com}" \
    commit -m "chore: sync Fluent $VERSION from fluent-app"

git push origin HEAD
echo "Published Fluent $VERSION to $DEST_REPO"
[[ $CLEANUP -eq 1 ]] && rm -rf "$WORKDIR"

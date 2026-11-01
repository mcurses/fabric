#!/bin/bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")" && pwd)
DEST=${1:-"$PWD"}
mkdir -p "$DEST"
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT
openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 -md sha256 -in "$ROOT/fabric-max-drop.zip.enc" -out "$TMP"
EXPECTED=$(awk '{print $1}' "$ROOT/archive.sha256")
ACTUAL=$(openssl dgst -sha256 "$TMP" | awk '{print $NF}')
[[ "$ACTUAL" == "$EXPECTED" ]] || { echo 'Archive checksum mismatch; not extracting.'; exit 1; }
unzip -n "$TMP" -d "$DEST"
echo "Read $DEST/fabric-max-drop/START-HERE.txt, then run play.command."

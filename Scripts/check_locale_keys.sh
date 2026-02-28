#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

extract_keys() {
  local f="$1"
  rg -o 'L\["[^"]+"\]' "$f" | sed 's/L\["//;s/"\]//' | sort -u
}

tmp_en=$(mktemp)
tmp_cn=$(mktemp)
tmp_tw=$(mktemp)
trap 'rm -f "$tmp_en" "$tmp_cn" "$tmp_tw"' EXIT

extract_keys "Locales/enUS.lua" > "$tmp_en"
extract_keys "Locales/zhCN.lua" > "$tmp_cn"
extract_keys "Locales/zhTW.lua" > "$tmp_tw"

echo "enUS: $(wc -l < "$tmp_en")"
echo "zhCN: $(wc -l < "$tmp_cn")"
echo "zhTW: $(wc -l < "$tmp_tw")"

echo

echo "[Missing in enUS compared to zhCN]"
comm -23 "$tmp_cn" "$tmp_en" || true

echo

echo "[Missing in zhTW compared to enUS]"
comm -23 "$tmp_en" "$tmp_tw" || true

echo

echo "[Missing in zhCN compared to enUS]"
comm -23 "$tmp_en" "$tmp_cn" || true

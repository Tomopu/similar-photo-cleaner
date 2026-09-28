#!/usr/bin/env bash
# SimilarPhotoCleaner/AppIcon.icon（Icon Composer 形式）から、見た目ごとのプレビュー PNG を書き出す。
# アイコンの編集は Xcode 付属の Icon Composer で AppIcon.icon を開いて行う。
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
ictool="/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool"
out="$root/docs/figure/icon"
mkdir -p "$out"
for appearance in Light Dark ClearLight ClearDark TintedLight TintedDark; do
  "$ictool" "$root/SimilarPhotoCleaner/AppIcon.icon" --export-preview iOS "$appearance" 512 512 1 "$out/$appearance.png" >/dev/null
done
echo "exported to $out"

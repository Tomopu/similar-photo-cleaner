#!/usr/bin/env bash
# docs/figure/src/*.mmd から docs/figure/*.png を生成する（要: @mermaid-js/mermaid-cli, Google Chrome）
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root/docs/figure"
for src in src/*.mmd; do
  name="$(basename "$src" .mmd)"
  mmdc -i "$src" -o "$name.png" -b white -s 2 -p "$root/scripts/puppeteer-config.json"
done

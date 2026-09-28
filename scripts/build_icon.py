#!/usr/bin/env python3
"""アプリアイコンを SVG で描き、iOS 用の 1024px PNG（標準・ダーク・色合い）に書き出す。

モチーフ: 重なった2枚の写真。奥の1枚（オレンジ＝削除候補）が少し傾き、
手前の1枚（残すベスト）に青いチェックが付く。

使い方: python3 scripts/build_icon.py
  → docs/design/icon/*.svg と SimilarPhotoCleaner/Assets.xcassets/AppIcon.appiconset/*.png
"""

import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SVG_DIR = ROOT / "docs" / "design" / "icon"
ICONSET = ROOT / "SimilarPhotoCleaner" / "Assets.xcassets" / "AppIcon.appiconset"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
SIZE = 1024

VARIANTS = {
    # name: 背景、写真の縁、手前の写真（空・山・太陽）、奥の写真、チェック
    "AppIcon": dict(
        bg=("#F6F6F2", "#E3E3DD"), frame="#FFFFFF", shadow="rgba(20,22,26,0.22)",
        sky=("#9FC3D9", "#D6E4EA"), far="#4F8FA1", near="#1F4E5C", sun="#F2B38A",
        back=("#F7B27A", "#E0784A"), check="#2F6FEB", tick="#FFFFFF",
    ),
    "AppIcon-Dark": dict(
        bg=("#343A45", "#1E2228"), frame="#ECEEF2", shadow="rgba(0,0,0,0.5)",
        sky=("#86AFC7", "#BCD2DC"), far="#3E7C8F", near="#17404B", sun="#F2B38A",
        back=("#F28A3C", "#B85A24"), check="#4F8AF7", tick="#FFFFFF",
    ),
    "AppIcon-Tinted": dict(
        bg=("#1A1A1A", "#000000"), frame="#E6E6E6", shadow="rgba(0,0,0,0.5)",
        sky=("#8C8C8C", "#B4B4B4"), far="#5E5E5E", near="#2E2E2E", sun="#D0D0D0",
        back=("#7A7A7A", "#4A4A4A"), check="#FFFFFF", tick="#1A1A1A",
    ),
}


def svg(c: dict) -> str:
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="{c['bg'][0]}"/><stop offset="1" stop-color="{c['bg'][1]}"/>
    </linearGradient>
    <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="{c['sky'][0]}"/><stop offset="1" stop-color="{c['sky'][1]}"/>
    </linearGradient>
    <linearGradient id="back" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="{c['back'][0]}"/><stop offset="1" stop-color="{c['back'][1]}"/>
    </linearGradient>
    <filter id="shadow" x="-30%" y="-30%" width="160%" height="160%">
      <feDropShadow dx="0" dy="28" stdDeviation="30" flood-color="{c['shadow']}"/>
    </filter>
    <clipPath id="photo"><rect x="312" y="330" width="400" height="400" rx="28"/></clipPath>
  </defs>

  <rect width="1024" height="1024" fill="url(#bg)"/>

  <!-- 全体を中央に寄せる -->
  <g transform="translate(512 512) scale(1.12) translate(-512 -512) translate(-44 -14)">

  <!-- 奥の写真（削除候補）: 右上へずらして傾ける -->
  <g transform="rotate(12 600 420)" filter="url(#shadow)">
    <rect x="352" y="192" width="480" height="480" rx="52" fill="{c['frame']}"/>
    <rect x="384" y="224" width="416" height="416" rx="30" fill="url(#back)"/>
  </g>

  <!-- 手前の写真（残す1枚） -->
  <g filter="url(#shadow)">
    <rect x="280" y="298" width="464" height="464" rx="56" fill="{c['frame']}"/>
  </g>
  <g clip-path="url(#photo)">
    <rect x="312" y="330" width="400" height="400" fill="url(#sky)"/>
    <circle cx="610" cy="440" r="46" fill="{c['sun']}"/>
    <path d="M312 640 L430 520 L520 600 L600 540 L712 640 L712 730 L312 730 Z" fill="{c['far']}"/>
    <path d="M312 690 L420 610 L520 670 L640 600 L712 650 L712 730 L312 730 Z" fill="{c['near']}"/>
  </g>

  <!-- 残す印 -->
  <g filter="url(#shadow)">
    <circle cx="716" cy="730" r="112" fill="{c['check']}"/>
  </g>
  <path d="M662 732 L700 770 L774 692" fill="none" stroke="{c['tick']}" stroke-width="34" stroke-linecap="round" stroke-linejoin="round"/>
  </g>
</svg>
"""


def render(svg_path: Path, png_path: Path) -> None:
    html = svg_path.with_suffix(".render.html")
    html.write_text(
        f'<!doctype html><html><head><style>html,body{{margin:0;padding:0;overflow:hidden}}</style></head>'
        f'<body><img src="{svg_path.name}" width="{SIZE}" height="{SIZE}" style="display:block"></body></html>',
        encoding="utf-8",
    )
    try:
        subprocess.run(
            [CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
             f"--window-size={SIZE},{SIZE}", f"--screenshot={png_path}", html.as_uri()],
            check=True, capture_output=True,
        )
    finally:
        html.unlink()
    # App Store の要件: アルファなしの RGB
    subprocess.run(["magick", str(png_path), "-background", "black", "-alpha", "remove", "-alpha", "off", f"PNG24:{png_path}"], check=True)


def main() -> None:
    SVG_DIR.mkdir(parents=True, exist_ok=True)
    for name, colors in VARIANTS.items():
        svg_path = SVG_DIR / f"{name}.svg"
        svg_path.write_text(svg(colors), encoding="utf-8")
        render(svg_path, ICONSET / f"{name}.png")
        print(f"rendered {name}.png")


if __name__ == "__main__":
    main()

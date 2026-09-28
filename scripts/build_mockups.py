#!/usr/bin/env python3
"""docs/design/mockups の画面モックアップから PNG とデザインキャンバス用ファイルを作る。

使い方:
  python3 scripts/build_mockups.py                 # docs/figure/ui/{dark,light}/*.png を生成
  python3 scripts/build_mockups.py --canvas DIR    # DIR/project/ にキャンバス用 .dc.html と canvas.json も書き出す
"""

import argparse
import datetime
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MOCKUPS = ROOT / "docs" / "design" / "mockups"
SCREENS = MOCKUPS / "screens"
PNG_DIR = ROOT / "docs" / "figure" / "ui"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
WIDTH, HEIGHT = 390, 844

# キャンバス上の並び（行ごと）と行タイトル
ROWS = [
    ("はじめる", ["01-onboarding", "02-scanning", "03-home"]),
    ("整理する", ["04-similar-groups", "05-compare", "06-swipe", "07-screenshots"]),
    ("削除・実績・設定", ["08-tray", "09-done", "10-history", "11-settings"]),
]
THEMES = [("dark", "ダーク"), ("light", "ライト")]


def themed(html: str, theme: str) -> str:
    return html if theme == "dark" else html.replace('class="screen"', 'class="screen theme-light"', 1)


def render_png(src: Path, out: Path) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            CHROME,
            "--headless=new",
            "--disable-gpu",
            "--hide-scrollbars",
            "--force-device-scale-factor=2",
            f"--window-size={WIDTH},{HEIGHT}",
            f"--screenshot={out}",
            src.as_uri(),
        ],
        check=True,
        capture_output=True,
    )


def canvas_name(stem: str, theme: str) -> str:
    if theme == "light":
        return f"{stem}-light.dc.html"
    return "Main.dc.html" if stem == ROWS[0][1][0] else f"{stem}.dc.html"


def to_dc_html(src: Path, css: str, theme: str) -> str:
    html = themed(src.read_text(encoding="utf-8"), theme)
    title = re.search(r"<title>(.*?)</title>", html, re.S).group(1)
    body = re.search(r"<body>\s*(.*?)\s*</body>", html, re.S).group(1)
    body = re.sub(
        r'href="(\d\d-[a-z-]+)\.html"',
        lambda m: f'href="{canvas_name(m.group(1), theme)}"',
        body,
    )
    props = json.dumps({"$preview": {"width": WIDTH, "height": HEIGHT}})
    return f"""<!doctype html>
<html lang="ja">
<head>
<meta charset="utf-8">
<title>{title}</title>
<script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
<style>
{css}
</style>
</helmet>
{body}
</x-dc>
<script type="text/x-dc" data-dc-script data-props='{props}'>
class Component extends DCLogic {{
renderVals() {{
return {{}};
}}
}}
</script>
</body>
</html>
"""


def write_canvas(canvas_dir: Path) -> None:
    project = canvas_dir / "project"
    project.mkdir(parents=True, exist_ok=True)
    css = (MOCKUPS / "common.css").read_text(encoding="utf-8")
    boards, order, notes = {}, [], {}
    y = 0
    for row_index, (row_title, stems) in enumerate(ROWS):
        notes[f"row{row_index + 1}"] = {
            "x": 0,
            "y": y - 300,
            "text": row_title,
            "kind": "title1",
            "maxW": len(stems) * WIDTH + (len(stems) - 1) * 80,
        }
        for theme, theme_label in THEMES:
            for col, stem in enumerate(stems):
                src = SCREENS / f"{stem}.html"
                name = canvas_name(stem, theme)
                (project / name).write_text(to_dc_html(src, css, theme), encoding="utf-8")
                title = re.search(r"<title>(.*?)</title>", src.read_text(encoding="utf-8")).group(1)
                boards[name] = {"x": col * (WIDTH + 80), "y": y, "w": WIDTH, "h": HEIGHT, "title": f"{title}（{theme_label}）"}
                order.append(name)
            y += HEIGHT + 120
        y += 280
    index = {
        "v": 3,
        "createdOnFiles": {"v": 1, "at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")},
        "title": "SimilarPhotoCleaner UIデザイン",
        "launch": {"view": "canvas"},
        "pages": [],
        "boards": boards,
        "order": order,
        "notes": notes,
        "designSystems": [],
    }
    (project / "canvas.json").write_text(json.dumps(index, ensure_ascii=False, indent=2), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--canvas", type=Path, help="キャンバス用ファイルの出力先")
    args = parser.parse_args()
    for src in sorted(SCREENS.glob("[0-9]*.html")):
        for theme, _ in THEMES:
            tmp = src.with_name(f".render-{theme}-{src.name}")
            tmp.write_text(themed(src.read_text(encoding="utf-8"), theme), encoding="utf-8")
            try:
                render_png(tmp, PNG_DIR / theme / f"{src.stem}.png")
            finally:
                tmp.unlink()
        print(f"rendered {src.stem}.png (dark, light)")
    if args.canvas:
        write_canvas(args.canvas)
        print(f"canvas files written to {args.canvas / 'project'}")


if __name__ == "__main__":
    main()

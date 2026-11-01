#!/usr/bin/env python3
"""杉並区公式サイトの「すぎなみアートウォーク」関連ページを定期チェックする。

- 前回の内容（monitor/snapshots/*.txt）と比べ、変化があれば GitHub Issue を作って通知する
- 変化がなければ docs/data/v1/content.json の checkedAt（最終確認日）を今日にする
- 変化があったときは checkedAt を更新しない（人が内容を確認してデータを直すまで）
- 配布場所に座標がなければ、国土地理院の住所検索で補う

GitHub Actions（.github/workflows/check-official.yml）から実行する。
"""
import datetime
import difflib
import json
import os
import re
import subprocess
import sys
import tempfile
import urllib.parse
import urllib.request
from html import unescape
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SNAP_DIR = ROOT / "monitor" / "snapshots"
CONTENT = ROOT / "docs" / "data" / "v1" / "content.json"
BASE = "https://www.city.suginami.tokyo.jp"

TARGETS = [
    ("event", "イベントページ", f"{BASE}/s092/event/27274.html", "html"),
    ("novelty-pdf", "ノベルティ配布場所一覧（PDF）", f"{BASE}/documents/27274/haihu.pdf", "pdf"),
    ("sign-27857", "阿佐ケ谷駅南口駅前広場", f"{BASE}/s092/27857.html", "html"),
    ("sign-27859", "阿佐ヶ谷児童遊園", f"{BASE}/s092/27859.html", "html"),
    ("sign-27860", "阿佐谷にしはら公園", f"{BASE}/s092/27860.html", "html"),
    ("sign-27861", "桃園川緑道", f"{BASE}/s092/27861.html", "html"),
    ("sign-27863", "高円寺中央公園", f"{BASE}/s092/27863.html", "html"),
    ("sign-27866", "馬橋公園", f"{BASE}/s092/27866.html", "html"),
    ("sign-27867", "阿佐谷地域区民センター（阿佐谷けやき公園）", f"{BASE}/s092/27867.html", "html"),
]

JST = datetime.timezone(datetime.timedelta(hours=9))
TODAY = datetime.datetime.now(JST).strftime("%Y-%m-%d")
UA = "Mozilla/5.0 (compatible; suginami-artwalk-checker; +https://github.com/J-mat0131/suginami-artwalk)"


def fetch(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


def html_text(raw: bytes) -> str:
    html = raw.decode("utf-8", errors="replace")
    start = html.find("ここから本文です")
    end = html.find("ここまでが本文です")
    if start != -1 and end > start:
        html = html[start:end]
    html = re.sub(r"(?is)<(script|style)\b.*?</\1>", "", html)
    html = re.sub(r"(?i)<br\s*/?>|</(p|div|li|tr|h\d|table)>", "\n", html)
    html = re.sub(r"<[^>]+>", " ", html)
    return normalize(unescape(html))


def pdf_text(raw: bytes) -> str:
    with tempfile.NamedTemporaryFile(suffix=".pdf") as f:
        f.write(raw)
        f.flush()
        out = subprocess.run(["pdftotext", "-layout", f.name, "-"], capture_output=True, check=True)
    return normalize(out.stdout.decode("utf-8", errors="replace"))


def normalize(text: str) -> str:
    lines = [re.sub(r"[ \t　]+", " ", l).strip() for l in text.splitlines()]
    return "\n".join(l for l in lines if l) + "\n"


def gsi_geocode(address: str):
    q = re.sub(r"^東京都", "", address)
    q = re.sub(r"(\d+-\d+-\d+)-\d+$", r"\1", q)  # 部屋番号を除く
    url = "https://msearch.gsi.go.jp/address-search/AddressSearch?q=" + urllib.parse.quote(q)
    try:
        results = json.loads(fetch(url))
    except Exception as e:  # noqa: BLE001
        print(f"geocode failed: {address}: {e}")
        return None
    for r in results:
        lon, lat = r["geometry"]["coordinates"]
        if "杉並区" in r["properties"].get("title", ""):
            return round(lat, 6), round(lon, 6)
    return None


def create_issue(title: str, body: str) -> None:
    # 同じタイトルの未解決 Issue があれば作らない
    existing = subprocess.run(
        ["gh", "issue", "list", "--state", "open", "--search", f'in:title "{title}"', "--json", "title"],
        capture_output=True, text=True)
    if existing.returncode == 0 and any(i["title"] == title for i in json.loads(existing.stdout or "[]")):
        print(f"issue already open: {title}")
        return
    with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False) as f:
        f.write(body)
        path = f.name
    subprocess.run(["gh", "issue", "create", "--title", title, "--body-file", path], check=True)


def main() -> int:
    SNAP_DIR.mkdir(parents=True, exist_ok=True)
    changes, failures, baselines = [], [], []

    for key, label, url, kind in TARGETS:
        try:
            raw = fetch(url)
            text = html_text(raw) if kind == "html" else pdf_text(raw)
        except Exception as e:  # noqa: BLE001
            failures.append((label, url, str(e)))
            continue
        if len(text.strip()) < 30:
            failures.append((label, url, "本文を読み取れませんでした"))
            continue
        snap = SNAP_DIR / f"{key}.txt"
        if not snap.exists():
            snap.write_text(text, encoding="utf-8")
            baselines.append(label)
            continue
        old = snap.read_text(encoding="utf-8")
        if old != text:
            diff = "".join(difflib.unified_diff(
                old.splitlines(keepends=True), text.splitlines(keepends=True),
                fromfile="前回", tofile="今回", n=1))
            changes.append((label, url, diff))
            snap.write_text(text, encoding="utf-8")

    # 配布場所の座標を補う
    content = json.loads(CONTENT.read_text(encoding="utf-8"))
    geocoded = 0
    for spot in content["novelty"]["spots"]:
        if spot.get("lat") is None or spot.get("lon") is None:
            pos = gsi_geocode(spot["address"])
            if pos:
                spot["lat"], spot["lon"] = pos
                geocoded += 1

    if not changes and not failures:
        content["checkedAt"] = TODAY
    CONTENT.write_text(json.dumps(content, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    if changes:
        body = [
            "杉並区公式サイトの「すぎなみアートウォーク」関連ページに更新がありました。",
            "内容を確認し、必要ならアプリのデータ（`docs/data/v1/content.json`）を更新してください。",
            "データを直すまで、アプリの「最終確認日」は更新されません。",
            "",
        ]
        for label, url, diff in changes:
            if len(diff) > 6000:
                diff = diff[:6000] + "\n…（長いため省略）\n"
            body += [f"### {label}", url, "", "```diff", diff.rstrip(), "```", ""]
        create_issue(f"公式サイトに更新があります（{TODAY}）", "\n".join(body))

    if failures:
        body = ["次のページを取得できませんでした。一時的な障害の可能性があります。", ""]
        body += [f"- {label}: {url}（{err}）" for label, url, err in failures]
        create_issue(f"公式サイトの取得に失敗しました（{TODAY}）", "\n".join(body))

    print(f"changes={len(changes)} failures={len(failures)} baselines={len(baselines)} geocoded={geocoded} checkedAt={content['checkedAt']}")
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as f:
            f.write(f"- 変化: {len(changes)}件\n- 取得失敗: {len(failures)}件\n- 初回記録: {len(baselines)}件\n"
                    f"- 座標を補完: {geocoded}件\n- 最終確認日: {content['checkedAt']}\n")
    print(f"::notice title=Official check::changes={len(changes)} failures={len(failures)} baselines={len(baselines)} geocoded={geocoded} checkedAt={content['checkedAt']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Insert one identical language bar into all nine READMEs, and check they still match.

The bar is generated rather than hand-written into each file: nine hand-written bars is
nine chances to drop a language, and the one that gets dropped is the one nobody reads.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path("/Users/admin/Documents/Steve/SalaryTicker")

# The app's own order, from AppLanguage.
LANGS = [
    ("README.md", "English"),
    ("README.zh-CN.md", "简体中文"),
    ("README.ja.md", "日本語"),
    ("README.ko.md", "한국어"),
    ("README.es.md", "Español"),
    ("README.fr.md", "Français"),
    ("README.de.md", "Deutsch"),
    ("README.pt.md", "Português"),
    ("README.ms.md", "Bahasa Melayu"),
]

BAR_MARK = "<!-- language-bar -->"


def bar_for(current: str) -> str:
    parts = [
        f"**{name}**" if fname == current else f"[{name}]({fname})"
        for fname, name in LANGS
    ]
    return f"{BAR_MARK}\n" + " · ".join(parts) + f"\n{BAR_MARK}"


def insert(path: pathlib.Path, fname: str) -> str:
    text = path.read_text()
    bar = bar_for(fname)

    # Replace an existing bar rather than stacking a second one.
    existing = re.compile(re.escape(BAR_MARK) + r".*?" + re.escape(BAR_MARK), re.S)
    if existing.search(text):
        path.write_text(existing.sub(bar, text, count=1))
        return "replaced"

    lines = text.split("\n")
    for i, line in enumerate(lines):
        if line.startswith("# "):
            lines.insert(i + 1, "\n" + bar)
            path.write_text("\n".join(lines))
            return "inserted"
    return "NO H1 — skipped"


def shape(path: pathlib.Path) -> dict:
    text = path.read_text()
    body = existing_stripped = re.sub(
        re.escape(BAR_MARK) + r".*?" + re.escape(BAR_MARK), "", text, flags=re.S
    )
    return {
        "headings": len(re.findall(r"^#{1,6} ", body, re.M)),
        "levels": "".join(str(len(m)) for m in re.findall(r"^(#{1,6}) ", body, re.M)),
        "fences": body.count("```"),
        "table_rows": len(re.findall(r"^\|", body, re.M)),
        # Paragraph count catches the drift the rest of this misses: a paragraph added to
        # the English and not to the translations leaves every heading and table intact.
        "paragraphs": len([
            l for l in body.split("\n")
            # The whitespace after the bullet matters: without it a paragraph opening with
            # **bold** is counted as a list item, and inconsistently between languages.
            if l.strip() and not re.match(r"^\s*(#|\||<|```|([-*+]|\d+[.)])\s)", l)
        ]),
        "images": sorted(re.findall(r'src="([^"]+)"', body)),
        "links": sorted(set(re.findall(r"\]\(([^)]+)\)", body))),
    }


if __name__ == "__main__":
    check_only = "--check" in sys.argv

    if not check_only:
        for fname, _ in LANGS:
            p = ROOT / fname
            print(f"  {fname:22} {insert(p, fname) if p.exists() else 'MISSING'}")
        print()

    reference = shape(ROOT / "README.md")
    print(f"  {'file':22} {'head':>5} {'fence':>6} {'rows':>5} {'para':>5}  structure")
    ok = True
    for fname, _ in LANGS:
        p = ROOT / fname
        if not p.exists():
            print(f"  {fname:22} MISSING")
            ok = False
            continue
        s = shape(p)
        problems = []
        if s["levels"] != reference["levels"]:
            problems.append("heading levels differ")
        if s["fences"] != reference["fences"]:
            problems.append("code fences differ")
        if s["table_rows"] != reference["table_rows"]:
            problems.append("table rows differ")
        if s["paragraphs"] != reference["paragraphs"]:
            problems.append(f"paragraphs differ: {s['paragraphs']} vs {reference['paragraphs']}")
        if s["images"] != reference["images"]:
            problems.append(f"images differ: {s['images']}")
        # Links may legitimately differ only by the language-bar targets, which are stripped.
        if s["links"] != reference["links"]:
            problems.append(f"links differ: {sorted(set(s['links']) ^ set(reference['links']))}")
        flag = "ok" if not problems else "; ".join(problems)
        if problems:
            ok = False
        print(f"  {fname:22} {s['headings']:>5} {s['fences']:>6} {s['table_rows']:>5} "
              f"{s['paragraphs']:>5}  {flag}")
    sys.exit(0 if ok else 1)

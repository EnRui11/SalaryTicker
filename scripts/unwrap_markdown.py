#!/usr/bin/env python3
"""Join hard-wrapped paragraphs back into one line each.

Markdown folds a newline inside a paragraph into a space. For English that is invisible,
which is why wrapping at 90 columns is a common house style. For Chinese it is not: nothing
separates 累计， from 以及 in print, so the fold inserts a space that does not belong there.

Joining rule: a space between the two halves, unless both sides of the break are full-width
characters -- then the two lines are simply run together, which is what the text was always
supposed to read as.

Code blocks, tables, headings, HTML and list markers are left exactly where they are; only
the continuation lines of a paragraph or a list item are pulled up.
"""
import pathlib
import re
import sys
import unicodedata

BULLET = re.compile(r"^(\s*)([-*+]|\d+[.)])\s")
STRUCTURAL = ("|", "#", ">", "<", "```", "~~~")


def wide(ch: str) -> bool:
    """Full-width enough that print puts no space beside it."""
    return unicodedata.east_asian_width(ch) in ("W", "F")


def join(left: str, right: str) -> str:
    if left and right and wide(left[-1]) and wide(right[0]):
        return left + right
    return left + " " + right


def structural(line: str) -> bool:
    stripped = line.lstrip()
    return not stripped or stripped.startswith(STRUCTURAL) or bool(BULLET.match(line))


def unwrap(text: str) -> str:
    out: list[str] = []
    in_fence = False

    for line in text.split("\n"):
        if line.lstrip().startswith(("```", "~~~")):
            in_fence = not in_fence
            out.append(line)
            continue

        if in_fence or structural(line):
            out.append(line)
            continue

        # A continuation line: pull it up onto whatever it continues.
        if out and out[-1].strip() and not out[-1].lstrip().startswith(("|", "#", "<")) \
                and not out[-1].lstrip().startswith(("```", "~~~")):
            out[-1] = join(out[-1].rstrip(), line.strip())
        else:
            out.append(line)

    return "\n".join(out)


if __name__ == "__main__":
    for name in sys.argv[1:]:
        path = pathlib.Path(name)
        before = path.read_text()
        after = unwrap(before)

        # Nothing may be lost: the two must hold the same words in the same order.
        norm = lambda s: re.sub(r"\s+", " ", s).strip()
        if norm(before.replace("\n", " ")) != norm(after.replace("\n", " ")):
            # CJK joins deliberately drop a space, so compare with spaces removed too.
            if norm(before).replace(" ", "") != norm(after).replace(" ", ""):
                print(f"  {name}: REFUSED — content would change")
                continue

        path.write_text(after)
        print(f"  {name}: {len(before.splitlines())} → {len(after.splitlines())} lines")

#!/usr/bin/env python3
"""Rebuild the launcher's emoji table.

    cd "$(mktemp -d)" && npm pack unicode-emoji-json emojilib
    for f in *.tgz; do mkdir "${f%.tgz}"; tar xzf "$f" -C "${f%.tgz}"; done
    python3 ~/vela/tools/emoji-tsv.py ~/vela/packages/quickshell/.config/quickshell/vela/assets

Names and order come from unicode-emoji-json (Unicode's emoji-test.txt, skin
tones left out), search words from emojilib. A word that only repeats the name
is dropped, and each emoji keeps at most eight, which is what keeps the file
near 130 KB.
"""
import glob
import json
import sys

KEEP = 8

out_dir = sys.argv[1]
pkg = lambda name, path: glob.glob(f"{name}-*/package/{path}")[0]
by = json.load(open(pkg("unicode-emoji-json", "data-by-emoji.json")))
order = json.load(open(pkg("unicode-emoji-json", "data-ordered-emoji.json")))
words = json.load(open(pkg("emojilib", "dist/emoji-en-US.json")))
versions = {n: json.load(open(pkg(n, "package.json")))["version"] for n in ("unicode-emoji-json", "emojilib")}

lines = [
    "# The emoji the launcher's `:` search offers: glyph, name, search words.",
    f"# Names and order from unicode-emoji-json {versions['unicode-emoji-json']} (Unicode's emoji-test.txt),",
    f"# search words from emojilib {versions['emojilib']}; both MIT, Copyright (c) 2019 and 2014",
    "# Mu-An Chiou -- see emoji.LICENSE. Skin-tone variants are left out: the",
    "# base glyph is the one a search should find.",
    "# Rebuilt by tools/emoji-tsv.py in the repository.",
]
for glyph in order:
    info = by.get(glyph)
    if not info:
        continue
    name = info["name"]
    in_name = set(name.lower().replace(":", "").split())
    extra = []
    for w in words.get(glyph, []):
        w = w.replace("_", " ").lower().strip()
        if not w or w == name.lower() or w in extra or "\t" in w or "," in w:
            continue
        if all(part in in_name for part in w.split()):
            continue
        extra.append(w)
        if len(extra) >= KEEP:
            break
    lines.append(f"{glyph}\t{name}\t{', '.join(extra)}")

open(f"{out_dir}/emoji.tsv", "w").write("\n".join(lines) + "\n")
licence = "emoji.tsv is built from two packages by the same author, both under the MIT\nLicense.\n"
for n in ("unicode-emoji-json", "emojilib"):
    licence += f"\n---- {n} ----\n\n" + open(pkg(n, "LICENSE")).read().strip() + "\n"
open(f"{out_dir}/emoji.LICENSE", "w").write(licence)
print(f"{len(lines)} lines")

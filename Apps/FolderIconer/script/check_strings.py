#!/usr/bin/env python3
"""Checks that every string the compiler extracted is a key in Resources/Localizable.xcstrings.

xcodebuild writes *.stringsdata per source file but never adds keys to the catalog. Run after
`script/build.sh FolderIconer Debug`. `--add` inserts missing keys as English source strings.
"""
import glob
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CATALOG = os.path.join(ROOT, "Resources", "Localizable.xcstrings")
BUILD = os.environ.get("MACFITKIT_BUILD_DIR", os.path.expanduser("~/Library/Caches/MacFitKit/Monorepo"))
OBJECTS = os.path.join(BUILD, "Build/Intermediates.noindex/FolderIconer.build/Debug/FolderIconer.build/Objects-normal/*/*.stringsdata")


def extracted():
    keys = set()
    files = glob.glob(OBJECTS)
    if not files:
        sys.exit(f"No .stringsdata under {os.path.dirname(OBJECTS)}. Run script/build.sh FolderIconer Debug first.")
    for path in files:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        # Files deleted since the last clean build leave their stringsdata behind.
        if not os.path.exists(data.get("source", "")):
            continue
        keys.update(entry["key"] for entry in data.get("tables", {}).get("Localizable", []))
    return keys


def main():
    with open(CATALOG, encoding="utf-8") as f:
        catalog = json.load(f)
    keys = extracted()
    missing = sorted(keys - catalog["strings"].keys())
    unused = sorted(k for k, v in catalog["strings"].items() if k not in keys and v.get("extractionState") != "manual")
    if "--add" in sys.argv and missing:
        for key in missing:
            catalog["strings"][key] = {}
        catalog["strings"] = dict(sorted(catalog["strings"].items()))
        with open(CATALOG, "w", encoding="utf-8") as f:
            f.write(json.dumps(catalog, indent=2, ensure_ascii=False, separators=(",", " : ")) + "\n")
        print(f"Added {len(missing)} keys to {os.path.relpath(CATALOG)}.")
        missing = []
    for key in unused:
        print(f"warning: not used by any source file: {key!r}")
    for key in missing:
        print(f"missing: {key!r}")
    if missing:
        sys.exit(f"{len(missing)} extracted strings are not in {os.path.relpath(CATALOG)}. Re-run with --add.")
    print(f"{len(keys)} extracted strings, all in the catalog.")


if __name__ == "__main__":
    main()

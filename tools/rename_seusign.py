#!/usr/bin/env python3
"""Rename this fork's app identity from "SEUsign" to "SEUsign".

The logo and packaging stay as they are; only the name changes.
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)

SKIP_DIRS = {".git", "_build", "packages", "Payload", "Zsign", "NimbleKit",
             "AltSourceKit", "IDeviceKitten"}
TEXT_EXT = {
    ".swift", ".m", ".h", ".plist", ".json", ".yml", ".yaml", ".md", ".txt",
    ".xcstrings", ".pbxproj", ".xcconfig", ".xcscheme", ".strings", ".sh",
    ".py", ".xml", ".entitlements", ".modulemap",
}
TEXT_NAMES = {"Makefile"}
PAIRS = [("SEUsign", "SEUsign"), ("seusign", "seusign")]


def decode(data):
    if data[:2] in (b"\xff\xfe", b"\xfe\xff"):
        return data.decode("utf-16"), "utf-16"
    try:
        return data.decode("utf-8"), "utf-8"
    except UnicodeDecodeError:
        return None, None


def main():
    changed = []
    for dirpath, dirnames, filenames in os.walk("."):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for name in filenames:
            path = os.path.join(dirpath, name)
            if os.path.splitext(name)[1] not in TEXT_EXT and name not in TEXT_NAMES:
                continue
            raw = open(path, "rb").read()
            text, encoding = decode(raw)
            if text is None or ("SEUsign" not in text and "seusign" not in text):
                continue
            new = text
            for old, rep in PAIRS:
                new = new.replace(old, rep)
            if new == text:
                continue
            with open(path, "wb") as fh:
                fh.write(new.encode(encoding))
            changed.append(path)

    xcconfig = open("Feather.xcconfig", encoding="utf-8").read()
    old, new = "FEATHER_PROJECT_VERSION=3.0.0", "FEATHER_PROJECT_VERSION=3.1.0"
    if old in xcconfig:
        xcconfig = xcconfig.replace(old, new)
        open("Feather.xcconfig", "w", encoding="utf-8", newline="").write(xcconfig)
        changed.append("Feather.xcconfig")

    if not changed:
        print("nothing to rename")
        return 0
    print("\n".join(sorted(changed)))
    print("%d files updated" % len(changed), file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())

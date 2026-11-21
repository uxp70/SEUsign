#!/usr/bin/env python3
"""One-shot rebrand of this Feather fork into Sigil.

Run from the repository root. Rewrites the app name, the logo (app icons,
glyph, document icon, alternate icons) and the app's interior branding:
defaults namespace, URL scheme, temp/documents prefixes, accent colour,
appearance palette, about/settings links, manifest, docs and packaging.
"""
import glob
import json
import os
import re

from PIL import Image, ImageChops, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)

APP = "Sigil"


def read(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def write(path, text):
    with open(path, "w", encoding="utf-8", newline="") as fh:
        fh.write(text)


def sub(path, pairs):
    s = read(path)
    for old, new in pairs:
        if old not in s:
            raise SystemExit("pattern not found in %s: %r" % (path, old[:60]))
        s = s.replace(old, new)
    write(path, s)


# ---------------------------------------------------------------- Swift source
SWIFT_PAIRS = [
    ('"Feather.', '"Sigil.'),
    ('"feather.', '"sigil.'),
    ("#848ef9", "#C8873A"),
    ("FeatherTweak", "SigilTweak"),
    ("FeatherEntitlement", "SigilEntitlement"),
    ("FeatherSigning_", "SigilSigning_"),
    ("FeatherImport_", "SigilImport_"),
    ("FeatherInstall_", "SigilInstall_"),
    ("FeatherDownloads", "SigilDownloads"),
    ("FeatherManualDownload", "SigilManualDownload"),
    ("// Documents/Feather/", "// Documents/Sigil/"),
]

for path in glob.glob("Feather/**/*.swift", recursive=True):
    s = read(path)
    out = s
    for old, new in SWIFT_PAIRS:
        out = out.replace(old, new)
    if out != s:
        write(path, out)

# URL scheme: new scheme accepted alongside the legacy one
sub("Feather/FeatherApp.swift", [
    ('if url.scheme == "feather" {', 'if url.scheme == "sigil" || url.scheme == "feather" {'),
    ('DataCache(name: "thewonderofyou.Feather.datacache")', 'DataCache(name: "sigil.datacache")'),
])

# Appearance: brand palette replaces the upstream one
tint_path = "Feather/Views/Settings/Appearance/AppearanceTintColorView.swift"
tint = read(tint_path)
new_tints = """\tprivate let _tintOptions: [(name: String, hex: String)] = [
\t\t("Brass", \t\t\t"#C8873A"),
\t\t("Ink", \t\t\t\t"#25303D"),
\t\t("Copper", \t\t\t"#B5623B"),
\t\t("Sea Glass", \t\t"#3E9A87"),
\t\t("Ember", \t\t\t"#D0472F"),
\t\t("Slate", \t\t\t"#5C6B7A"),
\t\t("Olive", \t\t\t"#7A8B4A"),
\t\t("Dusty Rose", \t\t"#C0707F")
\t]"""
tint, n = re.subn(
    r"\tprivate let _tintOptions: \[\(name: String, hex: String\)\] = \[.*?\n\t\]",
    lambda _m: new_tints,
    tint,
    flags=re.S,
)
if n != 1:
    raise SystemExit("tint palette not replaced")
write(tint_path, tint)

# About: keep credits, drop the upstream sponsor banner, link to this repository
about_path = "Feather/Views/Settings/About/AboutView.swift"
about = read(about_path)
about = about.replace(
    '\t@State private var _credits: [CreditsModel] = [\n'
    '\t\t.init(name: "C", desc: "Developer", github: "claration"),\n'
    '\t\t.init(name: "Asami", desc: "Developer", github: "Nyasami"),\n',
    '\t@State private var _credits: [CreditsModel] = [\n'
    '\t\t.init(name: "C", desc: "Original Feather developer", github: "claration"),\n'
    '\t\t.init(name: "Asami", desc: "Original Feather developer", github: "Nyasami"),\n'
)
about = about.replace(
    '\tlet pngURL = URL(string: "https://sponsors.claration.dev/sponsors.png")!\n',
    '\tlet repositoryURL = URL(string: "https://github.com/uxp70/SEUsign")!\n'
)
about_section = (
    '\t\t\tNBSection(.localized("About")) {\n'
    '\t\t\t\tButton {\n'
    '\t\t\t\t\tUIApplication.open(repositoryURL)\n'
    '\t\t\t\t} label: {\n'
    '\t\t\t\t\tText(.localized("Source Code"))\n'
    '\t\t\t\t}\n'
    '\t\t\t} footer: {\n'
    '\t\t\t\tText(.localized("Sigil is an on-device signing app, built on the open source Feather project."))\n'
    '\t\t\t}\n'
)
about, n = re.subn(
    r'\n\t\t\tNBSection\(\.localized\("Sponsors"\)\) \{.*?\n\t\t\t\}\n',
    "\n" + about_section,
    about,
    flags=re.S,
)
if n != 1:
    raise SystemExit("sponsors section not replaced")
write(about_path, about)

# Settings: no upstream donation nag, feedback goes to this repository
settings_path = "Feather/Views/Settings/SettingsView.swift"
settings = read(settings_path)
settings = settings.replace(
    '\tprivate let _donationsUrl = "https://github.com/sponsors/claration"\n'
    '\tprivate let _githubUrl = "https://github.com/claration/Feather"',
    '\tprivate let _githubUrl = "https://github.com/uxp70/SEUsign"',
)
settings, n = re.subn(
    r"\t*#if !NIGHTLY && !DEBUG\n\t*SettingsDonationCellView\(site: _donationsUrl\)\n\t*#endif\n",
    "",
    settings,
)
if n != 1 or "_donationsUrl" in settings:
    raise SystemExit("donation cell not removed")
write(settings_path, settings)

# Sources: star prompt and recommended source point at this fork
sub("Feather/Views/Sources/SourcesView.swift", [
    ('"https://github.com/khcrysalis/Feather"', '"https://github.com/uxp70/SEUsign"'),
])
sub("Feather/Views/Sources/SourcesAddView.swift", [
    ("https://raw.githubusercontent.com/claration/Feather/refs/heads/main/app-repo.json",
     "https://raw.githubusercontent.com/uxp70/SEUsign/refs/heads/main/app-repo.json"),
    ("https://github.com/claration/Feather/issues",
     "https://github.com/uxp70/SEUsign/issues"),
])

# App icon picker: the generated Sigil artwork
sub("Feather/Views/Settings/App Icon/AppIconView.swift", [
    ('\t\t\tAltIcon(displayName: "Feather", author: "Samara", key: nil),\n'
     '\t\t\tAltIcon(displayName: "Feather (macOS)", author: "Samara", key: "V2Mac"),\n'
     '\t\t\tAltIcon(displayName: "Feather v1", author: "Samara", key: "V1"),\n'
     '\t\t\tAltIcon(displayName: "Feather v1 (macOS)", author: "Samara", key: "V1Mac"),\n'
     '\t\t\tAltIcon(displayName: "Feather v0", author: "Samara", key: "V0"),\n'
     '\t\t\tAltIcon(displayName: "Feather Donor", author: "Samara", key: "Donor")',
     '\t\t\tAltIcon(displayName: "Sigil", author: "Sigil", key: nil),\n'
     '\t\t\tAltIcon(displayName: "Sigil Mono", author: "Sigil", key: "V2Mac"),\n'
     '\t\t\tAltIcon(displayName: "Sigil Deep Sea", author: "Sigil", key: "V1"),\n'
     '\t\t\tAltIcon(displayName: "Sigil Slate", author: "Sigil", key: "V1Mac"),\n'
     '\t\t\tAltIcon(displayName: "Sigil Paper", author: "Sigil", key: "V0"),\n'
     '\t\t\tAltIcon(displayName: "Sigil Ember", author: "Sigil", key: "Donor")'),
    ('\t\t"Wingio": [\n\t\t\tAltIcon(displayName: "Feather", author: "Wingio", key: "Wing"),',
     '\t\t"Alternates": [\n\t\t\tAltIcon(displayName: "Sigil Mint", author: "Sigil", key: "Wing"),'),
])

# --------------------------------------------------------------- Localizations
cat_path = "Feather/Resources/Localizable.xcstrings"
cat = read(cat_path)
cat = cat.replace("github.com/khcrysalis/Feather", "github.com/uxp70/SEUsign")
cat = cat.replace("github.com/claration/Feather", "github.com/uxp70/SEUsign")
cat = cat.replace("Feather\u2019", "Sigil\u2019").replace("Feather", "Sigil").replace("feather", "sigil")
write(cat_path, cat)
json.loads(cat)  # must stay valid JSON

# ------------------------------------------------------------- Build metadata
sub("Feather/Resources/Info.plist", [
    ("\t\t\t\t<string>feather</string>\n",
     "\t\t\t\t<string>sigil</string>\n\t\t\t\t<string>feather</string>\n"),
])

sub("Feather.xcodeproj/project.pbxproj", [
    ("INFOPLIST_KEY_CFBundleDisplayName = SEUsign;", "INFOPLIST_KEY_CFBundleDisplayName = Sigil;"),
    ("INFOPLIST_KEY_CFBundleDisplayName = Feather;", "INFOPLIST_KEY_CFBundleDisplayName = Sigil;"),
    ('PRODUCT_NAME = "$(TARGET_NAME)";', "PRODUCT_NAME = Sigil;"),
    ('INFOPLIST_KEY_NSHumanReadableCopyright = "Copyright (c) 2024 Samara M";',
     'INFOPLIST_KEY_NSHumanReadableCopyright = "Copyright (c) 2024 Samara M, 2026 Sigil contributors";'),
])

# The shared scheme is UTF-16; keep it that way
scheme_path = "Feather.xcodeproj/xcshareddata/xcschemes/Feather.xcscheme"
with open(scheme_path, "rb") as fh:
    scheme = fh.read().decode("utf-16")
if 'BuildableName = "Feather.app"' not in scheme:
    raise SystemExit("scheme buildable name not found")
scheme = scheme.replace('BuildableName = "Feather.app"', 'BuildableName = "Sigil.app"')
with open(scheme_path, "wb") as fh:
    fh.write(scheme.encode("utf-16"))

xcconfig = read("Feather.xcconfig")
xcconfig, n = re.subn(r"FEATHER_PROJECT_VERSION=[^\n]*", "FEATHER_PROJECT_VERSION=3.0.0", xcconfig)
if n != 1:
    raise SystemExit("version not replaced")
write("Feather.xcconfig", xcconfig)

sub("Feather/Resources/AppIcon.icon/icon.json", [
    ("srgb:0.47451,0.52157,0.97647,1.00000", "srgb:0.10196,0.14118,0.19216,1.00000"),
    ("srgb:0.39928,0.44985,0.96515,1.00000", "srgb:0.03137,0.04314,0.06275,1.00000"),
])

# ------------------------------------------------------------------ Packaging
write("Makefile", """NAME := Sigil
SCHEME := Feather
PLATFORMS := iphoneos maccatalyst

TMP := $(TMPDIR)/$(NAME)
CERT_JSON_URL := https://backloop.dev/pack.json

.PHONY: all clean deps $(PLATFORMS)

all: $(PLATFORMS)

clean:
\trm -rf $(TMP)
\trm -rf packages
\trm -rf Payload

deps:
\trm -rf deps || true
\tmkdir -p deps

\tcurl -fsSL "$(CERT_JSON_URL)" -o cert.json
\tjq -r '.cert' cert.json > deps/server.crt
\tjq -r '.key1, .key2' cert.json > deps/server.pem
\tjq -r '.info.domains.commonName' cert.json > deps/commonName.txt


$(PLATFORMS): deps
\trm -rf _build

\t@if [ "$@" = "iphoneos" ]; then \\
\t\tDEST="generic/platform=iOS"; \\
\telse \\
\t\tDEST="generic/platform=macOS,variant=Mac Catalyst"; \\
\tfi; \\
\txcodebuild \\
\t\t-project Feather.xcodeproj \\
\t\t-scheme $(SCHEME) \\
\t\t-configuration Release \\
\t\t-destination "$$DEST" \\
\t\t-derivedDataPath $(TMP)/$@ \\
\t\t-skipPackagePluginValidation \\
\t\tCODE_SIGNING_ALLOWED=NO \\
\t\tALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES=NO

\tmkdir -p _build/Payload
\tcp -R _build/Applications/*.app _build/Payload/Sigil.app
\tchmod -R 0755 _build/Payload/Sigil.app
\tcodesign --force --sign - --timestamp=none _build/Payload/Sigil.app
\tcp deps/* _build/Payload/Sigil.app/ || true

\tmkdir -p packages

\t@if [ "$@" = "iphoneos" ]; then \\
\t\tditto -c -k --sequesterRsrc --keepParent _build/Payload "packages/Sigil.ipa"; \\
\telse \\
\t\tditto -c -k --sequesterRsrc --keepParent _build/Payload/Sigil.app "packages/Sigil_Catalyst.zip"; \\
\tfi
""")

sub(".github/workflows/release.yml", [
    ("packages/SEUsign.ipa", "packages/Sigil.ipa"),
    ("Payload/SEUsign.app", "Payload/Sigil.app"),
    ('echo "SEUsign v${VERSION}"', 'echo "Sigil v${VERSION}"'),
    ("name: SEUsign-packages", "name: Sigil-packages"),
    ("name: SEUsign v${{ env.VERSION }}", "name: Sigil v${{ env.VERSION }}"),
])
sub(".github/workflows/update_repo.yml", [("/SEUsign.ipa", "/Sigil.ipa")])
sub("codemagic.yaml", [("SEUsign iOS Release", "Sigil iOS Release")])
sub("bitrise.yml", [("Build SEUsign", "Build Sigil")])

for path in glob.glob(".github/ISSUE_TEMPLATE/*.yml"):
    s = read(path)
    s = s.replace("github.com/khcrysalis/Feather", "github.com/uxp70/SEUsign").replace("Feather", "Sigil")
    write(path, s)

# ------------------------------------------------------------------- Manifest
manifest = {
    "name": "Sigil Repository",
    "identifier": "sigil-repo",
    "iconURL": "https://raw.githubusercontent.com/uxp70/SEUsign/main/Feather/Resources/Assets.xcassets/AppIcon.appiconset/feather.png",
    "website": "https://github.com/uxp70/SEUsign",
    "apps": [
        {
            "name": "Sigil",
            "bundleIdentifier": "thewonderofyou.Feather",
            "developerName": "uxp70",
            "iconURL": "https://raw.githubusercontent.com/uxp70/SEUsign/main/Feather/Resources/Assets.xcassets/AppIcon.appiconset/feather.png",
            "localizedDescription": "Sigil is a free on-device iOS application manager and signer. Sign, install and manage your own apps straight from your device.",
            "subtitle": "On-device signing application",
            "tintColor": "c8873a",
            "versions": [
                {
                    "version": "3.0.0",
                    "date": "2026-11-21T00:00:00Z",
                    "size": 0,
                    "downloadURL": "https://github.com/uxp70/SEUsign/releases/download/v3.0.0/Sigil.ipa",
                }
            ],
            "appPermissions": {},
            "screenshotURLs": [],
            "version": "3.0.0",
            "versionDate": "2026-11-21T00:00:00Z",
            "size": 0,
            "downloadURL": "https://github.com/uxp70/SEUsign/releases/download/v3.0.0/Sigil.ipa",
        }
    ],
    "news": [
        {
            "title": "Sigil 3.0.0",
            "identifier": "sigil-300",
            "caption": "Sigil has a new name, a new seal for its icon, and a reworked interior: brass accent, refreshed appearance options and a cleaner settings screen. Under the hood it is still the same on-device signer, built on the open source Feather project.",
            "tintColor": "C8873A",
            "date": "2026-11-21",
            "notify": True,
        }
    ],
}
write("app-repo.json", json.dumps(manifest, indent=2) + "\n")

# ----------------------------------------------------------------------- Docs
write("README.md", """# Sigil

[![GitHub Release](https://img.shields.io/github/v/release/uxp70/SEUsign?include_prereleases)](https://github.com/uxp70/SEUsign/releases)
[![GitHub License](https://img.shields.io/github/license/uxp70/SEUsign?color=%23C8873A)](https://github.com/uxp70/SEUsign/blob/main/LICENSE)

<div align="center">

<img title="Sigil" alt="Sigil" height="180" src="Feather/Resources/Assets.xcassets/AppIcon.appiconset/feather.png">

**Sigil** --- on-device app signing for iOS.

A rebranded, independently maintained fork of [Feather](https://github.com/claration/Feather) by Samara.

</div>

## Features

- User friendly, and clean UI.
- Sign and install applications.
- Supports [AltStore](https://faq.altstore.io/distribute-your-apps/make-a-source#apps) repositories.
- View detailed information about apps and your certificates.
- Configurable signing options mainly for modifying the app, such as appearance and allowing support for the files app.
  - This includes patching apps for compatibility and Liquid Glass.
- Tweak support for advanced users, using [Ellekit](https://github.com/tealbathingsuit/ellekit) for injection.
  - Supports injecting `.deb` and `.dylib` files.
- No tracking or analytics, ensuring user privacy.
- Open source and free.

## Download

Visit [releases](https://github.com/uxp70/SEUsign/releases) and get the latest `.ipa`.

<a href="https://github.com/uxp70/SEUsign/releases/latest/download/Sigil.ipa" target="_blank">
   <img src="https://github.com/CelloSerenity/altdirect/blob/main/assets/png/Download_Blue.png?raw=true" alt="Download .ipa" width="200">
</a>

## Building

Sigil is an iOS app built with Xcode. To build it yourself:

1. Clone the repository (including submodules):
   ```
   git clone --recurse-submodules https://github.com/uxp70/SEUsign.git
   ```
2. Open `Feather.xcworkspace` in Xcode.
3. Select the `Feather` scheme and build for your device.

Alternatively, the GitHub Actions workflow (`.github/workflows/release.yml`) builds on a macOS runner and produces `packages/Sigil.ipa`. Trigger it manually from the Actions tab or by pushing a `v*` tag.

The Mac Catalyst build is packaged as `packages/Sigil_Catalyst.zip`.

## Translating

Sigil has translation support. All localizations are located in `Feather/Resources/Localizable.xcstrings`.

To add a new language, open Xcode and use the interface to add/contribute to languages.

## Acknowledgements

- [Samara (claration)](https://github.com/claration) - Original author of Feather
- [idevice](https://github.com/jkcoxson/idevice) - Backend for builds, used for communication with `installd`.
- [*.backloop.dev](https://backloop.dev/) - localhost with public CA signed SSL certificate
- [Vapor](https://github.com/vapor/vapor) - A server-side Swift HTTP web framework.
- [Zsign](https://github.com/zhlynn/zsign) - Allowing to sign on-device, reimplemented to work on other platforms such as iOS.
- [LiveContainer](https://github.com/LiveContainer/LiveContainer) - Fixes/some help
- [Nuke](https://github.com/kean/Nuke) - Image caching.
- [Asspp](https://github.com/Lakr233/Asspp) - Some code for setting up the http server.
- [plistserver](https://github.com/nekohaxx/plistserver) - Hosted on https://api.palera.in.

## License

This project is licensed under the GPL-3.0 license. See [LICENSE](LICENSE) for details.
""")

# ---------------------------------------------------------------------- Icons
S = 4  # supersampling
RUNE = [(0.596, 0.355), (0.402, 0.355), (0.402, 0.502),
        (0.596, 0.502), (0.596, 0.648), (0.400, 0.648)]


def hex_rgb(value):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def vgrad(size, top, bottom):
    top, bottom = hex_rgb(top), hex_rgb(bottom)
    img = Image.new("RGB", (size, size))
    draw = ImageDraw.Draw(img)
    for y in range(size):
        t = y / max(1, size - 1)
        draw.line([(0, y), (size, y)],
                  fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return img


def dgrad(size, start, end):
    start, end = hex_rgb(start), hex_rgb(end)
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))
            px[x, y] = tuple(int(start[i] + (end[i] - start[i]) * t) for i in range(3))
    return img


def rune_mask(size, stroke=0.072):
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    pts = [(p[0] * size, p[1] * size) for p in RUNE]
    width = int(stroke * size)
    draw.line(pts, fill=255, width=width, joint="curve")
    for pt in pts:
        r = width / 2
        draw.ellipse([pt[0] - r, pt[1] - r, pt[0] + r, pt[1] + r], fill=255)
    return mask


def disc_mask(size, radius=0.305):
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    c, r = size / 2, radius * size
    draw.ellipse([c - r, c - r, c + r, c + r], fill=255)
    return mask


def icon(size, bg_top, bg_bottom, disc_start, disc_end, disc_r=0.305, stroke=0.072):
    n = size * S
    base = vgrad(n, bg_top, bg_bottom)
    plate_mask = ImageChops.subtract(disc_mask(n, disc_r), rune_mask(n, stroke))
    base.paste(dgrad(n, disc_start, disc_end), (0, 0), plate_mask)
    return base.resize((size, size), Image.LANCZOS)


def mark(size, color="#FFFFFF", disc=True, disc_r=0.40, stroke=0.098):
    n = size * S
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    mask = ImageChops.subtract(disc_mask(n, disc_r), rune_mask(n, stroke)) if disc else rune_mask(n, stroke)
    img.paste(Image.new("RGBA", (n, n), hex_rgb(color) + (255,)), (0, 0), mask)
    return img.resize((size, size), Image.LANCZOS)


INK = ("#1A2431", "#080B10")
BRASS = ("#F0BE68", "#A9762A")
VARIANTS = {
    "V0": ("#F4EFE6", "#DCD2C2", "#1A2431", "#080B10"),
    "V1": ("#0E2B2A", "#06100F", "#E8D9B5", "#B99B5C"),
    "V1Mac": ("#101418", "#050708", "#3E5162", "#1A2430"),
    "V2Mac": ("#05070A", "#000000", "#FFFFFF", "#C9CDD2"),
    "Donor": ("#2A1707", "#0C0703", "#FFD08A", "#C2701C"),
    "Wing": ("#0B2A2E", "#04141A", "#8FE3D0", "#3C9A87"),
}


def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)


save(icon(1024, *INK, *BRASS), "Feather/Resources/Assets.xcassets/AppIcon.appiconset/feather.png")
save(icon(1024, "#0A0D12", "#000000", "#E9B25B", "#8F6120"),
     "Feather/Resources/Assets.xcassets/AppIcon.appiconset/feather_dark.png")
save(mark(1024, disc_r=0.305, stroke=0.072),
     "Feather/Resources/Assets.xcassets/AppIcon.appiconset/feather_tint.png")
save(icon(1024, *INK, *BRASS), "Feather/Resources/AppIcon.icon/Assets/feather.png")
save(mark(1024, disc_r=0.305, stroke=0.072), "Feather/Resources/AppIcon.icon/Assets/feather 5.png")
save(mark(256), "Feather/Resources/Assets.xcassets/Glyph.imageset/feather.png")
save(icon(256, *INK, *BRASS), "Feather/Resources/feather_extension.png")

for key, palette in VARIANTS.items():
    for scale, px in (("2x", 120), ("3x", 180)):
        save(icon(px, *palette), "Feather/Resources/Icons/Main/%s@%s.png" % (key, scale))

for scale, px in (("2x", 120), ("3x", 180)):
    save(icon(px, *VARIANTS["Wing"]), "Feather/Resources/Icons/Wing/Wing@%s.png" % scale)

print("Sigil rebrand applied")

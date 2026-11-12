#!/bin/zsh
# Signs a built DMG for Sparkle and writes the website's appcast.xml (what "Kiểm tra cập nhật" reads).
# Run after scripts/make-dmg.sh, with the website repo next to this one:
#
#   scripts/publish-update.sh                # uses build/Tether-<current version>.dmg
#   WEBSITE=../tether-website BASE_URL=https://tether.hoangphuc.io.vn scripts/publish-update.sh
#
# The EdDSA private key lives in this Mac's login Keychain (created once with Sparkle's generate_keys).
# Release notes come from the matching entry in <website>/lib/changelog.ts.
set -euo pipefail

ROOT="${0:A:h:h}"
WEBSITE="${WEBSITE:-$ROOT/../tether-website}"
BASE_URL="${BASE_URL:-https://tether.hoangphuc.io.vn}"
APPCAST="${APPCAST:-$WEBSITE/public/appcast.xml}"

# Sparkle's command line tools come with the resolved Swift package.
SIGN_UPDATE=$(find "$ROOT/build/DerivedData" "$HOME/Library/Developer/Xcode/DerivedData" \
  -path "*artifacts/sparkle/Sparkle/bin/sign_update" -type f 2>/dev/null | head -1)
[[ -x "$SIGN_UPDATE" ]] || { echo "sign_update not found: build the app once so Swift packages resolve." >&2; exit 1; }

APP="$ROOT/build/DerivedData/Build/Products/Release/Tether.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$APP/Contents/Info.plist")
MIN_OS=$(/usr/libexec/PlistBuddy -c "Print LSMinimumSystemVersion" "$APP/Contents/Info.plist")
DMG="${DMG:-$ROOT/build/Tether-$VERSION.dmg}"
[[ -f "$DMG" ]] || { echo "Missing $DMG: run scripts/make-dmg.sh first." >&2; exit 1; }

echo "▸ Signing $DMG…"
SIGNATURE=$("$SIGN_UPDATE" "$DMG")   # sparkle:edSignature="…" length="…"

echo "▸ Writing $APPCAST…"
python3 - "$WEBSITE/lib/changelog.ts" "$APPCAST" "$VERSION" "$BUILD" "$MIN_OS" "$BASE_URL" "$SIGNATURE" <<'PY'
import html, re, sys
from email.utils import formatdate

changelog, out, version, build, min_os, base, signature = sys.argv[1:]
src = open(changelog, encoding="utf-8").read()

# Find this version's block in lib/changelog.ts.
m = re.search(r'version:\s*"' + re.escape(version) + r'"(.*?)changes:\s*\[(.*?)\]\s*,\s*\}', src, re.S)
if not m:
    sys.exit(f"Version {version} not found in {changelog}: add its release notes first.")
title = re.search(r'title:\s*"([^"]*)"', m.group(1))
labels = {"new": "Mới", "improved": "Cải thiện", "fixed": "Sửa lỗi"}
items = re.findall(r'\{\s*kind:\s*"(\w+)",\s*text:\s*"((?:[^"\\]|\\.)*)"\s*\}', m.group(2))

# Two columns (label | text) so long lines wrap under their own text, not under the label.
notes = ['<style>body{font:13px -apple-system,sans-serif;line-height:1.5}'
         'ul{list-style:none;padding:0;margin:0}'
         'li{display:grid;grid-template-columns:76px 1fr;column-gap:10px;margin:6px 0}'
         'b{font-weight:600}</style>']
if title:
    notes.append(f"<h3>{html.escape(title.group(1))}</h3>")
notes.append("<ul>")
for kind, text in items:
    notes.append(f"<li><b>{labels.get(kind, kind)}</b><span>{html.escape(text)}</span></li>")
notes.append("</ul>")

xml = f'''<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Tether</title>
    <link>{base}/</link>
    <language>vi</language>
    <item>
      <title>Tether {version}</title>
      <pubDate>{formatdate(localtime=True)}</pubDate>
      <sparkle:version>{build}</sparkle:version>
      <sparkle:shortVersionString>{version}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>{min_os}</sparkle:minimumSystemVersion>
      <sparkle:releaseNotesLink xml:lang="vi">{base}/whats-new/</sparkle:releaseNotesLink>
      <description><![CDATA[{"".join(notes)}]]></description>
      <enclosure url="{base}/downloads/Tether-{version}.dmg" type="application/octet-stream" {signature} />
    </item>
  </channel>
</rss>
'''
# Inline notes are what Sparkle shows; drop the link so it doesn't load the full page instead.
xml = xml.replace(f'      <sparkle:releaseNotesLink xml:lang="vi">{base}/whats-new/</sparkle:releaseNotesLink>\n', "")
open(out, "w", encoding="utf-8").write(xml)
print(f"  Tether {version} ({build}) · {len(items)} notes")
PY
echo "✓ $APPCAST"

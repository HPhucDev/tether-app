#!/bin/zsh
# Builds Tether (Release) and packages it as a drag-to-install DMG.
#
#   scripts/make-dmg.sh
#
# Optional, for public distribution (Gatekeeper-friendly):
#   DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)"   sign with Developer ID
#   NOTARY_PROFILE="tether-notary"                               notarize + staple
#     (create once with: xcrun notarytool store-credentials tether-notary --apple-id … --team-id …)
set -euo pipefail

ROOT="${0:A:h:h}"
BUILD="$ROOT/build"
DD="$BUILD/DerivedData"
STAGE="$BUILD/dmg-stage"
ASSETS="$ROOT/scripts/assets"
VOLNAME="Tether"

echo "▸ Building Release…"
SIGN_ARGS=()
if [[ -n "${DEVELOPER_ID:-}" ]]; then
  SIGN_ARGS=(CODE_SIGN_IDENTITY="$DEVELOPER_ID" CODE_SIGN_STYLE=Manual OTHER_CODE_SIGN_FLAGS="--timestamp")
fi
xcodebuild -project "$ROOT/Tether.xcodeproj" -scheme Tether -configuration Release \
  -destination "generic/platform=macOS" -derivedDataPath "$DD" "${SIGN_ARGS[@]}" build -quiet

APP="$DD/Build/Products/Release/Tether.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
DMG="$BUILD/Tether-$VERSION.dmg"
RW="$BUILD/Tether-rw.dmg"

echo "▸ Staging $VERSION…"
rm -rf "$STAGE" "$RW" "$DMG"
mkdir -p "$STAGE/.background"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
tiffutil -cathidpicheck "$ASSETS/dmg-background.png" "$ASSETS/dmg-background@2x.png" \
  -out "$STAGE/.background/background.tiff" >/dev/null

# Volume icon = app icon
if [[ -f "$APP/Contents/Resources/AppIcon.icns" ]]; then
  cp "$APP/Contents/Resources/AppIcon.icns" "$STAGE/.VolumeIcon.icns"
fi

echo "▸ Creating disk image…"
hdiutil create -volname "$VOLNAME" -srcfolder "$STAGE" -fs HFS+ -format UDRW -ov "$RW" >/dev/null
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$RW" | awk '/Apple_HFS/ {print $1}')
MOUNT="/Volumes/$VOLNAME"
sleep 1

if command -v SetFile >/dev/null && [[ -f "$MOUNT/.VolumeIcon.icns" ]]; then
  SetFile -a C "$MOUNT"
fi

echo "▸ Arranging window (Finder may ask for permission once)…"
if ! osascript <<OSA
tell application "Finder"
  tell disk "$VOLNAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 860, 520}
    set opts to the icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 112
    set text size of opts to 13
    set background picture of opts to file ".background:background.tiff"
    set position of item "Tether.app" of container window to {170, 200}
    set position of item "Applications" of container window to {490, 200}
    update without registering applications
    delay 1
    close
  end tell
end tell
OSA
then
  echo "  ⚠︎ Could not style the window (Finder automation denied). The DMG still works."
fi

chmod -Rf go-w "$MOUNT" || true
sync
hdiutil detach "$DEVICE" -quiet || hdiutil detach "$DEVICE" -force -quiet

echo "▸ Compressing…"
hdiutil convert "$RW" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
rm -f "$RW"

if [[ -n "${DEVELOPER_ID:-}" ]]; then
  codesign --sign "$DEVELOPER_ID" --timestamp "$DMG"
fi
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  echo "▸ Notarizing…"
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
fi

echo "✓ $DMG"

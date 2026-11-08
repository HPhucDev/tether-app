#!/bin/zsh
# Renders the DMG window background from background.html into scripts/assets/
# (800×580 @1x and @2x). Needs Google Chrome; only run it after editing the HTML.
# The PNGs are committed, so make-dmg.sh itself does not need Chrome.
#
#   scripts/dmg-art/render.sh
set -euo pipefail

HERE="${0:A:h}"
ASSETS="$HERE/../assets"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
PROFILE="$(mktemp -d)"
trap 'rm -rf "$PROFILE"' EXIT

render() {
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --user-data-dir="$PROFILE" \
    --force-device-scale-factor="$1" --window-size=800,580 \
    --screenshot="$2" "file://$HERE/background.html" >/dev/null 2>&1
}

render 1 "$ASSETS/dmg-background.png"
render 2 "$ASSETS/dmg-background@2x.png"
sips -g pixelWidth -g pixelHeight "$ASSETS"/dmg-background*.png | grep pixel

#!/bin/bash
# Last step for the generated images (needs ffmpeg).
#
# Flutter writes 32-bit PNGs. Google Play accepts only 24-bit PNGs with no
# alpha channel, so flatten them; the feature graphic is also drawn at 2x and
# scaled down here. The README banner is kept as a JPEG.
set -euo pipefail
cd "$(dirname "$0")/.."

flatten() { # file [filter]
  ffmpeg -y -loglevel error -i "$1" ${2:+-vf "$2"} -pix_fmt rgb24 "$1.tmp.png"
  mv "$1.tmp.png" "$1"
}

if [ -f store/play/feature-graphic.png ]; then
  flatten store/play/feature-graphic.png "scale=1024:500:flags=lanczos"
fi
for f in store/play/screenshots/screenshot-*.png; do
  [ -f "$f" ] && flatten "$f"
done
if [ -f docs/showcase.png ]; then
  ffmpeg -y -loglevel error -i docs/showcase.png -q:v 2 docs/showcase.jpg
  rm docs/showcase.png
fi
echo "Store graphics finished."

#!/bin/sh
# id: 4
# group: MAC
# desc: Package - build macOS .app and DMG
. "$(dirname "$0")/lib.sh"

set -e
enter

case "$(uname -s)" in
  Darwin*) ;;
  *)
    printf "FAIL  DMG packaging requires macOS\n"
    exit 1
    ;;
esac

exe=${MCTEXT_DMG_SOURCE:-dist/mctext/mctext}
[ -e "$exe.exe" ] && exe="$exe.exe"
if [ -z "${MCTEXT_DMG_SOURCE:-}" ]; then
  sh "$ROOT/ask.d/build-mac.sh"
fi
if [ ! -x "$exe" ]; then
  printf "FAIL  build first with task 2\n"
  exit 1
fi

case "$(uname -m)" in
  arm64)
    name=mctext_macos
    identifier=com.myridia.mctext.arm64
    display="McText (Apple silicon)"
    ;;
  *)
    name=mctext_macos_intel
    identifier=com.myridia.mctext.intel
    display="McText (Intel)"
    ;;
esac

app="$name.app"
dmg="dist/mctext/$name.dmg"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
ditto "$exe" "$app/Contents/MacOS/mctext"
cat > "$app/Contents/MacOS/mctext-launcher" <<'EOF'
#!/bin/sh
dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
[ -n "$DISPLAY" ] || DISPLAY=:0
DYLD_LIBRARY_PATH="$dir${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"
export DISPLAY DYLD_LIBRARY_PATH
exec "$dir/mctext" "$@"
EOF
exe_dir=${exe%/*}
[ "$exe_dir" = "$exe" ] && exe_dir=.
for dylib in "$exe_dir"/*.dylib; do
  [ -f "$dylib" ] || continue
  ditto "$dylib" "$app/Contents/MacOS/${dylib##*/}"
done
printf 'APPL????' > "$app/Contents/PkgInfo"
cat > "$app/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>McText</string>
  <key>CFBundleDisplayName</key>
  <string>$display</string>
  <key>CFBundleIdentifier</key>
  <string>$identifier</string>
  <key>CFBundleExecutable</key>
  <string>mctext-launcher</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleSignature</key>
  <string>????</string>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>LSMinimumSystemVersion</key>
  <string>11.0</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
EOF

chmod 755 "$app/Contents/MacOS/mctext" "$app/Contents/MacOS/mctext-launcher"
plutil -lint "$app/Contents/Info.plist"
test -x "$app/Contents/MacOS/mctext"
test -x "$app/Contents/MacOS/mctext-launcher"

stage=$(mktemp -d "${TMPDIR:-/tmp}/mctext-dmg-stage.XXXXXX")
trap 'rm -rf "$stage"' EXIT
ditto "$app" "$stage/$app"
ln -s /Applications "$stage/Applications"
hdiutil create -volname "mctext_macos" -srcfolder "$stage" -ov -format UDZO "$dmg"
hdiutil verify "$dmg"

mountpoint=$(mktemp -d "${TMPDIR:-/tmp}/mctext-dmg.XXXXXX")
trap 'hdiutil detach "$mountpoint" >/dev/null 2>&1 || true; rmdir "$mountpoint" 2>/dev/null || true; rm -rf "$stage"' EXIT
hdiutil attach -nobrowse -noautoopen -mountpoint "$mountpoint" "$dmg"
plutil -lint "$mountpoint/$app/Contents/Info.plist"
test -x "$mountpoint/$app/Contents/MacOS/mctext"
test -x "$mountpoint/$app/Contents/MacOS/mctext-launcher"
test -L "$mountpoint/Applications"
hdiutil detach "$mountpoint"
rmdir "$mountpoint"
rm -rf "$stage"
trap - EXIT

printf "ok    %s\n" "$dmg"

#!/bin/sh
. "$(dirname "$0")/lib.sh"

set -e
enter

fail() {
  printf 'FAIL  %s\n' "$1" >&2
  exit 1
}

lower_macos_target() {
  file=$1
  if command -v codesign >/dev/null 2>&1; then
    codesign --remove-signature "$file" >/dev/null 2>&1 || true
  fi
  if command -v xcrun >/dev/null 2>&1; then
    target="$file.macos-target"
    rm -f "$target"
    if xcrun vtool -show-build "$file" 2>/dev/null | grep -q 'LC_BUILD_VERSION'; then
      xcrun vtool -set-build-version macos 11.0 11.0 -replace -output "$target" "$file"
    elif xcrun vtool -show-build "$file" 2>/dev/null | grep -q 'LC_VERSION_MIN_MACOSX'; then
      xcrun vtool -set-version-min macos 11.0 11.0 -replace -output "$target" "$file"
    else
      cp -f "$file" "$target"
    fi
    mv "$target" "$file"
    chmod 755 "$file"
    if command -v codesign >/dev/null 2>&1; then
      codesign --force --sign - "$file" >/dev/null 2>&1 || true
    fi
  fi
}

copy_mac_dylib() {
  name=$1
  formula=$2
  inspect=$3
  dep=$(otool -L "$inspect" 2>/dev/null | awk -v needle="$name" 'index($0, needle) { print $1; exit }')
  [ -n "$dep" ] || return 0
  prefix=$(brew --prefix "$formula" 2>/dev/null || true)
  for src in "$prefix/lib/$name" "/usr/local/opt/$formula/lib/$name" "/opt/homebrew/opt/$formula/lib/$name"; do
    [ -f "$src" ] || continue
    dst="dist/mctext/$name"
    rm -f "$dst"
    cp -f "$src" "$dst"
    chmod 755 "$dst"
    lower_macos_target "$dst"
    break
  done
}

bundle_sdl2=no
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    windows=yes
    setup_task=7
    compression=nil
    application=' :application-type :gui'
    ;;
  Darwin*)
    windows=no
    setup_task=8
    compression=t
    application=
    requested_backend=${MCTEXT_BACKEND:-${MCCLIM_BACKEND:-}}
    if [ "$requested_backend" != clx ]; then
      bundle_sdl2=yes
    fi
    ;;
  *)
    windows=no
    setup_task=1
    compression=t
    application=
    ;;
esac

if [ "$windows" = yes ] && [ -n "${USERPROFILE:-}" ] && command -v cygpath >/dev/null 2>&1; then
  home_posix=$(cygpath -u "$USERPROFILE") || fail 'cannot determine Windows home directory'
else
  home_posix="$HOME"
fi

command -v sbcl >/dev/null 2>&1 || fail "sbcl missing; run task $setup_task in ask.sh"

ql_setup=
for candidate in "$home_posix/quicklisp/setup.lisp" "$HOME/quicklisp/setup.lisp"; do
  [ -f "$candidate" ] || continue
  ql_setup="$candidate"
  break
done
[ -n "$ql_setup" ] || fail "Quicklisp missing; run task $setup_task in ask.sh (checked $home_posix/quicklisp/setup.lisp)"

ql_root=$(dirname "$ql_setup")
[ -e "$ql_root/local-projects/mctext" ] || fail "local project missing; run task $setup_task in ask.sh"
if [ "$windows" = yes ]; then
  [ -f vendor/sdl2/SDL2.dll ] || fail 'SDL2.dll missing; run task 7 in ask.sh'
  export PATH="$ROOT/vendor/sdl2:$PATH"
fi
printf 'ok    dependencies\n'

sh "$ROOT/ask.d/clean.sh"
mkdir -p bin dist/mctext

sbcl --non-interactive \
  --load "$ql_setup" \
  --eval '(defparameter cl-user::*auto-start* nil)' \
  --load main.lisp \
  --eval '(defparameter cl-user::*bundled-font-bytes* (with-open-file (s (cl-dejavu:font-pathname "DejaVuSans.ttf") :element-type (quote (unsigned-byte 8))) (let* ((n (file-length s)) (b (make-array n :element-type (quote (unsigned-byte 8))))) (read-sequence b s) b)))' \
  --eval "(sb-ext:save-lisp-and-die \"bin/mctext\" :toplevel (function clim-user:main) :executable t :compression $compression$application)"

exe=bin/mctext
[ -e "$exe.exe" ] && exe="$exe.exe"
case "$(uname -s)" in
  Darwin*)
    copy_mac_dylib libzstd.1.dylib zstd "$exe"
    lower_macos_target "$exe"
    ;;
esac
rm -f "dist/mctext/${exe##*/}"
cp -f "$exe" "dist/mctext/${exe##*/}"
if [ -f vendor/sdl2/SDL2.dll ]; then
  rm -f dist/mctext/SDL2.dll
  cp -f vendor/sdl2/SDL2.dll dist/mctext/SDL2.dll
fi
if [ "$bundle_sdl2" = yes ]; then
  copy_mac_dylib libSDL2-2.0.0.dylib sdl2 "$exe"
  copy_mac_dylib libSDL3.dylib sdl3 dist/mctext/libSDL2-2.0.0.dylib
  [ -f dist/mctext/libSDL2-2.0.0.dylib ] || fail 'libSDL2-2.0.0.dylib missing; run task 8 in ask.sh'
  [ -f dist/mctext/libSDL3.dylib ] || fail 'libSDL3.dylib missing; run task 8 in ask.sh'
fi
printf "ok    dist/mctext\n"

#!/bin/sh
# id: 2
# group: SETUP
# desc: Build - save SBCL executable
. "$(dirname "$0")/lib.sh"

set -e
enter

fail() {
  printf 'FAIL  %s\n' "$1" >&2
  exit 1
}

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    windows=yes
    setup_task=7
    compression=nil
    application=' :application-type :gui'
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
[ -f "$home_posix/quicklisp/setup.lisp" ] || fail "Quicklisp missing; run task $setup_task in ask.sh"
[ -e "$home_posix/quicklisp/local-projects/mctext" ] || fail "local project missing; run task $setup_task in ask.sh"
if [ "$windows" = yes ]; then
  [ -f vendor/sdl2/SDL2.dll ] || fail 'SDL2.dll missing; run task 7 in ask.sh'
  export PATH="$ROOT/vendor/sdl2:$PATH"
fi
printf 'ok    dependencies\n'

"$ROOT/ask.d/clean.sh"
mkdir -p bin dist/mctext

sbcl --non-interactive \
  --eval '(defparameter cl-user::*auto-start* nil)' \
  --load main.lisp \
  --eval '(defparameter cl-user::*bundled-font-bytes* (with-open-file (s (cl-dejavu:font-pathname "DejaVuSans.ttf") :element-type (quote (unsigned-byte 8))) (let* ((n (file-length s)) (b (make-array n :element-type (quote (unsigned-byte 8))))) (read-sequence b s) b)))' \
  --eval "(sb-ext:save-lisp-and-die \"bin/mctext\" :toplevel (function clim-user:main) :executable t :compression $compression$application)"

exe=bin/mctext
[ -e "$exe.exe" ] && exe="$exe.exe"
case "$(uname -s)" in
  Darwin*)
    if command -v otool >/dev/null 2>&1; then
      zstd_dep=$(otool -L "$exe" 2>/dev/null | awk '/libzstd/ {print $1; exit}')
      if [ -n "$zstd_dep" ]; then
        zstd_name=${zstd_dep##*/}
        zstd_prefix=$(brew --prefix zstd 2>/dev/null || true)
        for zstd_src in "$zstd_prefix/lib/$zstd_name" "/usr/local/opt/zstd/lib/$zstd_name" "/opt/homebrew/opt/zstd/lib/$zstd_name"; do
          [ -f "$zstd_src" ] || continue
          zstd_copy="dist/mctext/$zstd_name"
          rm -f "$zstd_copy"
          cp -f "$zstd_src" "$zstd_copy"
          chmod 755 "$zstd_copy"
          if command -v codesign >/dev/null 2>&1; then
            codesign --remove-signature "$zstd_copy" >/dev/null 2>&1 || true
          fi
          if command -v xcrun >/dev/null 2>&1; then
            zstd_target="$zstd_copy.macos-target"
            if xcrun vtool -show-build "$zstd_copy" 2>/dev/null | grep -q 'LC_BUILD_VERSION'; then
              xcrun vtool -set-build-version macos 11.0 11.0 -replace -output "$zstd_target" "$zstd_copy"
            elif xcrun vtool -show-build "$zstd_copy" 2>/dev/null | grep -q 'LC_VERSION_MIN_MACOSX'; then
              xcrun vtool -set-version-min macos 11.0 11.0 -replace -output "$zstd_target" "$zstd_copy"
            else
              rm -f "$zstd_target"
              cp -f "$zstd_copy" "$zstd_target"
            fi
            mv "$zstd_target" "$zstd_copy"
            chmod 755 "$zstd_copy"
            if command -v codesign >/dev/null 2>&1; then
              codesign --force --sign - "$zstd_copy" >/dev/null 2>&1 || true
            fi
          fi
          break
        done
      fi
    fi
    if command -v codesign >/dev/null 2>&1; then
      codesign --remove-signature "$exe" >/dev/null 2>&1 || true
    fi
    if command -v xcrun >/dev/null 2>&1; then
      target="$exe.macos-target"
      if xcrun vtool -show-build "$exe" 2>/dev/null | grep -q 'LC_BUILD_VERSION'; then
        xcrun vtool -set-build-version macos 11.0 11.0 -replace -output "$target" "$exe"
      elif xcrun vtool -show-build "$exe" 2>/dev/null | grep -q 'LC_VERSION_MIN_MACOSX'; then
        xcrun vtool -set-version-min macos 11.0 11.0 -replace -output "$target" "$exe"
      else
        rm -f "$target"
        cp -f "$exe" "$target"
      fi
      mv "$target" "$exe"
      chmod 755 "$exe"
      if command -v codesign >/dev/null 2>&1; then
        codesign --force --sign - "$exe" >/dev/null 2>&1 || true
      fi
    fi
    ;;
esac
rm -f "dist/mctext/${exe##*/}"
cp -f "$exe" "dist/mctext/${exe##*/}"
if [ -f vendor/sdl2/SDL2.dll ]; then
  rm -f dist/mctext/SDL2.dll
  cp -f vendor/sdl2/SDL2.dll dist/mctext/SDL2.dll
fi
printf "ok    dist/mctext\n"

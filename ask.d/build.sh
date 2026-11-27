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

dist_dir=dist/mctext

brew_lib_path() {
  name=$1
  formula=$2
  formulas=$2
  [ "$2" = sdl2 ] && formulas='sdl2 sdl2-compat'
  for f in $formulas; do
    prefix=$(brew --prefix "$f" 2>/dev/null || true)
    for base in "$prefix" "/opt/homebrew/opt/$f" "/usr/local/opt/$f"; do
      [ -n "$base" ] || continue
      [ -f "$base/lib/$name" ] || continue
      printf '%s\n' "$base/lib/$name"
      return 0
    done
  done
  return 1
}

prepare_mac_dylib() {
  file=$1
  name=$2
  command -v install_name_tool >/dev/null 2>&1 || return 0
  install_name_tool -id "@rpath/$name" "$file" >/dev/null 2>&1 || true
  install_name_tool -add_rpath @loader_path "$file" >/dev/null 2>&1 || true
}

relocate_mac_dylib_dep() {
  file=$1
  needle=$2
  command -v otool >/dev/null 2>&1 || return 0
  command -v install_name_tool >/dev/null 2>&1 || return 0
  old=$(otool -L "$file" 2>/dev/null | awk -v needle="$needle" 'index($0, needle) { print $1; exit }')
  [ -n "$old" ] || return 0
  case "$old" in
    @rpath/*) return 0 ;;
  esac
  install_name_tool -change "$old" "@rpath/${old##*/}" "$file" >/dev/null 2>&1 || true
}

clear_mac_rpaths() {
  file=$1
  command -v otool >/dev/null 2>&1 || return 0
  command -v install_name_tool >/dev/null 2>&1 || return 0
  for rp in $(otool -l "$file" 2>/dev/null | awk '/cmd LC_RPATH/ { found=1 } found && /path / { print $2; found=0 }'); do
    install_name_tool -delete_rpath "$rp" "$file" >/dev/null 2>&1 || true
  done
}

copy_dylib_file() {
  src=$1
  name=$2
  dst="$dist_dir/$name"
  rm -f "$dst"
  cp -f "$src" "$dst"
  chmod 755 "$dst"
  clear_mac_rpaths "$dst"
  prepare_mac_dylib "$dst" "$name"
  lower_macos_target "$dst"
}

copy_brew_dylib() {
  name=$1
  formula=$2
  src=$(brew_lib_path "$name" "$formula") || return 1
  copy_dylib_file "$src" "$name"
}

copy_mac_sdl_dylibs() {
  copied_sdl2=no
  sdl2_file=
  for name in libSDL2-2.0.0.dylib libSDL2-2.0.dylib libSDL2.dylib; do
    if copy_brew_dylib "$name" sdl2; then
      copied_sdl2=yes
      [ -n "$sdl2_file" ] || sdl2_file="$dist_dir/$name"
    fi
  done
  [ "$copied_sdl2" = yes ] || fail "SDL2 dylib missing; run task $setup_task in ask.sh"
  [ -n "$sdl2_file" ] || sdl2_file="$dist_dir/libSDL2.dylib"

  sdl3_dep=$(otool -L "$sdl2_file" 2>/dev/null | awk '/libSDL3/ { n=$1; sub(".*/", "", n); print n; exit }')
  [ -n "$sdl3_dep" ] || sdl3_dep=libSDL3.dylib
  copied_sdl3=no
  for name in "$sdl3_dep" libSDL3.dylib libSDL3.0.dylib libSDL3.0.0.dylib; do
    if copy_brew_dylib "$name" sdl3; then
      copied_sdl3=yes
    fi
  done
  [ "$copied_sdl3" = yes ] || fail "SDL3 dylib missing; run task $setup_task in ask.sh"

  for file in "$sdl2_file" "$dist_dir/libSDL2.dylib" "$dist_dir/libSDL2-2.0.dylib" "$dist_dir/libSDL2-2.0.0.dylib"; do
    [ -f "$file" ] || continue
    relocate_mac_dylib_dep "$file" libSDL3
    lower_macos_target "$file"
  done
}

bundle_sdl2=no
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    windows=yes
    setup_task=8
    compression=nil
    application=' :application-type :gui'
    ;;
  Darwin*)
    windows=no
    setup_task=1
    compression=t
    application=
    requested_backend=${MCTEXT_BACKEND:-${MCCLIM_BACKEND:-}}
    if [ "$requested_backend" != clx ]; then
      bundle_sdl2=yes
    fi
    ;;
  *)
    windows=no
    setup_task=5
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
  [ -f vendor/sdl2/SDL2.dll ] || fail 'SDL2.dll missing; run task 8 in ask.sh'
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
    copy_brew_dylib libzstd.1.dylib zstd || fail "libzstd.1.dylib missing; run task $setup_task in ask.sh"
    if command -v install_name_tool >/dev/null 2>&1; then
      clear_mac_rpaths "$exe"
      install_name_tool -add_rpath @executable_path "$exe" >/dev/null 2>&1 || true
      relocate_mac_dylib_dep "$exe" libzstd
      if [ "$bundle_sdl2" = yes ]; then
        relocate_mac_dylib_dep "$exe" libSDL2
      fi
    fi
    lower_macos_target "$exe"
    ;;
esac
rm -f "$dist_dir/${exe##*/}"
cp -f "$exe" "$dist_dir/${exe##*/}"
if [ -f vendor/sdl2/SDL2.dll ]; then
  rm -f "$dist_dir/SDL2.dll"
  cp -f vendor/sdl2/SDL2.dll "$dist_dir/SDL2.dll"
fi
if [ "$bundle_sdl2" = yes ]; then
  copy_mac_sdl_dylibs
fi
printf "ok    %s\n" "$dist_dir"

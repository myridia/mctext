#!/bin/sh
set -e

ROOT=$(cd "$(dirname "$0")" && pwd)
PLATFORM=$(uname -s)
WINDOWS=no
case "$PLATFORM" in
  MINGW*|MSYS*|CYGWIN*) WINDOWS=yes ;;
esac

if [ "$WINDOWS" = yes ]; then
  HOME_POSIX=$(cygpath -u "$HOME" 2>/dev/null || printf '%s' "$HOME")
else
  HOME_POSIX="$HOME"
fi

if [ "$WINDOWS" = no ] && [ "${MCTEXT_BACKEND:-${MCCLIM_BACKEND:-}}" != "sdl2" ]; then
  printf "ok    sdl2 skipped (not Windows)\n"
  exit 0
fi

fetch() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1" -o "$2"
  else
    wget -q "$1" -O "$2"
  fi
}

mcclim_dir="$HOME_POSIX/quicklisp/local-projects/mcclim"
if [ -f "$mcclim_dir/mcclim.asd" ] && grep -q ':version "1.0.0"' "$mcclim_dir/mcclim.asd"; then
  printf "ok    mcclim 1.0.0\n"
else
  tmp_dir=$(mktemp -d)
  fetch "https://codeberg.org/McCLIM/McCLIM/archive/1.0.0-koliada.tar.gz" "$tmp_dir/mcclim.tar.gz"
  rm -rf "$mcclim_dir"
  mkdir -p "$mcclim_dir"
  tar -xzf "$tmp_dir/mcclim.tar.gz" --strip-components=1 -C "$mcclim_dir"
  mkdir -p "$HOME_POSIX/quicklisp/local-projects"
  rm -rf "$tmp_dir"
  printf "ok    mcclim 1.0.0\n"
fi

if [ "$PLATFORM" = Darwin ]; then
  case "$(uname -m)" in
    arm64|aarch64)
      sdl2_dir="$HOME_POSIX/quicklisp/local-projects/cl-sdl2"
      spec="$sdl2_dir/src/spec/SDL2.aarch64-apple-darwin9.spec"
      if [ -f "$spec" ]; then
        printf "ok    cl-sdl2 aarch64 spec\n"
      else
        tmp_dir=$(mktemp -d)
        fetch "https://github.com/lispgames/cl-sdl2/archive/f107198b1da0c3c1d749d3daa22bc85dd816e79b.tar.gz" "$tmp_dir/cl-sdl2.tar.gz"
        rm -rf "$sdl2_dir"
        mkdir -p "$sdl2_dir"
        tar -xzf "$tmp_dir/cl-sdl2.tar.gz" --strip-components=1 -C "$sdl2_dir"
        rm -rf "$tmp_dir"
        [ -f "$spec" ] || { printf "FAIL  cl-sdl2 aarch64 spec missing\n" >&2; exit 1; }
        printf "ok    cl-sdl2 aarch64 spec\n"
      fi
      ;;
  esac
fi

if [ "$WINDOWS" = no ]; then
  printf "ok    SDL2.dll skipped (use the host libsdl2)\n"
  exit 0
fi

dll="$ROOT/vendor/sdl2/SDL2.dll"
if [ -f "$dll" ]; then
  cp "$dll" "$ROOT/SDL2.dll"
  printf "ok    SDL2.dll\n"
  exit 0
fi

mkdir -p "$ROOT/vendor/sdl2"
tmp_dir=$(mktemp -d)
fetch "https://github.com/libsdl-org/SDL/releases/download/release-2.32.8/SDL2-2.32.8-win32-x64.zip" "$tmp_dir/sdl2.zip"
if command -v unzip >/dev/null 2>&1; then
  unzip -q -o -j "$tmp_dir/sdl2.zip" 'SDL2.dll' -d "$ROOT/vendor/sdl2"
else
  win_zip=$(cygpath -w "$tmp_dir/sdl2.zip" 2>/dev/null || printf '%s' "$tmp_dir/sdl2.zip")
  win_dir=$(cygpath -w "$tmp_dir/sdl2" 2>/dev/null || printf '%s' "$tmp_dir/sdl2")
  powershell.exe -NoProfile -Command "Expand-Archive -Force '$win_zip' '$win_dir'"
  cp "$tmp_dir/sdl2/SDL2.dll" "$dll"
fi
cp "$dll" "$ROOT/SDL2.dll"
rm -rf "$tmp_dir"
printf "ok    SDL2.dll\n"

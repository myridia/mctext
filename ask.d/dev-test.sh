#!/bin/sh
. "$(dirname "$0")/lib.sh"

set -e
enter

platform=$1
backend=$2

case "$platform:$(uname -s)" in
  windows:MINGW*|windows:MSYS*|windows:CYGWIN*) ;;
  mac:Darwin*) ;;
  linux:Linux*) ;;
  *)
    printf "FAIL  dev test %s does not match this platform\n" "$platform"
    exit 1
    ;;
esac

if ! command -v sbcl >/dev/null 2>&1; then
  printf "FAIL  sbcl missing; run the matching setup task first\n"
  exit 1
fi
if [ ! -f "$ql_setup" ]; then
  printf "FAIL  quicklisp missing; run the matching setup task first\n"
  exit 1
fi

MCTEXT_BACKEND=$backend
export MCTEXT_BACKEND

case "$platform" in
  windows)
    PATH="$ROOT/vendor/sdl2:$PATH"
    export PATH
    ;;
  mac)
    for formula in sdl2 sdl3 zstd; do
      prefix=$(brew --prefix "$formula" 2>/dev/null || true)
      [ -n "$prefix" ] || continue
      [ -d "$prefix/lib" ] || continue
      DYLD_LIBRARY_PATH="$prefix/lib${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"
    done
    export DYLD_LIBRARY_PATH
    ;;
esac

printf "ok    dev test - %s (%s)\n" "$platform" "$backend"
printf "ok    no-window smoke test\n"
sbcl --script main.lisp -nw
printf "ok    GUI test - close the window\n"
sbcl --script main.lisp
printf "ok    dev test complete\n"

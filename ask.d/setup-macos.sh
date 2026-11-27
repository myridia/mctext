#!/bin/sh
# id: 1
# group: MAC
# desc: Setup - macOS (SDL2)
. "$(dirname "$0")/lib.sh"

enter

case "$(uname -s)" in
  Darwin*) ;;
  *) fail 'task 8 is macOS-only; use task 1 on Linux/FreeBSD or task 7 on Windows' ;;
esac

missing=0
check_base_requirements

has_sdl_lib() {
  name=$1
  formula=$2
  prefix=$(brew --prefix "$formula" 2>/dev/null || true)
  [ -f "$prefix/lib/$name" ] || [ -f "/opt/homebrew/opt/$formula/lib/$name" ] || [ -f "/usr/local/opt/$formula/lib/$name" ]
}

if has_sdl_lib libSDL2-2.0.0.dylib sdl2 && has_sdl_lib libSDL3.dylib sdl3; then
  printf 'ok    sdl2 + sdl3\n'
else
  printf 'miss  sdl2/sdl3\n'
  missing=1
fi

if [ "$missing" -ne 0 ]; then
  printf 'setup installing missing requirements\n'
  if [ -x /opt/homebrew/bin/brew ]; then
    brew_bin=/opt/homebrew/bin/brew
  elif [ -x /usr/local/bin/brew ]; then
    brew_bin=/usr/local/bin/brew
  elif command -v brew >/dev/null 2>&1; then
    brew_bin=brew
  else
    fail 'brew not found; install Homebrew from https://brew.sh'
  fi
  "$brew_bin" install sbcl curl sdl2 sdl3 || fail 'brew install failed'
fi

command -v sbcl >/dev/null 2>&1 || fail 'sbcl missing after install; open a new shell if PATH changed'
printf 'ok    sbcl\n'

if has_sdl_lib libSDL2-2.0.0.dylib sdl2 && has_sdl_lib libSDL3.dylib sdl3; then
  printf 'ok    sdl2 + sdl3\n'
else
  fail 'SDL2 or SDL3 missing after install; open a new shell if PATH changed'
fi

install_quicklisp
[ -f "$ql_setup" ] || fail 'quicklisp missing after install'
printf 'ok    quicklisp\n'

register_local_project
MCTEXT_BACKEND=sdl2 "$ROOT/sdl2.sh" || fail 'sdl2.sh failed'
verify_quickload
printf 'setup verifying sdl2 backend\n'
sbcl --non-interactive \
  --load "$ql_setup" \
  --eval '(ql:register-local-projects)' \
  --eval '(ql:quickload :mcclim-sdl2)' \
  --eval '(sb-ext:exit)' || fail 'quickload :mcclim-sdl2 failed'
printf 'ok    sdl2 backend\n'
printf 'ok    setup complete\n'

#!/bin/sh
# id: 8
# group: SETUP
# desc: Setup - macOS requirements
. "$(dirname "$0")/lib.sh"

enter

case "$(uname -s)" in
  Darwin*) ;;
  *) fail 'task 8 is macOS-only; use task 1 on Linux/FreeBSD or task 7 on Windows' ;;
esac

missing=0
check_base_requirements

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
  "$brew_bin" install sbcl curl || fail 'brew install failed'
fi

command -v sbcl >/dev/null 2>&1 || fail 'sbcl missing after install; open a new shell if PATH changed'
printf 'ok    sbcl\n'

install_quicklisp
[ -f "$ql_setup" ] || fail 'quicklisp missing after install'
printf 'ok    quicklisp\n'

register_local_project
"$ROOT/sdl2.sh" || fail 'sdl2.sh failed'
verify_quickload
printf 'ok    setup complete\n'

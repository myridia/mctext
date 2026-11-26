#!/bin/sh
# id: 7
# group: SETUP
# desc: Setup - Windows requirements
. "$(dirname "$0")/lib.sh"

enter

fail() {
  printf 'FAIL  %s\n' "$1" >&2
  exit 1
}

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) ;;
  *) fail 'task 7 is Windows-only; use task 1 on Linux/macOS/FreeBSD' ;;
esac

if [ -n "${USERPROFILE:-}" ] && command -v cygpath >/dev/null 2>&1; then
  home_posix=$(cygpath -u "$USERPROFILE") || fail 'cannot determine Windows home directory'
else
  home_posix="$HOME"
fi
[ -n "$home_posix" ] || fail 'cannot determine Windows home directory'

ql_setup="$home_posix/quicklisp/setup.lisp"
sbclrc="$home_posix/.sbclrc"
local_projects="$home_posix/quicklisp/local-projects"
missing=0

if command -v sbcl >/dev/null 2>&1; then
  printf 'ok    sbcl\n'
else
  printf 'miss  sbcl\n'
  missing=1
fi

if command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1; then
  printf 'ok    curl/wget\n'
else
  printf 'miss  curl/wget\n'
  missing=1
fi

if [ -f "$ql_setup" ]; then
  printf 'ok    quicklisp\n'
else
  printf 'miss  quicklisp\n'
  missing=1
fi

if [ "$missing" -ne 0 ]; then
  printf 'setup installing missing requirements\n'
  installed=0
  if command -v choco >/dev/null 2>&1 || command -v choco.exe >/dev/null 2>&1; then
    printf 'setup trying choco\n'
    if choco install sbcl -y; then
      installed=1
    else
      printf 'warn choco install failed\n'
    fi
  fi
  if [ "$installed" -eq 0 ] && command -v scoop >/dev/null 2>&1; then
    printf 'setup trying scoop\n'
    if scoop install sbcl curl; then
      installed=1
    else
      printf 'warn scoop install failed\n'
    fi
  fi
  if [ "$installed" -eq 0 ] && { command -v winget >/dev/null 2>&1 || command -v winget.exe >/dev/null 2>&1; }; then
    printf 'setup trying winget\n'
    if winget install --id SBCL.SBCL -e --accept-source-agreements --accept-package-agreements; then
      installed=1
    else
      printf 'warn winget install failed\n'
    fi
  fi
  [ "$installed" -eq 1 ] || fail 'no supported package manager could install sbcl; install it manually'
fi

command -v sbcl >/dev/null 2>&1 || fail 'sbcl missing after install; open a new shell if PATH changed'
printf 'ok    sbcl\n'

if [ ! -f "$ql_setup" ]; then
  printf 'setup installing quicklisp\n'
  tmp_dir=$(mktemp -d) || fail 'cannot create temporary directory'
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL https://beta.quicklisp.org/quicklisp.lisp -o "$tmp_dir/quicklisp.lisp" || fail 'quicklisp download failed'
  else
    wget -q https://beta.quicklisp.org/quicklisp.lisp -O "$tmp_dir/quicklisp.lisp" || fail 'quicklisp download failed'
  fi
  sbcl --non-interactive \
    --load "$tmp_dir/quicklisp.lisp" \
    --eval '(quicklisp-quickstart:install)' \
    --eval '(sb-ext:exit)' || fail 'quicklisp install failed'
  rm -rf "$tmp_dir"
  if ! grep -q 'quicklisp/setup.lisp' "$sbclrc" 2>/dev/null; then
    printf '%s\n' \
      ';;; The following lines added by ql:add-to-init-file:' \
      '#-quicklisp' \
      '(let ((quicklisp-init (merge-pathnames "quicklisp/setup.lisp"' \
      '                                       (user-homedir-pathname))))' \
      '  (when (probe-file quicklisp-init)' \
      '    (load quicklisp-init)))' >> "$sbclrc" || fail 'cannot update ~/.sbclrc'
  fi
fi

[ -f "$ql_setup" ] || fail 'quicklisp missing after install'
printf 'ok    quicklisp\n'

mkdir -p "$local_projects" || fail 'cannot create quicklisp/local-projects'
win_link=$(cygpath -w "$local_projects/mctext" 2>/dev/null || printf '%s' "$local_projects/mctext")
win_root=$(cygpath -w "$ROOT" 2>/dev/null || printf '%s' "$ROOT")
if [ -e "$local_projects/mctext" ] || [ -L "$local_projects/mctext" ]; then
  cmd.exe //c rmdir "$win_link" >/dev/null 2>&1 || rm -f "$local_projects/mctext" 2>/dev/null || fail 'cannot replace existing local project'
fi
if ! cmd.exe //c mklink /J "$win_link" "$win_root" >/dev/null 2>&1; then
  ln -sfn "$ROOT" "$local_projects/mctext" 2>/dev/null || fail 'cannot register local project; run shell as administrator or enable developer mode'
  [ -L "$local_projects/mctext" ] || fail 'cannot register local project; run shell as administrator or enable developer mode'
fi
printf 'ok    local project mctext\n'

"$ROOT/sdl2.sh" || fail 'sdl2.sh failed'
export PATH="$ROOT/vendor/sdl2:$PATH"
printf 'ok    SDL2 path\n'

printf 'setup verifying quickload\n'
sbcl --non-interactive \
  --load "$ql_setup" \
  --eval '(ql:register-local-projects)' \
  --eval '(ql:quickload :mctext)' \
  --eval '(sb-ext:exit)' || fail 'quickload :mctext failed'
printf 'ok    quickload\n'
printf 'ok    setup complete\n'

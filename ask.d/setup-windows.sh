#!/bin/sh
# id: 8
# group: WINDOWS
# desc: Setup - Windows (SDL2)
. "$(dirname "$0")/lib.sh"

enter

fail() {
  printf 'FAIL  %s\n' "$1" >&2
  exit 1
}

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) ;;
  *) fail 'task 7 is Windows-only; use task 1 on Linux/FreeBSD or task 8 on macOS' ;;
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

sbcl_ok=no
download_ok=no
quicklisp_ok=no

if command -v sbcl >/dev/null 2>&1; then
  printf 'ok    sbcl\n'
  sbcl_ok=yes
else
  printf 'miss  sbcl\n'
fi

if command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1; then
  printf 'ok    curl/wget\n'
  download_ok=yes
else
  printf 'miss  curl/wget\n'
fi

if [ -f "$ql_setup" ]; then
  printf 'ok    quicklisp\n'
  quicklisp_ok=yes
else
  printf 'miss  quicklisp\n'
fi

if [ "$sbcl_ok" = no ]; then
  printf 'setup installing sbcl\n'
  installed=no
  if command -v choco >/dev/null 2>&1 || command -v choco.exe >/dev/null 2>&1; then
    printf 'setup trying choco\n'
    choco install sbcl -y || printf 'warn choco install failed\n'
    command -v sbcl >/dev/null 2>&1 && installed=yes
  fi
  if [ "$installed" = no ] && command -v scoop >/dev/null 2>&1; then
    printf 'setup trying scoop\n'
    scoop install sbcl || printf 'warn scoop install failed\n'
    command -v sbcl >/dev/null 2>&1 && installed=yes
  fi
  if [ "$installed" = no ] && { command -v winget >/dev/null 2>&1 || command -v winget.exe >/dev/null 2>&1; }; then
    printf 'setup trying winget\n'
    winget install --id SBCL.SBCL -e --accept-source-agreements --accept-package-agreements || printf 'warn winget install returned non-zero\n'
    command -v sbcl >/dev/null 2>&1 && installed=yes
  fi
  [ "$installed" = yes ] || fail 'sbcl missing after install; open a new shell if PATH changed'
  printf 'ok    sbcl\n'
fi

if [ "$download_ok" = no ]; then
  printf 'setup installing curl\n'
  installed=no
  if command -v choco >/dev/null 2>&1 || command -v choco.exe >/dev/null 2>&1; then
    choco install curl -y || printf 'warn choco curl install failed\n'
    command -v curl >/dev/null 2>&1 && installed=yes
  fi
  if [ "$installed" = no ] && command -v scoop >/dev/null 2>&1; then
    scoop install curl || printf 'warn scoop curl install failed\n'
    command -v curl >/dev/null 2>&1 && installed=yes
  fi
  if [ "$installed" = no ] && { command -v winget >/dev/null 2>&1 || command -v winget.exe >/dev/null 2>&1; }; then
    winget install --id Curl.Curl -e --accept-source-agreements --accept-package-agreements || printf 'warn winget curl install returned non-zero\n'
    command -v curl >/dev/null 2>&1 && installed=yes
  fi
  command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 || fail 'curl/wget missing after install; install it manually'
  printf 'ok    curl/wget\n'
fi

if [ "$quicklisp_ok" = no ]; then
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

[ -f "$ql_setup" ] || fail 'quicklisp missing after install; check USERPROFILE and HOME paths'
if [ "$quicklisp_ok" = no ]; then
  printf 'ok    quicklisp\n'
fi

mkdir -p "$local_projects" || fail 'cannot create quicklisp/local-projects'
win_link=$(cygpath -w "$local_projects/mctext" 2>/dev/null || printf '%s' "$local_projects/mctext")
win_root=$(cygpath -w "$ROOT" 2>/dev/null || printf '%s' "$ROOT")
project_ok=no
if [ -e "$local_projects/mctext" ] || [ -L "$local_projects/mctext" ]; then
  if [ -f "$local_projects/mctext/mctext.asd" ] && cmp -s "$local_projects/mctext/mctext.asd" "$ROOT/mctext.asd"; then
    project_ok=yes
    printf 'ok    existing local project mctext\n'
  else
    cmd.exe //c rmdir "$win_link" >/dev/null 2>&1 || rmdir "$local_projects/mctext" 2>/dev/null || rm -f "$local_projects/mctext" 2>/dev/null
    if [ -e "$local_projects/mctext" ] || [ -L "$local_projects/mctext" ]; then
      fail "invalid local project at $win_link; remove it manually and rerun task 7"
    fi
  fi
fi
if [ "$project_ok" = no ]; then
  if ! cmd.exe //c mklink /J "$win_link" "$win_root" >/dev/null 2>&1; then
    ln -sfn "$ROOT" "$local_projects/mctext" 2>/dev/null || fail 'cannot register local project; run shell as administrator or enable developer mode'
    [ -L "$local_projects/mctext" ] || fail 'cannot register local project; run shell as administrator or enable developer mode'
  fi
  printf 'ok    local project mctext\n'
fi

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

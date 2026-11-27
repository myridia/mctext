#!/bin/sh

ROOT=$(cd "$(dirname "$0")/.." && pwd)
ql_setup="$HOME/quicklisp/setup.lisp"

enter() {
  cd "$ROOT" || exit 1
}

fail() {
  printf 'FAIL  %s\n' "$1" >&2
  exit 1
}

check_base_requirements() {
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
}

install_quicklisp() {
  [ -f "$ql_setup" ] && return 0
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
  if ! grep -q 'quicklisp/setup.lisp' "$HOME/.sbclrc" 2>/dev/null; then
    printf '%s\n' \
      ';;; The following lines added by ql:add-to-init-file:' \
      '#-quicklisp' \
      '(let ((quicklisp-init (merge-pathnames "quicklisp/setup.lisp"' \
      '                                       (user-homedir-pathname))))' \
      '  (when (probe-file quicklisp-init)' \
      '    (load quicklisp-init)))' >> "$HOME/.sbclrc" || fail 'cannot update ~/.sbclrc'
  fi
}

register_local_project() {
  local_projects="$HOME/quicklisp/local-projects"
  mkdir -p "$local_projects" || fail 'cannot create quicklisp/local-projects'
  if [ -e "$local_projects/mctext" ] && [ ! -L "$local_projects/mctext" ]; then
    fail "$local_projects/mctext exists and is not a symlink"
  fi
  ln -sfn "$ROOT" "$local_projects/mctext" || fail 'cannot register local project'
  printf 'ok    local project mctext\n'
}

verify_quickload() {
  printf 'setup verifying quickload\n'
  sbcl --non-interactive \
    --load "$ql_setup" \
    --eval '(ql:register-local-projects)' \
    --eval '(ql:quickload :mctext)' \
    --eval '(sb-ext:exit)' || fail 'quickload :mctext failed'
  printf 'ok    quickload\n'
}

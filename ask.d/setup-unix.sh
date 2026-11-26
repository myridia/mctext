#!/bin/sh
# id: 1
# group: SETUP
# desc: Setup - Linux/macOS requirements
. "$(dirname "$0")/lib.sh"

enter

fail() {
  printf 'FAIL  %s\n' "$1" >&2
  exit 1
}

ql_setup="$HOME/quicklisp/setup.lisp"
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
  case "$(uname -s)" in
    Linux*)
      if command -v apt-get >/dev/null 2>&1; then
        if [ "$(id -u)" -eq 0 ]; then
          apt-get update || fail 'apt-get update failed'
          DEBIAN_FRONTEND=noninteractive apt-get install -y sbcl curl || fail 'apt-get install failed'
        elif command -v sudo >/dev/null 2>&1; then
          sudo apt-get update || fail 'apt-get update failed'
          sudo DEBIAN_FRONTEND=noninteractive apt-get install -y sbcl curl || fail 'apt-get install failed'
        else
          fail 'cannot install sbcl: run as root or install sudo'
        fi
      elif command -v dnf >/dev/null 2>&1; then
        dnf install -y sbcl curl || fail 'dnf install failed'
      elif command -v pacman >/dev/null 2>&1; then
        pacman -S --noconfirm sbcl curl || fail 'pacman install failed'
      else
        fail 'no supported package manager; install sbcl manually'
      fi
      ;;
    Darwin*)
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
      ;;
    FreeBSD*)
      if command -v pkg >/dev/null 2>&1; then
        pkg install -y sbcl curl || fail 'pkg install failed'
      else
        fail 'no supported package manager; install sbcl manually'
      fi
      ;;
    *)
      fail "unsupported platform: $(uname -s); use task 7 on Windows"
      ;;
  esac
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
  if ! grep -q 'quicklisp/setup.lisp' "$HOME/.sbclrc" 2>/dev/null; then
    printf '%s\n' \
      ';;; The following lines added by ql:add-to-init-file:' \
      '#-quicklisp' \
      '(let ((quicklisp-init (merge-pathnames "quicklisp/setup.lisp"' \
      '                                       (user-homedir-pathname))))' \
      '  (when (probe-file quicklisp-init)' \
      '    (load quicklisp-init)))' >> "$HOME/.sbclrc" || fail 'cannot update ~/.sbclrc'
  fi
fi

[ -f "$ql_setup" ] || fail 'quicklisp missing after install'
printf 'ok    quicklisp\n'

local_projects="$HOME/quicklisp/local-projects"
mkdir -p "$local_projects" || fail 'cannot create quicklisp/local-projects'
if [ -e "$local_projects/mctext" ] && [ ! -L "$local_projects/mctext" ]; then
  fail "$local_projects/mctext exists and is not a symlink"
fi
ln -sfn "$ROOT" "$local_projects/mctext" || fail 'cannot register local project'
printf 'ok    local project mctext\n'

"$ROOT/sdl2.sh" || fail 'sdl2.sh failed'

printf 'setup verifying quickload\n'
sbcl --non-interactive \
  --load "$ql_setup" \
  --eval '(ql:register-local-projects)' \
  --eval '(ql:quickload :mctext)' \
  --eval '(sb-ext:exit)' || fail 'quickload :mctext failed'
printf 'ok    quickload\n'
printf 'ok    setup complete\n'

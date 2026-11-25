#!/bin/sh
# id: 1
# group: SETUP
# desc: Setup - check and install requirements
. "$(dirname "$0")/lib.sh"

enter

missing=0
ql_setup="$HOME/quicklisp/setup.lisp"

if command -v sbcl >/dev/null 2>&1; then
  printf "ok    sbcl\n"
else
  printf "FAIL  sbcl missing\n"
  missing=1
fi

if command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1; then
  printf "ok    curl/wget\n"
else
  printf "FAIL  curl/wget missing\n"
  missing=1
fi

if [ -f "$ql_setup" ]; then
  printf "ok    quicklisp\n"
else
  printf "FAIL  quicklisp missing\n"
  missing=1
fi

if [ "$missing" -ne 0 ]; then
  case "$(uname -s)" in
    Linux*)
      if command -v apt-get >/dev/null 2>&1; then
        if [ "$(id -u)" -eq 0 ]; then
          apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y sbcl curl
        elif command -v sudo >/dev/null 2>&1; then
          sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y sbcl curl
        else
          printf "FAIL cannot install sbcl: sudo not found\n"
          exit 1
        fi
      elif command -v dnf >/dev/null 2>&1; then
        dnf install -y sbcl curl
      elif command -v pacman >/dev/null 2>&1; then
        pacman -S --noconfirm sbcl curl
      else
        printf "FAIL no supported package manager; install sbcl manually\n"
        exit 1
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
        printf "FAIL brew not found; install Homebrew from https://brew.sh\n"
        exit 1
      fi
      "$brew_bin" install sbcl curl
      ;;
    MINGW*|MSYS*|CYGWIN*)
      if command -v choco >/dev/null 2>&1 || command -v choco.exe >/dev/null 2>&1; then
        choco install sbcl -y
      elif command -v scoop >/dev/null 2>&1; then
        scoop install sbcl curl
      elif command -v winget >/dev/null 2>&1 || command -v winget.exe >/dev/null 2>&1; then
        winget install --id SteelBankCommonLisp.SBCL -e --accept-source-agreements --accept-package-agreements
      else
        printf "FAIL no supported package manager; install sbcl manually\n"
        exit 1
      fi
      ;;
    *)
      printf "FAIL unsupported platform: %s\n" "$(uname -s)"
      exit 1
      ;;
  esac
fi

if [ ! -f "$ql_setup" ]; then
  tmp_dir=$(mktemp -d)
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL https://beta.quicklisp.org/quicklisp.lisp -o "$tmp_dir/quicklisp.lisp"
  else
    wget -q https://beta.quicklisp.org/quicklisp.lisp -O "$tmp_dir/quicklisp.lisp"
  fi
  sbcl --non-interactive \
    --load "$tmp_dir/quicklisp.lisp" \
    --eval '(quicklisp-quickstart:install)' \
    --eval '(sb-ext:exit)'
  rm -rf "$tmp_dir"
  if ! grep -q 'quicklisp/setup.lisp' "$HOME/.sbclrc" 2>/dev/null; then
    printf '%s\n' \
      ';;; The following lines added by ql:add-to-init-file:' \
      '#-quicklisp' \
      '(let ((quicklisp-init (merge-pathnames "quicklisp/setup.lisp"' \
      '                                       (user-homedir-pathname))))' \
      '  (when (probe-file quicklisp-init)' \
      '    (load quicklisp-init)))' >> "$HOME/.sbclrc"
  fi
fi

local_projects="$HOME/quicklisp/local-projects"
mkdir -p "$local_projects"
if [ -L "$local_projects/mctext" ]; then
  ln -sfn "$ROOT" "$local_projects/mctext"
elif [ ! -e "$local_projects/mctext" ]; then
  ln -s "$ROOT" "$local_projects/mctext"
fi
printf "ok    local project mctext\n"

"$ROOT/sdl2.sh"

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) export PATH="$ROOT/vendor/sdl2:$PATH" ;;
esac

sbcl --non-interactive \
  --load "$HOME/quicklisp/setup.lisp" \
  --eval '(ql:register-local-projects)' \
  --eval '(ql:quickload :mctext)' \
  --eval '(sb-ext:exit)'

for cmd in sbcl; do
  if command -v "$cmd" >/dev/null 2>&1; then
    printf "ok    %s\n" "$cmd"
  else
    printf "FAIL  %s missing after install; open a new shell if PATH changed\n" "$cmd"
    exit 1
  fi
done

if [ -f "$HOME/quicklisp/setup.lisp" ]; then
  printf "ok    quicklisp\n"
else
  printf "FAIL  quicklisp missing after install\n"
  exit 1
fi

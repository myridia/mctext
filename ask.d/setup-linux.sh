#!/bin/sh
# id: 5
# group: LINUX
# desc: Setup - Linux/FreeBSD (CLX)
. "$(dirname "$0")/lib.sh"

enter

missing=0
check_base_requirements

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
    FreeBSD*)
      if command -v pkg >/dev/null 2>&1; then
        pkg install -y sbcl curl || fail 'pkg install failed'
      else
        fail 'no supported package manager; install sbcl manually'
      fi
      ;;
    *)
      fail "unsupported platform: $(uname -s); use task 1 on macOS or task 8 on Windows"
      ;;
  esac
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

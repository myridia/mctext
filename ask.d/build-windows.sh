#!/bin/sh
# id: 9
# group: WINDOWS
# desc: Build - Windows SDL2 executable
. "$(dirname "$0")/lib.sh"

set -e
MCTEXT_BACKEND=sdl2
export MCTEXT_BACKEND
exec sh "$ROOT/ask.d/build.sh"

#!/bin/sh
# id: 2
# group: MAC
# desc: Build - macOS SDL2 executable
. "$(dirname "$0")/lib.sh"

set -e
MCTEXT_BACKEND=sdl2
export MCTEXT_BACKEND
exec sh "$ROOT/ask.d/build.sh"

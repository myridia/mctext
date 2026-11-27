#!/bin/sh
# id: 10
# group: WINDOWS
# desc: Dev test - Windows (SDL2)
. "$(dirname "$0")/lib.sh"

set -e
exec sh "$ROOT/ask.d/dev-test.sh" windows sdl2

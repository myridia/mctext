#!/bin/sh
# id: 3
# group: MAC
# desc: Dev test - macOS (SDL2)
. "$(dirname "$0")/lib.sh"

set -e
exec sh "$ROOT/ask.d/dev-test.sh" mac sdl2

#!/bin/sh
# id: 7
# group: LINUX
# desc: Dev test - Linux (CLX)
. "$(dirname "$0")/lib.sh"

set -e
exec sh "$ROOT/ask.d/dev-test.sh" linux clx

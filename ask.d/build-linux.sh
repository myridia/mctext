#!/bin/sh
# id: 6
# group: LINUX
# desc: Build - Linux CLX executable
. "$(dirname "$0")/lib.sh"

set -e
MCTEXT_BACKEND=clx
export MCTEXT_BACKEND
exec sh "$ROOT/ask.d/build.sh"

#!/bin/sh
# id: 5
# group: MAINTENANCE
# desc: Clean - remove dist, bin, and macOS bundles
. "$(dirname "$0")/lib.sh"

set -e
enter

rm -rf bin dist mctext_macos.app mctext_macos_intel.app
printf "ok    cleaned build output\n"

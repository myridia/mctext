#!/bin/sh
# id: 12
# group: DEVELOPMENT
# desc: Run - sbcl --script main.lisp
. "$(dirname "$0")/lib.sh"

enter
sbcl --script main.lisp

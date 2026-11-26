#!/bin/sh
# id: 3
# group: RUN
# desc: Run - sbcl --script main.lisp
. "$(dirname "$0")/lib.sh"

enter
sbcl --script main.lisp

#!/bin/sh
# id: 6
# group: DEVELOPMENT
# desc: Dev - interactive REPL with reload helpers
. "$(dirname "$0")/lib.sh"

enter
sbcl --noinform \
  --load "$HOME/quicklisp/setup.lisp" \
  --load dev.lisp \
  --eval '(format t "~&Dev REPL ready:~%  (dev-start)          open mctext~%  (dev-reload)        reload changed files~%  (dev-force-reload)  reload every mctext file~%")'

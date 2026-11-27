#!/bin/sh
# id: 11
# group: DEVELOPMENT
# desc: Dev - REPL with GUI and automatic reload
. "$(dirname "$0")/lib.sh"

enter
sbcl --noinform \
  --load "$HOME/quicklisp/setup.lisp" \
  --load dev.lisp \
  --eval '(clim-user:dev-start)' \
  --eval '(format t "~&Dev REPL ready; mctext started; changes under src/ and mctext.asd reload automatically:~%  (clim-user:dev-reload)        reload changed files~%  (clim-user:dev-force-reload)  reload every mctext file~%  (clim-user:dev-start)        reopen if closed~%  (clim-user:dev-watch-stop)   stop automatic reload~%")'

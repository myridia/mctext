(defsystem "mctext"
  :version "0.1.0"
  :author "veto"
  :license "GPL-3.0-or-later"
  :depends-on ("mcclim" "cl-json" "bordeaux-threads" "anathema" "anathema-doom")
  :serial t
  :components ((:file "src/package")
               (:file "src/model")
               (:file "src/store")
               (:file "src/clipboard-log")
               (:file "src/clipboard")
               (:file "src/theme")
               (:file "src/gui")
               (:file "src/cli")))

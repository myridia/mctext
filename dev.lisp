(defvar cl-user::*auto-start* nil)

(load (merge-pathnames "main.lisp" *load-truename*))

(in-package #:clim-user)

(defvar *dev-gui-thread* nil)

(defun dev-start ()
  (unless (and *dev-gui-thread* (bt:thread-alive-p *dev-gui-thread*))
    (setf *dev-gui-thread*
          (bt:make-thread (lambda () (mctext:main :args nil))
                          :name "mctext dev gui")))
  *dev-gui-thread*)

(defun dev-reload ()
  (ql:quickload :mctext)
  (mctext:activate-theme)
  (format t "~&mctext reloaded.~%")
  t)

(defun dev-force-reload ()
  (asdf:load-system :mctext :force t)
  (mctext:activate-theme)
  (format t "~&mctext force-reloaded.~%")
  t)

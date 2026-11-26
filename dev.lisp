(defvar cl-user::*auto-start* nil)
(defvar cl-user::*dev-root*
  (make-pathname :name nil :type nil :defaults *load-truename*))

(load (merge-pathnames "main.lisp" cl-user::*dev-root*))

(in-package #:clim-user)

(defvar *dev-gui-thread* nil)
(defvar *dev-watch-thread* nil)
(defvar *dev-watch-running* nil)
(defvar *dev-watch-seconds* 1)

(defun dev-source-files ()
  (append
   (uiop:directory-files (merge-pathnames "src/" cl-user::*dev-root*) "*.lisp")
   (list (merge-pathnames "mctext.asd" cl-user::*dev-root*))))

(defun dev-file-signature (path)
  (handler-case
      (list (file-write-time path) (file-length path))
    (error () nil)))

(defun dev-file-signatures ()
  (let (signatures)
    (dolist (file (dev-source-files))
      (let ((signature (dev-file-signature file)))
        (when signature
          (push (cons file signature) signatures))))
    signatures))

(defun dev-watch-loop ()
  (let ((signatures (dev-file-signatures)))
    (loop while *dev-watch-running*
          do (sleep *dev-watch-seconds*)
             (let ((current (dev-file-signatures)))
               (unless (equal current signatures)
                 (setf signatures current)
                 (format t "~&Source changed; reloading mctext...~%")
                 (handler-case
                     (dev-reload)
                   (error (condition)
                     (format *error-output* "~&Auto-reload failed: ~A~%" condition))))))))

(defun dev-watch-start ()
  (unless (and *dev-watch-thread* (bt:thread-alive-p *dev-watch-thread*))
    (setf *dev-watch-running* t
          *dev-watch-thread*
          (bt:make-thread #'dev-watch-loop :name "mctext source watch")))
  *dev-watch-thread*)

(defun dev-watch-stop ()
  (setf *dev-watch-running* nil)
  (let ((thread *dev-watch-thread*))
    (setf *dev-watch-thread* nil)
    (when thread
      (handler-case (bt:join-thread thread) (error () nil)))))

(defun dev-start ()
  (dev-watch-start)
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

(export '(dev-start dev-reload dev-force-reload dev-watch-start dev-watch-stop)
        "CLIM-USER")

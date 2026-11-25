(in-package #:mctext)

(defvar *theme-set-function* nil)
(defvar *theme-activate-function* nil)
(defvar *theme-name* :dark)

(defun theme-available-p ()
  (and *theme-set-function* *theme-activate-function*))

(defun theme-status (name)
  (if (theme-available-p)
      (format nil "Theme: ~A." name)
      (format nil "Theme: ~A (clim-modern missing; run task 1)." name)))

(defun install-theme-backend ()
  (let ((ql-package (find-package "QL")))
    (when ql-package
      (let ((quickload (find-symbol "QUICKLOAD" ql-package)))
        (when (and quickload (fboundp quickload))
          (when (handler-case
                    (progn (funcall quickload :clim-modern) t)
                  (error () nil))
            (let ((modern-package (find-package "CLIM-MODERN")))
              (when modern-package
                (let ((set (find-symbol "SET-THEME" modern-package))
                      (activate (find-symbol "ACTIVATE-MODERN-LOOK" modern-package)))
                  (when (and set (fboundp set))
                    (setf *theme-set-function* (symbol-function set)))
                  (when (and activate (fboundp activate))
                    (setf *theme-activate-function* (symbol-function activate))))))))))))

(defun activate-theme ()
  (when *theme-activate-function*
    (funcall *theme-activate-function*))
  (when (and *theme-set-function* *theme-name*)
    (funcall *theme-set-function* *theme-name*)))

(defun set-theme (name)
  (setf *theme-name* name)
  (when *theme-set-function*
    (funcall *theme-set-function* name)))

(install-theme-backend)

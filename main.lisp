(defvar cl-user::*auto-start* t)
(defvar cl-user::*bundled-font-bytes* nil)

(let ((setup (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname))))
  (cond ((find-package "QL") nil)
        ((probe-file setup) (load setup))
        (t (error "Quicklisp not found. Run task ~A in ask.sh."
                  (cond ((or (member :win32 *features*)
                             (member :mingw32 *features*)
                             (member :cygwin *features*))
                         7)
                        ((member :darwin *features*) 8)
                        (t 1))))))

(when (fboundp 'ql:register-local-projects)
  (ql:register-local-projects))

(defvar cl-user::*backend*
  (let ((requested (or (sb-ext:posix-getenv "MCTEXT_BACKEND")
                       (sb-ext:posix-getenv "MCCLIM_BACKEND"))))
    (cond ((and requested (plusp (length requested))
                (string-equal requested "sdl2")) :sdl2)
          ((and requested (plusp (length requested))
                (string-equal requested "clx")) :clx)
          ((and requested (plusp (length requested)))
           (error "Unknown backend ~s (use sdl2 or clx)" requested))
          ((or (member :win32 *features*)
               (member :mingw32 *features*)
               (member :cygwin *features*)) :sdl2)
          ((member :darwin *features*) :sdl2)
           (t :clx))))

(ql:quickload :mctext)

(mctext:activate-theme)

(when (eq cl-user::*backend* :sdl2)
  (ql:quickload :mcclim-sdl2)
  (load (merge-pathnames "sdl2-runtime.lisp"
                         (or *load-truename* *default-pathname-defaults*)))
  (setf clim:*default-server-path* '(:sdl2-soft)))

(in-package :clim-user)

(defun use-bundled-font ()
  (when cl-user::*bundled-font-bytes*
    (let* ((dir (merge-pathnames ".cache/mctext/" (user-homedir-pathname)))
           (font (merge-pathnames "DejaVuSans.ttf" dir)))
      (ensure-directories-exist dir)
      (with-open-file (stream font :direction :output
                                   :if-exists :supersede
                                   :if-does-not-exist :create
                                   :element-type '(unsigned-byte 8))
        (write-sequence cl-user::*bundled-font-bytes* stream))
      (setf mcclim-truetype::*truetype-font-path* dir
            mcclim-truetype::*families/faces*
            (loop for entry in mcclim-truetype::*families/faces*
                  collect (cons (car entry) font))))))

(defun start-main ()
  (use-bundled-font)
  (unwind-protect
       (mctext:main :args (uiop:command-line-arguments))
    #+(and sbcl darwin)
    (when (eq cl-user::*backend* :sdl2)
      (ignore-errors
        (funcall (symbol-function (intern "QUIT-SDL2-PORT" "CL-USER")))))))

(defun main ()
  (when (eq cl-user::*backend* :sdl2)
    (funcall (symbol-function (intern "RESET-SDL2-USER-EVENT-ID" "CL-USER"))))
  #+(and sbcl darwin)
  (if (eq cl-user::*backend* :sdl2)
      (let ((thread (clim-sys:make-process (function start-main)
                                           :name "McText Main")))
        (bt:join-thread thread))
      (start-main))
  #-(and sbcl darwin)
  (start-main))

(export 'main)

(when cl-user::*auto-start*
  (main))

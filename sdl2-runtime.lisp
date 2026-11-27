(defun cl-user::reset-sdl2-user-event-id ()
  (setf sdl2::*user-event-id*
        (plus-c:c-let ((atomic sdl2-ffi:sdl-atomic-t))
          (setf (atomic :value) 0)
          atomic)))

(mcclim-sdl2::define-sdl2-request center-sdl2-window (mirror)
  (let ((window (mcclim-sdl2::sdl2-mirror-window mirror)))
    (sdl2-ffi.functions:sdl-set-window-bordered window 1)
    (sdl2:set-window-position window :centered :centered)))

(defmethod climb:enable-mirror :around
    ((port mcclim-sdl2::sdl2-port)
     (sheet clim-extensions:top-level-sheet-mixin))
  (declare (ignore port))
  (let ((mirror (clim:sheet-direct-mirror sheet)))
    (when (typep mirror 'mcclim-sdl2::sdl2-mirror)
      (center-sdl2-window mirror :synchronize t)))
  (call-next-method))

#+(and sbcl darwin)
(defun mcclim-sdl2::%init-port (port)
  (log:info "Starting the port ~s on the SDL2 main thread." port)
  (unless (mcclim-sdl2::main-thread port)
    (setf (mcclim-sdl2::main-thread port)
          (clim-sys:make-process
           (lambda ()
             (sdl2:init)
             (sdl2:in-main-thread (:no-event t)
               (mcclim-sdl2::%loop-port port)))))
    (loop until mcclim-sdl2::*initialized-p*
          do (clim-sys:with-lock-held (mcclim-sdl2::*initialized-lock*)
               (clim-sys:condition-wait mcclim-sdl2::*initialized-cv*
                                        mcclim-sdl2::*initialized-lock*)))))

#+(and sbcl darwin)
(defun cl-user::quit-sdl2-port ()
  (let ((port (clim:find-port)))
    (when (typep port 'mcclim-sdl2::sdl2-port)
      (clim:destroy-port port)))
  (when (and (boundp 'sdl2::*main-thread-channel*) sdl2::*main-thread-channel*)
    (sdl2:quit)))

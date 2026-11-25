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

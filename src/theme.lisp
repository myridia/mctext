(in-package #:mctext)

(anathema:define-theme mctext-light-theme (anathema:theme) ()
  (:default-initargs :name "Light")
  (:specifiers
   (anathema.style:default
    :foreground-ink "202124"
    :background-ink "f8f9fa"
    :outline-ink "5f6368")
   (anathema.style:highlight
    :foreground-ink "1a73e8")))

(anathema:define-theme mctext-high-contrast-theme (anathema:theme) ()
  (:default-initargs :name "High contrast")
  (:specifiers
   (anathema.style:default
    :foreground-ink "ffffff"
    :background-ink "000000"
    :outline-ink "ffff00")
   (anathema.style:highlight
    :foreground-ink "ffff00")))

(defvar *theme-name* :dark)

(defun theme-object (name)
  (ecase name
    (:dark anathema-doom:*doom-one*)
    (:light *mctext-light-theme*)
    (:high-contrast *mctext-high-contrast-theme*)))

(defun theme-foreground ()
  (anathema:style-foreground-ink anathema.style:*default*))

(defun theme-background ()
  (anathema:style-background-ink anathema.style:*default*))

(defun theme-status (name)
  (format nil "Theme: ~A." name))

(defun activate-theme ()
  (setf anathema:*current-theme* (theme-object *theme-name*)))

(defun set-theme (name)
  (setf *theme-name* name)
  (setf anathema:*current-theme* (theme-object name)))

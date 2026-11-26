(in-package #:mctext)

(defun input-stream-for (text)
  (make-string-input-stream text))

(defun try-program (command text)
  (handler-case
      (progn
        (uiop:run-program command :input (input-stream-for text)
                                  :output nil
                                  :error-output nil)
        t)
    (error () nil)))

(defun temp-directory ()
  (let ((dir (or (uiop:getenv "TMPDIR")
                 (uiop:getenv "TEMP")
                 (uiop:getenv "TMP")
                 "/tmp")))
    (pathname (concatenate 'string (string-right-trim "/\\" dir) "/"))))

(defun copy-with-powershell (text)
  (let* ((path (merge-pathnames (format nil "mctext-clipboard-~36R.txt" (random 1679616))
                                (temp-directory)))
         (escaped (with-output-to-string (stream)
                    (loop for ch across (namestring path)
                          do (if (char= ch #\')
                                 (write-string "''" stream)
                                 (write-char ch stream)))))
         (command (list "powershell" "-NoProfile" "-NonInteractive" "-Command"
                        (format nil "Get-Content -Raw -Encoding UTF8 -LiteralPath '~A' | Set-Clipboard" escaped))))
    (with-open-file (stream path :direction :output :if-exists :supersede
                                 :if-does-not-exist :create :external-format :utf-8)
      (write-string text stream))
    (unwind-protect
         (handler-case
             (progn (uiop:run-program command :output nil :error-output nil) t)
           (error () nil))
      (ignore-errors (delete-file path)))))

(defun copy-to-clipboard (text)
  (let ((copied (cond ((or (member :win32 *features*)
                           (member :mingw32 *features*)
                           (member :cygwin *features*))
                       (copy-with-powershell text))
                      ((member :darwin *features*)
                       (try-program (list "pbcopy") text))
                      ((try-program (list "wl-copy") text) t)
                      ((try-program (list "xclip" "-selection" "clipboard") text) t)
                      ((try-program (list "xsel" "--clipboard" "--input") text) t)
                      (t nil))))
    (when copied (note-own-clipboard-write text))
    copied))

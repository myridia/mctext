(in-package #:mctext)

(defstruct (clipboard-entry (:constructor make-clipboard-entry (&key id text source time)))
  id
  text
  source
  time)

(defvar *clipboard-log* nil)
(defvar *clipboard-log-lock* (bt:make-lock "mctext clipboard log"))
(defvar *clipboard-log-thread* nil)
(defvar *clipboard-watch-running* nil)
(defvar *clipboard-own-writes* nil)
(defvar *clipboard-poll-seconds* 2)

(defun windows-platform-p ()
  (or (member :win32 *features*)
      (member :mingw32 *features*)
      (member :cygwin *features*)))

(defun clipboard-readers ()
  (cond ((windows-platform-p)
         (list (cons "clipboard" '("powershell" "-NoProfile" "-NonInteractive" "-Command" "Get-Clipboard -Raw"))))
        ((member :darwin *features*)
         (list (cons "clipboard" '("pbpaste"))))
        (t
         (list (cons "wayland" '("wl-paste" "--no-newline"))
               (cons "clipboard" '("xclip" "-selection" "clipboard" "-o"))
               (cons "primary" '("xclip" "-selection" "primary" "-o"))
               (cons "clipboard" '("xsel" "--clipboard" "--output"))
               (cons "primary" '("xsel" "--primary" "--output"))))))

(defun run-reader (command)
  (handler-case
      (let ((output (uiop:run-program command :output :string :error-output nil)))
        (when output
          (let ((trimmed (string-right-trim '(#\Newline #\Return) output)))
            (when (plusp (length trimmed)) trimmed))))
    (error () nil)))

(defun note-own-clipboard-write (text)
  (when (and text (plusp (length text)))
    (bt:with-lock-held (*clipboard-log-lock*)
      (push text *clipboard-own-writes*))))

(defun record-clipboard-text (text source)
  (when (and text
             (plusp (length (string-trim '(#\Space #\Tab #\Newline #\Return) text))))
    (bt:with-lock-held (*clipboard-log-lock*)
      (let ((own (position text *clipboard-own-writes* :test #'string=)))
        (if own
            (setf *clipboard-own-writes*
                  (loop for item in *clipboard-own-writes*
                        for index from 0
                        unless (= index own) collect item))
            (unless (find text *clipboard-log*
                          :key #'clipboard-entry-text :test #'string=)
              (push (make-clipboard-entry :id (new-id "clip")
                                          :text text
                                          :source source
                                          :time (get-universal-time))
                    *clipboard-log*)))))))

(defun clipboard-entries ()
  (bt:with-lock-held (*clipboard-log-lock*)
    (copy-list *clipboard-log*)))

(defun remove-clipboard-entry (entry)
  (bt:with-lock-held (*clipboard-log-lock*)
    (setf *clipboard-log* (remove entry *clipboard-log* :test #'eq))))

(defun clear-clipboard-log ()
  (bt:with-lock-held (*clipboard-log-lock*)
    (setf *clipboard-log* nil)))

(defun clipboard-entry-time-string (entry)
  (multiple-value-bind (second minute hour day month year)
      (decode-universal-time (or (clipboard-entry-time entry) 0))
    (format nil "~D-~2,'0D-~2,'0D ~2,'0D:~2,'0D:~2,'0D"
            year month day hour minute second)))

(defun clipboard-entry-preview (entry)
  (let* ((text (or (clipboard-entry-text entry) ""))
         (end (or (position #\Newline text) (length text)))
         (line (subseq text 0 end)))
    (if (> (length line) 60)
        (concatenate 'string (subseq line 0 60) "...")
        line)))

(defun clipboard-watch-loop ()
  (loop while *clipboard-watch-running*
        do (dolist (reader (clipboard-readers))
             (let ((text (run-reader (cdr reader))))
               (when text (record-clipboard-text text (car reader)))))
           (sleep *clipboard-poll-seconds*)))

(defun start-clipboard-watch ()
  (unless *clipboard-log-thread*
    (setf *clipboard-watch-running* t
          *clipboard-log-thread*
          (bt:make-thread #'clipboard-watch-loop :name "mctext clipboard watch"))))

(defun stop-clipboard-watch ()
  (setf *clipboard-watch-running* nil)
  (let ((thread *clipboard-log-thread*))
    (setf *clipboard-log-thread* nil)
    (when thread
      (handler-case (bt:join-thread thread) (error () nil)))))

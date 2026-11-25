(in-package #:mctext)

(define-presentation-type mctext-group ())

(define-presentation-type mctext-snippet ())

(define-presentation-method present (group (type mctext-group) stream (view textual-view) &key)
  (declare (ignore type view))
  (format stream "~A" (or (mctext-group-name group) "")))

(define-presentation-method present (snippet (type mctext-snippet) stream (view textual-view) &key)
  (declare (ignore type view))
  (format stream "~A" (or (mctext-snippet-name snippet) "")))

(defun frame-filter (frame)
  (slot-value frame 'filter))

(defun frame-group-id (frame)
  (slot-value frame 'group-id))

(defun frame-snippet-id (frame)
  (slot-value frame 'snippet-id))

(defun frame-status (frame)
  (slot-value frame 'status))

(defun redisplay-pane (frame name)
  (let ((pane (find-pane-named frame name)))
    (when pane (redisplay-frame-pane frame pane :force-p t))))

(defun set-status (frame message)
  (setf (slot-value frame 'status) message)
  (redisplay-pane frame 'status-pane))

(defun current-group (frame)
  (find-group (frame-group-id frame)))

(defun current-snippet (frame)
  (find-snippet (frame-snippet-id frame)))

(defun text-pane-value (frame)
  (let ((pane (find-pane-named frame 'text-pane)))
    (and pane (gadget-value pane))))

(defun save-current-text (frame)
  (let ((snippet (current-snippet frame)))
    (when snippet
      (update-snippet-text snippet (or (text-pane-value frame) "")))))

(defun display-groups (frame stream)
  (dolist (group (visible-groups (frame-filter frame)))
    (present group 'mctext-group :stream stream)
    (terpri stream)))

(defun display-snippets (frame stream)
  (dolist (snippet (visible-snippets (frame-group-id frame) (frame-filter frame)))
    (present snippet 'mctext-snippet :stream stream)
    (terpri stream)))

(defun display-status (frame stream)
  (write-string (or (frame-status frame) "") stream))

(defun search-changed (gadget value)
  (declare (ignore gadget))
  (with-application-frame (frame)
    (setf (slot-value frame 'filter) value)
    (redisplay-pane frame 'groups-pane)
    (redisplay-pane frame 'snippets-pane)))

(defun invoke-command (command)
  (with-application-frame (frame)
    (execute-frame-command frame command)))

(defun cb-new-group (gadget)
  (declare (ignore gadget))
  (invoke-command '(com-new-group)))

(defun cb-new-snippet (gadget)
  (declare (ignore gadget))
  (invoke-command '(com-new-snippet-current)))

(defun cb-rename (gadget)
  (declare (ignore gadget))
  (invoke-command '(com-rename-current)))

(defun cb-save (gadget)
  (declare (ignore gadget))
  (invoke-command '(com-save-snippet)))

(defun cb-copy (gadget)
  (declare (ignore gadget))
  (invoke-command '(com-copy-current)))

(defun cb-delete (gadget)
  (declare (ignore gadget))
  (invoke-command '(com-delete-current)))

(defun cb-quit (gadget)
  (declare (ignore gadget))
  (invoke-command '(com-quit)))

(define-application-frame mctext-frame ()
  ((filter :initform "" :initarg :filter)
   (group-id :initform nil :initarg :group-id)
   (snippet-id :initform nil :initarg :snippet-id)
   (status :initform "Ready." :initarg :status))
  (:command-table (mctext-frame :inherit-from (clim:accept-values)))
  (:menu-bar mctext-menu-bar)
  (:panes
   (search-pane :text-field
                :value ""
                :width 300
                :value-changed-callback 'search-changed)
   (groups-pane :application
                :display-function 'display-groups
                :display-time :command-loop
                :width 180
                :height 180
                :scroll-bars :vertical)
   (snippets-pane :application
                  :display-function 'display-snippets
                  :display-time :command-loop
                  :width 260
                  :height 180
                  :scroll-bars :vertical)
   (text-pane (make-pane 'text-editor-pane
                         :nlines 14
                         :ncolumns 78
                         :value ""))
   (status-pane :application
                :display-function 'display-status
                :display-time :command-loop
                :height 30
                :scroll-bars nil
                :background +gray40+
                :foreground +white+)
   (interactor :interactor
               :height 28
               :scroll-bars nil)
   (new-group-button :push-button :label "New group" :activate-callback 'cb-new-group)
   (new-snippet-button :push-button :label "New Snippets" :activate-callback 'cb-new-snippet)
   (rename-button :push-button :label "Rename" :activate-callback 'cb-rename)
   (save-button :push-button :label "Save" :activate-callback 'cb-save)
   (copy-button :push-button :label "Copy" :activate-callback 'cb-copy)
   (delete-button :push-button :label "Delete" :activate-callback 'cb-delete)
   (quit-button :push-button :label "Quit" :activate-callback 'cb-quit))
  (:layouts
   (default
    (vertically (:spacing 4)
      (horizontally (:spacing 4)
        new-group-button
        new-snippet-button
        rename-button
        save-button
        copy-button
        delete-button
        quit-button)
      search-pane
      (horizontally (:spacing 6)
        (labelling (:label "Groups") groups-pane)
        (labelling (:label "Snippets") snippets-pane))
      (labelling (:label "Text")
        (scrolling (:scroll-bar :vertical :height 240) text-pane))
      interactor
      status-pane))))

(defun prompt-string (frame prompt &optional default)
  (let ((stream (find-pane-named frame 'interactor))
        (result nil))
    (accepting-values (stream :own-window t
                              :exit-boxes '((:exit "OK") (:abort "Cancel")))
      (setf result (accept 'string :prompt prompt :stream stream
                                   :default (or default ""))))
    result))

(defun select-snippet (frame snippet)
  (save-current-text frame)
  (setf (slot-value frame 'snippet-id) (and snippet (mctext-snippet-id snippet)))
  (let ((pane (find-pane-named frame 'text-pane)))
    (when pane
      (setf (gadget-value pane) (if snippet (or (mctext-snippet-text snippet) "") ""))))
  (set-status frame
              (if snippet
                  (format nil "Selected ~A" (mctext-snippet-name snippet))
                  "No text selected.")))

(define-mctext-frame-command (com-select-group :name t) ((group 'mctext-group))
  (let ((frame *application-frame*))
    (setf (slot-value frame 'group-id) (mctext-group-id group))
    (setf (slot-value frame 'snippet-id) nil)
    (let ((first (first (visible-snippets (mctext-group-id group) (frame-filter frame)))))
      (select-snippet frame first))
    (redisplay-pane frame 'snippets-pane)
    (set-status frame (format nil "Group ~A" (mctext-group-name group)))))

(define-mctext-frame-command (com-select-snippet :name t) ((snippet 'mctext-snippet))
  (let ((frame *application-frame*))
    (select-snippet frame snippet)))

(define-mctext-frame-command (com-copy-snippet :name t) ((snippet 'mctext-snippet))
  (let ((frame *application-frame*))
    (save-current-text frame)
    (if (copy-to-clipboard (or (mctext-snippet-text snippet) ""))
        (set-status frame (format nil "Copied ~A" (mctext-snippet-name snippet)))
        (set-status frame "Clipboard failed. Install wl-copy, xclip or xsel."))))

(define-mctext-frame-command (com-copy-current :name t) ()
  (let ((frame *application-frame*)
        (snippet (current-snippet *application-frame*)))
    (save-current-text frame)
    (if snippet
        (if (copy-to-clipboard (or (mctext-snippet-text snippet) ""))
            (set-status frame (format nil "Copied ~A" (mctext-snippet-name snippet)))
            (set-status frame "Clipboard failed. Install wl-copy, xclip or xsel."))
        (set-status frame "No text selected."))))

(define-mctext-frame-command (com-save-snippet :name t) ()
  (let ((frame *application-frame*)
        (snippet (current-snippet *application-frame*)))
    (if snippet
        (progn
          (update-snippet-text snippet (or (text-pane-value frame) ""))
          (set-status frame (format nil "Saved ~A" (mctext-snippet-name snippet))))
        (set-status frame "No text selected."))))

(define-mctext-frame-command (com-new-group :name t) ()
  (let* ((frame *application-frame*)
         (name (prompt-string frame "New group name")))
    (when (and name (plusp (length name)))
      (let ((group (add-group name)))
        (setf (slot-value frame 'group-id) (mctext-group-id group))
        (redisplay-pane frame 'groups-pane)
        (redisplay-pane frame 'snippets-pane)
        (set-status frame (format nil "Created group ~A" name))))))

(define-mctext-frame-command (com-new-snippet-in-group :name t) ((group 'mctext-group))
  (let* ((frame *application-frame*)
         (name (prompt-string frame "New text name")))
    (when (and name (plusp (length name)))
      (let ((snippet (add-snippet (mctext-group-id group) name)))
        (setf (slot-value frame 'group-id) (mctext-group-id group))
        (redisplay-pane frame 'snippets-pane)
        (select-snippet frame snippet)
        (set-status frame (format nil "Created ~A" name))))))

(define-mctext-frame-command (com-new-snippet-current :name t) ()
  (let ((frame *application-frame*)
        (group (current-group *application-frame*)))
    (if group
        (execute-frame-command frame (list 'com-new-snippet-in-group group))
        (set-status frame "Create a group first."))))

(define-mctext-frame-command (com-rename-current :name t) ()
  (let ((frame *application-frame*)
        (snippet (current-snippet *application-frame*))
        (group (current-group *application-frame*)))
    (cond (snippet
           (let ((name (prompt-string frame "Rename text" (mctext-snippet-name snippet))))
             (when (and name (plusp (length name)))
               (update-snippet-name snippet name)
               (redisplay-pane frame 'snippets-pane)
               (set-status frame (format nil "Renamed to ~A" name)))))
          (group
           (let ((name (prompt-string frame "Rename group" (mctext-group-name group))))
             (when (and name (plusp (length name)))
               (update-group-name group name)
               (redisplay-pane frame 'groups-pane)
               (set-status frame (format nil "Renamed group to ~A" name)))))
          (t (set-status frame "Nothing selected.")))))

(define-mctext-frame-command (com-delete-snippet :name t) ((snippet 'mctext-snippet))
  (let ((frame *application-frame*))
    (delete-snippet-object snippet)
    (setf (slot-value frame 'snippet-id) nil)
    (let ((pane (find-pane-named frame 'text-pane)))
      (when pane (setf (gadget-value pane) "")))
    (redisplay-pane frame 'snippets-pane)
    (set-status frame (format nil "Deleted ~A" (mctext-snippet-name snippet)))))

(define-mctext-frame-command (com-delete-current :name t) ()
  (let ((snippet (current-snippet *application-frame*)))
    (if snippet
        (execute-frame-command *application-frame* (list 'com-delete-snippet snippet))
        (set-status *application-frame* "No text selected."))))

(define-mctext-frame-command (com-quit :name t) ()
  (let ((frame *application-frame*))
    (save-current-text frame)
    (save-store)
    (frame-exit frame)))

(define-presentation-to-command-translator select-mctext-group
    (mctext-group com-select-group mctext-frame
                  :gesture :select
                  :documentation "Show texts")
  (object)
  (list object))

(define-presentation-to-command-translator select-mctext-snippet
    (mctext-snippet com-select-snippet mctext-frame
                    :gesture :select
                    :documentation "Show text")
  (object)
  (list object))

(define-presentation-to-command-translator copy-mctext-snippet
    (mctext-snippet com-copy-snippet mctext-frame
                    :gesture :menu
                    :documentation "Copy to clipboard")
  (object)
  (list object))

(define-presentation-to-command-translator delete-mctext-snippet
    (mctext-snippet com-delete-snippet mctext-frame
                    :gesture :menu
                    :documentation "Delete")
  (object)
  (list object))

(define-presentation-to-command-translator new-snippet-mctext-group
    (mctext-group com-new-snippet-in-group mctext-frame
                  :gesture :menu
                  :documentation "New text")
  (object)
  (list object))

(define-mctext-frame-command (com-clear-search :name t) ()
  (let ((frame *application-frame*))
    (setf (slot-value frame 'filter) "")
    (let ((pane (find-pane-named frame 'search-pane)))
      (when pane (setf (gadget-value pane) "")))
    (redisplay-pane frame 'groups-pane)
    (redisplay-pane frame 'snippets-pane)
    (set-status frame "Search cleared.")))

(define-mctext-frame-command (com-about :name t) ()
  (set-status *application-frame* "McText 0.1.0 - local text vault"))

(define-command-table mctext-file-menu
  :inherit-from nil
  :menu (("New group" :command com-new-group)
          ("New Snippets" :command com-new-snippet-current)
          ("divider" :divider nil)
          ("Save" :command com-save-snippet)
          ("divider" :divider nil)
          ("Quit" :command com-quit)))

(define-command-table mctext-edit-menu
  :inherit-from nil
  :menu (("Rename" :command com-rename-current)
          ("Copy to clipboard" :command com-copy-current)
          ("divider" :divider nil)
          ("Delete" :command com-delete-current)))

(define-command-table mctext-view-menu
  :inherit-from nil
  :menu (("Clear search" :command com-clear-search)))

(define-command-table mctext-help-menu
  :inherit-from nil
  :menu (("About McText" :command com-about)))

(define-command-table mctext-menu-bar
  :inherit-from nil
  :menu (("File" :menu mctext-file-menu)
          ("Edit" :menu mctext-edit-menu)
          ("View" :menu mctext-view-menu)
          ("Help" :menu mctext-help-menu)))

(defun initialize-frame (frame)
  (let ((group (first *groups*)))
    (when group
      (setf (slot-value frame 'group-id) (mctext-group-id group))))
  (let ((snippet (first (visible-snippets (frame-group-id frame) ""))))
    (when snippet
      (setf (slot-value frame 'snippet-id) (mctext-snippet-id snippet))
      (let ((pane (find-pane-named frame 'text-pane)))
        (when pane (setf (gadget-value pane) (or (mctext-snippet-text snippet) ""))))))
  (redisplay-pane frame 'groups-pane)
  (redisplay-pane frame 'snippets-pane)
  (redisplay-pane frame 'status-pane)
  frame)

(defmethod run-frame-top-level :before ((frame mctext-frame) &key)
  (initialize-frame frame))

(defun gui-main ()
  (run-frame-top-level
   (make-application-frame 'mctext-frame :width 960 :height 640)))

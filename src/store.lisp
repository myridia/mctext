(in-package #:mctext)

(defvar *groups* nil)
(defvar *snippets* nil)
(defvar *revisions* (make-hash-table :test #'equal))
(defvar *store-dirty* nil)

(defun data-dir ()
  (let* ((windows (or (member :win32 *features*)
                      (member :mingw32 *features*)
                      (member :cygwin *features*)))
         (base (if windows
                   (or (uiop:getenv "APPDATA")
                       (merge-pathnames "AppData/Roaming/" (user-homedir-pathname)))
                   (or (uiop:getenv "XDG_DATA_HOME")
                       (merge-pathnames ".local/share/" (user-homedir-pathname))))))
    (merge-pathnames (if windows "McText/" "mctext/")
                     (uiop:ensure-directory-pathname base))))

(defun store-path ()
  (merge-pathnames "mctext.json" (data-dir)))

(defun key-name (key)
  (cond ((symbolp key) (symbol-name key))
        ((stringp key) key)
        (t (princ-to-string key))))

(defun alist-get (alist key)
  (cdr (assoc key alist :test (lambda (a b) (string-equal (key-name a) (key-name b))))))

(defun rev-number (rev)
  (let ((end (position #\- (or rev ""))))
    (or (ignore-errors (parse-integer (subseq (or rev "") 0 (or end (length rev)))))
        0)))

(defun next-rev (id)
  (let* ((old (gethash id *revisions* "0-0"))
         (number (1+ (rev-number old))))
    (setf (gethash id *revisions*)
          (format nil "~D-~36R" number (random 1679616)))))

(defun group-doc (group)
  (list (cons "type" "group")
        (cons "id" (mctext-group-id group))
        (cons "name" (mctext-group-name group))
        (cons "sort" (mctext-group-sort group))))

(defun snippet-doc (snippet)
  (list (cons "type" "snippet")
        (cons "id" (mctext-snippet-id snippet))
        (cons "group" (mctext-snippet-group-id snippet))
        (cons "name" (mctext-snippet-name snippet))
        (cons "text" (mctext-snippet-text snippet))
        (cons "tags" (mctext-snippet-tags snippet))
        (cons "sort" (mctext-snippet-sort snippet))))

(defun docs ()
  (append (mapcar (lambda (group)
                    (let ((id (mctext-group-id group)))
                      (list (cons "id" id)
                            (cons "_rev" (next-rev id))
                            (cons "doc" (group-doc group)))))
                  *groups*)
          (mapcar (lambda (snippet)
                    (let ((id (mctext-snippet-id snippet)))
                      (list (cons "id" id)
                            (cons "_rev" (next-rev id))
                            (cons "doc" (snippet-doc snippet)))))
                  *snippets*)))

(defun save-store ()
  (uiop:ensure-all-directories-exist (list (data-dir)))
  (with-open-file (stream (store-path) :direction :output
                                       :if-exists :supersede
                                       :if-does-not-exist :create
                                       :external-format :utf-8)
    (write-string (cl-json:encode-json-to-string
                   (list (cons "version" 1) (cons "docs" (docs))))
                  stream))
  (setf *store-dirty* nil)
  t)

(defun ensure-defaults ()
  (when (null *groups*)
    (setf *groups* (list (make-group :id "group-general" :name "General" :sort 0))))
  (unless (find "group-general" *groups* :key #'mctext-group-id :test #'equal)
    (setf *groups* (append *groups*
                           (list (make-group :id "group-general"
                                             :name "General"
                                             :sort (length *groups*))))))
  (when (null *snippets*)
    (setf *snippets*
          (list (make-snippet :id "snippet-email"
                              :group-id "group-general"
                              :name "Email reply"
                              :text "Hello,

Please check the attached file and let me know if you need anything else.

Thanks."
                              :tags (list "email")
                              :sort 0)
                (make-snippet :id "snippet-code"
                              :group-id "group-general"
                              :name "Code review prompt"
                              :text "Review this code for correctness, clarity and edge cases. Suggest concrete improvements."
                              :tags (list "ai" "code")
                              :sort 1)
                (make-snippet :id "snippet-shell"
                              :group-id "group-general"
                              :name "Common shell commands"
                              :text "git status\ngit diff\ngit log --oneline -10"
                              :tags (list "shell")
                              :sort 2)))))

(defun parse-group (doc)
  (let ((id (alist-get doc "id"))
        (name (alist-get doc "name"))
        (sort (alist-get doc "sort")))
    (when (and id name)
      (make-group :id id :name name :sort (or sort 0)))))

(defun parse-snippet (doc)
  (let ((id (alist-get doc "id"))
        (group (alist-get doc "group"))
        (name (alist-get doc "name"))
        (text (alist-get doc "text"))
        (tags (alist-get doc "tags"))
        (sort (alist-get doc "sort")))
    (when (and id group name)
      (make-snippet :id id :group-id group :name name :text (or text "")
                    :tags (or tags nil) :sort (or sort 0)))))

(defun load-store ()
  (setf *groups* nil *snippets* nil *revisions* (make-hash-table :test #'equal))
  (let ((path (store-path)))
    (if (probe-file path)
        (handler-case
            (let* ((json (with-open-file (stream path :direction :input
                                                        :external-format :utf-8)
                           (let ((buffer (make-string (file-length stream))))
                             (read-sequence buffer stream)
                             buffer)))
                   (root (cl-json:decode-json-from-string json))
                   (docs (or (alist-get root "docs") nil)))
              (dolist (entry docs)
                (let* ((id (alist-get entry "id"))
                       (rev (alist-get entry "_rev"))
                       (doc (or (alist-get entry "doc") nil))
                       (type (and doc (alist-get doc "type"))))
                  (when id (setf (gethash id *revisions*) (or rev "0-0")))
                  (cond ((string-equal type "group")
                         (let ((group (parse-group doc)))
                           (when group (push group *groups*))))
                        ((string-equal type "snippet")
                         (let ((snippet (parse-snippet doc)))
                           (when snippet (push snippet *snippets*)))))))
              (setf *groups* (sort *groups* #'< :key #'mctext-group-sort)
                    *snippets* (sort *snippets* #'< :key #'mctext-snippet-sort)))
          (error () (ensure-defaults)))
        (ensure-defaults)))
  (ensure-defaults)
  t)

(defun find-group (id)
  (find id *groups* :key #'mctext-group-id :test #'equal))

(defun find-snippet (id)
  (find id *snippets* :key #'mctext-snippet-id :test #'equal))

(defun add-group (name)
  (let ((group (make-group :id (new-id "group")
                           :name name
                           :sort (length *groups*))))
    (push group *groups*)
    (setf *groups* (sort *groups* #'< :key #'mctext-group-sort))
    (save-store)
    group))

(defun add-snippet (group-id name)
  (let ((snippet (make-snippet :id (new-id "snippet")
                               :group-id group-id
                               :name name
                               :text ""
                               :tags nil
                               :sort (length *snippets*))))
    (push snippet *snippets*)
    (setf *snippets* (sort *snippets* #'< :key #'mctext-snippet-sort))
    (save-store)
    snippet))

(defun update-snippet-text (snippet text)
  (unless (string= (or (mctext-snippet-text snippet) "") (or text ""))
    (setf (mctext-snippet-text snippet) text)
    (save-store))
  snippet)

(defun update-snippet-name (snippet name)
  (setf (mctext-snippet-name snippet) name)
  (save-store)
  snippet)

(defun update-group-name (group name)
  (setf (mctext-group-name group) name)
  (save-store)
  group)

(defun delete-snippet-object (snippet)
  (setf *snippets* (remove snippet *snippets* :test #'eq))
  (save-store)
  t)

(defun delete-group-object (group)
  (let ((id (mctext-group-id group)))
    (setf *groups* (remove group *groups* :test #'eq)
          *snippets* (remove-if (lambda (snippet)
                                  (string= (mctext-snippet-group-id snippet) id))
                                *snippets*))
    (save-store)
    t))

(defun visible-groups (filter)
  (remove-if-not (lambda (group) (group-matches-p group filter)) *groups*))

(defun visible-snippets (group-id filter)
  (remove-if-not
   (lambda (snippet)
     (and (or (null group-id) (string= (mctext-snippet-group-id snippet) group-id))
          (snippet-matches-p snippet filter)))
   *snippets*))

(in-package #:mctext)

(declaim (ftype (function (t) t) find-group))

(defstruct (mctext-group (:constructor make-group (&key id name sort)))
  id
  name
  sort)

(defstruct (mctext-snippet (:constructor make-snippet (&key id group-id name text tags sort)))
  id
  group-id
  name
  text
  tags
  sort)

(defun new-id (prefix)
  (format nil "~A-~36R-~36R" prefix (get-universal-time) (random 1679616)))

(defun group-name-of (group-id)
  (let ((group (find-group group-id)))
    (if group (mctext-group-name group) "")))

(defun snippet-matches-p (snippet filter)
  (or (null filter)
      (string= filter "")
      (let ((haystack (string-downcase
                       (format nil "~A ~A ~A ~A"
                               (or (mctext-snippet-name snippet) "")
                               (or (mctext-snippet-text snippet) "")
                               (group-name-of (mctext-snippet-group-id snippet))
                               (format nil "~{~A ~}" (or (mctext-snippet-tags snippet) nil))))))
        (search (string-downcase filter) haystack))))

(defun group-matches-p (group filter)
  (or (null filter)
      (string= filter "")
      (search (string-downcase filter)
              (string-downcase (or (mctext-group-name group) "")))))

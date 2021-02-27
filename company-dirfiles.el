;;; company-dirfiles.el --- company-mode completion backend for file names.  -*- lexical-binding: t; -*-

;; Copyright (C) 2009-2011, 2014-2015  Free Software Foundation, Inc.
;; Copyright (C) 2021  Foo Chuan Wei

;; Author: Foo Chuan Wei
;; Keywords: convenience, matching
;; Version: 0.1.0
;; Package-Requires: ((emacs "24.3") (company "0.9.3"))

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; This is a completion backend for the company-mode.
;;
;; This completion backend provides completion for file names and is meant to be
;; a replacement for the company-files backend that is included in company-mode.
;;
;; This backend is substantially based on company-files.el from company-mode
;; 0.9.13. Nikolaj Schumacher is the author of company-files.el.
;;
;; Usage:
;;
;; Put this file in your load-path, then add this backend to the
;; company-backends list:
;;
;;   (setq company-backends (cons #'company-dirfiles
;;                                (delete #'company-files company-backends)))
;;
;; Contributing:
;;
;; Bug reports, suggestions, and patches should be submitted on GitHub:
;; https://github.com/cwfoo/company-dirfiles

;;; Code:

(require 'company)
(require 'cl-lib)

(defgroup company-dirfiles nil
  "Completion backend for file names."
  :group 'company)

(defcustom company-dirfiles-exclusions nil
  "File name extensions and directory names to ignore.
The values should use the same format as `completion-ignored-extensions'."
  :type '(const string))

(defvar company-dirfiles--regexps
  (let* ((root (if (eq system-type 'windows-nt)
                   "[a-zA-Z]:/"
                 "/"))
         (begin (concat "\\(?:\\.\\{1,2\\}/\\|~/\\|" root "\\)")))
    (list (concat "\"\\(" begin "[^\"\n]*\\)")
          (concat "\'\\(" begin "[^\'\n]*\\)")
          (concat "\\(?:[ \t=\[]\\|^\\)\\(" begin "[^ \t\n]*\\)"))))

(defun company-dirfiles--connected-p (file)
  (or (not (file-remote-p file))
      (file-remote-p file nil t)))

(defun company-dirfiles--grab-existing-name ()
  ;; Grab the file name.
  ;; When surrounded with quotes, it can include spaces.
  (let (file dir)
    (and (cl-dolist (regexp company-dirfiles--regexps)
           (when (setq file (company-grab-line regexp 1))
             (cl-return file)))
         (company-dirfiles--connected-p file)
         (setq dir (file-name-directory file))
         (not (string-match "//" dir))
         (file-exists-p dir)
         file)))

(defun company-dirfiles--trailing-slash-p (file)
  (let ((len (length file)))
    (and (> len 0) (eq (aref file (1- len)) ?/))))

(defun company-dirfiles--exclusions-filtered (completions)
  "Filter out file name extensions and directories listed in
`company-dirfiles-exclusions'"
  (let* ((dir-exclusions (cl-delete-if-not #'company-dirfiles--trailing-slash-p
                                           company-dirfiles-exclusions))
         (file-exclusions (cl-set-difference company-dirfiles-exclusions
                                             dir-exclusions)))
    (cl-loop for c in completions
             unless (if (company-dirfiles--trailing-slash-p c)
                        (member c dir-exclusions)
                      (cl-find-if (lambda (exclusion)
                                    (string-suffix-p exclusion c))
                                  file-exclusions))
             collect c)))

(defun company-dirfiles--file-name-all-completions (file dir)
  "Like `file-name-all-completions', but filters out file name extensions and
directories listed in `company-dirfiles-exclusions'."
  (let ((completions (file-name-all-completions file dir)))
    (if company-dirfiles-exclusions
        (company-dirfiles--exclusions-filtered completions)
      completions)))

(defun company-dirfiles--complete (prefix)
  (let* ((dir (file-name-directory prefix))
         (file (file-name-nondirectory prefix))
         (completion-ignore-case read-file-name-completion-ignore-case)
         (completions
          (cl-remove-if (lambda (f)
                          (or (equal f "./")
                              (equal f "../")))
                        (company-dirfiles--file-name-all-completions file dir)))
         (candidates
          (mapcar (lambda (f)
                    (let ((full-filename (concat dir f)))
                      (cond ((company-dirfiles--trailing-slash-p f)
                             (propertize
                              ;; Remove trailing slash.
                              (substring full-filename
                                         0 (1- (length full-filename)))
                              'filetype "[dir] "))
                            (t (propertize full-filename
                                           'filetype "[file]")))))
                  completions)))
    (all-completions prefix candidates)))

(defun company-dirfiles--annotate (candidate)
  (format " %s" (get-text-property 0 'filetype candidate)))

;;;###autoload
(defun company-dirfiles (command &optional arg &rest ignored)
  "`company-mode' completion backend for file names.
Completions works for proper absolute and relative files paths.
File paths with spaces are only supported inside strings."
  (interactive (list 'interactive))
  (cl-case command
    (interactive (company-begin-backend 'company-dirfiles))
    (prefix (company-dirfiles--grab-existing-name))
    (candidates (company-dirfiles--complete arg))
    (annotation (company-dirfiles--annotate arg))))

(provide 'company-dirfiles)
;;; company-dirfiles.el ends here

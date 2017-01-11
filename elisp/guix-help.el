;;; guix-help.el --- Help commands  -*- lexical-binding: t -*-

;; Copyright © 2016–2017 Alex Kost <alezost@gmail.com>

;; This file is part of Emacs-Guix.

;; Emacs-Guix is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; Emacs-Guix is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with Emacs-Guix.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; This file provides auxiliary help commands for Emacs-Guix.

;;; Code:

(require 'bui)
(require 'guix nil t)
(require 'guix-utils)


;;; "Help" buffer

(guix-define-groups help
  :group-doc "Settings for '\\[guix-help]'."
  :faces-group-doc "Faces for '\\[guix-help]'.")

(defcustom guix-help-buffer-name "*Guix Help*"
  "Buffer name for '\\[guix-help]'."
  :type 'string
  :group 'guix-help)

(defcustom guix-help-doc-column 40
  "Column at which 'doc' button is inserted."
  :type 'integer
  :group 'guix-help)

(defface guix-help-heading
  '((t :inherit bui-info-heading))
  "Face for headings in `guix-help-buffer-name' buffer."
  :group 'guix-help-faces)

(defvar guix-help-specifications
  '("Show packages"
    guix-all-available-packages
    guix-newest-available-packages
    guix-installed-user-packages
    guix-installed-system-packages
    guix-installed-packages
    guix-obsolete-packages
    guix-packages-by-name
    guix-packages-by-license
    guix-packages-by-location
    guix-package-from-file
    guix-search-by-name
    guix-search-by-regexp

    "Show profiles"
    guix-profiles

    "Show profile generations"
    guix-generations
    guix-last-generations
    guix-generations-by-time
    guix-system-generations
    guix-last-system-generations
    guix-system-generations-by-time

    "Show/browse package licenses"
    guix-licenses
    guix-browse-license-url
    guix-find-license-definition

    "Show/find package locations"
    guix-locations
    guix-find-location
    guix-edit

    "Magit-like interface"
    guix

    "Show Hydra builds and jobsets"
    guix-hydra-latest-builds
    guix-hydra-queued-builds
    guix-hydra-jobsets

    "Hide hash parts in \"/gnu/store/…-foo\" file names"

    (guix-prettify-mode nil t)
    global-guix-prettify-mode

    "Highlighting for package build logs"
    (guix-build-log-mode nil t)
    (guix-build-log-minor-mode nil t)

    "Highlighting for Guix .scm files"
    (guix-devel-mode nil t)

    "Miscellaneous commands"
    ;; `guix-emacs-autoload-packages' is available in Emacs installed
    ;; with Guix.
    (guix-emacs-autoload-packages t nil)
    guix-set-current-profile
    guix-pull
    guix-apply-manifest
    (guix-about t nil)
    (guix-version t nil))
  "List of command specifications for '\\[guix-help]'.
Each specification can have one of the following forms:

  TITLE
  COMMAND-NAME
  (COMMAND-NAME COMMAND-BUTTON? INFO-BUTTON?)

TITLE is a string.

COMMAND-NAME is a symbol.

COMMAND-BUTTON? is a boolean value; it defines whether
COMMAND-NAME is buttonized or not.

INFO-BUTTON? is a boolean value; it defines whether 'info' button
should be displayed or not.")

(defvar guix-help-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map (make-composed-keymap button-buffer-map
                                                 special-mode-map)))
  "Keymap for Emacs-Guix Help and About buffers.")

(define-derived-mode guix-help-mode special-mode "Help"
  "Major mode for '\\[guix-about]' and '\\[guix-help]' buffers.

\\{help-mode-map}")

(defun guix-insert-info-button (label info-node)
  "Insert button with LABEL to open texinfo manual.
INFO-NODE is the name passed to `info' function."
  (bui-insert-button
   label 'button
   'action (lambda (button)
             (info (button-get button 'node)))
   'node info-node))

(defun guix-insert-info-command-button (label name)
  "Insert button with LABEL to open texinfo manual for command NAME."
  (bui-insert-button
   label 'button
   'help-echo (format "Display info manual for '%S'" name)
   'action (lambda (button)
             (guix-goto-command-index-topic
              (symbol-name (button-get button 'name))))
   'name name))

(defun guix-insert-doc-button (label symbol)
  "Insert button with LABEL to open the docstring of SYMBOL."
  (bui-insert-button
   label 'button
   'help-echo (format "Display documentation of '%S'" symbol)
   'action (lambda (button)
             (describe-symbol (button-get button 'symbol)))
   'symbol symbol))

(defun guix-insert-command-button (command)
  "Insert button to run 'M-x COMMAND'."
  (let ((command-string (symbol-name command)))
    (bui-insert-button
     command-string 'button
     'help-echo (format "Call 'M-x %s'" command-string)
     'action (lambda (button)
               (call-interactively (button-get button 'command)))
     'command command)))

(declare-function Info-follow-nearest-node "info" t)

(defun guix-goto-index-topic (index-node topic)
  "Open TOPIC of INDEX-NODE in the Emacs-Guix manual."
  (require 'info)
  (info (concat "(emacs-guix)" index-node))
  (goto-char (point-min))
  (unless (re-search-forward (concat "\\* +" (regexp-quote topic))
                             nil t)
    (user-error "No such index topic: %s" topic))
  (Info-follow-nearest-node))

(defun guix-goto-command-index-topic (topic)
  "Open TOPIC of Command index in the Emacs-Guix manual."
  (guix-goto-index-topic "Command Index" topic))

(defun guix-help-insert-specification (spec)
  "Insert command specification SPEC at point.
See `guix-help-specifications' for the meaning of SPEC."
  (pcase spec
    ((pred symbolp)
     (guix-help-insert-specification (list spec t t)))
    ((pred stringp)
     (bui-newline)
     (bui-format-insert spec 'guix-help-heading)
     (bui-newline 2))
    (`(,name ,command-button? ,info-button?)
     (when (fboundp name)
       (bui-with-indent bui-indent
         (if command-button?
             (guix-insert-command-button name)
           (insert (symbol-name name)))
         (indent-to guix-help-doc-column 2)
         (guix-insert-doc-button "doc" name)
         (when info-button?
           (insert " ")
           (guix-insert-info-command-button "info" name)))
       (bui-newline)))
    (_
     (insert "<unknown specification>")
     (bui-newline))))

(defun guix-help-reinsert-content (content-function)
  "Erase the current buffer and call CONTENT-FUNCTION to fill it."
  (let ((inhibit-read-only t))
    (erase-buffer)
    (funcall content-function)))

(defun guix-help-make-revert-function (content-function)
  "Return a revert function for `revert-buffer-function'."
  (lambda (_ignore-auto noconfirm)
    (when (or noconfirm
              (y-or-n-p (format "Revert %s buffer? " (buffer-name))))
      (guix-help-reinsert-content content-function))))

(defun guix-help-display-buffer (buffer-name content-function)
  "Display BUFFER-NAME buffer and call CONTENT-FUNCTION to fill it."
  (with-current-buffer (get-buffer-create buffer-name)
    (guix-help-mode)
    (setq-local revert-buffer-function
                (guix-help-make-revert-function content-function))
    (guix-help-reinsert-content content-function))
  (switch-to-buffer buffer-name))

(defun guix-help-insert-content ()
  "Insert summary of Emacs-Guix commands into the current buffer."
  (setq header-line-format
        " Summary of the available M-x commands")
  (mapc #'guix-help-insert-specification
        guix-help-specifications)
  ;; Remove an extra newline in the beginning of buffer.
  (goto-char (point-min))
  (delete-char 1))

(defun guix-help-show ()
  "Display a summary of the available Emacs-Guix commands.
Unlike `guix-help', this command always recreates
`guix-help-buffer-name' buffer."
  (interactive)
  (guix-help-display-buffer guix-help-buffer-name
                            #'guix-help-insert-content))

;;;###autoload
(defun guix-help ()
  "Display a summary of the available Emacs-Guix commands.
Switch to `guix-help-buffer-name' buffer if it already exists."
  (interactive)
  (guix-switch-to-buffer-or-funcall
   guix-help-buffer-name #'guix-help-show))

(provide 'guix-help)

;;; guix-help.el ends here

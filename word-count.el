;;; word-count.el --- show the number of characters/words/lines in the mode line. -*- lexical-binging: t -*-

;; Copyright (C) 2012-2018 Hiroyuki Komatsu

;; Author:  Hiroyuki Komatsu
;; Maintainer: Tomasz Skutnik and Masayuki Hatta

;; URL: https://github.com/mhatta/word-count-mode
;; Version: 1

;; This file is not part of GNU Emacs.

;;; License:

;; Licensed under the same terms as Emacs.

;;; Commentary:

;; 1) M-+ (word-count-mode) toggles word-count mode.
;; 2) M-[space] (word-count-set-area) sets area for counting words.
;; 3) M-x word-count-set-region sets region or paragraph for counting words.
;; 4) M-x word-count-set-marker sets marker for counting words.

;; Put the following in your init.el.

;; (autoload 'word-count-mode "word-count"
;;           "Minor mode to count words." t nil)
;; (global-set-key "\M-+" 'word-count-mode)

;;; Code:

;; Checking Emacs or XEmacs. (APEL?)
(if (not (boundp 'running-xemacs))
    (defconst word-count-running-xemacs nil))

(defun word-count-check-value (value)
  "Check VALUE."
  (and (boundp value)
       (symbol-value value)))

;; word-count-region-active-p
(if word-count-running-xemacs
    (defun word-count-region-active-p ()
      (region-active-p))
  (defun word-count-region-active-p ()
    (word-count-check-value 'mark-active))
  )

;; word-count-transient-mode-p
(if word-count-running-xemacs
    (defun word-count-transient-mode-p ()
      (word-count-check-value 'zmacs-regions))
  (defun word-count-transient-mode-p ()
    (word-count-check-value 'transient-mark-mode))
  )

;; Define word-count-transient-region-active-p
(defun word-count-transient-region-active-p ()
  "Define word-count-transient-region-active-p."
  (and (word-count-transient-mode-p)
       (word-count-region-active-p)))

;; ------------------------------------------------------------

(defun word-count-marker-set (marker &optional position buffer type)
  "Set MARKER for counting words at POSITION in BUFFER TYPE."
  (or (markerp (eval marker))
      (set marker (make-marker)))
  (or position
      (setq position (point)))
  (set-marker (eval marker) position buffer)
  (set-marker-insertion-type (eval marker) type)
  )

(defun word-count-defvar (symbol value &optional doc-string)
  "Set SYMBOL to VALUE or DOC-STRING."
  (if (not (boundp symbol))
      (set symbol value))
  (if doc-string
      (put symbol 'variable-documentation doc-string))
  symbol)

(defun word-count-defvar-locally (symbol initvalue &optional docstring)
  "Set locally SYMBOL to INITVALUE and DOCSTRING."
  (word-count-defvar symbol initvalue docstring)
  (make-variable-buffer-local symbol)
  symbol)

(defun word-count-set-minor-mode (name modeline &optional key-map)
  "Set NAME to MODELINE or KEY-MAP."
  (make-variable-buffer-local name)
  (setq minor-mode-alist
	(word-count-alist-add minor-mode-alist (list name modeline)))
  (and key-map
       (setq minor-mode-map-alist
	     (word-count-alist-add minor-mode-map-alist (cons name key-map)))
       )
  )

(defun word-count-point-at-bop (&optional point)
  "Point at POINT."
  (save-excursion
    (goto-char (or point (point)))
    (backward-paragraph 1)
    (point)))

(defun word-count-point-at-eop (&optional point)
  "Point at POINT."
  (save-excursion
    (goto-char (or point (point)))
    (forward-paragraph 1)
    (point)))

;; word-count-alist ------------------------------------------------------------

(defun word-count-alist-add! (alist new-cons)
  "Add ALIST NEW-CONS."
  (if (null alist)
      (error "Word-count-alist-add! can not deal nil as an alist")
    (let ((current-cons (assoc (car new-cons) alist)))
      (if current-cons
	  (setcdr current-cons (cdr new-cons))
	(if (car alist)
	    (nconc alist (list new-cons))
	  (setcar alist new-cons))
	)
      alist)))
  
(defun word-count-alist-add (alist new-cons)
  "Add ALIST NEW-CONS."
  (if (null alist)
      (list new-cons)
    (let ((return-alist (copy-alist alist)))
      (word-count-alist-add! return-alist new-cons)
      return-alist)))
  
(defun word-count-alist-delete (alist key)
  "Delete ALIST KEY."
  (if key
      (let (return-alist)
	(mapcar #'(lambda (x)
		   (or (equal key (car x))
		       (setq return-alist (cons x return-alist))))
		alist)
	(if return-alist
	    (reverse return-alist)
	  (list nil)))
    alist)
  )

(defun word-count-alist-get-value (key alist)
  "Return a value corresponded to KEY or 't' from ALIST."
  (if (consp alist)
      (let ((assoc-pair (assoc key alist)))
        (if assoc-pair
            (cdr assoc-pair)
          (cdr (assoc t alist))))
    alist))

;; word-count-string ------------------------------------------------------------

(defun word-count-string-split (string regexp)
  "Divide STRING from REGEXP."
  (let ((start 0) match-list splited-list)
    (while (string-match regexp string start)
      (setq match-list
	    (append match-list (list (match-beginning 0) (match-end 0))))
      (setq start (match-end 0))
      )
    (setq match-list (append '(0) match-list (list (length string))))
    (while match-list
      (setq splited-list
	    (cons (substring string (nth 0 match-list) (nth 1 match-list))
		  splited-list))
      (setq match-list (nthcdr 2 match-list))
      )
    (reverse splited-list)))

(defun word-count-string-replace (target-string from-regexp to-string)
  "Replace TARGET-STRING from FROM-REGEXP to TO-STRING."
  (if (string-match from-regexp target-string)
      (setq target-string
	    (mapconcat #'(lambda (x) x)
		       (word-count-string-split target-string from-regexp)
		       to-string))
    )
  target-string)

;; word-count-match ------------------------------------------------------------

(defun word-count-match-count-string (regexp string)
  "Count REGEXP STRING."
  (save-match-data
    (let ((i 0) (n 0))
      (while (and (string-match regexp string i) (< i (match-end 0)))
	(setq i (match-end 0))
	(setq n (1+ n)))
      n)))
  
(if word-count-running-xemacs
    (eval
     '(defun word-count-match-count-region (regexp start end &optional buffer)
	(word-count-match-count-string regexp (buffer-substring start end buffer))
	))
  (eval
   '(defun word-count-match-count-region (regexp start end &optional buffer)
      (save-excursion
	(and buffer (set-buffer buffer))
	(word-count-match-count-string regexp (buffer-substring start end))
	)))
  )

;; word-count-sign ------------------------------------------------------------

(defun word-count-color-find (color-name &optional alt-tty-color-num)
  "Find COLOR-NAME ALT-TTY-COLOR-NUM."
  (if window-system color-name
    (and (functionp 'find-tty-color)
	 (or (and color-name (find-tty-color color-name))
	     (nth alt-tty-color-num (tty-color-list))))
    ))

(defvar word-count-sign-marker-overlay-alist (list nil))
(defun word-count-sign-marker (marker &optional face)
  "Sign MARKER FACE."
  (let ((overlay (cdr (assoc marker word-count-sign-marker-overlay-alist)))
	(start (min marker (1- (point-max)))) ;; for EOB
	(end (min (1+ marker) (point-max))))
    (if overlay
	(move-overlay overlay start end (marker-buffer marker))
      (setq overlay (make-overlay start end (marker-buffer marker)))
      (word-count-alist-add! word-count-sign-marker-overlay-alist (cons marker overlay))
      )
    (overlay-put overlay 'face (or face 'highlight))
    (overlay-put overlay 'evaporate t)
    (add-hook 'post-command-hook 'word-count-sign-marker-redisplay t t)
    ))

(defun word-count-sign-marker-off (marker)
  "Off MARKER."
  (let ((overlay (cdr (assoc marker word-count-sign-marker-overlay-alist))))
    (if overlay
	(delete-overlay overlay))
    (setq word-count-sign-marker-overlay-alist
	  (word-count-alist-delete word-count-sign-marker-overlay-alist marker))
    (remove-hook 'post-command-hook 'word-count-sign-marker-redisplay t)
    ))

(defun word-count-sign-marker-redisplay ()
  "Redisplay marker."
  (mapcar
   #'(lambda (cons) (word-count-sign-marker (car cons)))
   word-count-sign-marker-overlay-alist))

(defvar word-count-sign-region-overlay-alist (list nil))
(defun word-count-sign-region (start end &optional buffer face)
  "Count words from START to END in BUFFER FACE."
  (or buffer (setq buffer (current-buffer)))
  (let* ((region (list start end buffer))
	 (overlay (cdr (assoc region word-count-sign-region-overlay-alist))))
    (if overlay
	(move-overlay overlay start end buffer)
      (setq overlay (make-overlay start end buffer nil t))
      (word-count-alist-add! word-count-sign-region-overlay-alist (cons region overlay))
      )
    (overlay-put overlay 'face (or face 'highlight))
    (overlay-put overlay 'evaporate t)
    ))

(defun word-count-sign-region-off (start end &optional buffer)
  "Count words from START to END in BUFFER."
  (or buffer (setq buffer (current-buffer)))
  (let* ((region (list start end buffer))
	 (overlay (cdr (assoc region word-count-sign-region-overlay-alist))))
    (if overlay
	(delete-overlay overlay))
    (setq word-count-sign-region-overlay-alist
	  (word-count-alist-delete word-count-sign-region-overlay-alist region))
    ))


;; ----------------------------------------------------------------------
;; word-count-mode
;; ----------------------------------------------------------------------

(defcustom word-count-non-character-regexp "[\n\t ]"
  "Regexp what is not counted as characters.")
(defcustom word-count-word-regexp "[a-z0-9_-]+"
  "Regexp what is counted as words.")
(defcustom word-count-non-line-regexp "^[\t ]*\n\\|^[\t ]+$"
  "Regexp what is not counted as lines.")
(defcustom word-count-preremove-regexp-alist
  '((latex-mode . ("\\\\%" "%.*$")) (tex-mode . ("\\\\%" "%.*$"))
    (html-mode . ("<[^>]*>")) (sgml-mode . ("<[^>]*>"))
    (t . nil))
  "Regexp alist what is used by preremove operation.
These regexps are replaced to one space (ie '\\\\%' -> ' ', '%.*$' -> ' ').
A pair with 't' is a default.")
(defcustom word-count-modeline-string " WC:"
				  "String of modeline for word-count mode.")
(defcustom word-count-mode-hook nil
  "Function or functions called when ‘word-count-mode’ is executed.")
(defcustom word-count-mode-init-hook nil
  "Function or functions called when word-count.el is loaded.")

(defcustom word-count-marker-foreground (word-count-color-find "#D0D0D0" 7)
  "Color for word-count mode.")
(defcustom word-count-marker-background (word-count-color-find "#5050A0" 3)
  "Color for word-count mode.")
(defcustom word-count-region-foreground (word-count-color-find "#D0D0D0" 7)
  "Color for word-count mode.")
(defcustom word-count-region-background (word-count-color-find "#5050A0" 3)
  "Color for word-count mode.")

(if (not (boundp 'word-count-marker-face))
    (progn
      (defcustom word-count-marker-face (make-face 'word-count-marker-face)
	"Face for word-count mode.")
      (set-face-foreground word-count-marker-face word-count-marker-foreground)
      (set-face-background word-count-marker-face word-count-marker-background)
      ))

(if (not (boundp 'word-count-region-face))
    (progn
      (defcustom word-count-region-face (make-face 'word-count-region-face)
	"Face for word-count mode.")
      (set-face-foreground word-count-region-face word-count-region-foreground)
      (set-face-background word-count-region-face word-count-region-background)
      ))

(global-set-key "\M-+" 'word-count-mode)
(defvar word-count-mode-map (make-sparse-keymap))
(define-key word-count-mode-map "\M- " 'word-count-set-area)


(defvar word-count-mode nil "*Non-nil means in an word-count mode.")
(word-count-set-minor-mode 'word-count-mode 'word-count-modeline word-count-mode-map)

(word-count-defvar-locally 'word-count-modeline " WC")
(word-count-defvar-locally 'word-count-marker-beginning nil)
(word-count-defvar-locally 'word-count-marker-end nil)

(defun word-count-mode (&optional arg)
  "Count words with ARG."
  (interactive "P")
  (setq word-count-mode
	(if (null arg) (not word-count-mode) (> (prefix-numeric-value arg) 0)))
  (if word-count-mode
      (word-count-mode-on)
    (word-count-mode-off))
  (run-hooks 'word-count-mode-hook)
  )

(defun word-count-mode-on ()
  "Set ‘word-count-mode’ on."
  (interactive)
  (setq word-count-mode t)
  (if (word-count-transient-region-active-p)
      (word-count-set-region)
    (word-count-set-marker))
  (add-hook 'post-command-hook 'word-count-modeline-display t t)
  )

(defun word-count-mode-off ()
  "Set ‘word-count-mode’ off."
  (interactive)
  (setq word-count-mode nil)
  (remove-hook 'post-command-hook 'word-count-modeline-display t)
  (word-count-set-marker-off)
  (word-count-set-region-off)
  )

(defun word-count-set-area ()
  "Set area for ‘word-count-mode’."
  (interactive)
  (or word-count-mode
      (word-count-mode))
  (if (word-count-transient-region-active-p)
      (word-count-set-region)
    (word-count-set-marker)
    ))

(defun word-count-set-marker ()
  "Set marker."
  (interactive)
  (or word-count-mode (word-count-mode))
  (word-count-set-region-off)
  (word-count-marker-set 'word-count-marker-beginning)
  (word-count-sign-marker word-count-marker-beginning word-count-marker-face)
  )

(defun word-count-set-marker-off ()
  "Set marker off."
  (word-count-sign-marker-off word-count-marker-beginning)
  )

(defun word-count-set-region ()
  "Set region."
  (interactive)
  (or word-count-mode (word-count-mode))
  (word-count-set-marker-off)
  (if (word-count-transient-region-active-p)
      (progn
	(word-count-marker-set 'word-count-marker-beginning (min (mark) (point)))
	(word-count-marker-set 'word-count-marker-end (max (mark) (point)) nil t)
	)
    (word-count-marker-set 'word-count-marker-beginning (word-count-point-at-bop))
    (word-count-marker-set 'word-count-marker-end       (word-count-point-at-eop) nil t)
    )
  (word-count-sign-region word-count-marker-beginning word-count-marker-end nil
		    word-count-region-face)
  )

(defun word-count-set-region-off ()
  "Set region off."
  (word-count-sign-region-off word-count-marker-beginning word-count-marker-end)
  (and (markerp word-count-marker-end)
       (set-marker word-count-marker-end nil))
  (setq word-count-marker-end nil)
  )

(defun word-count-modeline-display ()
  "Display modeline."
  (setq word-count-modeline (word-count-modeline-create))
  (force-mode-line-update)
  )

(defun word-count-modeline-create ()
  "Create modeline."
  (let ((beginning word-count-marker-beginning)
	(end (or word-count-marker-end (point))))
    (concat
     word-count-modeline-string
     (apply 'format "%d/%d/%d" (word-count-CWL-region beginning end))
     (if (word-count-transient-region-active-p)
	 (apply 'format " (%d/%d/%d)" (word-count-CWL-region)))
     )))

(defun word-count-CWL-region (&optional start end)
  "Set CWL region from START to END."
  (word-count-CWL-string (word-count-buffer-substring start end)))

(defun word-count-CWL-string (string)
  "Set CWL STRING."
  (setq string (word-count-preremove-string string))
  (list
   (word-count-characters-string string t)
   (word-count-words-string      string t)
   (word-count-lines-string      string t)
   ))

(defun word-count-characters-region (&optional start end)
  "Set character region from START to END."
  (word-count-characters-string (word-count-buffer-substring start end)))

(defun word-count-words-region (&optional start end)
  "Set word region from START to END."
  (word-count-words-string (word-count-buffer-substring start end)))

(defun word-count-lines-region (&optional start end)
  "Set lines region from START to END."
  (word-count-lines-string (word-count-buffer-substring start end)))

(defun word-count-buffer-substring (&optional start end)
  "Substring buffer from START to END."
  (or start (setq start (region-beginning)))
  (or end (setq end (region-end)))
  (buffer-substring start end))


(defun word-count-characters-string (string &optional nopreremove)
  "Count characters in STRING NOPREREMOVE."
  (or nopreremove
      (setq string (word-count-preremove-string string)))
  (- (length string)
     (word-count-match-count-string word-count-non-character-regexp string)
     ))

(defun word-count-words-string (string &optional nopreremove)
  "Count words in STRING NOPREREMOVE."
  (or nopreremove
      (setq string (word-count-preremove-string string)))
  (word-count-match-count-string word-count-word-regexp string))

(defun word-count-lines-string (string &optional nopreremove)
  "Count lines in STRING NOPREREMOVE."
  (or nopreremove
      (setq string (word-count-preremove-string string)))
  (- (1+ (word-count-match-count-string
	  "\n" (substring string 0 (max 0 (1- (length string))))))
     (word-count-match-count-string word-count-non-line-regexp string)
     ))


(defun word-count-preremove-string (string &optional patterns)
  "Count preremove string in STRING PATTERNS."
  (mapcar #'(lambda (pattern)
	     (setq string (word-count-string-replace string pattern " ")))
	  (or patterns
	      (word-count-alist-get-value major-mode
				    word-count-preremove-regexp-alist)))
  string)

(run-hooks 'word-count-mode-init-hook)
(provide 'word-count)
;; ----------------------------------------------------------------------

;; Local Variables:
;; indent-tabs-mode: nil
;; End:
;;; word-count.el ends here

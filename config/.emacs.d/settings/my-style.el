;;;
;;;
;;;

;;; インデントモードの設定
(setq c-default-style
      '((java-mode . "java") (other . "bsd")))

;(setq-default tab-width 4)
;(setq c-basic-offset 4)
(physical-line-mode t)

;; Set indent settings.
(defun set-indent-ws4 ()
  (interactive)
  (setq tab-width 4)
  (setq c-basic-offset 4)
  (setq indent-tabs-mode nil)
  (message "Set c-basic-offset 4, and indent-tabs-mode nil."))

;; Set indent settings.
(defun set-indent-ws8 ()
  (interactive)
  (setq tab-width 8)
  (setq c-basic-offset 8)
  (setq indent-tabs-mode t)
  (message "Set c-basic-offset 8, and indent-tabs-mode t."))

(define-key global-map "\C-c4" 'set-indent-ws4)
(define-key global-map "\C-c8" 'set-indent-ws8)

(add-hook 'c-mode-hook
          '(lambda ()
             (setq tab-width 4)
             (setq c-basic-offset 4)
             (setq indent-tabs-mode nil)))

(add-hook 'c-mode-common-hook
          '(lambda ()
             (physical-line-mode t)
             (gtags-mode 1)
             (gtags-make-complete-list)))

(add-hook 'c++-mode-hook
          '(lambda ()
             (setq tab-width 4)
             (setq c-basic-offset 4)
             (setq indent-tabs-mode nil)))

(add-hook 'lisp-mode-hook
          '(lambda ()
             (physical-line-mode t)
             (setq indent-tabs-mode nil)))

(add-hook 'emacs-lisp-mode-hook
          '(lambda ()
             (physical-line-mode t)
             (setq indent-tabs-mode nil)))

(add-hook 'html-mode-hook
          '(lambda ()
             (physical-line-mode t)
             (setq indent-tabs-mode nil)))

;; csharp
(autoload 'csharp-mode "csharp-mode" "C# edit mode." t)
(add-to-list 'auto-mode-alist
             '("\\.cs\\'" . c++-mode))

(add-hook 'csharp-mode-hook
          '(lambda ()
             (setq c-basic-offset 4)
             (setq-default tab-width 4)
             (setq indent-tabs-mode nil)))

;; dox
(add-to-list 'auto-mode-alist
             '("\\.dox\\'" . text-mode))

(add-hook 'text-mode-hook
          '(lambda ()
             (physical-line-mode t)
             (setq indent-tabs-mode nil)))

;; scheme
(setq process-coding-system-alist
      (cons '("gosh" utf-8 . utf-8) process-coding-system-alist))

(setq scheme-program-name "gosh -l")
(autoload 'scheme-mode "cmuscheme" "Major mode for Scheme." t)
(autoload 'run-scheme "cmuscheme" "Major mode for Scheme." t)

(add-hook 'scheme-mode-hook
          '(lambda ()
             (physical-line-mode t)
             (setq tab-width 4)
             (setq indent-tabs-mode nil)))

;; javascript
(autoload 'javascript-mode "javascript" nil t)
(add-to-list 'auto-mode-alist
             '("\\.\\(js\\|as\\|json\\|jsn\\)\\'" . javascript-mode))

(add-hook 'javascript-mode-hook
          '(lambda ()
             (physical-line-mode t)
             (setq tab-width 4)
             (setq indent-tabs-mode t)
             (setq javascript-indent-level 4)
             (setq javascript-basic-offset tab-width)))

;; ruby
(autoload 'ruby-mode "ruby-mode" "")
(add-to-list 'auto-mode-alist
             '("\\.rb\\'" . ruby-mode))
(add-to-list 'interpreter-mode-alist
             '("ruby" . ruby-mode))

(autoload 'run-ruby "inf-ruby" "")
(autoload 'inf-run-keys "inf-ruby-keys" "")
(add-hook 'ruby-mode-hook
          '(lambda ()
             (physical-line-mode t)
             (inf-ruby-keys)))

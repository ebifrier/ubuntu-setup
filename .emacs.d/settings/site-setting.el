;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Anything
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(require 'anything-config)
 (setq anything-sources
       (list anything-c-source-buffers
             anything-c-source-bookmarks
             anything-c-source-file-name-history
             anything-c-source-info-pages
;;             anything-c-source-info-elisp
             anything-c-source-man-pages
             anything-c-source-locate
             anything-c-source-emacs-commands
             anything-c-source-calculation-result))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; GDB
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; 有用なバッファを開くモード
(setq gdb-many-windows t)

;;; 変数の上にマウスカーソルを置くと値を表示
(add-hook 'gdb-mode-hook
          '(lambda ()
             (global-set-key [f5] 'gud-cont)
             (global-set-key [f10] 'gud-next)
             (global-set-key [f11] 'gud-step)
             (global-set-key [f12] 'gud-until)
             (global-set-key [f9] 'gud-tbreak)
             (gud-tooltip-mode t)))

;;; I/O バッファを表示
(setq gdb-use-separate-io-buffer t)

;;; t にすると mini buffer に値が表示される
(setq gud-tooltip-echo-area nil)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Physical Line
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(require 'physical-line)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Anthy or Prime
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;(load-library "anthy")
;(setq default-input-method 'japanese-anthy)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Auto Completion
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(require 'auto-complete)
(global-auto-complete-mode t)

(define-key ac-complete-mode-map "\C-n" 'ac-next)
(define-key ac-complete-mode-map "\C-p" 'ac-previous)

(setq-default ac-sources '(ac-source-abbrev ac-source-words-in-buffer))
(setq ac-auto-start nil)
(global-set-key "\C-x/" 'ac-start)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Widen Window
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; (require 'widen-window)
;; (setq ww-ratio 0.75)
;; (add-to-list 'ww-advised-functions
;;              'shell-command
;;              'compile)
;; (global-widen-window-mode t)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; GNU Global (gtags)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(autoload 'gtags-mode "gtags" "" t)
(setq gtags-mode-hook
      '(lambda ()
         (define-key gtags-mode-map "\C-ct" 'gtags-find-tag)
         (define-key gtags-mode-map "\C-cr" 'gtags-find-rtag)
         (define-key gtags-mode-map "\C-cs" 'gtags-find-symbol)
         (define-key gtags-mode-map "\C-cf" 'gtags-find-file)
         ))

;; バッファ移動後でもポップが使えように。
(global-set-key "\C-c/" 'gtags-pop-stack)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Shell Command
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(require 'shell-command)
(shell-command-completion-mode)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Color Theme
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(require 'color-theme)
(color-theme-initialize)
(color-theme-charcoal-black)

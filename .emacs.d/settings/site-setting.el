
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; GDB
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; �L�p�ȃo�b�t�@���J�����[�h
(setq gdb-many-windows t)

;;; �ϐ��̏�Ƀ}�E�X�J�[�\����u���ƒl��\��
(add-hook 'gdb-mode-hook
          '(lambda ()
             (global-set-key [f5] 'gud-cont)
             (global-set-key [f10] 'gud-next)
             (global-set-key [f11] 'gud-step)
             (global-set-key [f12] 'gud-until)
             (global-set-key [f9] 'gud-tbreak)
             (gud-tooltip-mode t)))

;;; I/O �o�b�t�@��\��
(setq gdb-use-separate-io-buffer t)

;;; t �ɂ���� mini buffer �ɒl���\�������
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

;; �o�b�t�@�ړ���ł��|�b�v���g���悤�ɁB
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

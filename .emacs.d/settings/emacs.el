;;;
;;;
;;;


;; Read from ~/.emacs
; (setq *network-emacs-home* "~/Dropbox/settings/emacs")
; (load "~/Dropbox/settings/emacs/emacs.el")


(defun make-home-path (file-name)
  (expand-file-name
   (concat *network-emacs-home* "/" file-name)))

;; You have to append the lisp directories to the load-path,
;; before this script is loaded.
(setq load-path
      (append `(,(make-home-path "settings")
                ,(make-home-path "site-lisp")
                ,(make-home-path "site-lisp/color-theme-6.6.0")
                ,(make-home-path "site-lisp/ruby-mode"))
	    load-path))

;; load setting files
(load "config")
(load "site-setting")
(load "tabbar-setting")
(load "font-setting")
(load "shell-command")

(load "my-style")


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(setq inhibit-startup-message t)
(setq ring-bell-function 'ignore)

(define-key global-map "\C-h" 'delete-backward-char) ; 削除
(define-key global-map "\M-h" 'backward-kill-word) ; 単語単位で削除
(define-key global-map "\C-xh" 'backward-delete-char-untabify) ; 削除
(define-key global-map "\M-?" 'help-for-help)        ; ヘルプ
(define-key global-map "\C-a" 'physical-line-beginning-of-line)    ; 行頭
(define-key global-map "\C-e" 'physical-line-end-of-line)    ; 行末
(define-key global-map "\C-ci" 'indent-region)       ; インデント
(define-key global-map "\C-c;" 'comment-region)      ; コメントアウト
(define-key global-map "\C-c:" 'uncomment-region)    ; コメント解除
;(define-key global-map "\C-x/" 'dabbrev-expand)      ; 補完
(define-key global-map "\C-?" 'undo)
(define-key global-map "\C-\\" 'undo)
;(define-key global-map "\C-\\" nil) ; \C-\の日本語入力の設定を無効にする
;(define-key global-map "\C-o" 'toggle-input-method)  ; 日本語入力切替
(define-key global-map [backspace] 'delete-backward-char)
(define-key global-map "\M-g" 'goto-line)

(setq compilation-window-height 10)

;; Shell command with compilation buffer.
(defun create-shell-window (shell-height)
  (save-selected-window
    (let* ((main-win (selected-window))
           (sub-win (next-window main-win nil t))
           (comp-win (get-buffer-window "*compilation*" t))
           (shell-win (get-buffer-window "*shell*" t))
           (shell-buf (get-buffer-create "*shell*")))
      (cond
       (comp-win
        (set-window-buffer comp-win shell-buf))
       (shell-win
        (set-window-buffer shell-win shell-buf))
       ((eq main-win sub-win)
        (let* ((total-height (window-height main-win))
               (shell-win (split-window main-win (- total-height shell-height))))
          (set-window-buffer shell-win shell-buf)))
       (t
        (set-window-buffer sub-win shell-buf)))
      shell-buf)))

(defun shell-command-with-window (command)
  (interactive (list (read-from-minibuffer "Shell command: "
                                           nil nil nil 'shell-command-history)))
  (let ((main-buf (window-buffer (selected-window))))
    (shell-command command
                   (create-shell-window
                    compilation-window-height))
    (set-window-buffer (selected-window) main-buf)))

;; C-c c でコンパイル
(define-key mode-specific-map "c" 'compile)
(define-key mode-specific-map "o" 'next-error)
(define-key mode-specific-map "@" 'shell-command-with-window)

;; パスワードを隠す
(add-hook 'comint-output-filter-functions
          'comint-watch-for-password-prompt)

;(c-toggle-hungry-state t)
(setq backward-delete-char-untabify-method 'hungry)

;;; ホイールマウス
(mouse-wheel-mode t)
(setq mouse-wheel-follow-mouse t)

;;; 補完時に大文字小文字を区別しない
(setq completion-ignore-case t)

;;; 強力な補完機能を使う
;;; p-bでprint-bufferとか
;(load "complete")
;(partial-completion-mode 1)

;;; スクロールを一行ずつにする
(setq scroll-step 1)

;;; スクロールバーを右側に表示する
(set-scroll-bar-mode 'right)

;;; 最近使ったファイルを保存(M-x recentf-open-filesで開く)
(recentf-mode)

;;; カラム数を表示
;(line-number-mode t)
(column-number-mode t)

;; メニューバー、ツールバーを非表示
(tool-bar-mode -1)
(menu-bar-mode -1)

;; 色つけを常に行う
(global-font-lock-mode t)

;;; フォント設定
(cond
 ((eq window-system 'x)
  ;(my-set-font "IPAゴシック" "IPAゴシック" 13 1.1)
  '())
 ((or (eq window-system 'w32)
      (eq window-system 'win32))
  (my-set-font "Courier new" "Osaka_unicode" 12 1.1)))

;; ウィンドウのサイズ設定
(if (boundp 'window-system)
    (setq initial-frame-alist
          (append initial-frame-alist
                  (list '(width . 90)
                        '(height . 40)))))

;;; emacsclient サーバを起動
(server-start)

(remove-hook
 'kill-buffer-query-functions
 'server-kill-buffer-query-function)

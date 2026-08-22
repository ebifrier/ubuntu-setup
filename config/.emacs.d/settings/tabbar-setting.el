;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; tabbar-mode: バッファ上部にタブを表示する
;   
; - 参考ページ 
; -- EmacsWiki - Tab Bar Mode:
;      http://www.emacswiki.org/cgi-bin/wiki/TabBarMode
; -- 見た目の変更 - Amit's Thoughts: Emacs: buffer tabs:
;      http://amitp.blogspot.com/2007/04/emacs-buffer-tabs.html
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; scratch buffer 以外をまとめてタブに表示する
(require 'cl) ; for emacs-22.0.50 on Vine Linux 4.2
 (when (require 'tabbar nil t)
    (setq tabbar-buffer-groups-function
	  (lambda (b) (list "All Buffers")))
    (setq tabbar-buffer-list-function
          (lambda ()
            (remove-if
             (lambda(buffer)
               (find (aref (buffer-name buffer) 0) " *"))
             (buffer-list))))
    (tabbar-mode))

;; Ctrl-Tab, Ctrl-Shift-Tab でタブを切り替える
(dolist (func '(tabbar-mode tabbar-forward-tab tabbar-forward-group tabbar-backward-tab tabbar-backward-group))
  (autoload func "tabbar" "Tabs at the top of buffers and easy control-tab navigation"))
(defmacro defun-prefix-alt (name on-no-prefix on-prefix &optional do-always)
  `(defun ,name (arg)
     (interactive "P")
     ,do-always
     (if (equal nil arg)
	 ,on-no-prefix
       ,on-prefix)))
(defun-prefix-alt shk-tabbar-next (tabbar-forward-tab) (tabbar-forward-group) (tabbar-mode 1))
(defun-prefix-alt shk-tabbar-prev (tabbar-backward-tab) (tabbar-backward-group) (tabbar-mode 1))
(global-set-key [(control tab)] 'shk-tabbar-next)
(global-set-key [(control shift tab)] 'shk-tabbar-prev)

;; 外観変更
(set-face-attribute
 'tabbar-default-face nil
 :background "gray20")
(set-face-attribute
 'tabbar-unselected-face nil
 :background "gray30"
 :foreground "gray70"
 :box nil)
(set-face-attribute
 'tabbar-selected-face nil
 :background "gray70"
 :foreground "black"
 :box nil)
(set-face-attribute
 'tabbar-button-face nil
 :box '(:line-width 1 :color "gray72" :style released-button))
(set-face-attribute
 'tabbar-separator-face nil
 :height 1.0)

;; F4 で tabbar-mode
(global-set-key [f4] 'tabbar-mode)

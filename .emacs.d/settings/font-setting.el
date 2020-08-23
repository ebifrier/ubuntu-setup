;;;
;;; フォントの設定を行います。
;;;

(defun my-list-fonts ()
  (prin1-to-string (x-list-fonts "*")))

(defun my-set-assoc-data (list key value)
  ;; リストに既に同じキーがあれば上書き、無ければ新規追加
  (let ((item (assoc key (symbol-value list))))
	(if item
		(setcdr item value)
	  (add-to-list list (cons key value)))))

(defun my-set-font (ascii-font jis-font size mul)
  ;; フォント設定
  ;; ascii フォント、和文フォント、サイズ、倍率の順に指定する。
  (create-fontset-from-ascii-font
   (concat "-outline-" ascii-font "-normal-r-normal-normal-"
           (int-to-string size) "-*-*-*-*-*-iso8859-1")
   nil
   (concat ascii-font (int-to-string size)))
  (let* ((encoded (encode-coding-string jis-font 'emacs-mule))
         (family (concat encoded "*"))
         (fontset (concat "fontset-" ascii-font (int-to-string size))))
    (set-fontset-font fontset 'japanese-jisx0208 (cons family "jisx0208-sjis"))
    (set-fontset-font fontset 'katakana-jisx0201 (cons family "jisx0201-katakana"))
    (my-set-assoc-data 'face-font-rescale-alist (concat ".*" encoded ".*") mul)
    (my-set-assoc-data 'default-frame-alist 'font fontset)
    (set-frame-font fontset)))

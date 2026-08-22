;
;
;

(setq *network-emacs-home*
      (expand-file-name (concat (getenv "HOME") "/.emacs.d")))

(load (expand-file-name (concat *network-emacs-home* "/settings/emacs.el")))

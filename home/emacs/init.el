;;; init.el -*- lexical-binding: t; -*-

(setq custom-file (locate-user-emacs-file "custom.el"))
(load custom-file 'noerror)

(setopt inhibit-startup-screen t)

(load-theme 'solarized-selenized-black t)
(set-face-attribute 'default nil :family "monospace")

(use-package evil
  :init (setq evil-want-keybinding nil)
  :config (evil-mode 1))

(use-package evil-collection
  :after evil
  :config (evil-collection-init))

;; Late, so each buffer gets its project's direnv environment before
;; eglot or Proof General look for executables.
(use-package envrc
  :hook (after-init . envrc-global-mode))

(use-package eglot
  :hook ((c-mode c++-mode java-mode tuareg-mode nix-mode) . eglot-ensure))

(use-package proof-general)

(use-package web-mode
  :mode ("\\.html?\\'" "\\.[jt]sx\\'"))

(use-package markdown-mode
  :mode ("\\.md\\'" . gfm-mode)
  :custom (markdown-fontify-code-blocks-natively t))

(use-package sail-mode
  :mode ("\\.sail\\'" . sail-mode))

(add-to-list 'auto-mode-alist '("\\.pl\\'" . prolog-mode))

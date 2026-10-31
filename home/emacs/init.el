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
;; eglot looks for executables.
(use-package envrc
  :hook (after-init . envrc-global-mode))

(use-package eglot
  :hook ((c-mode c++-mode java-mode tuareg-mode nix-mode) . eglot-ensure))

;; Deferred like eglot-ensure, so lake comes from the project's envrc
;; environment.
(use-package lean4-mode
  :hook (lean4-mode . lsp-deferred))

;; yasnippet isn't installed, and lsp-mode warns at each server start.
(use-package lsp-mode
  :custom (lsp-enable-snippet nil))

(use-package web-mode
  :mode ("\\.html?\\'" "\\.[jt]sx\\'"))

(use-package markdown-mode
  :mode ("\\.md\\'" . gfm-mode)
  :custom (markdown-fontify-code-blocks-natively t))

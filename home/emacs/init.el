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
  :hook (lean4-mode . lsp-deferred)
  :config
  ;; Lean answers inlay hint requests partially while it elaborates, then
  ;; asks for them again. lsp-mode has no handler for that, so it warns
  ;; and keeps the partial hints. Each request cancels the last, so only
  ;; the selected window's are re-requested. Remove when lsp-mode handles
  ;; it: https://github.com/emacs-lsp/lsp-mode/issues/4230
  (puthash "workspace/inlayHint/refresh"
           (lambda (workspace _params)
             (with-current-buffer (window-buffer)
               (when (and lsp-inlay-hints-mode
                          (memq workspace lsp--buffer-workspaces))
                 (lsp-update-inlay-hints (window-start) (window-end nil t))))
             nil)
           (lsp--client-request-handlers (gethash 'lean4-lsp lsp-clients))))

(use-package lsp-mode
  :custom
  (lsp-inlay-hint-enable t)
  ;; yasnippet and company aren't installed, and lsp-mode warns at each
  ;; server start and buffer.
  (lsp-enable-snippet nil)
  (lsp-completion-provider :none))

(use-package web-mode
  :mode ("\\.html?\\'" "\\.[jt]sx\\'"))

(use-package markdown-mode
  :mode ("\\.md\\'" . gfm-mode)
  :custom (markdown-fontify-code-blocks-natively t))

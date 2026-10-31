{ pkgs, ... }:
{
  programs.emacs = {
    enable = true;
    package = pkgs.emacs-pgtk;
    extraPackages =
      epkgs: with epkgs; [
        solarized-theme
        evil
        evil-collection
        envrc
        tuareg
        web-mode
        markdown-mode
        nix-mode
        # Not on MELPA or ELPA.
        (melpaBuild {
          pname = "lean4-mode";
          version = "1.1.2-unstable-2026-10-30";
          src = pkgs.fetchFromGitHub {
            owner = "leanprover-community";
            repo = "lean4-mode";
            rev = "833a282ef20d3b2589671e1c2f4a4f44f8b21715";
            hash = "sha256-Il/OxEuYd693XUOXrPSn9S4iH+4uLE4hgUcNwdLhNXU=";
          };
          # data holds the abbreviations of its input method.
          files = ''(:defaults "data")'';
          packageRequires = [
            dash
            lsp-mode
            magit-section
          ];
        })
      ];
  };

  home.file.".emacs.d/init.el".source = ./init.el;
}

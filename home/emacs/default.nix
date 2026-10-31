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
      ];
  };

  home.file.".emacs.d/init.el".source = ./init.el;
}

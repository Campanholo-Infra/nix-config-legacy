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
        proof-general
        tuareg
        clojure-mode
        cider
        web-mode
        markdown-mode
        nix-mode
        (treesit-grammars.with-grammars (g: [ g.tree-sitter-typescript ]))
        (trivialBuild {
          pname = "sail-mode";
          inherit (pkgs.ocamlPackages.sail) version src;
          sourceRoot = "sail-${pkgs.ocamlPackages.sail.version}/editors";
        })
      ];
  };

  home.file.".emacs.d/init.el".source = ./init.el;
}

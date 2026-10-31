{
  description = "Enzo's machines";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.2.0";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pre-commit.follows = "";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    helium = {
      url = "github:oxcl/nix-flake-helium-browser";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Not following our nixpkgs: its binary cache only has builds against its own pin.
    llm-agents.url = "github:numtide/llm-agents.nix";
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in
    {
      nixosConfigurations.MONSTRAO = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [ ./hosts/MONSTRAO ];
      };
      nixosConfigurations.MONSTRINHO = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [ ./hosts/MONSTRINHO ];
      };

      templates = {
        default = {
          path = ./templates/default;
          description = "Flake dev shell with direnv";
        };
        c = {
          path = ./templates/c;
          description = "C/C++ with CMake and clangd";
        };
        java = {
          path = ./templates/java;
          description = "Java with jdtls";
        };
        ocaml = {
          path = ./templates/ocaml;
          description = "OCaml in a project-local opam switch";
        };
      };

      formatter.x86_64-linux = pkgs.nixfmt-tree;
      checks.x86_64-linux.formatting = pkgs.nixfmt-tree.check self;
    };
}

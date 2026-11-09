{
  config,
  inputs,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  # The engine the plugin's launcher runs. Built from the plugin's own revision, so the two never drift.
  impeccable = pkgs.rustPlatform.buildRustPackage {
    pname = "impeccable";
    inherit ((lib.importTOML "${inputs.impeccable}/Cargo.toml").workspace.package) version;
    src = inputs.impeccable;
    cargoLock.lockFile = "${inputs.impeccable}/Cargo.lock";
    cargoBuildFlags = [
      "--package"
      "impeccable"
    ];
    # Its tests drive Chrome, which the build sandbox lacks.
    doCheck = false;
    meta.mainProgram = "impeccable";
  };
in
{
  home = {
    stateVersion = "26.05";
    # Not programs.claude-code.plugins: it links each top-level entry on its own, so Claude Code refuses every skill
    # the manifest lists as escaping the plugin directory. Remove when this is fixed:
    # https://github.com/nix-community/home-manager/issues/9906
    file = {
      "${config.programs.claude-code.configDir}/skills/mattpocock-skills".source =
        inputs.mattpocock-skills;
      "${config.programs.claude-code.configDir}/skills/impeccable".source = "${inputs.impeccable}/plugin";
    };
    packages = with pkgs; [
      ripgrep
      fd
      jq
    ];
  };

  programs = {
    bash.enable = true;
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    claude-code = {
      enable = true;
      # Installed system-wide.
      package = null;
      # Claude Code saves its own preferences, like the model, to the same file.
      mutableSettings = true;
      settings = {
        autoMemoryEnabled = false;
        enabledPlugins = {
          "cc-plugin-telemetry@builtin" = false;
          "cc-plugin-plugin-authoring@builtin" = false;
        };
        attribution = {
          commit = "";
          pr = "";
        };
        env = {
          ANTHROPIC_BASE_URL =
            let
              proxy = osConfig.services.cliproxyapi.settings.server;
            in
            "http://${proxy.host}:${toString proxy.port}";
          # Otherwise the launcher downloads its engine into ~/.impeccable on first run.
          IMPECCABLE_BIN = lib.getExe impeccable;
        };
      };
    };
    pi-coding-agent = {
      enable = true;
      # Installed system-wide.
      package = null;
      # pi saves its own preferences, like the model, to the same file.
      mutableSettings = true;
      # The skills the Claude Code plugin ships. skills/ also holds in-progress and deprecated ones.
      settings.skills = map (
        skill: "${inputs.mattpocock-skills}/${lib.removePrefix "./" skill}"
      ) (lib.importJSON "${inputs.mattpocock-skills}/.claude-plugin/plugin.json").skills;
    };
    gh.enable = true;
    git = {
      enable = true;
      settings = {
        user = {
          name = "Enzo L. Campanholo";
          email = "199099542+enzo-campanholo@users.noreply.github.com";
        };
        init.defaultBranch = "main";
      };
      ignores = [ "**/.claude/settings.local.json" ];
    };
  };
}

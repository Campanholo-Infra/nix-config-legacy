{
  osConfig,
  pkgs,
  ...
}:
{
  home = {
    stateVersion = "26.05";
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
        env.ANTHROPIC_BASE_URL =
          let
            proxy = osConfig.services.cliproxyapi.settings.server;
          in
          "http://${proxy.host}:${toString proxy.port}";
      };
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

{
  config,
  inputs,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  palette = import ./selenized.nix;
  sans = {
    name = "Adwaita Sans";
    package = pkgs.adwaita-fonts;
  };
  mono = {
    name = "JetBrains Mono";
    package = pkgs.jetbrains-mono;
  };
in
{
  imports = [
    inputs.nix-index-database.homeModules.default
    inputs.helium.homeModules.default
  ];

  # The NixOS module already installs niri's units, portals and xwayland-satellite.
  wayland.windowManager.niri = {
    enable = true;
    package = osConfig.programs.niri.package;
    systemd.enable = false;
    xwaylandSatellitePackage = null;
    portalPackage = null;
    extraConfig = builtins.replaceStrings [ "@fg_0@" "@bg_2@" ] [ palette.fg_0 palette.bg_2 ] (
      builtins.readFile ./niri.kdl
    );
  };

  fonts.fontconfig.defaultFonts = {
    sansSerif = [ sans.name ];
    monospace = [ mono.name ];
  };
  gtk = {
    enable = true;
    font = sans;
    colorScheme = "dark";
  };
  home.pointerCursor = {
    enable = true;
    name = "Adwaita";
    package = pkgs.adwaita-icon-theme;
    size = 24;
    gtk.enable = true;
  };

  home.packages = with pkgs; [
    mono.package
    nautilus
    wl-clipboard
    playerctl
    loupe
    mpv
  ];

  programs.helium.enable = true;

  # Gives Qt apps (sioyek, CoolerControl) the portal's dark color scheme and native file dialogs.
  qt = {
    enable = true;
    platformTheme.name = "xdgdesktopportal";
  };

  programs.fish = {
    enable = true;
    interactiveShellInit = "set -g fish_greeting";
  };
  programs.nix-index-database.comma.enable = true;
  programs.ghostty = {
    enable = true;
    settings = {
      theme = "Selenized Black";
      font-family = mono.name;
      command = lib.getExe config.programs.fish.package;
    };
  };

  programs.sioyek = {
    enable = true;
    # sioyek's OpenGL 3.3 core surface never maps under Qt's Wayland backend.
    # Drop the wrapper once https://github.com/ahrm/sioyek/issues/1660 is fixed.
    package = pkgs.symlinkJoin {
      inherit (pkgs.sioyek) name meta;
      paths = [ pkgs.sioyek ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = "wrapProgram $out/bin/sioyek --set QT_QPA_PLATFORM xcb";
    };
    config.startup_commands = [ "toggle_dark_mode" ];
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "helium.desktop";
      "x-scheme-handler/http" = "helium.desktop";
      "x-scheme-handler/https" = "helium.desktop";
      "application/pdf" = "sioyek.desktop";
      "text/plain" = "emacs.desktop";
    }
    // lib.genAttrs [
      "image/gif"
      "image/jpeg"
      "image/png"
      "image/webp"
    ] (_: "org.gnome.Loupe.desktop");
  };
}

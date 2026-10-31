{
  config,
  lib,
  pkgs,
  ...
}:
let
  palette = import ./selenized.nix;
  swaylock = lib.getExe config.programs.swaylock.package;
  # fuzzel wants RRGGBBAA without the leading #.
  rgba = color: lib.removePrefix "#" color + "ff";
in
{
  programs.waybar = {
    enable = true;
    systemd.enable = true;
    settings.main = {
      start_hidden = true;
      position = "bottom";
      modules-left = [ "niri/workspaces" ];
      modules-center = [ "niri/window" ];
      modules-right = [
        "pulseaudio"
        "clock"
      ];
      clock.format = "{:%a %d %b %H:%M}";
      pulseaudio.on-click = lib.getExe pkgs.pavucontrol;
    };
    style = ''
      * {
        font-family: monospace;
        font-size: 13px;
        border: none;
        border-radius: 0;
        box-shadow: none;
        min-height: 0;
      }
      window#waybar {
        background: ${palette.bg_0};
        color: ${palette.fg_0};
      }
      #workspaces button {
        padding: 0 6px;
        background: ${palette.bg_1};
        color: ${palette.dim_0};
        border: 1px solid ${palette.bg_2};
      }
      #workspaces button.focused {
        background: ${palette.bg_2};
        color: ${palette.fg_1};
        border-color: ${palette.dim_0};
      }
      #workspaces button.urgent {
        background: ${palette.red};
        color: ${palette.bg_0};
      }
      #window {
        padding: 0 8px;
      }
      #pulseaudio, #clock {
        padding: 0 8px;
        border-left: 1px solid ${palette.bg_2};
      }
    '';
  };

  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        font = "sans-serif";
        terminal = "${lib.getExe config.programs.ghostty.package} -e";
      };
      colors = {
        background = rgba palette.bg_0;
        text = rgba palette.fg_0;
        match = rgba palette.blue;
        selection = rgba palette.bg_2;
        selection-text = rgba palette.fg_1;
        selection-match = rgba palette.br_blue;
        border = rgba palette.dim_0;
      };
    };
  };

  home.packages = [
    (pkgs.writeShellApplication {
      name = "power-menu";
      runtimeInputs = [ config.programs.fuzzel.package ];
      text = ''
        case "$(printf '%s\n' Lock Suspend 'Log out' Reboot 'Power off' | fuzzel --dmenu)" in
          Lock) ${swaylock} -f ;;
          Suspend) systemctl suspend ;;
          'Log out') niri msg action quit --skip-confirmation ;;
          Reboot) systemctl reboot ;;
          'Power off') systemctl poweroff ;;
        esac
      '';
    })
  ];

  services.mako = {
    enable = true;
    settings = {
      font = "sans-serif 11";
      default-timeout = 5000;
      background-color = palette.bg_1;
      text-color = palette.fg_0;
      border-color = palette.dim_0;
    };
  };

  programs.swaylock = {
    enable = true;
    settings = {
      color = palette.bg_0;
      inside-color = palette.bg_1;
      ring-color = palette.bg_2;
      key-hl-color = palette.blue;
      text-color = palette.fg_0;
    };
  };

  services.swayidle = {
    enable = true;
    events.before-sleep = "${swaylock} -f";
  };

  services.polkit-gnome.enable = true;

  # Caspar David Friedrich, Monk by the Sea (1808-1810), Alte Nationalgalerie.
  # https://artsandculture.google.com/asset/KwEv_TMiJhn5kA, fetched with dezoomify-rs.
  systemd.user.services.swaybg = {
    Unit = {
      Description = "Wallpaper";
      ConditionEnvironment = "WAYLAND_DISPLAY";
      PartOf = [ config.wayland.systemd.target ];
      After = [ config.wayland.systemd.target ];
    };
    Service = {
      ExecStart = "${lib.getExe pkgs.swaybg} --mode fill --image ${./monk-by-the-sea.jpg}";
      Restart = "on-failure";
    };
    Install.WantedBy = [ config.wayland.systemd.target ];
  };
}

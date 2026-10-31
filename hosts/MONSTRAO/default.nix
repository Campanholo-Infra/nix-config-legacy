{ inputs, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    inputs.lanzaboote.nixosModules.lanzaboote
    ../../modules/nixos/common.nix
    ../../modules/nixos/desktop.nix
  ];

  networking.hostName = "MONSTRAO";

  boot = {
    lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
      # The 1 GiB ESP is shared with Windows.
      configurationLimit = 5;
    };
    # CoolerControl needs this driver for the board's Nuvoton NCT6799 fan controller, and nothing loads it automatically.
    kernelModules = [ "nct6775" ];
  };
  environment.systemPackages = [ pkgs.sbctl ];

  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    # Blackwell is only supported by the open kernel modules.
    open = true;
    powerManagement.enable = true;
    nvidiaSettings = false;
  };
  nixpkgs.config.allowUnfreePackages = [
    "nvidia-x11"
    "yEd"
  ];

  # The driver keeps freed buffers instead of returning them, so niri grows to ~1 GiB of VRAM.
  # https://github.com/NVIDIA/egl-wayland/issues/126#issuecomment-2379945259
  # Drop this once the driver's own nvidia-application-profiles-rc has a rule for niri.
  environment.etc."nvidia/nvidia-application-profiles-rc.d/50-niri.json".text = builtins.toJSON {
    rules = [
      {
        pattern = {
          feature = "procname";
          matches = "niri";
        };
        profile = "Limit Free Buffer Pool On Wayland Compositors";
      }
    ];
    profiles = [
      {
        name = "Limit Free Buffer Pool On Wayland Compositors";
        settings = [
          {
            key = "GLVidHeapReuseRatio";
            value = 0;
          }
        ];
      }
    ];
  };

  # The Logitech receiver (c547) wakes the machine from S3 a few seconds after every suspend
  # (/sys/power/pm_wakeup_irq and its wakeup counters). The mouse on its charging cable (c094) is
  # disabled too, so only the keyboard and power button wake it.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="046d", ATTR{idProduct}=="c547|c094", ATTR{power/wakeup}="disabled"
  '';

  programs.coolercontrol.enable = true;

  programs.nh.flake = "/home/isolino/nix-config";

  users.users.isolino.extraGroups = [ "wheel" ];

  # Never load a new NVIDIA driver under a running session.
  system.autoUpgrade.operation = "boot";

  home-manager.users.isolino =
    { config, ... }:
    {
      imports = [
        ../../home/common.nix
        ../../home/dev.nix
        ../../home/emacs
        ../../home/neovim.nix
        ../../home/linux/desktop.nix
        ../../home/linux/session.nix
      ];
      xdg.configFile."niri/host.kdl".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix-config/hosts/MONSTRAO/niri.kdl";
    };

  system.stateVersion = "26.05";
}

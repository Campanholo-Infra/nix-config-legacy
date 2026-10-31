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
  ];

  # The driver keeps freed buffers instead of returning them, so niri grows to ~1 GiB of VRAM.
  # https://github.com/NVIDIA/egl-wayland/issues/126#issuecomment-2379945259
  # The driver's own nvidia-application-profiles-rc applies its "No VidMem Reuse" profile to other
  # compositors; drop this once the driver ships a niri rule.
  environment.etc."nvidia/nvidia-application-profiles-rc.d/50-niri.json".text = builtins.toJSON {
    rules = [
      {
        pattern = {
          feature = "procname";
          matches = "niri";
        };
        profile = "No VidMem Reuse";
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

  users.users.isolino = {
    extraGroups = [ "wheel" ];
    # Root-only, outside this public repo. If missing, activation only warns and locks
    # isolino; if empty, console login takes no password.
    hashedPasswordFile = "/var/lib/hashed-passwords/isolino";
  };

  # Never load a new NVIDIA driver under a running session.
  system.autoUpgrade.operation = "boot";

  home-manager.users.isolino = {
    imports = [
      ../../home/common.nix
      ../../home/emacs
      ../../home/neovim.nix
      ../../home/desktop/desktop.nix
      ../../home/desktop/session.nix
    ];
    programs.claude-code.settings.autoMode = {
      soft_deny = [
        "$defaults"
        "Bash(nixos-rebuild switch --target-host root@*:*)"
      ];
      environment = [
        "### Org-wide"
        "**Organization**: None configured"
        "**Cloud provider(s)**: None configured"
        "**Repository visibility**: public — enzo-campanholo/nix-config-legacy (confirmed via gh); enzo-campanholo/nix-config, not yet created, will replace it; treat as public — only this repo's own work belongs here, never ported/sensitive content"
        "**Internal sharing / snippet hosting**: None configured — treat public paste/gist services as outside the trust boundary"
        "**Secrets management**: Tailscale login kept in /var/lib/tailscale (not in repo); CLIProxyAPI logins kept in /var/lib/cliproxyapi (not in repo) — both excluded from the repo by design, per README"
        "**Default / protected branches**: main (default branch, via gh); Rulesets: none listed; Protected branches: none listed (via gh) — treat as unprotected since no rulesets were found either"
        "**CI/CD deploy targets**: GitHub Actions workflow updates flake.lock daily; both MONSTRAO and MONSTRINHO auto-deploy main at 04:40 via pull — pushing to main is equivalent to deploying to both machines"
        "**Network posture**: None configured"
        "**Host containment**: None configured — assume Claude Code runs on MONSTRAO, an ordinary developer machine with open internet"
        "**Source control**: The trusted repo (enzo-campanholo/nix-config-legacy, then enzo-campanholo/nix-config, not yet created, once it replaces it) and its origin remote only (no additional orgs configured)"
        "**Trusted internal domains**: None configured"
        "**Trusted cloud buckets**: None configured"
        "**Key internal services**: CLIProxyAPI at 127.0.0.1:8317 on both machines (proxies Claude model requests, local-only, firewalled on MONSTRINHO to isolino only)"
        "**Internal package registry**: None configured"
        "**Sensitive data locations & audiences**: /var/lib/tailscale (Tailscale login state), /var/lib/cliproxyapi (Claude subscription logins), /var/lib/sbctl (MONSTRAO's Secure Boot keys) — all machine-local, never committed to the repo; share only with the user"
        "**Data retention / declassification**: None configured"
        "**Sensitive remote targets**: any namespace/host/container with 'prod' or 'production' as a whole word/segment (no explicit prod targets found); EFI/Microsoft on MONSTRAO's EFI partition, which it shares with Windows, is a separate explicit do-not-touch boundary per CLAUDE.md"
        "**Protected deployment namespaces / environments**: None configured — fall back to the Sensitive remote targets heuristic"
        "**Protected IaC scopes**: IAM, RBAC, networking, quota, and node-pool resources; anything whose name or tag carries 'prod' or 'production' as a whole word or name segment"
        "### User-specific"
        "**Primary use of Claude Code**: NixOS/Home Manager system configuration for personal machines (MONSTRAO desktop, MONSTRINHO home server)"
        "**Trusted repo**: enzo-campanholo/nix-config-legacy (public; enzo-campanholo/nix-config, not yet created, will replace it) at /home/isolino/nix-config, and its origin remote — only this repo's own work is OK to push here; no secrets or sensitive data regardless of visibility"
        "**Org-specific CLIs**: None configured — project uses nix, nixos-rebuild, nh, home-manager tooling routinely under this project"
        "MONSTRINHO deploys go to root@ (not the isolino user) by explicit design per CLAUDE.md/README — a trusted isolino user would let its agents become root; routine deploy commands targeting root@MONSTRINHO are expected, not an escalation"
      ];
    };
  };

  system.stateVersion = "26.05";
}

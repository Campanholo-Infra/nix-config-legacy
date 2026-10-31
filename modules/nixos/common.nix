{
  config,
  inputs,
  pkgs,
  ...
}:
{
  imports = [ inputs.home-manager.nixosModules.home-manager ];

  environment.systemPackages = with inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}; [
    claude-code
    pi
    # For logging the proxy in to the subscriptions.
    config.services.cliproxyapi.package
  ];

  # Pools the Claude subscriptions, using each until it runs out. It takes no client keys, so Claude Code
  # keeps its claude.ai login, and the features that need it, while sending model requests here.
  services.cliproxyapi = {
    enable = true;
    settings = {
      server.host = "127.0.0.1";
      routing.strategy = "fill-first";
      # Otherwise it downloads its web panel from GitHub at every start, though nothing uses it.
      management.disable-control-panel = true;
    };
  };

  nix = {
    channel.enable = false;
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      extra-substituters = [ "https://cache.numtide.com" ];
      extra-trusted-public-keys = [
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      ];
    };
    optimise.automatic = true;
  };
  system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;

  system.autoUpgrade = {
    enable = true;
    flake = "github:enzo-campanholo/nix-config-legacy#${config.networking.hostName}";
    upgrade = false;
  };

  # Otherwise anyone at the boot menu can add init=/bin/sh to the kernel command line.
  boot.loader.systemd-boot.editor = false;

  time.timeZone = "America/Sao_Paulo";

  services.fwupd.enable = true;

  services.tailscale.enable = true;
  services.resolved = {
    # Without resolved, tailscaled reads the upstream DNS servers when it starts, before DHCP has provided any.
    enable = true;
    # Anything on the LAN can answer these lookups, and the machines find each other through Tailscale's DNS.
    settings.Resolve = {
      LLMNR = false;
      MulticastDNS = false;
    };
  };

  # Completions for system packages in fish, which Ghostty starts. The login shell stays bash.
  programs.fish.enable = true;

  programs.nh = {
    enable = true;
    clean = {
      enable = true;
      extraArgs = "--keep 5 --no-direnv";
    };
  };

  users.users.isolino.isNormalUser = true;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
  };
}

{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  isolinoKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHmdvVI+bCuVV30u90N68GFXu4SY439a9wKV1SOIr7Rs isolino@MONSTRAO";
  llmAgents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  # The subscription proxy takes no client keys, so this is what keeps lavietos's agents off isolino's subscriptions.
  proxyOnlyForIsolino = "OUTPUT -o lo -p tcp --dport ${toString config.services.cliproxyapi.settings.server.port} -m owner ! --uid-owner isolino -j REJECT";
in
{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
    inputs.disko.nixosModules.disko
    ../../modules/nixos/common.nix
  ];

  networking.hostName = "MONSTRINHO";

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    kernelParams = [ "consoleblank=60" ];
  };

  services.logind.settings.Login.HandleLidSwitch = "ignore";
  systemd.sleep.settings.Sleep = {
    AllowSuspend = false;
    AllowHibernation = false;
  };
  services.upower = {
    enable = true;
    criticalPowerAction = "PowerOff";
  };
  # Without a desktop nothing activates upower over D-Bus, so it would never see the battery run down.
  systemd.services.upower.wantedBy = [ "multi-user.target" ];
  services.thermald.enable = true;
  # This firmware has no usable adaptive policy: thermald exits and expects a restart to run without one, as upstream's unit does.
  systemd.services.thermald.serviceConfig.Restart = "on-failure";
  zramSwap.enable = true;
  # Leave RAM outside users' workloads even if their zram pages don't compress.
  systemd.slices.user.sliceConfig = {
    MemoryMax = "6G";
    MemorySwapMax = "2G";
  };
  # Users' builds, their agents' included, run in nix-daemon, outside user.slice; root's, like the nightly upgrade's,
  # don't go through it. Substituting fills it mostly with page cache, which MemoryHigh reclaims first.
  systemd.services.nix-daemon.serviceConfig = {
    MemoryHigh = "2.5G";
    MemoryMax = "3G";
  };
  # T3 sizes app-t3code-agents.slice from physical RAM (5.6 GiB here) and doesn't rewrite its parent, so bound each
  # user's agents and terminals here. Both users' (2 × 2G), the T3 servers and lavietos's Hermes (~1.1G) fit under the
  # shared cap, so a busy agent can't make the T3 servers thrash.
  # oomd kills the agent under pressure, and T3 fails its turn for Claude and pi. 80%: at 40%, oomd killed an agent
  # running `nix flake check` that wasn't starved.
  systemd.user.slices.app-t3code.sliceConfig = {
    MemoryHigh = "1792M";
    MemoryMax = "2G";
    MemorySwapMax = "768M";
    ManagedOOMMemoryPressure = "kill";
    ManagedOOMMemoryPressureLimit = "80%";
  };

  services.openssh = {
    enable = true;
    # Only from the LAN and over Tailscale, not on the public IPv6 address.
    openFirewall = false;
    # Every key is declared here: an agent could otherwise let anyone in as its user by adding one to ~/.ssh.
    authorizedKeysInHomedir = false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };
  networking.firewall = {
    extraCommands = ''
      iptables -A nixos-fw -p tcp --dport 22 -s 192.168.15.0/24 -j nixos-fw-accept
      iptables -A ${proxyOnlyForIsolino}
    '';
    extraStopCommands = "iptables -D ${proxyOnlyForIsolino} || true";
  };
  # dhcpcd's resolvconf hook makes each protocol overwrite or clear the whole link's DNS in resolved.
  networking.useNetworkd = true;
  networking.useDHCP = false;
  systemd.network.networks."10-ethernet" = {
    matchConfig.Name = "enp2s0";
    networkConfig.DHCP = "yes";
    # The router also offers itself as an IPv6 DNS server, and its replies to EDNS queries are malformed
    # (the OPT record ahead of the answer). Keep the DHCPv4 servers only.
    ipv6AcceptRAConfig.UseDNS = false;
    dhcpV6Config.UseDNS = false;
  };
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  users.users = {
    # Deploys go to root@: making isolino a trusted Nix user would let its agents become root.
    root.openssh.authorizedKeys.keys = [ isolinoKey ];
    # No wheel for either user: our agents run as us, and sudo would give them the whole machine.
    isolino = {
      openssh.authorizedKeys.keys = [ isolinoKey ];
      linger = true;
    };
    lavietos = {
      isNormalUser = true;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJU9VqlHeLAvukPFLKW8vN4BedMxQBasFvn6JYD4NCZe luis@DESKTOP-I16FQN7"
      ];
      packages = [
        pkgs.python3
        llmAgents.hermes-agent
      ];
      linger = true;
    };
  };
  # With no wheel, sudo is only a setuid-root binary for agents to probe.
  security.sudo.enable = false;

  systemd.tmpfiles.rules = [
    "d /srv/isolino 0700 isolino users"
    "d /srv/lavietos 0700 lavietos users"
    "d /srv/shared 2770 root users"
    # Keeps files in the shared directory writable by both of us whatever the creator's umask.
    "a+ /srv/shared - - - - default:group::rwx"
  ];

  programs.git.enable = true;
  # T3's bundled chrome-headless-shell and downloaded browsers like Playwright's are generic Linux binaries, which
  # NixOS can't run otherwise.
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      glib
      nspr
      nss
      dbus
      at-spi2-core
      libx11
      libxcomposite
      libxdamage
      libxext
      libxfixes
      libxrandr
      libxcb
      libxkbcommon
      libgbm
      expat
      alsa-lib
      fontconfig
      freetype
    ];
  };
  environment.systemPackages = [
    # Ghostty on MONSTRAO sends TERM=xterm-ghostty over SSH.
    pkgs.ghostty.terminfo
    # The wrapper only adds providers to PATH: claude and pi are installed anyway, and the rest go unused.
    llmAgents.t3code.unwrapped
  ];

  # `hermes gateway install` writes a unit that runs Nix's bare Python, which can't load Hermes.
  systemd.user.services.hermes = {
    description = "Hermes Agent gateway";
    wantedBy = [ "default.target" ];
    unitConfig = {
      ConditionUser = "lavietos";
      ConditionPathExists = "%h/.hermes/config.yaml";
    };
    # The default PATH would hide the user's tools from the agent.
    enableDefaultPath = false;
    serviceConfig = {
      ExecStart = "${lib.getExe llmAgents.hermes-agent} gateway run";
      Restart = "on-failure";
      # It takes SIGTERM for a crash: dumps diagnostics and skips saving its state.
      KillSignal = "SIGINT";
      # Keeps the files its agents create, in /tmp too, private to their user.
      UMask = "0077";
    };
  };

  # Not t3code.service, the name `t3 service install` gives its own unit, which would override this one.
  systemd.user.services.t3 = {
    description = "T3 Code server";
    # A switch that changes it restarts it, so the nightly upgrade picks up new versions. That kills its terminals,
    # and with them any switch run from one: deploy from MONSTRAO.
    wantedBy = [ "default.target" ];
    # Deploys log in as root, whose user manager would otherwise serve T3 Code as root.
    unitConfig.ConditionUser = "!@system";
    # The default PATH would hide the user's tools from its agents and terminals.
    enableDefaultPath = false;
    environment = {
      T3CODE_TELEMETRY_ENABLED = "false";
      # T3 Connect's tunnel, which T3 otherwise downloads into ~/.t3/tools.
      T3CODE_CLOUDFLARED_PATH = lib.getExe pkgs.cloudflared;
    };
    serviceConfig = {
      # A port per user from their UID: 31000 for isolino, 31001 for lavietos. Tailscale Serve and T3 Connect's tunnel
      # reach it on loopback.
      ExecStart = "${lib.getExe llmAgents.t3code.unwrapped} serve --host 127.0.0.1 --port 3%U";
      Restart = "on-failure";
      RestartSec = 5;
      # Its terminals run interactive shells, which ignore SIGTERM but not SIGHUP.
      SendSIGHUP = true;
      # In case it still hangs, don't hold up shutdown. A clean stop exits 130.
      TimeoutStopSec = 10;
      SuccessExitStatus = 130;
      # Keeps the files its agents and terminals create, in /tmp too, private to their user.
      UMask = "0077";
    };
  };
  # Browsers only give HTTPS pages the clipboard API, which T3 copies paths with: each user's T3 port 3%U is served at
  # https://monstrinho.<tailnet>.ts.net:4%U, the only name its certificate covers. This owns the whole serve config, so
  # nothing served by hand outlives a restart.
  systemd.services.t3-tailscale-serve = {
    description = "Serve T3 Code over HTTPS on the tailnet";
    after = [ "tailscaled.service" ];
    wants = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ config.services.tailscale.package ];
    # tailscaled reports ready while its backend is still NoState, which serve rejects as "unexpected state: NoState".
    # Not after tailscale-online.target: it waits without a timeout, which could hang switches and boot.
    script = ''
      tailscale wait --timeout=1m
      tailscale serve reset
      tailscale serve --bg --https=41000 http://127.0.0.1:31000
      tailscale serve --bg --https=41001 http://127.0.0.1:31001
    '';
    preStop = "tailscale serve reset";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # A oneshot has no start timeout, and serve can wait forever for HTTPS to be enabled on the tailnet.
      TimeoutStartSec = "2min";
      # In case tailscaled takes longer, as without network at boot.
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  system.autoUpgrade = {
    allowReboot = true;
    rebootWindow = {
      lower = "04:00";
      upper = "06:00";
    };
  };

  home-manager.users.isolino.imports = [
    ../../home/common.nix
    ../../home/neovim.nix
  ];

  system.stateVersion = "26.05";
}

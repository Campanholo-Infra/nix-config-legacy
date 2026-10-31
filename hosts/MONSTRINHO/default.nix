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
  uid = user: toString config.users.users.${user}.uid;
  servePort = user: "4${uid user}";
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
    # Blanking the console is what turns the closed lid's eDP panel and backlight off.
    # A lit panel after a root DRM client exits doesn't mean this is ineffective: the
    # client relights it without unblanking fbcon.
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
  networking.firewall.extraInputRules = "ip saddr 192.168.15.0/24 tcp dport 22 accept";
  # SSH and Serve are reached over Tailscale. tailscaled's own iptables rules accept tailscale0, but the nftables
  # firewall drops it anyway.
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
  # Our agents listen on loopback without authentication (dev servers, agent-browser's Chromium DevTools port), so only
  # their user and root may connect. The output hook sees only the sending socket: the SYN shows the client's UID, and
  # only the SYN-ACK shows the listener's. So the SYN stores the client's UID in the conntrack mark (whose 0xff0000 bits
  # are tailscaled's, saved at priority mangle), a SYN-ACK to another user is dropped and flagged, and the client's
  # retried SYN, a second later, is refused. UDP requests still get through; only the replies are dropped.
  networking.nftables.tables.loopback-owners = {
    family = "inet";
    content = ''
      chain output {
        type filter hook output priority mangle - 5; policy accept;
        oifname "lo" ct direction original ct mark & 0x1000000 != 0 reject
        oifname "lo" ct state new ct mark set meta skuid
        ${lib.concatMapStrings
          (user: ''
            oifname "lo" ct direction reply meta skuid ${uid user} ct mark & 0xffff != { 0, ${uid user} } ct mark set ct mark | 0x1000000 drop
          '')
          [
            "isolino"
            "lavietos"
          ]
        }
        # Root's proxies to one user. CLIProxyAPI takes no client keys, so this is what keeps lavietos's agents off
        # isolino's subscriptions; Tailscale Serve would let each user's agents into the other's T3.
        oifname "lo" tcp dport ${toString config.services.cliproxyapi.settings.server.port} meta skuid != ${uid "isolino"} reject
        oifname "lo" tcp dport ${servePort "isolino"} meta skuid != ${uid "isolino"} reject
        oifname "lo" tcp dport ${servePort "lavietos"} meta skuid != ${uid "lavietos"} reject
      }
    '';
  };
  # The owner's devices connect here, never the reverse. MONSTRAO's tailscaled lets every SYN to its peerapi port past
  # its ACLs (net/tstun/wrap.go) and into its netstack, ahead of its firewall (wgengine/netstack/netstack.go), and takes
  # MONSTRINHO, logged in as the same user, for one of the owner's own devices. Root's connections too: tailscaled dials
  # as root for `tailscale nc`, which any user can run.
  networking.nftables.tables.tailnet-egress = {
    family = "inet";
    content = ''
      chain output {
        type filter hook output priority filter; policy accept;
        oifname "tailscale0" ip daddr 100.100.100.100 meta l4proto { tcp, udp } th dport 53 accept
        oifname "tailscale0" ip6 daddr fd7a:115c:a1e0::53 meta l4proto { tcp, udp } th dport 53 accept
        oifname "tailscale0" ct state new reject
      }
    '';
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

  users.users = {
    # Deploys go to root@: making isolino a trusted Nix user would let its agents become root.
    root.openssh.authorizedKeys.keys = [ isolinoKey ];
    # No wheel for either user: our agents run as us, and sudo would give them the whole machine.
    # The T3 ports and loopback-owners depend on these uids.
    isolino = {
      uid = 1000;
      openssh.authorizedKeys.keys = [ isolinoKey ];
      packages = [ llmAgents.agent-browser ];
      linger = true;
    };
    lavietos = {
      uid = 1001;
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

  programs.git.enable = true;
  # T3 downloads chrome-headless-shell into ~/.t3/tools, and Playwright and Puppeteer download browsers into ~/.cache:
  # generic Linux binaries, which NixOS can't run otherwise.
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
      cairo
      pango
      cups
    ];
  };
  environment.systemPackages = [
    # Ghostty on MONSTRAO sends TERM=xterm-ghostty over SSH.
    pkgs.ghostty.terminfo
    # The wrapper only adds providers to PATH: claude and pi are installed anyway, and the rest go unused.
    llmAgents.t3code.unwrapped
  ];
  documentation.nixos.enable = false;

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
      tailscale serve --bg --https=${servePort "isolino"} http://127.0.0.1:3${uid "isolino"}
      tailscale serve --bg --https=${servePort "lavietos"} http://127.0.0.1:3${uid "lavietos"}
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

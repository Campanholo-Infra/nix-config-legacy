# nix-config

NixOS and Home Manager configuration for my machines: MONSTRAO, a desktop, and MONSTRINHO, a headless home server on a laptop.

## Rebuild

```sh
nh os switch        # or: sudo nixos-rebuild switch --flake ~/nix-config
```

Deploy MONSTRINHO from MONSTRAO, without sudo. It logs in as root because deploying as isolino would require isolino to be a trusted Nix user, which would let its agents become root.

```sh
nixos-rebuild switch --flake ~/nix-config#MONSTRINHO --target-host root@MONSTRINHO
```

A daily GitHub Action updates `flake.lock` once the checks and both builds pass. Both machines install `main` at 04:40, or as soon as they're back on if they were off or asleep. MONSTRAO stages it for its next boot. MONSTRINHO switches to it, or reboots into it if the kernel or initrd changed; outside 04:00–06:00 it skips the reboot and waits for the next boot. Either way this replaces anything deployed by hand, so push your changes.

## Tailscale

Both machines run Tailscale. After installing one, log it in once and follow the login URL; the login is kept in `/var/lib/tailscale`, not in the repo.

```sh
sudo tailscale up                  # MONSTRAO
ssh root@MONSTRINHO tailscale up   # MONSTRINHO
tailscale ping MONSTRINHO
```

## Claude subscriptions

Both machines run CLIProxyAPI on 127.0.0.1:8317, which uses one Claude subscription until it runs out and then the other. Claude Code sends its model requests there and keeps its own claude.ai login for everything else. On MONSTRINHO the firewall lets only isolino reach it.

Log each machine's proxy in to both subscriptions, running the command once per account. Open the URL it prints, approve, and paste back the URL of the `localhost` page that fails to load. The logins are kept in `/var/lib/cliproxyapi`, not in the repo.

```sh
cd / && sudo -u cliproxyapi cliproxyapi -config /var/lib/cliproxyapi/config.yaml --claude-login -no-browser
ssh -t root@MONSTRINHO 'cd /var/lib/cliproxyapi && runuser -u cliproxyapi -- cliproxyapi -config config.yaml --claude-login -no-browser'
```

## T3 Code on MONSTRINHO

Each user has a Nix-managed `t3.service` listening on loopback: isolino's on port 31000 and lavietos's on 31001. Reach it over the tailnet at `https://monstrinho.<tailnet>.ts.net:41000` (isolino) or `:41001` (lavietos), or through T3 Connect.

As that user, `journalctl --user -u t3` shows the pairing token printed at startup, and `t3 pair` mints a new one.

To enable T3 Connect, run these as the user whose environment you want to connect to:

```sh
t3 connect link --headless
systemctl --user restart t3
```

Linking saves setup for the next server start. Use `systemctl --user status t3`, not `t3 service status`: the latter only checks T3's own installer. Don't run `t3 service install` alongside the Nix-managed service. Restarting T3 interrupts its terminals.

## Rex on MONSTRINHO

isolino has a Nix-managed personal Rex server, `rex.service`. Only the Tailscale account MONSTRINHO is logged in as can connect to it. From Rex's Apple apps, add `monstrinho.<tailnet>.ts.net` as a remote host. From another machine's CLI, run `rex -S https://monstrinho.<tailnet>.ts.net ls`. On MONSTRINHO, `rex client ls` shows who is connected.

A switch never restarts the server, so it keeps running the old version after an update. Run `systemctl --user restart rex` to move to the new version. Restarting ends every Rex session.

## Recovery

- Run `sudo nixos-rebuild switch --rollback` on MONSTRAO or `ssh root@MONSTRINHO nixos-rebuild switch --rollback`; if a machine doesn't boot, pick an older generation in its boot menu first. Then revert or fix the bad commit on GitHub: both machines reinstall `main` daily, and stopping `nixos-upgrade.timer` only lasts until the next reboot.
- MONSTRAO's Secure Boot keys live in `/var/lib/sbctl`. Back them up. If they are lost, nothing new will boot until Secure Boot is turned off or new keys are enrolled.
- MONSTRAO's 1 GiB EFI partition is shared with Windows. Never delete `EFI/Microsoft`. The boot menu keeps 5 generations so the partition does not fill up.

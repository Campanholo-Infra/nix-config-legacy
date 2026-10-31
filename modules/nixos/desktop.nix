{
  config,
  lib,
  pkgs,
  ...
}:
{
  programs.niri.enable = true;
  environment.systemPackages = [ pkgs.xwayland-satellite ];

  services.greetd = {
    enable = true;
    useTextGreeter = true;
    settings.default_session.command = "${lib.getExe pkgs.tuigreet} --time --remember --background doom --asterisks --cmd ${lib.getExe' config.programs.niri.package "niri-session"}";
  };
  console = {
    packages = [ pkgs.terminus_font ];
    font = "ter-v24b";
  };
  # The GPU driver replaces the firmware framebuffer after systemd-vconsole-setup has run, which resets
  # the console to the kernel's font. systemd only reapplies the font for new vtcon devices, and this isn't one.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="graphics", KERNEL=="fb[0-9]*", RUN+="${lib.getExe' config.systemd.package "systemctl"} --no-block restart systemd-vconsole-setup.service"
  '';

  services.logind.settings.Login.HandlePowerKey = "suspend";

  # GTK 4.20 leaves dead keys to an input method on Wayland; this has it compose them itself.
  # https://niri-wm.github.io/niri/Application-Issues.html#gtk-4-dead-keys-compose
  environment.sessionVariables.GTK_IM_MODULE = "simple";

  networking.networkmanager.enable = true;
  networking.modemmanager.enable = false;
  users.users.isolino.extraGroups = [ "networkmanager" ];

  # Completions for system packages in fish, which Ghostty starts. The login shell stays bash.
  programs.fish.enable = true;

  security.rtkit.enable = true;
  services.gvfs.enable = true;
  services.speechd.enable = false;
}

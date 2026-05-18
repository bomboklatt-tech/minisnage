{ pkgs, lib, userConfig, ... }:

let
  validRestart = [ "always" "on-failure" "no" ];
  gui = userConfig.kiosk.gui;
in

assert lib.assertOneOf "userConfig.kiosk.restart"
  userConfig.kiosk.restart validRestart;

lib.mkMerge [
  # Shared: user, group, autologin on tty2-tty6.
  {
    users.users.${userConfig.kiosk.user} = {
      isNormalUser = true;
      group = userConfig.kiosk.user;
      home = "/home/${userConfig.kiosk.user}";
      createHome = true;
      shell = pkgs.bashInteractive;
    };
    users.groups.${userConfig.kiosk.user} = { };

    services.getty.autologinUser = userConfig.kiosk.user;
  }

  # Console kiosk: hello-kiosk grabs tty1.
  (lib.mkIf (!gui) {
    systemd.services."getty@tty1".enable = false;

    systemd.services.hello-kiosk = {
      description = "mininix kiosk task (console)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" "systemd-user-sessions.service" ];
      wants = [ "network-online.target" ];
      conflicts = [ "getty@tty1.service" ];
      serviceConfig = {
        Type = "idle";
        ExecStart = "${pkgs.hello-kiosk}/bin/hello-kiosk";
        User = userConfig.kiosk.user;
        Restart = userConfig.kiosk.restart;
        StandardInput = "tty";
        StandardOutput = "tty";
        StandardError = "tty";
        TTYPath = "/dev/tty1";
        TTYReset = "yes";
        TTYVHangup = "yes";
        TTYVTDisallocate = "yes";
      };
    };
  })

  # GUI kiosk: cage (Wayland compositor) on tty1, runs hello-kiosk-gui (foot).
  # All wayland/wlroots/foot deps only enter the closure on this path.
  (lib.mkIf gui {
    services.cage = {
      enable = true;
      user = userConfig.kiosk.user;
      program = "${pkgs.hello-kiosk-gui}/bin/hello-kiosk-gui";
    };

    # services.cage sets hardware.graphics = mkDefault true, but our
    # minimization module pins it false at default priority. Force it on
    # for this path.
    hardware.graphics.enable = lib.mkForce true;
  })
]

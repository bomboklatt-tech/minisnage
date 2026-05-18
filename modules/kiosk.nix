{ pkgs, lib, userConfig, ... }:

let
  validRestart = [ "always" "on-failure" "no" ];
in

assert lib.assertOneOf "userConfig.kiosk.restart"
  userConfig.kiosk.restart validRestart;

{
  users.users.${userConfig.kiosk.user} = {
    isNormalUser = true;
    group = userConfig.kiosk.user;
    home = "/home/${userConfig.kiosk.user}";
    createHome = true;
    shell = pkgs.bashInteractive;
  };
  users.groups.${userConfig.kiosk.user} = { };

  # tty1 is owned by the kiosk service. Stop getty from grabbing it.
  systemd.services."getty@tty1".enable = false;

  # Autologin the kiosk user on the other VTs (tty2-tty6) so anyone with
  # console access can drop into a shell for inspection.
  services.getty.autologinUser = userConfig.kiosk.user;

  systemd.services.hello-kiosk = {
    description = "mininix kiosk task";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "systemd-user-sessions.service" ];
    wants = [ "network-online.target" ];
    conflicts = [ "getty@tty1.service" ];
    serviceConfig = {
      Type = "idle";
      ExecStart = "${pkgs.hello-kiosk}/bin/hello-kiosk";
      User = userConfig.kiosk.user;
      Restart = userConfig.kiosk.restart;

      # Take over /dev/tty1 so cowsay (and anything else the script prints)
      # is visible on the console.
      StandardInput = "tty";
      StandardOutput = "tty";
      StandardError = "tty";
      TTYPath = "/dev/tty1";
      TTYReset = "yes";
      TTYVHangup = "yes";
      TTYVTDisallocate = "yes";
    };
  };
}

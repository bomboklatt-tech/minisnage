{ pkgs, lib, userConfig, ... }:

let
  validRestart = [ "always" "on-failure" "no" ];
in

assert lib.assertOneOf "userConfig.kiosk.restart"
  userConfig.kiosk.restart validRestart;

{
  users.users.${userConfig.kiosk.user} = {
    isSystemUser = true;
    group = userConfig.kiosk.user;
  };
  users.groups.${userConfig.kiosk.user} = { };

  systemd.services.hello-kiosk = {
    description = "mininix kiosk task";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.hello-kiosk}/bin/hello-kiosk";
      User = userConfig.kiosk.user;
      Restart = userConfig.kiosk.restart;
    };
  };
}

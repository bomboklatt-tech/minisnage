{ config, lib, ... }:

let
  cfg = config.mininix;
in

{
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  users.users.root.openssh.authorizedKeys.keys = cfg.sshAuthorizedKeys;

  networking.hostName = cfg.hostname;

  # WiFi block only emitted when at least one network is configured.
  networking.wireless = lib.mkIf (cfg.wifi != [ ]) {
    enable = true;
    networks = builtins.listToAttrs (map (n: {
      name = n.ssid;
      value = { psk = n.psk; };
    }) cfg.wifi);
  };
}

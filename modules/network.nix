{ lib, userConfig, ... }:

{
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  users.users.root.openssh.authorizedKeys.keys = userConfig.sshAuthorizedKeys;

  networking.hostName = userConfig.hostname;

  # WiFi block only emitted when at least one network is configured.
  networking.wireless = lib.mkIf (userConfig.wifi != [ ]) {
    enable = true;
    networks = builtins.listToAttrs (map (n: {
      name = n.ssid;
      value = { psk = n.psk; };
    }) userConfig.wifi);
  };
}

{ lib, ... }:

let
  wifiNetwork = lib.types.submodule {
    options = {
      ssid = lib.mkOption {
        type = lib.types.str;
        description = "WiFi network SSID.";
      };
      psk = lib.mkOption {
        type = lib.types.str;
        description = ''
          Pre-shared key (WPA2). Stored plaintext - acceptable for this
          appliance because nothing else lives on the host.
        '';
      };
    };
  };
in

{
  options.mininix = {
    wifi = lib.mkOption {
      type = lib.types.listOf wifiNetwork;
      default = [ ];
      description = ''
        WiFi networks to associate with. An empty list disables
        wpa_supplicant entirely so the daemon isn't pulled into the closure.
      '';
    };

    sshAuthorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        SSH public keys authorized to log in as root. Empty list = no
        key-based root login (password auth may still be available when
        mininix.debug = true).
      '';
    };
  };
}

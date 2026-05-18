# All user-facing configuration for mininix.
# Checked into git as plaintext - this is by design.
#
# NOTE: cross-compiling from darwin requires a system-level linux-builder
# (nix-darwin's `nix.linux-builder` or a remote builder). This flake does
# not configure it.
{ pkgs, ... }:

{
  mininix = {
    hostname = "mininix";

    # WiFi networks. Empty list disables wpa_supplicant entirely.
    wifi = [
      # { ssid = "MyNetwork"; psk = "my-password"; }
    ];

    # SSH authorized keys for root. Empty list = no key-based ssh login
    # (mininix.debug = true also forces password auth on).
    sshAuthorizedKeys = [
      # "ssh-ed25519 AAAA... user@host"
    ];

    # Use squashfs + repart immutable layout on VM. Ignored on SBC images
    # (sdImage is always mutable ext4).
    readOnlyRoot = true;

    kiosk = {
      user = "kiosk";
      restart = "always"; # one of: "always", "on-failure", "no"
      # false: console (tty1) kiosk, no Wayland deps.
      # true:  Wayland kiosk via cage; pulls wlroots/foot/font into closure.
      gui = false;

      # Program the kiosk runs. Swap freely:
      #   pkgs.hello-kiosk      - console cowsay (gui = false)
      #   pkgs.hello-kiosk-gui  - Wayland cowsay in foot (gui = true)
      #   any Wayland app       - e.g. pkgs.chromium for kiosk browsers
      # null + empty command = no kiosk service; autologin only.
      package = pkgs.hello-kiosk;

      # Override or extend: [ "${pkgs.htop}/bin/htop" "--no-color" ]
      command = [ ];

      # Extra binaries on PATH for the kiosk program.
      runtimeInputs = [ ];
    };

    # Debug mode: root password "root", PermitRootLogin yes, password auth.
    # Set to false for production images.
    debug = true;
  };
}

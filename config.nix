# All user-facing configuration for mininix.
# Checked into git as plaintext - this is by design.
#
# NOTE: cross-compiling from darwin requires a system-level linux-builder
# (nix-darwin's `nix.linux-builder` or a remote builder). This flake does
# not configure it.
{
  hostname = "mininix";

  # WiFi networks. Empty list disables wpa_supplicant entirely.
  wifi = [
    # { ssid = "MyNetwork"; psk = "my-password"; }
  ];

  # SSH authorized keys for root. Empty list = no ssh login possible.
  sshAuthorizedKeys = [
    # "ssh-ed25519 AAAA... user@host"
  ];

  # Use squashfs + repart immutable layout on VM. Ignored on SBC images
  # (sdImage is always mutable ext4).
  readOnlyRoot = true;

  kiosk = {
    user = "kiosk";
    restart = "always"; # one of: "always", "on-failure", "no"
    # false: console (tty1) kiosk via hello-kiosk
    # true:  Wayland kiosk via cage + foot terminal (pulls in wlroots/foot)
    gui = false;
  };

  # Debug mode: root password "root", PermitRootLogin yes, password auth.
  # Set to false for production images.
  debug = true;
}

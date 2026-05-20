# Debug overlay - applies when config.mininix.debug = true.
# Intended for VM iteration; should not be active in production images.
{
  lib,
  pkgs,
  config,
  ...
}:

lib.mkIf config.mininix.debug {
  # Drop straight into a root shell when boot fails (no password prompt
  # from sulogin).
  boot.kernelParams = [ "systemd.setenv=SYSTEMD_SULOGIN_FORCE=1" ];

  # Plaintext root password "root" plus SSH password auth, so the user can
  # log in without an ssh key being configured.
  users.users.root.password = "root";
  users.mutableUsers = false;

  services.openssh.settings = {
    PermitRootLogin = lib.mkForce "yes";
    PasswordAuthentication = lib.mkForce true;
  };

  # Diagnostics available in the initrd emergency shell. When the
  # /nix/store mount fails the only binaries reachable are those baked
  # into the initrd, so the standard partition / block / text utilities
  # have to be inlined here. Cost is paid only when debug = true.
  #   gptfdisk:   gdisk, sgdisk, cgdisk
  #   util-linux: dmesg, lsblk, blkid, blockdev, partx, fdisk
  #   parted:     partprobe (forces BLKRRPART so the kernel re-parses GPT)
  #   gnugrep:    grep / egrep / fgrep
  boot.initrd.systemd.initrdBin = [
    pkgs.gptfdisk
    pkgs.util-linux
    pkgs.parted
    pkgs.gnugrep
  ];
}

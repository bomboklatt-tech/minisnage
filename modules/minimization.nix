# Single source of truth for image size reduction.
# Each option here is a deliberate trade-off; comment says why.
{ lib, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/perlless.nix")
  ];

  # No nix in the running system - we have no updates path.
  nix.enable = false;
  system.disableInstallerTools = true;

  # Drop all documentation.
  documentation.enable = false;
  documentation.man.enable = false;
  documentation.info.enable = false;
  documentation.doc.enable = false;
  documentation.nixos.enable = false;

  # Single locale.
  i18n.supportedLocales = [ "en_US.UTF-8/UTF-8" ];

  # No default user packages.
  environment.defaultPackages = [ ];
  programs.command-not-found.enable = false;

  # No nscd (name service caching).
  services.nscd.enable = false;
  system.nssModules = lib.mkForce [ ];

  # No fonts, graphics, audio, input subsystems.
  fonts.enableDefaultPackages = false;
  fonts.fontconfig.enable = false;
  services.speechd.enable = false;
  hardware.graphics.enable = false;
  services.pipewire.enable = false;
  services.libinput.enable = false;
  services.udisks2.enable = false;

  # Required for initrd-systemd-repart used by modules/image/base.nix.
  boot.initrd.systemd.enable = true;

  # No firewall, no storage stack we don't use.
  networking.firewall.enable = false;
  services.lvm.enable = false;
  boot.swraid.enable = false;
  boot.supportedFilesystems = lib.mkForce [
    "ext4"
    "vfat"
    "squashfs"
    "tmpfs"
  ];

  # No default editor.
  programs.nano.enable = true;
  systemd.enableEmergencyMode = false;
}

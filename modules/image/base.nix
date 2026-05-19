# Cross-cutting image base.
#
# Every host that builds via image.repart imports this. It owns the
# read-only nix-store partition (squashfs), the tmpfs root, and the
# repart-grown /var + /home that come up on first boot. The bootloader
# variants (uefi.nix, extlinux.nix) layer on top of this to add the boot
# partition.
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

let
  postProcess = config.mininix.image.postProcess;
in
{
  imports = [
    (modulesPath + "/image/repart.nix")
  ];

  # `system.build.imageFinal` is what the flake consumes. With an empty
  # postProcess this is just `system.build.image` straight from
  # image.repart; with one it's a wrapping derivation that runs the
  # snippet against the raw .img (used for the RockPro64 u-boot dd).
  system.build.imageFinal =
    if postProcess == "" then
      config.system.build.image
    else
      pkgs.runCommand config.image.repart.name { } ''
        mkdir -p "$out"
        cp -L ${config.system.build.image}/*.raw "$out/"
        chmod -R u+w "$out"
        raw=$(find "$out" -name '*.raw' | head -1)
        ${postProcess}
      '';

  image.repart.partitions."20-store" = {
    storePaths = [ config.system.build.toplevel ];
    # Mounted at /nix/store; store paths sit at "/" inside the squashfs
    # so the in-store layout matches /nix/store/<hash> post-mount. Without
    # this, the default "/nix/store" produces /nix/store/nix/store/<hash>
    # and the cmdline `init=` path fails to canonicalize after switch_root.
    nixStorePrefix = "/";
    repartConfig = {
      Format = "squashfs";
      Label = "nix-store";
      Minimize = "guess";
      ReadOnly = "yes";
      Type = "linux-generic";
    };
  };

  # First-boot inflation. virtio_blk on qemu and most SBC SoCs presents
  # the rootfs media as /dev/vda; if a board needs something else (e.g.
  # /dev/mmcblk0 on RPi), the host overrides this.
  boot.initrd.systemd.repart.enable = true;
  boot.initrd.systemd.repart.device = lib.mkDefault "/dev/vda";

  # loop.ko is required in initrd because the /nix/store mount uses the
  # `loop` option (see fileSystems below). Without this, mount(8) can't
  # set up /dev/loopN against the squashfs partition and the mount unit
  # times out waiting for the device.
  boot.initrd.kernelModules = [ "loop" ];

  # Force a udev retrigger on the block subsystem after systemd-repart
  # finishes. systemd-repart only re-emits uevents for partitions it
  # touches (the ones it creates or resizes); pre-existing partitions
  # like the nix-store squashfs keep whatever udev state they had from
  # the initial kernel probe. On slow MMC controllers (seen on rk3399)
  # the initial probe can race repart's GPT rewrite and the
  # by-partlabel/nix-store symlink never lands, so the mount unit waits
  # forever. A retrigger + settle deterministically restores the
  # symlink before initrd-fs.target tries the mount.
  boot.initrd.systemd.services.udev-retrigger-block = {
    description = "Re-trigger udev for block devices after systemd-repart";
    # wantedBy + `-` prefixed ExecStarts so a slow/timing-out udevadm
    # settle is best-effort and never tanks initrd-fs.target.
    wantedBy = [ "initrd-fs.target" ];
    after = [ "systemd-repart.service" ];
    before = [ "initrd-fs.target" ];
    unitConfig.DefaultDependencies = false;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = [
        "-${config.boot.initrd.systemd.package}/bin/udevadm trigger --action=change --subsystem-match=block"
        "-${config.boot.initrd.systemd.package}/bin/udevadm settle --timeout=30"
      ];
    };
  };

  systemd.repart.partitions = {
    "30-var" = {
      Format = "ext4";
      Label = "var";
      Type = "var";
      Weight = 1000;
    };
    "40-home" = {
      Format = "ext4";
      Label = "home";
      Type = "home";
      Weight = 2000;
    };
  };

  # Mounts shared by every host. The boot variant adds /boot.
  fileSystems."/" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [ "mode=0755" ];
  };

  # squashfs has no filesystem-level label; mount by GPT partition name.
  # `loop` wraps the partition in /dev/loopN before mounting (requires
  # loop.ko in initrd; see boot.initrd.kernelModules above).
  # `x-systemd.device-timeout=300` raises the default 90s wait for the
  # by-partlabel symlink: on slow SD cards with large squashfs partitions
  # udev/blkid probing can run past the 90s window.
  fileSystems."/nix/store" = lib.mkIf config.mininix.readOnlyRoot {
    device = "/dev/disk/by-partlabel/nix-store";
    fsType = "squashfs";
    neededForBoot = true;
    options = [
      "loop"
      "ro"
      "x-systemd.device-timeout=300"
    ];
  };

  fileSystems."/var" = {
    device = "/dev/disk/by-partlabel/var";
    fsType = "ext4";
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-partlabel/home";
    fsType = "ext4";
  };
}

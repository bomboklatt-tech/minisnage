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

  # `system.build.imageFinal` is what the flake consumes. We always wrap
  # so the artifact lands as `${name}.img` (drag-and-drop friendly for
  # most flashers) rather than the upstream `.raw`, and so any host
  # postProcess (e.g. the RockPro64 u-boot dd) gets a single uniform
  # `$raw` shell variable pointing at the renamed file.
  system.build.imageFinal = pkgs.runCommand "${config.image.repart.name}-img" { } ''
    mkdir -p "$out"
    src=$(find ${config.system.build.image} -name '*.raw' | head -1)
    cp -L "$src" "$out/${config.image.repart.name}.img"
    chmod u+w "$out/${config.image.repart.name}.img"
    raw="$out/${config.image.repart.name}.img"
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

  # Reconcile kernel partition table with on-disk GPT after
  # systemd-repart finishes. Observed on rk3399 with a large squashfs
  # closure: systemd-repart writes a correct 4-entry GPT, but the
  # kernel's in-memory partition table is left with the pre-existing
  # nix-store entry deleted via BLKPG_DEL_PARTITION and never re-added,
  # while the new var/home entries are added cleanly. `partprobe` issues
  # BLKRRPART which forces a full re-parse from on-disk GPT, restoring
  # every slot. The follow-up `udevadm trigger`/`settle` ensures the
  # by-partlabel symlinks land before initrd-fs.target tries the mount.
  #
  # `pkgs.parted` is pulled into the initrd via storePaths so the unit's
  # absolute path reference is valid.
  #
  # wantedBy + `-` prefixed ExecStarts so any single step failing
  # (partprobe on a transient EBUSY, udevadm settle timing out) is
  # best-effort and never tanks initrd-fs.target.
  boot.initrd.systemd.storePaths = [ pkgs.parted ];

  boot.initrd.systemd.services.udev-retrigger-block = {
    description = "Re-parse GPT and re-trigger udev after systemd-repart";
    wantedBy = [ "initrd-fs.target" ];
    after = [ "systemd-repart.service" ];
    before = [ "initrd-fs.target" ];
    unitConfig.DefaultDependencies = false;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = [
        "-${pkgs.parted}/bin/partprobe ${config.boot.initrd.systemd.repart.device}"
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

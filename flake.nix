{
  description = "mininix - minimal NixOS appliance images";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs = inputs @ { self, flake-parts, nixpkgs, nixos-hardware }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      flake =
        let
          mkHost = import ./lib/mkHost.nix { inherit inputs; };

          hosts = {
            vm        = { hostModule = ./hosts/vm.nix;        hostPlatform = "x86_64-linux"; };
            vm-uboot  = { hostModule = ./hosts/vm-uboot.nix;  hostPlatform = "aarch64-linux"; };
            rpi4      = { hostModule = ./hosts/rpi4.nix;      hostPlatform = "aarch64-linux"; };
            rpi5      = { hostModule = ./hosts/rpi5.nix;      hostPlatform = "aarch64-linux"; };
            rockpro64 = { hostModule = ./hosts/rockpro64.nix; hostPlatform = "aarch64-linux"; };
          };
        in {
          lib.mkHost = mkHost;

          nixosConfigurations = builtins.mapAttrs
            (_: hostArgs: mkHost hostArgs { buildPlatform = hostArgs.hostPlatform; })
            hosts;
        };

      perSystem = { system, pkgs, lib, ... }:
        let
          mkHost = import ./lib/mkHost.nix { inherit inputs; };

          # VM defaults to current arch: darwin systems map to their Linux
          # equivalent, so aarch64-darwin builds an aarch64-linux VM
          # (cheapest path through aarch64-linux linux-builder).
          toLinux = builtins.replaceStrings [ "darwin" ] [ "linux" ];
          vmHostPlatform = toLinux system;

          hosts = {
            vm        = { hostModule = ./hosts/vm.nix;        hostPlatform = vmHostPlatform; };
            vm-uboot  = { hostModule = ./hosts/vm-uboot.nix;  hostPlatform = "aarch64-linux"; };
            rpi4      = { hostModule = ./hosts/rpi4.nix;      hostPlatform = "aarch64-linux"; };
            rpi5      = { hostModule = ./hosts/rpi5.nix;      hostPlatform = "aarch64-linux"; };
            rockpro64 = { hostModule = ./hosts/rockpro64.nix; hostPlatform = "aarch64-linux"; };
          };

          buildOne = name: hostArgs:
            let cfg = (mkHost hostArgs { buildPlatform = system; }).config;
            in if name == "vm"
               then cfg.system.build.image
               else cfg.system.build.sdImage;

          vmImage = buildOne "vm" hosts.vm;
          vmUbootImage = buildOne "vm-uboot" hosts.vm-uboot;

          # Linux pkgs matching the VM's arch - used to obtain a firmware
          # file (AAVMF_CODE.fd / OVMF_CODE.fd). The .fd is data read by
          # qemu, so it doesn't matter that pkgs is for a different host.
          vmPkgs = inputs.nixpkgs.legacyPackages.${vmHostPlatform};
          isAarch64VM = lib.hasPrefix "aarch64" vmHostPlatform;
          firmwareFile = "${vmPkgs.OVMF.fd}/FV/${if isAarch64VM then "AAVMF_CODE.fd" else "OVMF_CODE.fd"}";

          qemuBin = if isAarch64VM then "qemu-system-aarch64" else "qemu-system-x86_64";
          qemuArchArgs = if isAarch64VM then "-machine virt -cpu host" else "";
          qemuAccel = if pkgs.stdenv.hostPlatform.isDarwin then "-accel hvf" else "-enable-kvm";
          qemuDisplay = if pkgs.stdenv.hostPlatform.isDarwin then "cocoa" else "gtk";

          runVmScript = pkgs.writeShellApplication {
            name = "run-vm";
            runtimeInputs = [ pkgs.qemu pkgs.findutils pkgs.coreutils ];
            text = ''
              IMG=$(find ${vmImage} -name '*.raw' | head -1)
              if [ -z "$IMG" ]; then
                echo "No .raw image found in ${vmImage}" >&2
                exit 1
              fi

              # The raw image is sized exactly to its partitions; systemd-repart
              # needs free space at the end of the disk to create /var and /home
              # at first boot. We wrap it in a 4G qcow2 overlay so the source raw
              # in the store stays read-only and the guest sees a larger disk.
              # State is ephemeral - the overlay is deleted on exit.
              OVERLAY=$(mktemp -t run-vm.XXXXXX.qcow2)
              trap 'rm -f "$OVERLAY"' EXIT
              qemu-img create -q -f qcow2 -F raw -b "$IMG" "$OVERLAY" 4G > /dev/null

              ${qemuBin} -m 1024 ${qemuArchArgs} ${qemuAccel} \
                -drive if=pflash,format=raw,readonly=on,file=${firmwareFile} \
                -drive file="$OVERLAY",if=virtio,format=qcow2 \
                -nic user,model=virtio-net-pci,hostfwd=tcp::2222-:22 \
                -device virtio-gpu-pci \
                -device qemu-xhci -device usb-kbd -device usb-tablet \
                -display ${qemuDisplay} -serial stdio
            '';
          };

          # vm-uboot: aarch64-linux guest with u-boot supplied via -bios.
          # Mirrors the SBC boot path (u-boot -> extlinux -> kernel) so we
          # can test that path without flashing hardware.
          ubootPkgs = inputs.nixpkgs.legacyPackages."aarch64-linux";
          ubootBin = "${ubootPkgs.ubootQemuAarch64}/u-boot.bin";

          runVmUbootScript = pkgs.writeShellApplication {
            name = "run-vm-uboot";
            runtimeInputs = [ pkgs.qemu pkgs.findutils pkgs.coreutils ];
            text = ''
              # sdImage drops the raw .img under sd-image/; pick that (not the .zst).
              # -type f: with compressImage=false the store path itself is named "*.img",
              # so we filter directories out.
              IMG=$(find ${vmUbootImage} -type f -name '*.img' ! -name '*.zst' | head -1)
              if [ -z "$IMG" ]; then
                echo "No raw .img found in ${vmUbootImage}" >&2
                exit 1
              fi

              OVERLAY=$(mktemp -t run-vm-uboot.XXXXXX.qcow2)
              trap 'rm -f "$OVERLAY"' EXIT
              qemu-img create -q -f qcow2 -F raw -b "$IMG" "$OVERLAY" 4G > /dev/null

              # TCG (software emulation) instead of HVF: u-boot on aarch64 does
              # MMIO with instructions whose ESR.isv bit is unset, which hits an
              # assertion in qemu's hvf backend (hvf.c:2030). AAVMF/UEFI dodges
              # this so the regular run-vm path keeps using HVF. Trade-off: TCG
              # boot is meaningfully slower but reliable. -cpu host requires
              # hardware accel; "max" is the right pick for TCG.
              # virtio-gpu-device (MMIO via DT) instead of virtio-gpu-pci:
              # without UEFI/AAVMF to pre-initialize PCI, the kernel can be
              # finicky enumerating virtio-gpu-pci. The MMIO variant is
              # described directly in the DT that qemu hands to u-boot and
              # has no PCI ordering issues.
              qemu-system-aarch64 -m 1024 -machine virt -cpu max -accel tcg \
                -bios ${ubootBin} \
                -drive file="$OVERLAY",if=virtio,format=qcow2 \
                -nic user,model=virtio-net-pci,hostfwd=tcp::2222-:22 \
                -device virtio-gpu-pci \
                -device qemu-xhci -device usb-kbd -device usb-tablet \
                -display ${qemuDisplay} -serial stdio
            '';
          };
        in {
          packages = lib.mapAttrs buildOne hosts;

          apps.run-vm = {
            type = "app";
            program = "${runVmScript}/bin/run-vm";
          };

          apps.run-vm-uboot = {
            type = "app";
            program = "${runVmUbootScript}/bin/run-vm-uboot";
          };

          devShells.default = pkgs.mkShell {
            packages = [
              pkgs.nix-output-monitor
              pkgs.qemu
            ];
          };
        };
    };
}

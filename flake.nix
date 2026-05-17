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
            rpi4      = { hostModule = ./hosts/rpi4.nix;      hostPlatform = "aarch64-linux"; };
            rpi5      = { hostModule = ./hosts/rpi5.nix;      hostPlatform = "aarch64-linux"; };
            rockpro64 = { hostModule = ./hosts/rockpro64.nix; hostPlatform = "aarch64-linux"; };
          };

          buildOne = name: hostArgs:
            let cfg = (mkHost hostArgs { buildPlatform = system; }).config;
            in if name == "vm"
               then cfg.system.build.image
               else cfg.system.build.sdImage;

          # Linux pkgs matching the VM's arch - used to obtain a firmware
          # file (AAVMF_CODE.fd / OVMF_CODE.fd). The .fd is data read by
          # qemu, so it doesn't matter that pkgs is for a different host.
          vmPkgs = inputs.nixpkgs.legacyPackages.${vmHostPlatform};
          isAarch64VM = lib.hasPrefix "aarch64" vmHostPlatform;
          firmwareFile = "${vmPkgs.OVMF.fd}/FV/${if isAarch64VM then "AAVMF_CODE.fd" else "OVMF_CODE.fd"}";

          qemuBin = if isAarch64VM then "qemu-system-aarch64" else "qemu-system-x86_64";
          qemuArchArgs = if isAarch64VM then "-machine virt -cpu host" else "";
          qemuAccel = if pkgs.stdenv.hostPlatform.isDarwin then "-accel hvf" else "-enable-kvm";

          runVmScript = pkgs.writeShellApplication {
            name = "run-vm";
            runtimeInputs = [ pkgs.qemu pkgs.findutils ];
            text = ''
              QCOW=$(find result -name '*.qcow2' | head -1)
              if [ -z "$QCOW" ]; then
                echo "No qcow2 found in result/. Run 'make vm' first." >&2
                exit 1
              fi
              exec ${qemuBin} -m 1024 ${qemuArchArgs} ${qemuAccel} \
                -drive if=pflash,format=raw,readonly=on,file=${firmwareFile} \
                -drive file="$QCOW",if=virtio,format=qcow2 \
                -nic user,model=virtio-net-pci,hostfwd=tcp::2222-:22
            '';
          };
        in {
          packages = lib.mapAttrs buildOne hosts;

          apps.run-vm = {
            type = "app";
            program = "${runVmScript}/bin/run-vm";
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

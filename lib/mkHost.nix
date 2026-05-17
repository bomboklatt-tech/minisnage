# Factory for nixosConfigurations with cross-compile support.
#
# Usage:
#   mkHost {
#     hostModule = ./hosts/vm.nix;
#     hostPlatform = "x86_64-linux";
#   } { buildPlatform = "aarch64-darwin"; }
#
# Returns an evaluated nixosConfiguration. The toLinux helper rewrites
# darwin -> linux in the build platform so eval-time platform checks pass
# on macOS while the actual build runs via the configured linux-builder.
{ inputs }:

{ hostModule, hostPlatform }:
{ buildPlatform }:

let
  toLinux = builtins.replaceStrings [ "darwin" ] [ "linux" ];
in
inputs.nixpkgs.lib.nixosSystem {
  modules = [
    hostModule
    ../modules/common.nix
    {
      nixpkgs.buildPlatform = toLinux buildPlatform;
      nixpkgs.hostPlatform = hostPlatform;
    }
  ];
  specialArgs = {
    userConfig = import ../config.nix;
    inherit inputs;
  };
}

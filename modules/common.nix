{ ... }:

{
  imports = [
    ./options
    ./minimization.nix
    ./network.nix
    ./kiosk.nix
    ./debug.nix
  ];

  # Apply local package overlay so pkgs.hello-kiosk* exist.
  nixpkgs.overlays = [ (import ../pkgs) ];

  system.stateVersion = "25.11";
}

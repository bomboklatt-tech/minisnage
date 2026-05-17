{ ... }:

{
  imports = [
    ./minimization.nix
    ./network.nix
    ./kiosk.nix
  ];

  # Apply local package overlay so pkgs.hello-kiosk exists.
  nixpkgs.overlays = [ (import ../pkgs) ];

  system.stateVersion = "25.11";
}

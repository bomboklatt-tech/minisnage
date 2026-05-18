{ ... }:

{
  imports = [
    ./hostname.nix
    ./network.nix
    ./kiosk.nix
    ./image.nix
    ./debug.nix
  ];
}

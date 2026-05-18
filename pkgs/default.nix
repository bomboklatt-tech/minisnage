# Overlay aggregating local packages. Applied by modules/common.nix.
final: prev: {
  # Helpers
  mkGuiTerminalKiosk = final.callPackage ./lib/mkGuiTerminalKiosk.nix { };

  # Default kiosk programs
  hello-kiosk = final.callPackage ./hello-kiosk { };
  hello-kiosk-gui = final.callPackage ./hello-kiosk-gui { };
}

# Overlay aggregating local packages. Applied by modules/common.nix.
final: prev: {
  hello-kiosk = final.callPackage ./hello-kiosk { };
}

{ writeShellApplication, writeText, foot, cozette, fontconfig, lib }:

# Helper that builds a kiosk program suitable for `mininix.kiosk.package`
# in gui mode: spawns a terminal (default foot) running the supplied
# shell text. Carries its own fontconfig so no system-wide fonts.* setup
# is required - good for our minimization, which has fontconfig off.
#
# Currently foot-specific (writes a foot.ini); to support another
# terminal, copy this helper and adapt the config writer.
{
  name,
  text,
  runtimeInputs ? [ ],
  terminal ? foot,
  font ? cozette,
  # Family name as it appears in the font metadata - verify via
  # `fc-query --format '%{family[0]}\n' <font-file>`. Foot's `font=` is a
  # fontconfig pattern, so we match by family rather than file path
  # (path mode is unreliable for bitmap-derived fonts).
  fontName ? "CozetteVector",
  fontSize ? 13,
  extraTerminalArgs ? [ ],
}:

let
  # Per-process fontconfig: pull in nixpkgs' default config (so standard
  # aliases work) and add the chosen font's share/fonts dir.
  fontsConf = writeText "${name}-fonts.conf" ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
    <fontconfig>
      <include ignore_missing="yes">${fontconfig.out}/etc/fonts/fonts.conf</include>
      <dir>${font}/share/fonts</dir>
    </fontconfig>
  '';

  footConfig = writeText "${name}-foot.ini" ''
    [main]
    font=${fontName}:size=${toString fontSize}
  '';

  payload = writeShellApplication {
    name = "${name}-payload";
    runtimeInputs = runtimeInputs;
    text = text;
  };

  terminalBin = "${terminal}/bin/${terminal.meta.mainProgram or "foot"}";
in
writeShellApplication {
  name = name;
  runtimeInputs = [ terminal ];
  text = ''
    export FONTCONFIG_FILE=${fontsConf}
    exec ${terminalBin} --config=${footConfig} ${lib.escapeShellArgs extraTerminalArgs} -- ${payload}/bin/${name}-payload
  '';
}

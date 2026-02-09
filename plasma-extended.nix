{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.plasma-extended;
  stylixCfg = config.programs.stylix-extended;

  # Parse a base16 YAML scheme file to extract the palette
  parseScheme =
    schemeFile:
    let
      jsonFile = pkgs.runCommand "scheme.json" { nativeBuildInputs = [ pkgs.yq-go ]; } ''
        yq -o=json '.palette' ${schemeFile} > $out
      '';
    in
    builtins.fromJSON (builtins.readFile jsonFile);

  # Convert hex color to RGB triplet string "R,G,B"
  hexToRgb =
    hex:
    let
      # Remove # prefix if present
      clean = lib.removePrefix "#" hex;
      r = builtins.substring 0 2 clean;
      g = builtins.substring 2 2 clean;
      b = builtins.substring 4 2 clean;
      hexToDec =
        h:
        let
          chars = lib.stringToCharacters (lib.toLower h);
          hexVal =
            c:
            let
              idx = lib.lists.findFirstIndex (x: x == c) 0 [
                "0"
                "1"
                "2"
                "3"
                "4"
                "5"
                "6"
                "7"
                "8"
                "9"
                "a"
                "b"
                "c"
                "d"
                "e"
                "f"
              ];
            in
            idx;
        in
        (hexVal (builtins.elemAt chars 0)) * 16 + (hexVal (builtins.elemAt chars 1));
    in
    "${toString (hexToDec r)},${toString (hexToDec g)},${toString (hexToDec b)}";

  # Generate a KDE color scheme from a base16 palette
  # Reference: https://github.com/nix-community/stylix/blob/master/modules/kde/hm.nix
  generateKdeColorScheme =
    name: palette:
    let
      c = builtins.mapAttrs (_: hexToRgb) palette;
    in
    ''
      [ColorEffects:Disabled]
      Color=${c.base01}
      ColorAmount=0
      ColorEffect=0
      ContrastAmount=0.65
      ContrastEffect=1
      IntensityAmount=0.1
      IntensityEffect=2

      [ColorEffects:Inactive]
      ChangeSelectionColor=true
      Color=${c.base01}
      ColorAmount=0.025
      ColorEffect=2
      ContrastAmount=0.1
      ContrastEffect=2
      Enable=false
      IntensityAmount=0
      IntensityEffect=0

      [Colors:Button]
      BackgroundAlternate=${c.base02}
      BackgroundNormal=${c.base01}
      DecorationFocus=${c.base0D}
      DecorationHover=${c.base0D}
      ForegroundActive=${c.base0D}
      ForegroundInactive=${c.base04}
      ForegroundLink=${c.base0D}
      ForegroundNegative=${c.base08}
      ForegroundNeutral=${c.base09}
      ForegroundNormal=${c.base05}
      ForegroundPositive=${c.base0B}
      ForegroundVisited=${c.base0E}

      [Colors:Complementary]
      BackgroundAlternate=${c.base01}
      BackgroundNormal=${c.base00}
      DecorationFocus=${c.base0D}
      DecorationHover=${c.base0D}
      ForegroundActive=${c.base0D}
      ForegroundInactive=${c.base04}
      ForegroundLink=${c.base0D}
      ForegroundNegative=${c.base08}
      ForegroundNeutral=${c.base09}
      ForegroundNormal=${c.base05}
      ForegroundPositive=${c.base0B}
      ForegroundVisited=${c.base0E}

      [Colors:Header]
      BackgroundAlternate=${c.base01}
      BackgroundNormal=${c.base00}
      DecorationFocus=${c.base0D}
      DecorationHover=${c.base0D}
      ForegroundActive=${c.base0D}
      ForegroundInactive=${c.base04}
      ForegroundLink=${c.base0D}
      ForegroundNegative=${c.base08}
      ForegroundNeutral=${c.base09}
      ForegroundNormal=${c.base05}
      ForegroundPositive=${c.base0B}
      ForegroundVisited=${c.base0E}

      [Colors:Header][Inactive]
      BackgroundAlternate=${c.base01}
      BackgroundNormal=${c.base00}
      DecorationFocus=${c.base0D}
      DecorationHover=${c.base0D}
      ForegroundActive=${c.base0D}
      ForegroundInactive=${c.base04}
      ForegroundLink=${c.base0D}
      ForegroundNegative=${c.base08}
      ForegroundNeutral=${c.base09}
      ForegroundNormal=${c.base05}
      ForegroundPositive=${c.base0B}
      ForegroundVisited=${c.base0E}

      [Colors:Selection]
      BackgroundAlternate=${c.base0D}
      BackgroundNormal=${c.base0D}
      DecorationFocus=${c.base0D}
      DecorationHover=${c.base0D}
      ForegroundActive=${c.base00}
      ForegroundInactive=${c.base00}
      ForegroundLink=${c.base00}
      ForegroundNegative=${c.base08}
      ForegroundNeutral=${c.base09}
      ForegroundNormal=${c.base00}
      ForegroundPositive=${c.base0B}
      ForegroundVisited=${c.base0E}

      [Colors:Tooltip]
      BackgroundAlternate=${c.base01}
      BackgroundNormal=${c.base00}
      DecorationFocus=${c.base0D}
      DecorationHover=${c.base0D}
      ForegroundActive=${c.base0D}
      ForegroundInactive=${c.base04}
      ForegroundLink=${c.base0D}
      ForegroundNegative=${c.base08}
      ForegroundNeutral=${c.base09}
      ForegroundNormal=${c.base05}
      ForegroundPositive=${c.base0B}
      ForegroundVisited=${c.base0E}

      [Colors:View]
      BackgroundAlternate=${c.base01}
      BackgroundNormal=${c.base00}
      DecorationFocus=${c.base0D}
      DecorationHover=${c.base0D}
      ForegroundActive=${c.base0D}
      ForegroundInactive=${c.base04}
      ForegroundLink=${c.base0D}
      ForegroundNegative=${c.base08}
      ForegroundNeutral=${c.base09}
      ForegroundNormal=${c.base05}
      ForegroundPositive=${c.base0B}
      ForegroundVisited=${c.base0E}

      [Colors:Window]
      BackgroundAlternate=${c.base01}
      BackgroundNormal=${c.base00}
      DecorationFocus=${c.base0D}
      DecorationHover=${c.base0D}
      ForegroundActive=${c.base0D}
      ForegroundInactive=${c.base04}
      ForegroundLink=${c.base0D}
      ForegroundNegative=${c.base08}
      ForegroundNeutral=${c.base09}
      ForegroundNormal=${c.base05}
      ForegroundPositive=${c.base0B}
      ForegroundVisited=${c.base0E}

      [General]
      ColorScheme=${name}
      Name=${name}
      shadeSortColumn=true

      [KDE]
      contrast=4

      [WM]
      activeBackground=${c.base00}
      activeBlend=${c.base05}
      activeForeground=${c.base05}
      inactiveBackground=${c.base01}
      inactiveBlend=${c.base04}
      inactiveForeground=${c.base04}
    '';

  # Resolve scheme paths from stylix-extended config
  darkSchemeFile = "${pkgs.base16-schemes}/share/themes/${stylixCfg.colorSchemes.dark}.yaml";
  lightSchemeFile = "${pkgs.base16-schemes}/share/themes/${stylixCfg.colorSchemes.light}.yaml";

  # Parse palettes
  darkPalette = parseScheme darkSchemeFile;
  lightPalette = parseScheme lightSchemeFile;

in
{
  options.programs.plasma-extended = {
    enable = lib.mkEnableOption "Plasma/KDE with Stylix theme integration";

    generateStylixThemes = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Generate KDE color scheme files from Stylix color schemes";
    };
  };

  config = lib.mkIf cfg.enable {
    # Generate Stylix-based color scheme files for darkman to switch between
    xdg.dataFile = lib.mkIf cfg.generateStylixThemes {
      "color-schemes/stylix-dark.colors".text = generateKdeColorScheme "stylix-dark" darkPalette;
      "color-schemes/stylix-light.colors".text = generateKdeColorScheme "stylix-light" lightPalette;
    };
  };
}

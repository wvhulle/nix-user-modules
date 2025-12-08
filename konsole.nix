{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.konsole-extended;
  fontsCfg = config.programs.typography;

  formatValue =
    value: if lib.isBool value then (if value then "true" else "false") else toString value;

  formatSection =
    sectionName: sectionAttrs:
    "[${sectionName}]\n"
    + lib.concatStringsSep "\n" (
      lib.mapAttrsToList (key: value: "${key}=${formatValue value}") sectionAttrs
    )
    + "\n";

  formatConfig = config: lib.concatStringsSep "\n" (lib.mapAttrsToList formatSection config);

  mkProfileFile =
    name: colorScheme:
    let
      fontString = lib.concatStringsSep "," [
        cfg.font.family
        (toString cfg.font.pointSize)
        (toString cfg.font.pixelSize)
        (toString cfg.font.styleHint)
        (toString cfg.font.weight)
        (if cfg.font.italic then "1" else "0")
        (if cfg.font.underline then "1" else "0")
        (if cfg.font.strikeOut then "1" else "0")
        (if cfg.font.fixedPitch then "1" else "0")
        (if cfg.font.rawStyleString then "1" else "0")
      ];
      config = {
        "Appearance" = {
          AntiAliasFonts = true;
          BoldIntense = true;
          ColorScheme = colorScheme;
          Font = fontString;
          UseFontLineChararacters = true;
          LineSpacing = 0;
          Ligatures = true;
        };
        "General" = {
          Name = name;
          Parent = "FALLBACK/";
          Command = "${pkgs.zellij}/bin/zellij";
        };
        "Scrolling".HistoryMode = 2;
        "Terminal Features" = {
          BlinkingCursorEnabled = true;
          FlowControlEnabled = false;
        };
        "Text Features" = {
          ShapingEnabled = true;
          AllowWordWrap = false;
        };
        "Interaction Options" = {
          AllowEscapedLinks = false;
          AllowMouseTracking = true;
          AutoCopySelectedText = true;
          OpenLinksByDirectClickEnabled = true;
          TextEditorCmd = 6;
          TextEditorCmdCustom = "hx PATH:LINE:COLUMN";
          TrimLeadingSpacesInSelectedText = true;
          TrimTrailingSpacesInSelectedText = true;
          UnderlineFilesEnabled = true;
        };
      };
    in
    pkgs.writeText "${name}.profile" (formatConfig config);

in
{
  options.programs.konsole-extended = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable Konsole terminal emulator";
    };

    profiles = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        Dark = "Breeze";
        Light = "BlackOnWhite";
      };
      example = {
        Dark = "Breeze";
        Light = "BlackOnWhite";
        Custom = "SolarizedDark";
      };
      description = "Profile names mapped to their color schemes";
    };

    defaultProfile = lib.mkOption {
      type = lib.types.str;
      default = "Dark";
      description = "Default profile name";
    };

    font = {
      family = lib.mkOption {
        type = lib.types.str;
        default = fontsCfg.terminal.name;
        description = "Font family name (defaults to typography.terminal.name)";
      };

      pointSize = lib.mkOption {
        type = lib.types.int;
        default = fontsCfg.sizes.terminal;
        description = "Font size in points (defaults to typography.sizes.terminal)";
      };

      pixelSize = lib.mkOption {
        type = lib.types.int;
        default = -1;
        description = "Font size in pixels (-1 means use point size)";
      };

      styleHint = lib.mkOption {
        type = lib.types.int;
        default = 5;
        description = "Font style hint (5 = TypeWriter/Monospace)";
      };

      weight = lib.mkOption {
        type = lib.types.int;
        default = 50;
        description = "Font weight (50 = Normal, 75 = Bold, 25 = Light)";
      };

      italic = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether font is italic (0 = false, 1 = true)";
      };

      underline = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether font is underlined";
      };

      strikeOut = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether font has strikethrough";
      };

      fixedPitch = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether font has fixed character width";
      };

      rawStyleString = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Raw style string parameter (usually 0)";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.file = lib.mapAttrs' (
      name: colorScheme:
      lib.nameValuePair ".local/share/konsole/${name}.profile" {
        source = mkProfileFile name colorScheme;
      }
    ) cfg.profiles;

    home.activation.konsoleConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD mkdir -p $HOME/.config
      $DRY_RUN_CMD cat > $HOME/.config/konsolerc << 'EOF'
      [Desktop Entry]
      DefaultProfile=${cfg.defaultProfile}.profile

      [KonsoleWindow]
      ShowWindowTitleOnTitleBar=true

      [General]
      ConfigVersion=1
      EOF
    '';
  };
}

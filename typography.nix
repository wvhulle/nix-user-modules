{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.typography;

  fontSpec = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Font family name";
      };
      package = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = null;
        description = "Font package to install (null if system font)";
      };
    };
  };

  presets = {
    fira = {
      terminal = {
        name = "FiraCode Nerd Font Mono";
        package = pkgs.nerd-fonts.fira-code;
      };
      editor = {
        name = "Fira Code";
        package = pkgs.fira-code;
      };
      ui = {
        name = "Fira Sans";
        package = pkgs.fira;
      };
      serif = {
        name = "Noto Serif";
        package = pkgs.noto-fonts;
      };
    };

    jetbrains = {
      terminal = {
        name = "JetBrainsMono Nerd Font Mono";
        package = pkgs.nerd-fonts.jetbrains-mono;
      };
      editor = {
        name = "JetBrains Mono";
        package = pkgs.jetbrains-mono;
      };
      ui = {
        name = "Inter";
        package = pkgs.inter;
      };
      serif = {
        name = "Noto Serif";
        package = pkgs.noto-fonts;
      };
    };

    hack = {
      terminal = {
        name = "Hack Nerd Font Mono";
        package = pkgs.nerd-fonts.hack;
      };
      editor = {
        name = "Hack";
        package = pkgs.hack-font;
      };
      ui = {
        name = "Roboto";
        package = pkgs.roboto;
      };
      serif = {
        name = "Roboto Slab";
        package = pkgs.roboto-slab;
      };
    };

    iosevka = {
      terminal = {
        name = "Iosevka Nerd Font Mono";
        package = pkgs.nerd-fonts.iosevka;
      };
      editor = {
        name = "Iosevka";
        package = pkgs.iosevka;
      };
      ui = {
        name = "Iosevka Aile";
        package = pkgs.iosevka;
      };
      serif = {
        name = "Iosevka Etoile";
        package = pkgs.iosevka;
      };
    };

    monaspace = {
      terminal = {
        name = "Monaspace Neon";
        package = pkgs.monaspace;
      };
      editor = {
        name = "Monaspace Neon";
        package = pkgs.monaspace;
      };
      ui = {
        name = "Inter";
        package = pkgs.inter;
      };
      serif = {
        name = "Noto Serif";
        package = pkgs.noto-fonts;
      };
    };

    cascadia = {
      terminal = {
        name = "CaskaydiaCove Nerd Font Mono";
        package = pkgs.nerd-fonts.caskaydia-cove;
      };
      editor = {
        name = "Cascadia Code";
        package = pkgs.cascadia-code;
      };
      ui = {
        name = "Segoe UI";
        package = null;
      };
      serif = {
        name = "Noto Serif";
        package = pkgs.noto-fonts;
      };
    };

    sourcecodepro = {
      terminal = {
        name = "SauceCodePro Nerd Font Mono";
        package = pkgs.nerd-fonts.sauce-code-pro;
      };
      editor = {
        name = "Source Code Pro";
        package = pkgs.source-code-pro;
      };
      ui = {
        name = "Source Sans 3";
        package = pkgs.source-sans;
      };
      serif = {
        name = "Source Serif 4";
        package = pkgs.source-serif;
      };
    };
  };

  activePreset = presets.${cfg.preset};
  resolved = lib.recursiveUpdate activePreset cfg.overrides;

  collectPackages =
    f:
    lib.unique (
      lib.filter (p: p != null) [
        f.terminal.package
        f.editor.package
        f.ui.package
        f.serif.package
      ]
    );

  mkFontFamilyString =
    primary: fallbacks:
    lib.concatStringsSep ", " (map (f: "'${f}'") ([ primary ] ++ fallbacks ++ [ "monospace" ]));
in
{
  options.programs.typography = {
    enable = lib.mkEnableOption "centralized font configuration" // {
      default = true;
    };

    preset = lib.mkOption {
      type = lib.types.enum (builtins.attrNames presets);
      default = "fira";
      description = ''
        Font preset to use. Available presets:
        - fira: FiraCode + Fira Sans (default)
        - jetbrains: JetBrains Mono + Inter
        - hack: Hack + Roboto
        - iosevka: Iosevka family
        - monaspace: GitHub Monaspace + Inter
        - cascadia: Cascadia Code (Windows Terminal font)
        - sourcecodepro: Adobe Source family
      '';
    };

    overrides = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
      default = { };
      description = "Override specific fonts from the selected preset";
      example = lib.literalExpression ''
        {
          ui = {
            name = "Ubuntu";
            package = pkgs.ubuntu_font_family;
          };
        }
      '';
    };

    sizes = {
      terminal = lib.mkOption {
        type = lib.types.int;
        default = 10;
        description = "Font size for terminal emulators";
      };
      editor = lib.mkOption {
        type = lib.types.int;
        default = 13;
        description = "Font size for code editors";
      };
      ui = lib.mkOption {
        type = lib.types.int;
        default = 10;
        description = "Font size for UI elements";
      };
      small = lib.mkOption {
        type = lib.types.int;
        default = 8;
        description = "Font size for small UI text";
      };
    };

    terminal = lib.mkOption {
      type = fontSpec;
      default = resolved.terminal;
      defaultText = lib.literalExpression "preset.terminal with overrides applied";
      description = "Terminal font (monospace with nerd font icons)";
    };

    editor = lib.mkOption {
      type = fontSpec;
      default = resolved.editor;
      defaultText = lib.literalExpression "preset.editor with overrides applied";
      description = "Editor font (monospace, good for coding)";
    };

    ui = lib.mkOption {
      type = fontSpec;
      default = resolved.ui;
      defaultText = lib.literalExpression "preset.ui with overrides applied";
      description = "UI font (sans-serif, readable)";
    };

    serif = lib.mkOption {
      type = fontSpec;
      default = resolved.serif;
      defaultText = lib.literalExpression "preset.serif with overrides applied";
      description = "Serif font (documents, reading)";
    };

    terminalFontFamily = lib.mkOption {
      type = lib.types.str;
      default = mkFontFamilyString cfg.terminal.name [ cfg.editor.name ];
      defaultText = lib.literalExpression "'terminal', 'editor', monospace";
      description = "CSS-style font-family string for terminals with fallbacks";
    };

    editorFontFamily = lib.mkOption {
      type = lib.types.str;
      default = mkFontFamilyString cfg.editor.name [ cfg.terminal.name ];
      defaultText = lib.literalExpression "'editor', 'terminal', monospace";
      description = "CSS-style font-family string for editors with fallbacks";
    };

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = collectPackages cfg ++ [ pkgs.font-awesome ];
      defaultText = lib.literalExpression "[ terminal.package editor.package ui.package serif.package font-awesome ]";
      description = "Font packages to install";
    };

    plasma.enable = lib.mkOption {
      type = lib.types.bool;
      default = config.programs.plasma.enable or false;
      description = "Whether to configure KDE Plasma desktop fonts";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = cfg.packages;

    fonts.fontconfig = {
      enable = true;
      defaultFonts = {
        monospace = [ cfg.terminal.name ];
        sansSerif = [ cfg.ui.name ];
        serif = [ cfg.serif.name ];
      };
    };

    programs.kitty.font = lib.mkDefault {
      inherit (cfg.terminal) name;
      size = cfg.sizes.terminal;
    };

    programs.plasma.fonts = lib.mkIf cfg.plasma.enable {
      general = {
        family = cfg.ui.name;
        pointSize = cfg.sizes.ui;
      };
      fixedWidth = {
        family = cfg.terminal.name;
        pointSize = cfg.sizes.terminal;
      };
      small = {
        family = cfg.ui.name;
        pointSize = cfg.sizes.small;
      };
      toolbar = {
        family = cfg.ui.name;
        pointSize = cfg.sizes.ui;
      };
      menu = {
        family = cfg.ui.name;
        pointSize = cfg.sizes.ui;
      };
      windowTitle = {
        family = cfg.ui.name;
        pointSize = cfg.sizes.ui;
      };
    };
  };
}

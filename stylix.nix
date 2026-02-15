{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.stylix-extended;
  fontPresets = import ./font-presets.nix { inherit pkgs; };
  themes = import ./base16-themes.nix { inherit pkgs; };
  activePreset = fontPresets.${cfg.fontPreset};
  themeNames = builtins.attrNames themes;
in
{
  # Re-export themes for autocomplete in user config
  options.programs.stylix-extended.themes = lib.mkOption {
    type = lib.types.attrs;
    default = themes;
    readOnly = true;
    description = "Available base16 color schemes (use for autocomplete)";
  };

  options.programs.stylix-extended = {
    enable = lib.mkEnableOption "Stylix theming" // {
      default = true;
    };

    # Typography
    fontPreset = lib.mkOption {
      type = lib.types.enum (builtins.attrNames fontPresets);
      default = "plex";
      description = "Font family preset: plex, fira, jetbrains, hack, iosevka, lilex, monaspace, cascadia, sourcecodepro";
    };

    sizes = {
      terminal = lib.mkOption {
        type = lib.types.int;
        default = 9;
      };
      applications = lib.mkOption {
        type = lib.types.int;
        default = 10;
      };
      desktop = lib.mkOption {
        type = lib.types.int;
        default = 10;
      };
      popups = lib.mkOption {
        type = lib.types.int;
        default = 10;
      };
    };

    # Color schemes - use lib.types.enum for type safety and autocomplete
    colorSchemes = {
      dark = lib.mkOption {
        type = lib.types.enum themeNames;
        default = "gruvbox-dark-hard";
        description = "Base16 color scheme for dark mode";
      };
      light = lib.mkOption {
        type = lib.types.enum themeNames;
        default = "atelier-dune-light";
        description = "Base16 color scheme for light mode";
      };
    };

    polarity = lib.mkOption {
      type = lib.types.enum [
        "dark"
        "light"
        "either"
      ];
      default = "dark";
      description = "Default color polarity (darkman overrides at runtime)";
    };

    plasma.enable = lib.mkOption {
      type = lib.types.bool;
      default = config.programs.plasma.enable or false;
      description = "Configure KDE Plasma fonts via Stylix";
    };
  };

  config = lib.mkIf cfg.enable {
    stylix = {
      enable = true;
      autoEnable = true;

      base16Scheme = "${pkgs.base16-schemes}/share/themes/${cfg.colorSchemes.dark}.yaml";
      inherit (cfg) polarity;

      fonts = {
        inherit (activePreset) monospace sansSerif serif;
        emoji = {
          package = pkgs.noto-fonts-color-emoji;
          name = "Noto Color Emoji";
        };
        sizes = {
          inherit (cfg.sizes)
            terminal
            applications
            desktop
            popups
            ;
        };
      };

      # Disable targets handled by darkman via -extended modules
      targets = {
        kitty.enable = false;
        kde.enable = false;
        helix.enable = false;
        # neovim.enable = false;
        vscode.enable = false;
        # zed.enable = false;
        zellij.enable = false;
        gnome.enable = false;
        firefox.enable = false;

        # Disable GTK2 to avoid backup file conflicts on rebuild
        gtk.enable = false;
      };
    };

    fonts.fontconfig = {
      enable = true;
      defaultFonts = {
        monospace = [ activePreset.monospace.name ];
        sansSerif = [ activePreset.sansSerif.name ];
        serif = [ activePreset.serif.name ];
      };
    };

    home.packages = lib.unique (
      lib.filter (p: p != null) [
        activePreset.monospace.package
        activePreset.sansSerif.package
        activePreset.serif.package
        pkgs.noto-fonts-color-emoji
      ]
    );

    # For base16-preview.nu to locate theme YAML files
    home.sessionVariables.BASE16_THEMES = "${pkgs.base16-schemes}/share/themes";

    programs.plasma.fonts = lib.mkIf cfg.plasma.enable {
      general = {
        family = activePreset.sansSerif.name;
        pointSize = cfg.sizes.desktop;
      };
      fixedWidth = {
        family = activePreset.monospace.name;
        pointSize = cfg.sizes.terminal;
      };
      small = {
        family = activePreset.sansSerif.name;
        pointSize = cfg.sizes.desktop - 2;
      };
      toolbar = {
        family = activePreset.sansSerif.name;
        pointSize = cfg.sizes.desktop;
      };
      menu = {
        family = activePreset.sansSerif.name;
        pointSize = cfg.sizes.desktop;
      };
      windowTitle = {
        family = activePreset.sansSerif.name;
        pointSize = cfg.sizes.desktop;
      };
    };
  };
}

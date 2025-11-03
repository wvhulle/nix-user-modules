{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.dayNightTheme;

  konsole-theme-nu-bin = pkgs.writers.writeNuBin "konsole-theme-nu" (
    builtins.readFile ./konsole-theme.nu
  );

  themeScript = pkgs.writers.writeNuBin "theme" (builtins.readFile ./theme.nu);

  makeThemeScript =
    subcommand: args:
    let
      argStr = lib.concatStringsSep " " (map lib.escapeShellArg args);
      scriptPath = pkgs.lib.makeBinPath [
        pkgs.coreutils
        pkgs.glib
        pkgs.systemd
        pkgs.kdePackages.plasma-workspace
        konsole-theme-nu-bin
      ];
      xdgDataDirs = pkgs.lib.concatStringsSep ":" [
        "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}"
        "${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}"
      ];
    in
    pkgs.writeShellScript "theme-${subcommand}" ''
      export PATH="${scriptPath}:$PATH"
      export XDG_DATA_DIRS="${xdgDataDirs}"
      ${themeScript}/bin/theme ${subcommand} ${argStr}
    '';
in
{
  options.programs.dayNightTheme = {
    enable = lib.mkEnableOption "automatic day/night theme switching with darkman";

    location = {
      latitude = lib.mkOption {
        type = lib.types.float;
        default = 50.8;
        description = "Latitude for sunrise/sunset calculation";
      };

      longitude = lib.mkOption {
        type = lib.types.float;
        default = 4.3;
        description = "Longitude for sunrise/sunset calculation";
      };

      longitudeOffset = lib.mkOption {
        type = lib.types.float;
        default = 0.0;
        description = "Longitude offset (e.g., -15 to trigger dark mode 1 hour earlier)";
      };
    };

    themes = {
      gtk = {
        dark = lib.mkOption {
          type = lib.types.str;
          default = "Breeze-Dark";
          description = "GTK theme name for dark mode";
        };

        light = lib.mkOption {
          type = lib.types.str;
          default = "Breeze";
          description = "GTK theme name for light mode";
        };
      };

      plasma = {
        dark = {
          lookAndFeel = lib.mkOption {
            type = lib.types.str;
            default = "org.kde.breezedark.desktop";
            description = "Plasma look and feel for dark mode";
          };

          colorScheme = lib.mkOption {
            type = lib.types.str;
            default = "BreezeDark";
            description = "Plasma color scheme for dark mode";
          };
        };

        light = {
          lookAndFeel = lib.mkOption {
            type = lib.types.str;
            default = "org.kde.breeze.desktop";
            description = "Plasma look and feel for light mode";
          };

          colorScheme = lib.mkOption {
            type = lib.types.str;
            default = "BreezeLight";
            description = "Plasma color scheme for light mode";
          };
        };
      };

      konsole = {
        dark = lib.mkOption {
          type = lib.types.str;
          default = "Dark";
          description = "Konsole theme name for dark mode";
        };

        light = lib.mkOption {
          type = lib.types.str;
          default = "Light";
          description = "Konsole theme name for light mode";
        };
      };

      cursor = {
        dark = lib.mkOption {
          type = lib.types.str;
          default = "Breeze_Snow";
          description = "Cursor theme name for dark mode";
        };

        light = lib.mkOption {
          type = lib.types.str;
          default = "Breeze_Light";
          description = "Cursor theme name for light mode";
        };
      };
    };

    darkman = {
      useGeoclue = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Use geoclue for automatic location detection";
      };

      dbusServer = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable D-Bus server for darkman";
      };

      portal = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable portal integration";
      };

      extraSettings = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = "Additional settings to pass to darkman";
      };
    };

    extraDarkModeScripts = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional scripts to run when switching to dark mode";
      example = {
        custom-app = "/path/to/custom-dark-script.sh";
      };
    };

    extraLightModeScripts = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional scripts to run when switching to light mode";
      example = {
        custom-app = "/path/to/custom-light-script.sh";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.darkman = {
      enable = true;

      settings = lib.mkMerge [
        {
          lat = cfg.location.latitude;
          lng = cfg.location.longitude + cfg.location.longitudeOffset;
          dbusserver = cfg.darkman.dbusServer;
          inherit (cfg.darkman) portal;
          usegeoclue = cfg.darkman.useGeoclue;
        }
        cfg.darkman.extraSettings
      ];

      darkModeScripts = lib.mkMerge [
        {
          gtk-theme = makeThemeScript "gtk" [ cfg.themes.gtk.dark ];
          plasma-theme = makeThemeScript "plasma" [
            cfg.themes.plasma.dark.lookAndFeel
            cfg.themes.plasma.dark.colorScheme
          ];
          konsole-theme = makeThemeScript "konsole" [ cfg.themes.konsole.dark ];
          cursor-theme = makeThemeScript "cursor" [ cfg.themes.cursor.dark ];
        }
        cfg.extraDarkModeScripts
      ];

      lightModeScripts = lib.mkMerge [
        {
          gtk-theme = makeThemeScript "gtk" [ cfg.themes.gtk.light ];
          plasma-theme = makeThemeScript "plasma" [
            cfg.themes.plasma.light.lookAndFeel
            cfg.themes.plasma.light.colorScheme
          ];
          konsole-theme = makeThemeScript "konsole" [ cfg.themes.konsole.light ];
          cursor-theme = makeThemeScript "cursor" [ cfg.themes.cursor.light ];
        }
        cfg.extraLightModeScripts
      ];
    };
  };
}

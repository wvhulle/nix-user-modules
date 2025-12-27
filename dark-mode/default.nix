{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.darkMode;

  lightDarkApp = lib.types.submodule {
    options = {
      dark = lib.mkOption {
        type = lib.types.str;
        description = "Theme name for dark mode";
      };
      light = lib.mkOption {
        type = lib.types.str;
        description = "Theme name for light mode";
      };
      script = lib.mkOption {
        type = lib.types.path;
        description = "Path to the theme switching script";
      };
    };
  };

  lightDarkAppSet = lib.types.attrsOf lightDarkApp;

  makeThemeScript =
    name: app: mode: theme:
    let
      scriptPath = pkgs.lib.makeBinPath [
        pkgs.nushell
        pkgs.coreutils
        pkgs.glib
        pkgs.systemd
        pkgs.kdePackages.plasma-workspace
      ];
      xdgDataDirs = pkgs.lib.concatStringsSep ":" [
        "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}"
        "${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}"
      ];
    in
    pkgs.writeShellScript "theme-${name}-${mode}" ''
      export PATH="${scriptPath}:$PATH"
      export XDG_DATA_DIRS="${xdgDataDirs}"
      ${app.script} '${theme}' ${mode}
    '';

in
{
  options.programs.darkMode = {
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

    apps = lib.mkOption {
      type = lightDarkAppSet;
      default = {
        gtk = {
          dark = "Breeze-Dark";
          light = "Breeze";
          script = ./gtk-theme.nu;
        };

        plasma = {
          dark = "org.kde.breezedark.desktop";
          light = "org.kde.breeze.desktop";
          script = ./plasma-theme.nu;
        };

        konsole = {
          dark = "Dark";
          light = "Light";
          script = ./konsole-theme.nu;
        };

        cursor = {
          dark = "Breeze_Snow";
          light = "Breeze_Light";
          script = ./cursor-theme.nu;
        };

        kitty = {
          # Use underscores for spaces
          dark = "GitHub_Dark";
          light = "GitHub_Light";
          script = ./kitty-theme.nu;
        };

        claude-code = {
          dark = "dark";
          light = "light";
          script = ./claude-code-theme.nu;
        };
      };
      description = "Applications with dark/light theme support";
    };

  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      (pkgs.makeDesktopItem {
        name = "darkman-toggle";
        desktopName = "Toggle Dark Mode";
        comment = "Toggle between light and dark themes";
        exec = "${pkgs.darkman}/bin/darkman toggle";
        icon = "fill-color";
        terminal = false;
        type = "Application";
        categories = [
          "Settings"
          "DesktopSettings"
        ];
        startupNotify = false;
      })
    ];

    services.darkman = {
      enable = true;

      settings = {
        lat = cfg.location.latitude;
        lng = cfg.location.longitude + cfg.location.longitudeOffset;
        dbusserver = true;
        portal = true;
      };

      darkModeScripts = lib.mapAttrs (name: app: makeThemeScript name app "dark" app.dark) cfg.apps;
      lightModeScripts = lib.mapAttrs (name: app: makeThemeScript name app "light" app.light) cfg.apps;
    };
  };
}

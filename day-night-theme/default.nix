{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.dayNightTheme;

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
      args = lib.mkOption {
        type = lib.types.functionTo (lib.types.listOf lib.types.str);
        description = "Function that takes theme name and returns args list";
        default = theme: [ theme ];
      };
    };
  };

  lightDarkAppSet = lib.types.attrsOf lightDarkApp;

  makeThemeScript =
    name: app: theme:
    let
      args = app.args theme;
      argStr = lib.concatStringsSep " " (map lib.escapeShellArg args);
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
    pkgs.writeShellScript "theme-${name}" ''
      export PATH="${scriptPath}:$PATH"
      export XDG_DATA_DIRS="${xdgDataDirs}"
      ${pkgs.nushell}/bin/nu ${app.script} ${argStr}
    '';

  makeThemeBin =
    name: script:
    pkgs.writeShellScriptBin name ''
      exec ${pkgs.nushell}/bin/nu ${script} "$@"
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

    apps = lib.mkOption {
      type = lightDarkAppSet;
      default = {
        gtk = {
          dark = "Breeze-Dark";
          light = "Breeze";
          script = ./gtk-theme.nu;
        };

        plasma = {
          dark = "org.kde.breezedark.desktop BreezeDark";
          light = "org.kde.breeze.desktop BreezeLight";
          script = ./plasma-theme.nu;
          args = theme: lib.splitString " " theme;
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
          dark = "dark Catppuccin-Mocha";
          light = "light Catppuccin-Latte";
          script = ./kitty-theme.nu;
          args = theme: lib.splitString " " theme;
        };

        claude-code = {
          dark = "dark";
          light = "light";
          script = ./claude-code-theme.nu;
        };
      };
      description = "Applications with dark/light theme support";
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
    ]
    ++ (lib.mapAttrsToList (name: app: makeThemeBin "${name}-theme" app.script) cfg.apps);

    services.darkman = {
      enable = true;

      settings = {
        lat = cfg.location.latitude;
        lng = cfg.location.longitude + cfg.location.longitudeOffset;
        dbusserver = true;
        portal = true;
      };

      darkModeScripts = lib.mkMerge [
        (lib.mapAttrs' (
          name: app: lib.nameValuePair "${name}-theme" (makeThemeScript name app app.dark)
        ) cfg.apps)
        cfg.extraDarkModeScripts
      ];

      lightModeScripts = lib.mkMerge [
        (lib.mapAttrs' (
          name: app: lib.nameValuePair "${name}-theme" (makeThemeScript name app app.light)
        ) cfg.apps)
        cfg.extraLightModeScripts
      ];
    };
  };
}

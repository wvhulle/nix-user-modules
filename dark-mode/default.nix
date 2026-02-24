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
        description = "Theme name for dark mode (passed as first arg to script)";
      };
      light = lib.mkOption {
        type = lib.types.str;
        description = "Theme name for light mode (passed as first arg to script)";
      };
      script = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to the theme switching script";
      };
      scriptArgs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Extra arguments passed after theme and mode";
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
        pkgs.dbus
        pkgs.kdePackages.plasma-workspace
        pkgs.kdePackages.kconfig
      ];
      xdgDataDirs = pkgs.lib.concatStringsSep ":" [
        "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}"
        "${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}"
        "${pkgs.gtk4}/share/gsettings-schemas/${pkgs.gtk4.name}"
      ];
      extraArgs = lib.concatMapStringsSep " " lib.escapeShellArg app.scriptArgs;
    in
    pkgs.writeShellScript "theme-${name}-${mode}" (
      if !builtins.isNull app.script then
        ''
          export PATH="${scriptPath}:$PATH"
          export XDG_DATA_DIRS="${xdgDataDirs}"
          ${app.script} '${theme}' ${mode} ${extraArgs}
        ''
      else
        ""
    );

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
        plasma = {
          dark = "stylix-dark";
          light = "stylix-light";
          script = ./plasma-theme.nu;
        };

        kitty = {
          dark = "stylix-dark";
          light = "stylix-light";
          script = ./kitty-theme.nu;
        };

        helix = {
          dark = "papercolor-dark";
          light = "papercolor-light";
          script = ./copy-config-theme.nu;
          scriptArgs = [
            "helix"
            "config.toml"
          ];
        };

        zellij = {
          dark = "stylix-dark";
          light = "stylix-light";
          script = ./copy-config-theme.nu;
          scriptArgs = [
            "zellij"
            "config.kdl"
          ];
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

    # Configure xdg-desktop-portal to use darkman for Settings (color-scheme)
    # This provides consistent portal signals for Firefox and other apps
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.kdePackages.xdg-desktop-portal-kde ];
      config.common = {
        default = [ "kde" ];
        "org.freedesktop.impl.portal.Settings" = [ "darkman" ];
      };
    };

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

    # # Apply theme when Stylix color schemes change
    # xdg.dataFile."color-schemes/stylix-dark.colors".onChange = ''
    #   ${pkgs.darkman}/bin/darkman toggle 2>/dev/null || true
    #   ${pkgs.darkman}/bin/darkman toggle 2>/dev/null || true
    # '';
    # xdg.dataFile."color-schemes/stylix-light.colors".onChange = ''
    #   ${pkgs.darkman}/bin/darkman toggle 2>/dev/null || true
    #   ${pkgs.darkman}/bin/darkman toggle 2>/dev/null || true
    # '';
  };
}

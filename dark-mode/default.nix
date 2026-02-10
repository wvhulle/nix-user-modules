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
        type = lib.types.nullOr lib.types.path;
        default = null;
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
        pkgs.dbus
        pkgs.kdePackages.plasma-workspace
        pkgs.kdePackages.kconfig
      ];
      xdgDataDirs = pkgs.lib.concatStringsSep ":" [
        "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}"
        "${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}"
        "${pkgs.gtk4}/share/gsettings-schemas/${pkgs.gtk4.name}"
      ];
    in
    pkgs.writeShellScript "theme-${name}-${mode}" (
      if !builtins.isNull app.script then
        ''
          export PATH="${scriptPath}:$PATH"
          export XDG_DATA_DIRS="${xdgDataDirs}"
          ${app.script} '${theme}' ${mode}
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
        gtk = {
          dark = "Breeze-Dark";
          light = "Breeze";
          script = ./gtk-theme.nu;
        };

        plasma = {
          # Use Stylix-generated themes from plasma-extended module
          # These are generated from base16 schemes in ~/.local/share/color-schemes/
          dark = "stylix-dark";
          light = "stylix-light";
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
          # Use Stylix-generated themes from kitty-extended module
          # These are generated from base16 schemes in ~/.config/kitty/themes/
          dark = "stylix-dark";
          light = "stylix-light";
          script = ./kitty-theme.nu;
        };

        helix = {
          dark = "everblush";
          light = "eiffel";
        };

        neovim = {
          dark = "catppuccin-mocha";
          light = "catppuccin-latte";
          script = ./neovim-theme.nu;
        };

        claude-code = {
          dark = "dark";
          light = "light";
          script = ./claude-code-theme.nu;
        };

        vscode = {
          dark = "GitHub Dark";
          light = "GitHub Light";
        };

        zed = {
          dark = "One Dark";
          light = "One Light";
          # No script needed - Zed uses theme.mode = "system" to follow OS preference
        };

        zellij = {
          # Use Stylix-generated themes from zellij-extended module
          # Note: Zellij doesn't support runtime theme switching for existing sessions
          # The script updates a marker file; new sessions will use the correct theme
          dark = "stylix-dark";
          light = "stylix-light";
          script = ./zellij-theme.nu;
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
  };
}

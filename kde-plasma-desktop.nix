{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.kde-plasma-desktop;
  stylixCfg = config.programs.stylix-extended;

  darkSchemeFile = "${pkgs.base16-schemes}/share/themes/${stylixCfg.colorSchemes.dark}.yaml";
  lightSchemeFile = "${pkgs.base16-schemes}/share/themes/${stylixCfg.colorSchemes.light}.yaml";

  # Script as a stable derivation - only rebuilds when script content changes
  base16ToKdeScript = pkgs.writeText "base16-to-kde.nu" (
    builtins.readFile ./dark-mode/base16-to-kde.nu
  );

  # Generate KDE color scheme using nushell script
  generateKdeScheme =
    name: schemeFile:
    pkgs.runCommand "kde-colorscheme-${name}" { nativeBuildInputs = [ pkgs.nushell ]; } ''
      nu ${base16ToKdeScript} ${schemeFile} ${name} > $out
    '';

  darkColorsFile = generateKdeScheme "stylix-dark" darkSchemeFile;
  lightColorsFile = generateKdeScheme "stylix-light" lightSchemeFile;

in
{
  options.programs.kde-plasma-desktop = {
    enable = lib.mkEnableOption "Plasma desktop with Stylix theme integration";

    generateStylixThemes = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Generate KDE color scheme files from Stylix color schemes for darkman";
    };
  };

  config = lib.mkIf cfg.enable {
    # Generate color schemes for darkman to switch between
    xdg.dataFile = lib.mkIf cfg.generateStylixThemes {
      "color-schemes/stylix-dark.colors".source = darkColorsFile;
      "color-schemes/stylix-light.colors".source = lightColorsFile;
    };

    # Plasma-manager configuration (enabled minimally for numlock only)
    # Convert existing settings: nix run github:nix-community/plasma-manager -- -n
    # https://nix-community.github.io/plasma-manager/options.xhtml
    # Widget names: kpackagetool6 --type=Plasma/Applet --list --global
    programs.plasma = {
      enable = false; # Enable for numlock setting to work on Wayland
      overrideConfig = true;

      # Enable numlock on startup for Wayland sessions
      input.keyboard.numlockOnStartup = "on";

      # Wallpaper and panel configuration disabled to preserve manual KDE settings
      # workspace.wallpaperPictureOfTheDay.provider = "bing";
      # kscreenlocker.appearance.wallpaperPictureOfTheDay.provider = "bing";

      # panels = [
      #   {
      #     location = "bottom";
      #     floating = true;
      #     widgets = [
      #       { name = "org.kde.plasma.kicker"; }
      #       {
      #         name = "org.kde.plasma.taskmanager";
      #         config.General.launchers = [
      #           "preferred://filemanager"
      #           "applications:firefox.desktop"
      #           "applications:signal.desktop"
      #           "applications:kitty.desktop"
      #           "applications:lunatask.desktop"
      #         ];
      #       }
      #       "org.kde.plasma.marginsseparator"
      #       {
      #         name = "martchus.syncthingplasmoid";
      #         config = {
      #           selectedConfig = 0;
      #           showTabTexts = false;
      #           showDownloads = true;
      #         };
      #       }
      #       {
      #         systemTray.items = {
      #           shown = [
      #             "org.kde.plasma.networkmanagement"
      #             "org.kde.plasma.bluetooth"
      #             "org.kde.plasma.battery"
      #             "org.kde.plasma.brightness"
      #             "org.kde.plasma.volume"
      #           ];
      #           hidden = [ "org.kde.plasma.clipboard" ];
      #         };
      #       }
      #       {
      #         digitalClock = {
      #           calendar.firstDayOfWeek = "monday";
      #           time = {
      #             format = "24h";
      #             showSeconds = "always";
      #           };
      #           date = {
      #             enable = true;
      #             format = "isoDate";
      #           };
      #         };
      #       }
      #     ];
      #   }
      # ];
    };
  };
}

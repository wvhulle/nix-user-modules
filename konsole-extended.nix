{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.konsole-extended;
  fontsCfg = config.programs.typography;
in
{
  options.programs.konsole-extended = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable Konsole terminal emulator configuration";
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

    command = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "${pkgs.zellij}/bin/zellij";
      description = "Command to run on new sessions";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.konsole = {
      enable = true;
      inherit (cfg) defaultProfile;
      profiles = lib.mapAttrs (name: colorScheme: {
        inherit colorScheme;
        inherit (cfg) command;
        font = {
          inherit (fontsCfg.terminal) name;
          size = fontsCfg.sizes.terminal;
        };
      }) cfg.profiles;
      extraConfig = {
        KonsoleWindow.ShowWindowTitleOnTitleBar = true;
      };
    };
  };
}

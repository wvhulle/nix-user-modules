{
  config,
  lib,
  ...
}:

let
  cfg = config.services.brightness-extended;
in
{
  options.services.brightness-extended = {
    enable = lib.mkEnableOption "extended brightness configuration with wluma";

    timeThresholds = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        "7" = "dim"; # 7 AM - morning
        "9" = "normal"; # 9 AM - full daylight
        "12" = "bright"; # noon - peak brightness
        "18" = "normal"; # 6 PM - evening
        "20" = "dim"; # 8 PM - getting dark
        "22" = "dark"; # 10 PM - night
      };
      description = "Time-based brightness thresholds";
      example = {
        "8" = "dim";
        "10" = "normal";
        "14" = "bright";
        "19" = "normal";
        "21" = "dim";
        "23" = "dark";
      };
    };

    additionalWlumaSettings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Additional wluma configuration settings";
    };
  };

  config = lib.mkIf cfg.enable {
    services.wluma = {
      enable = true;
      settings = lib.mkMerge [
        {
          als.time = {
            thresholds = cfg.timeThresholds;
          };
        }
        cfg.additionalWlumaSettings
      ];
    };
  };
}

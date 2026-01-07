{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.nushell-extended;
in
{
  options.programs.nushell-extended = {
    enable = lib.mkEnableOption "extended nushell configuration";
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile = {
      "nushell/autoload" = {
        source = ./autoload;
        recursive = true;
      };
    };

    programs = {
      nushell = {
        enable = true;

        envFile.source = ./env.nu;
        configFile.source = ./config.nu;
        loginFile.source = ./login.nu;
      };
    };

    home.packages = [ pkgs.libnotify ];
  };
}

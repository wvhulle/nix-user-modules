{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.kde-apps;
in
{
  options.programs.kde-apps = {
    enable = lib.mkEnableOption "KDE applications";

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = with pkgs.kdePackages; [
        kate
        dolphin
        konsole
        ark
        okular
        filelight
        kaccounts-integration
        kaccounts-providers
        partitionmanager
      ];
      description = "KDE packages to install";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = cfg.packages;
  };
}

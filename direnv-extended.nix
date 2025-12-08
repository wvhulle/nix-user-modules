{ config, lib, pkgs, ... }:

let cfg = config.programs.direnv-extended;
in {
  options.programs.direnv-extended = {
    enable = lib.mkEnableOption "extended direnv configuration";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.direnv;
      description = "The direnv package to use";
    };

    silentMode = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description =
        "Whether to enable silent mode (no output on environment changes)";
    };

    hideEnvDiff = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to hide environment variable differences";
    };

    strictEnv = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to enable strict environment checking";
    };

    customStdlib = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Custom stdlib functions to add to direnv";
      example = ''
        use_python() {
          export PYTHONPATH="$PWD:$PYTHONPATH"
        }
      '';
    };

    whitelist = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Direnv whitelist configuration";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.direnv = {
      enable = true;
      inherit (cfg) package;
      enableNushellIntegration = false;
      enableBashIntegration = true;
      enableFishIntegration = true;

      nix-direnv = { enable = true; };

      config = {
        global = {
          silent = cfg.silentMode;
          # log_format = if cfg.silentMode then "" else "%s";
          hide_env_diff = cfg.hideEnvDiff;
          strict_env = cfg.strictEnv;
        };
        inherit (cfg) whitelist;
      };

      stdlib = cfg.customStdlib;
    };

    # home.sessionVariables = {
    #   DIRENV_LOG_FORMAT = if cfg.silentMode then "" else "%s";
    # };
  };
}

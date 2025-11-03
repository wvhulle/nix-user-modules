# Extended Nushell configuration module
# Provides additional configuration options beyond standard home-manager programs.nushell
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.nushell-extended;

  # Single consolidated configuration file
  consolidatedConfigFile = "nushell-config.nu";
in
{
  options.programs.nushell-extended = {
    enable = lib.mkEnableOption "extended nushell configuration";

    defaultAliases = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to include default shell aliases (ll, tree)";
    };

    environmentVariables = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Environment variables to set in nushell env.nu";
      example = {
        EDITOR = "hx";
        PAGER = "less";
      };
    };

    enableCommonDefaults = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable common environment variable defaults (LC_ALL, SSH_AUTH_SOCK)";
    };

    username = lib.mkOption {
      type = lib.types.str;
      default = config.home.username;
      description = "Username for nushell configuration";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.nushell = {
      enable = true;

      shellAliases = lib.mkIf cfg.defaultAliases {
        ll = "${pkgs.eza}/bin/eza -la";
        tree = "${pkgs.eza}/bin/eza --tree";
      };

      settings = {
        show_banner = false;
        rm = {
          always_trash = true;
        };
      };

      extraEnv =
        let
          # Merge all environment variable sources
          allEnvVars =
            cfg.environmentVariables
            // (lib.optionalAttrs cfg.enableCommonDefaults {
              LC_ALL = "en_US.UTF-8";
              SSH_AUTH_SOCK = "\${XDG_RUNTIME_DIR}/ssh-agent";
              NU_PLUGIN_DIRS = "[\"${config.home.homeDirectory}/.cargo/bin\"]";
            })
            // config.home.sessionVariables; # Include home-manager session variables
        in
        lib.concatStringsSep "\n" (
          lib.mapAttrsToList (name: value: "$env.${name} = \"${value}\"") allEnvVars
        );

      extraConfig = builtins.readFile (./${consolidatedConfigFile});
    };
  };
}

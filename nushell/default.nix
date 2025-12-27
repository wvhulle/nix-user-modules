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

    shellAliases = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Shell aliases for nushell";
    };
  };

  config = lib.mkIf cfg.enable {
    programs = {
      nushell = {
        enable = true;
        shellAliases = {
          ll = "${pkgs.eza}/bin/eza -la";
        }
        // cfg.shellAliases;

        settings = {
          show_banner = false;
          rm.always_trash = true;
        };

        extraEnv =
          let
            envVars = {
              LC_ALL = "en_US.UTF-8";
              SSH_AUTH_SOCK = "\${XDG_RUNTIME_DIR}/ssh-agent";
            }
            // config.home.sessionVariables;
            envVarLines = lib.mapAttrsToList (name: value: ''$env.${name} = "${value}"'') envVars;
            pathPrepend =
              lib.optionalString (config.home.sessionPath != [ ])
                "$env.PATH = ($env.PATH | prepend [${
                  lib.concatMapStringsSep " " (p: ''"${p}"'') config.home.sessionPath
                }])";
          in
          lib.concatStringsSep "\n" (envVarLines ++ [ pathPrepend ]);

        extraConfig = builtins.readFile ./config.nu;
      };
    };
  };
}

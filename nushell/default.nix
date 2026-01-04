{
  config,
  lib,
  ...
}:

let
  cfg = config.programs.nushell-extended;
  scriptsDir = ./scripts;
in
{
  options.programs.nushell-extended = {
    enable = lib.mkEnableOption "extended nushell configuration";
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile = {
      "nushell/scripts" = {
        source = scriptsDir;
        recursive = true;
      };
    };

    programs = {
      nushell = {
        enable = true;

        configFile.source = ./config.nu;

        extraEnv =
          let
            envVarLines = lib.mapAttrsToList (
              name: value: ''$env.${name} = "${value}"''
            ) config.home.sessionVariables;
            pathPrepend =
              lib.optionalString (config.home.sessionPath != [ ])
                "$env.PATH = ($env.PATH | prepend [${
                  lib.concatMapStringsSep " " (p: ''"${p}"'') config.home.sessionPath
                }])";
          in
          lib.concatStringsSep "\n" (envVarLines ++ [ pathPrepend ]);
      };
    };
  };
}

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.nushell-extended;
  langsCfg = config.programs.languages;

  # Collect additionalPaths from all enabled languages
  languagePaths =
    if langsCfg.enable then
      lib.pipe langsCfg.languages [
        (lib.filterAttrs (_: l: l.enable))
        lib.attrValues
        (lib.concatMap (l: l.additionalPaths))
      ]
    else
      [ ];

  # Generate path add commands for language-specific paths
  pathAddCommands = lib.concatMapStringsSep "\n" (p: ''path add "${p}"'') languagePaths;
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
        extraEnv = lib.mkIf (languagePaths != [ ]) pathAddCommands;
        configFile.source = ./config.nu;
        loginFile.source = ./login.nu;
      };
    };

    home.packages = [ pkgs.libnotify ];

    home.sessionVariables = {
      REEDLINE_LS = "nu-lint --lsp";
    };
  };
}

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

  # Convert home.sessionVariables to nushell $env assignments
  # Handles $HOME → ($env.HOME) substitution for nushell string interpolation
  toNushellValue =
    value:
    let
      str = toString value;
    in
    if lib.hasInfix "$HOME" str then
      ''$"${builtins.replaceStrings [ "$HOME" ] [ "($env.HOME)" ] str}"''
    else
      ''"${str}"'';

  sessionVarCommands = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      name: value: "$env.${name} = ${toNushellValue value}"
    ) config.home.sessionVariables
  );
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
        extraEnv = lib.mkMerge [
          (lib.mkIf (languagePaths != [ ]) pathAddCommands)
          (lib.mkIf (config.home.sessionVariables != { }) sessionVarCommands)
        ];
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

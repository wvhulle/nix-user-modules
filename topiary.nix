# Don't use this with a manual `cargo install tiopiary` as it will cause conflicts.
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.programs.topiary;

  languageType = types.submodule {
    options = {
      extensions = mkOption {
        type = types.listOf types.str;
        description = "File extensions for this language";
      };

      queryFile = mkOption {
        type = types.path;
        description = "Path to the tree-sitter query file (.scm)";
      };

      grammar = mkOption {
        type = types.attrs;
        description = "Grammar configuration for the language";
      };
    };
  };

  languagesConfig = pkgs.writeText "languages.ncl" ''
    {
      languages = {
        ${concatStringsSep ",\n    " (
          mapAttrsToList (name: lang: ''
            ${name} = {
              extensions = ${builtins.toJSON lang.extensions},
              grammar.source.git = {
                git = "${lang.grammar.source.git.git}",
                rev = "${lang.grammar.source.git.rev}",
              },
            }'') cfg.languages
        )}
      },
    }
  '';
in
{
  options.programs.topiary = {
    enable = mkEnableOption "topiary formatter";

    package = mkOption {
      type = types.package;
      default = pkgs.topiary;
      description = "The topiary package to use.";
    };

    languages = mkOption {
      type = types.attrsOf languageType;
      default = { };
      description = "Language configurations for topiary";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];

    xdg.configFile = mkIf (cfg.languages != { }) (
      {
        "topiary/languages.ncl".source = languagesConfig;
      }
      // mapAttrs' (
        name: lang: nameValuePair "topiary/languages/${name}.scm" { source = lang.queryFile; }
      ) cfg.languages
    );

    # Also set systemd user session variables so GUI applications (like VS Code) can see them
    systemd.user.sessionVariables = mkIf (cfg.languages != { }) {
      TOPIARY_CONFIG_FILE = "${config.xdg.configHome}/topiary/languages.ncl";
      TOPIARY_LANGUAGE_DIR = "${config.xdg.configHome}/topiary/languages";
    };
  };
}

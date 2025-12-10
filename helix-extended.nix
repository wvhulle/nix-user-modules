{ config, lib, ... }:

let
  cfg = config.programs.helix-extended;
  langCfg = config.programs.languages;

  getFormatterCommand =
    name: formatter:
    if formatter.command != "" then formatter.command else "${formatter.package}/bin/${name}";

  getLangServers = langName: lib.attrNames (langCfg.languages.${langName}.servers or { });

  getLangFormatter = langName: langCfg.languages.${langName}.formatter or null;
in
{
  options.programs.helix-extended = {
    enable = lib.mkEnableOption "extended helix configuration";
  };

  config = lib.mkIf cfg.enable {
    programs.helix = {
      enable = true;
      defaultEditor = true;

      settings = {
        theme = "ao";

        editor = {
          # gutters = [
          #   "diff"
          #   "diagnostics"
          #   "line-numbers"
          #   "spacer"
          # ];
          auto-format = true;

          auto-save = {
            enable = true;
            focus-lost = true;
            after-delay = {
              enable = true;
              timeout = 1000;
            };
          };
          bufferline = "multiple";
          indent-guides = {
            render = true;
          };
          end-of-line-diagnostics = "hint";
          inline-diagnostics = {
            cursor-line = "warning";
            other-lines = "error";
          };

          soft-wrap = {
            enable = true;
          };
        };
      };

      languages = {
        language =
          let
            # Map from languages.nix names to helix language identifiers
            langNameMap = {
              nushell = "nu";
            };

            mkLanguageConfig =
              langName: _:
              let
                helixLangName = langNameMap.${langName} or langName;
                formatter = getLangFormatter langName;
                formatterName =
                  if formatter != null then formatter.package.pname or formatter.package.name else null;
              in
              {
                name = helixLangName;
                auto-format = true;
                language-servers = getLangServers langName;
              }
              // lib.optionalAttrs (formatter != null) {
                formatter = {
                  command = getFormatterCommand formatterName formatter;
                  args = formatter.args ++ lib.optional (langName == "markdown") helixLangName;
                };
              };

            enabledLanguages = lib.filterAttrs (_: l: l.enable) langCfg.languages;
          in
          lib.sortOn (l: l.name) (lib.mapAttrsToList mkLanguageConfig enabledLanguages);

        language-server =
          let
            getServerCommand =
              name: server:
              if server.command != "" then
                server.command
              else if server.package != null then
                "${server.package}/bin/${name}"
              else
                null;

            mkServerConfig =
              name: server:
              let
                cmd = getServerCommand name server;
              in
              lib.nameValuePair name (
                lib.optionalAttrs (cmd != null) { command = cmd; }
                // lib.optionalAttrs (server.args != [ ]) {
                  inherit (server) args;
                }
                // lib.optionalAttrs (server.config != { }) {
                  inherit (server) config;
                }
              );

            allServers = lib.foldl' (acc: langCfg: acc // langCfg.servers) { } (
              lib.attrValues (lib.filterAttrs (_: l: l.enable) langCfg.languages)
            );

            enabledServers = lib.filterAttrs (_: s: s.enable) allServers;
          in
          lib.mapAttrs' mkServerConfig enabledServers;
      };
    };

    programs.languages.enable = true;
  };
}

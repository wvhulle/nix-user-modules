{ config, lib, ... }:

let
  cfg = config.programs.helix-extended;
  langCfg = config.programs.languages;
  enabledLanguages = lib.filterAttrs (_: l: l.enable) langCfg.languages;
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
        theme = "base16_transparent";

        editor = {
          completion-replace = true;
          lsp = {
            display-progress-messages = true;
            display-inlay-hints = true;
            goto-reference-include-declaration = false;
            snippets = false;
          };
          trim-final-newlines = true;
          trim-trailing-whitespace = true;
          popup-border = "all";
          line-number = "relative";
          rulers = [ ];
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
              timeout = 500;
            };
          };
          bufferline = "multiple";
          indent-guides = {
            render = true;
          };
          end-of-line-diagnostics = "disable"; # TODO: Find a way to only show hints inline, long diagnostics become unreadable inline
          inline-diagnostics = {
            cursor-line = "disable";
            other-lines = "disable";
          };

          soft-wrap = {
            enable = true;
          };

          shell = [
            "nu"
            "-c"
          ];

        };

        keys = {

          insert = {
            S-tab = "move_parent_node_start";
          };

          select = {
            tab = "extend_parent_node_end";
            S-tab = "extend_parent_node_start";

          };
          normal = {
            tab = "move_parent_node_end";
            S-tab = "move_parent_node_start";
            S-l = ":buffer-next";
            S-h = ":buffer-previous";
            "C-l" = [
              ":write-all"
              ":run-shell-command zellij run --in-place -c -- lazygit -p %sh{dirname %{buffer_name}}"
              ":redraw"
              ":reload-all"
            ];
            space = {
              i = {
                c = ":toggle inline-diagnostics.cursor-line hint disable";
                e = ":toggle end-of-line-diagnostics warning disable";
                o = ":toggle inline-diagnostics.other-lines error disable";

              };
              # t = {
              #   "1" = ":theme ${config.programs.darkMode.apps.helix.dark}";
              #   "2" = ":theme ${config.programs.darkMode.apps.helix.light}";

              # };

              B = ''
                :echo %sh{git blame -L %{cursor_line},+1 %{buffer_name}}
              '';
              N = ":run-shell-command ${./helix-copy-filename.nu} %{buffer_name}";
              L = ":echo %sh{${./helix-repo-link.nu} %{buffer_name} %{cursor_line}}";
            };
          };
        };
      };

      languages =
        let
          cleanup = lib.filterAttrs (_: v: v != null && v != [ ] && v != { });

          toHelixLanguage =
            name: lang:
            {
              inherit name;
              auto-format = true;
              language-servers = lib.attrNames (lang.servers or { });
              file-types = if lang.fileTypes != [ ] then lang.fileTypes else lang.extensions;
            }
            // cleanup {
              inherit (lang) scope roots;
              grammar = if lang.grammar != null then lang.grammar.name else null;
              formatter =
                if lang.formatter != null then
                  {
                    inherit (lang.formatter) command args;
                  }
                else
                  null;
              debugger =
                if lang.debugger != null && lang.debugger.enable then
                  cleanup {
                    inherit (lang.debugger)
                      name
                      transport
                      command
                      templates
                      args
                      ;
                  }
                else
                  null;
            };

          toHelixServer = _: server: cleanup { inherit (server) command args config; };

          toHelixGrammar = _: lang: {
            inherit (lang.grammar) name;
            source = lib.filterAttrs (_: v: v != null) lang.grammar.source;
          };

          # Only generate [[grammar]] entries for grammars that Helix should fetch/build itself.
          # Grammars with a `package` are placed directly into the runtime via xdg.configFile.
          fetchedGrammars = lib.filterAttrs (
            _: l: l.grammar != null && l.grammar.package == null
          ) enabledLanguages;
        in
        {
          language = lib.sortOn (l: l.name) (lib.mapAttrsToList toHelixLanguage enabledLanguages);

          language-server = lib.mapAttrs toHelixServer langCfg.servers;

          grammar = lib.mapAttrsToList toHelixGrammar fetchedGrammars;
        };
    };

    # Place pre-built grammars and query files into the Helix runtime
    xdg.configFile = lib.mkMerge (
      lib.mapAttrsToList
        (
          _: lang:
          let
            g = lang.grammar;
          in
          # Pre-built grammar .so
          (lib.optionalAttrs (g != null && g.package != null) {
            "helix/runtime/grammars/${g.name}.so".source = "${g.package}/${g.name}.so";
          })
          # Query files
          // (lib.mapAttrs' (
            queryName: queryPath:
            lib.nameValuePair "helix/runtime/queries/${g.name}/${queryName}.scm" {
              source = queryPath;
            }
          ) (lib.optionalAttrs (g != null) lang.queries))
        )
        (
          lib.filterAttrs (
            _: l: l.grammar != null && (l.grammar.package != null || l.queries != { })
          ) enabledLanguages
        )
    );

    programs.languages.enable = true;
  };
}

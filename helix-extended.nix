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
        theme = "modus_vivendi";

        editor = {
          completion-replace = true;
          lsp = {
            display-progress-messages = false;
            display-inlay-hints = true;
            goto-reference-include-declaration = false;
            snippets = false;
          };
          trim-final-newlines = true;
          trim-trailing-whitespace = true;
          popup-border = "all";
          line-number = "relative";
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
              t = {
                "1" = ":theme ${config.programs.darkMode.apps.helix.dark}";
                "2" = ":theme ${config.programs.darkMode.apps.helix.light}";

              };

              B = ''
                :echo %sh{git blame -L %{cursor_line},+1 %{buffer_name}}
              '';
              N = ":run-shell-command ${./helix-copy-filename.nu} %{buffer_name}";
            };
          };
        };
      };

      languages =
        let
          toHelixLanguage =
            name: lang:
            {
              inherit name;
              auto-format = true;
              language-servers = lib.attrNames (lang.servers or { });
              file-types = if lang.fileTypes != [ ] then lang.fileTypes else lang.extensions;
            }
            // lib.optionalAttrs (lang.scope != null) { inherit (lang) scope; }
            // lib.optionalAttrs (lang.roots != [ ]) { inherit (lang) roots; }
            // lib.optionalAttrs (lang.formatter != null) {
              formatter = {
                command = lang.formatter.command or (lib.getExe lang.formatter.package);
                inherit (lang.formatter) args;
              };
            }
            // lib.optionalAttrs (lang.debugger != null && lang.debugger.enable) {
              debugger = {
                inherit (lang.debugger)
                  name
                  transport
                  command
                  templates
                  ;
              }
              // lib.optionalAttrs (lang.debugger.args != [ ]) { inherit (lang.debugger) args; };
            };

          toHelixServer =
            _: server:
            lib.optionalAttrs (server.command != null) { inherit (server) command; }
            // lib.optionalAttrs (server.args != [ ]) { inherit (server) args; }
            // lib.optionalAttrs (server.config != { }) { inherit (server) config; };
        in
        {
          language = lib.sortOn (l: l.name) (lib.mapAttrsToList toHelixLanguage enabledLanguages);

          language-server = lib.mapAttrs toHelixServer langCfg.servers;
        };
    };

    programs.languages.enable = true;
  };
}

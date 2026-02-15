{ config, lib, ... }:

let
  cfg = config.programs.zed-extended;
  langCfg = config.programs.languages;
  # fontsCfg = config.stylix.fonts;
  enabledLanguages = lib.filterAttrs (_: l: l.enable) langCfg.languages;

  # Zed uses capitalized language names (Rust, Python, Nix)
  capitalize = s: lib.toUpper (lib.substring 0 1 s) + lib.substring 1 (-1) s;

  # Convert server name from underscores to dashes (rust_analyzer -> rust-analyzer)
  toZedServerName = name: lib.replaceStrings [ "_" ] [ "-" ] name;

  # Map server config to Zed's lsp format
  toZedLspConfig =
    _: server:
    lib.optionalAttrs (server.config != { }) { initialization_options = server.config; }
    // lib.optionalAttrs (server.command != null) {
      binary = {
        path = server.command;
      }
      // lib.optionalAttrs (server.args != [ ]) { arguments = server.args; };
    };

  # Convert language config to Zed's languages format
  toZedLanguage =
    name: lang:
    lib.nameValuePair (capitalize name) (
      {
        language_servers = map (s: toZedServerName s.name) (
          lib.attrValues (lib.filterAttrs (_: s: s.enable) lang.servers)
        );
      }
      // lib.optionalAttrs (lang.formatter != null && lang.formatter.enable) {
        formatter = {
          external = {
            inherit (lang.formatter) command;
            arguments = lang.formatter.args;
          };
        };
      }
    );
in
{
  options.programs.zed-extended = {
    enable = lib.mkEnableOption "extended zed configuration";
  };

  config = lib.mkIf cfg.enable {
    programs.zed-editor = {
      enable = true;

      # Fully managed by Nix - use .zed/settings.json in projects for overrides
      mutableUserSettings = false;

      extensions = [
        "nix"
        "toml"
        "nushell"
        "typst"
      ];

      userSettings = {
        # Theme integration (follows OS dark/light preference)
        # theme = {
        #   mode = "system";
        #   inherit (config.programs.darkMode.apps.zed) dark;
        #   inherit (config.programs.darkMode.apps.zed) light;
        # };

        # Font configuration from Stylix
        # buffer_font_family = fontsCfg.monospace.name;
        # buffer_font_size = fontsCfg.sizes.applications;
        # ui_font_family = fontsCfg.sansSerif.name;
        # ui_font_size = fontsCfg.sizes.desktop;

        # Built-in Helix mode (also enables vim_mode)
        helix_mode = true;

        # Format on save
        format_on_save = "on";

        # LSP configuration - generated from languages
        lsp = lib.mapAttrs' (
          name: server: lib.nameValuePair (toZedServerName name) (toZedLspConfig name server)
        ) langCfg.servers;

        # Language-specific settings
        languages = lib.mapAttrs' toZedLanguage enabledLanguages;
      };
    };

    programs.languages.enable = true;
  };
}

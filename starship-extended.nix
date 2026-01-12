{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.starship-extended;

  # Convert TOML preset files to Nix attrsets and merge them
  presetSettings = lib.pipe cfg.presets [
    (map (
      preset: builtins.fromTOML (builtins.readFile "${cfg.package}/share/starship/presets/${preset}.toml")
    ))
    (builtins.foldl' lib.recursiveUpdate { })
  ];

  # Merge preset settings with user settings (user settings take precedence)
  mergedSettings = lib.recursiveUpdate presetSettings cfg.settings;
in
{
  options.programs.starship-extended = {
    enable = lib.mkEnableOption "extended starship configuration with preset support";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.starship;
      description = "The starship package to use";
    };

    presets = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "nerd-font-symbols"
        "no-empty-icons"
      ];
      description = ''
        List of starship presets to apply. Presets are applied in order,
        with later presets overriding earlier ones. User settings override all presets.
        Preset files are read from the starship package's share/starship/presets directory.
      '';
    };

    enableNushellIntegration = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable Nushell integration";
    };

    enableBashIntegration = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to enable Bash integration";
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = ''
        Starship configuration settings. These are merged with preset settings,
        with user settings taking precedence.
      '';
      example = {
        format = "$username $directory $git_branch$git_status\n$character";
        character = {
          success_symbol = "[>](bold green)";
          error_symbol = "[>](bold red)";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    programs.starship = {
      enable = true;
      inherit (cfg) package enableNushellIntegration enableBashIntegration;
      settings = mergedSettings;
    };
  };
}

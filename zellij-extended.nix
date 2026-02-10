{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.zellij-extended;
  stylixCfg = config.programs.stylix-extended;

  darkSchemeFile = "${pkgs.base16-schemes}/share/themes/${stylixCfg.colorSchemes.dark}.yaml";
  lightSchemeFile = "${pkgs.base16-schemes}/share/themes/${stylixCfg.colorSchemes.light}.yaml";

  # Script as a stable derivation - only rebuilds when script content changes
  base16ToZellijScript = pkgs.writeText "base16-to-zellij.nu" (
    builtins.readFile ./dark-mode/base16-to-zellij.nu
  );

  # Generate Zellij theme from base16 scheme
  generateZellijTheme =
    name: schemeFile:
    pkgs.runCommand "zellij-theme-${name}" { nativeBuildInputs = [ pkgs.nushell ]; } ''
      nu ${base16ToZellijScript} ${schemeFile} ${name} > $out
    '';

  darkThemeFile = generateZellijTheme "stylix-dark" darkSchemeFile;
  lightThemeFile = generateZellijTheme "stylix-light" lightSchemeFile;

  # Select default theme based on stylix polarity
  defaultTheme = if stylixCfg.polarity == "light" then "stylix-light" else "stylix-dark";
in
{
  options.programs.zellij-extended = {
    enable = lib.mkEnableOption "extended zellij configuration";

    generateStylixThemes = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Generate Zellij themes from Stylix color schemes for darkman";
    };
  };

  config = lib.mkIf cfg.enable {
    # Generate theme files for darkman to reference
    xdg.configFile = lib.mkIf cfg.generateStylixThemes {
      "zellij/themes/stylix-dark.kdl".source = darkThemeFile;
      "zellij/themes/stylix-light.kdl".source = lightThemeFile;
    };

    programs.zellij = {
      enable = true;

      layouts = {
        mobile = {
          layout = {
            _props = {
              default_mode = "normal";
            };
            _children = [
              {
                default_tab_template = {
                  _children = [
                    {
                      pane = {
                        size = 1;
                        borderless = true;
                        plugin = {
                          location = "zellij:tab-bar";
                        };
                      };
                    }
                    { "children" = { }; }
                  ];
                };
              }
              {
                tab = {
                  _props = {
                    name = "shell";
                    focus = true;
                  };
                  _children = [
                    {
                      pane = { };
                    }
                  ];
                };
              }
            ];
          };
        };
      };

      settings = {
        show_startup_tips = false;
        default_layout = "compact";
        theme = defaultTheme;
        default_mode = "locked";
        mouse_mode = true;

        keybinds = {
          locked = {
            "bind \"Alt h\"" = {
              MoveFocus = "Left";
            };
            "bind \"Alt j\"" = {
              MoveFocus = "Down";
            };
            "bind \"Alt k\"" = {
              MoveFocus = "Up";
            };
            "bind \"Alt l\"" = {
              MoveFocus = "Right";
            };
          };
        };

        ui = {
          pane_frames = {
            hide_session_name = true;
          };
        };
        simplified_ui = true;
      };
    };
  };
}

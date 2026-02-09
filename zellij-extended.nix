{ config, lib, ... }:

let
  cfg = config.programs.zellij-extended;
in
{
  options.programs.zellij-extended = {
    enable = lib.mkEnableOption "extended zellij configuration";
  };

  config = lib.mkIf cfg.enable {
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
        # theme managed by Stylix
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

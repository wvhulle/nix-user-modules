{
  lib,
  config,
  ...
}:

let
  cfg = config.services.syncthing-extended;
in
{
  options.services.syncthing-extended = {
    enable = lib.mkEnableOption "Syncthing file synchronization";

    guiAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1:8384";
      description = "Address and port for Syncthing GUI";
      example = "0.0.0.0:8384";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.local/share/syncthing";
      description = "Directory where Syncthing stores its data";
    };

    configDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.config/syncthing";
      description = "Directory where Syncthing stores its configuration";
    };

    openDefaultPorts = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to open default Syncthing ports in the firewall";
    };

    folders = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            path = lib.mkOption {
              type = lib.types.str;
              description = "Path to the folder";
            };
            id = lib.mkOption {
              type = lib.types.str;
              description = "Folder ID";
            };
            label = lib.mkOption {
              type = lib.types.str;
              default = "";
              description = "Folder label";
            };
            devices = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "List of device IDs to share this folder with";
            };
            versioning = lib.mkOption {
              type = lib.types.nullOr lib.types.attrs;
              default = null;
              description = "Versioning configuration";
              example = {
                type = "staggered";
                params = {
                  cleanInterval = "3600";
                  maxAge = "365";
                };
              };
            };
          };
        }
      );
      default = { };
      description = "Folders to synchronize";
    };

    devices = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            id = lib.mkOption {
              type = lib.types.str;
              description = "Device ID";
            };
            name = lib.mkOption {
              type = lib.types.str;
              description = "Device name";
            };
            addresses = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ "dynamic" ];
              description = "Device addresses";
            };
            compression = lib.mkOption {
              type = lib.types.enum [
                "always"
                "metadata"
                "never"
              ];
              default = "metadata";
              description = "Compression setting";
            };
            introducer = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Whether this device is an introducer";
            };
          };
        }
      );
      default = { };
      description = "Devices to connect to";
    };

    extraOptions = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Extra options for Syncthing configuration";
    };
  };

  config = lib.mkIf cfg.enable {
    services.syncthing = {
      enable = true;

      tray = lib.mkDefault false;

      extraOptions = [
        "-gui-address=${cfg.guiAddress}"
        "-home=${cfg.configDir}"
      ];
    };

    home.file = {
      "${lib.removePrefix config.home.homeDirectory cfg.dataDir}/.keep".text = "";
      "${lib.removePrefix config.home.homeDirectory cfg.configDir}/.keep".text = "";
    };

    # or by directly editing the config.xml file after initial setup
  };
}

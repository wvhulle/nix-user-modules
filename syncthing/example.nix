# Example Syncthing configuration for Home Manager
#
# To use this module in your Home Manager configuration:
#
# 1. Import the module:
#    imports = [ ./user-modules/syncthing ];
#
# 2. Enable and configure:
#    services.syncthing-extended = {
#      enable = true;
#      guiAddress = "127.0.0.1:8384";
#    };

{
  # Basic configuration - local access only
  services.syncthing-extended = {
    enable = true;
    guiAddress = "127.0.0.1:8384";
  };

  # Advanced configuration example
  # services.syncthing-extended = {
  #   enable = true;
  #   guiAddress = "0.0.0.0:8384";  # Allow LAN access
  #
  #   # Custom directories
  #   dataDir = "${config.home.homeDirectory}/Syncthing";
  #   configDir = "${config.home.homeDirectory}/.config/syncthing";
  #
  #   # Open firewall ports (if you have system access)
  #   openDefaultPorts = true;
  # };
}

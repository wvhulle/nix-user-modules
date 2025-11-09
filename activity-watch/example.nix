# Example ActivityWatch configuration for Home Manager
#
# To use this module in your Home Manager configuration:
#
# 1. Import the module:
#    imports = [ ./user-modules/activity-watch ];
#
# 2. Enable and configure:
#    programs.activitywatch = {
#      enable = true;
#      # Default categories are automatically loaded
#      # To override: categories = { ... };
#    };

{
  # Basic configuration - just enable everything with default categories
  programs.activitywatch = {
    enable = true;
    # Default categories from categories.nix are automatically loaded
  };

  # Advanced configuration example
  # programs.activitywatch = {
  #   enable = true;
  #
  #   server = {
  #     enable = true;
  #     port = 5600;
  #     host = "127.0.0.1";
  #     corsOrigins = [
  #       "http://localhost:5600"
  #       "http://127.0.0.1:5600"
  #     ];
  #   };
  #
  #   watchers = {
  #     afk = true;        # Enable AFK detection
  #     window = true;     # Enable Wayland window tracking
  #     vscode = true;     # Enable VSCode extension
  #   };
  #
  #   categories = {
  #     Work = {
  #       regex = "Code|GitHub|Programming";
  #       color = "#2E7D32";
  #       score = 10;
  #       children = {
  #         Programming = {
  #           keywords = [ "GitHub" "vim" "Code" "rust" "python" ];
  #           color = "#1565C0";
  #         };
  #       };
  #     };
  #
  #     Media = {
  #       keywords = [ "YouTube" "Netflix" "Spotify" ];
  #       color = "#D32F2F";
  #     };
  #   };
  #
  #   importCategories = true;
  # };
}

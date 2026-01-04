# Nushell core configuration

# Setup PATH before loading scripts
$env.PATH = (
  $env.PATH | prepend [
    ($env.HOME | path join '.nix-profile' 'bin')
    '/run/current-system/sw/bin'
  ]
)

# Environment variables
$env.LC_ALL = "en_US.UTF-8"
$env.NU_PLUGIN_DIRS = [($env.HOME | path join '.cargo' 'bin')]
$env.LD_LIBRARY_PATH = $"($env.LD_LIBRARY_PATH? | default ''):/run/current-system/sw/lib"

# Settings
$env.config.show_banner = false
$env.config.rm.always_trash = true
$env.config.display_errors.exit_code = true

# Aliases
alias ll = eza -la
alias home-switch = home-manager switch --flake ~/.config/nixos#wvhulle@x1 -b backup
alias system-switch = sudo nixos-rebuild switch --flake ~/.config/nixos#x1

# Hooks
$env.config.hooks.command_not_found = {|cmd| command-not-found $cmd }

# Load integrations from scripts directory
use scripts/direnv.nu
use scripts/kitty.nu
use scripts/navi.nu
use scripts/notifications.nu
use scripts/theme.nu

# Nushell shell itself (put env vars in env.nu)

# Source autoload scripts
source ~/.config/nushell/autoload/base16-preview.nu
source ~/.config/nushell/autoload/command-not-found.nu
source ~/.config/nushell/autoload/direnv.nu
source ~/.config/nushell/autoload/kitty.nu
source ~/.config/nushell/autoload/navi.nu
source ~/.config/nushell/autoload/notifications.nu
source ~/.config/nushell/autoload/starship.nu
source ~/.config/nushell/autoload/theme.nu

$env.config.show_banner = false
$env.config.rm.always_trash = true
$env.config.completions.case_sensitive = false
$env.config.completions.algorithm = "fuzzy"
$env.config.use_kitty_protocol = true
$env.config.filesize.precision = 3
$env.config.float_precision = 4
$env.config.table.mode = "light"

# Aliases
alias home-switch = nh home switch $"/home/($env.USER)/.config/nixos" --show-trace -b backup
alias system-switch = nh os switch $"/home/($env.USER)/.config/nixos" --show-trace
alias sg = ast-grep

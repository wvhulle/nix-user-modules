# Nushell shell itself (put env vars in env.nu)

$env.config.show_banner = false
$env.config.rm.always_trash = true
$env.config.completions.case_sensitive = false
$env.config.completions.algorithm = "fuzzy"
$env.config.use_kitty_protocol = true
$env.config.filesize.precision = 3
$env.config.float_precision = 4

# Aliases
alias home-switch = nh home switch $"/home/($env.USER)/.config/nixos" --show-trace -b backup
alias system-switch = nh os switch $"/home/($env.USER)/.config/nixos" --show-trace
alias sg = ast-grep

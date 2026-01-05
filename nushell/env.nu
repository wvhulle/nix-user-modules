# Nushell environment configuration
# This file loads before config.nu and sets up the environment

# Source NixOS environment to get proper PATH and other variables
# This is essential for SSH logins to work correctly
$env.PATH = (
  $env.PATH
  | split row (char esep)
  | prepend [
    ($env.HOME | path join '.nix-profile' 'bin')
    '/run/current-system/sw/bin'
    '/run/wrappers/bin'
  ]
  | uniq
)
$env.LC_ALL = "en_US.UTF-8"
$env.NU_PLUGIN_DIRS = [($env.HOME | path join '.cargo' 'bin')]
$env.LD_LIBRARY_PATH = $"($env.LD_LIBRARY_PATH? | default ''):/run/current-system/sw/lib"

use std/util "path add"

# Core system paths - language-specific paths added via home-manager extraEnv
path add /run/wrappers/bin
path add ($env.HOME | path join .local bin) # For Python installed by UV
path add ($env.HOME | path join .nix-profile bin)

# Root folders for finding Nu modules (`use PATH_IN_FOLDER`)
load-env {
  NU_LIB_DIRS: [($nu.default-config-dir | path join nu-scripts)]
  LC_ALL: en_US.UTF-8
  NU_PLUGIN_DIRS: [($env.HOME | path join .cargo bin)]
  LD_LIBRARY_PATH: $"($env.LD_LIBRARY_PATH? | default ''):/run/current-system/sw/lib"
}

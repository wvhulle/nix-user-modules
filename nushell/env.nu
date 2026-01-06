$env.PATH ++= [
  ($env.HOME | path join '.nix-profile' 'bin')
  '/run/wrappers/bin'
  ($env.HOME | path join .local bin) # For Python installed by UV
]

# Root folders for finding Nu modules (`use PATH_IN_FOLDER`)
$env.NU_LIB_DIRS = [
  ($nu.default-config-dir | path join 'nu-scripts')
]

$env.LC_ALL = "en_US.UTF-8"
$env.NU_PLUGIN_DIRS = [($env.HOME | path join '.cargo' 'bin')]
$env.LD_LIBRARY_PATH = $"($env.LD_LIBRARY_PATH? | default ''):/run/current-system/sw/lib"

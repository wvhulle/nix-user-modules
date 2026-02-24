#!/usr/bin/env nu

# Generic config-copy theme switcher.
# Copies config-{mode}.{ext} to config.{ext} in the given XDG config subdirectory.
# Used by apps (helix, zellij) that pre-generate dark/light config variants.

export def main [
  theme_name: string
  mode: string
  config_subdir: string
  config_filename: string
] {
  let config_dir = ($env.XDG_CONFIG_HOME? | default $"($env.HOME)/.config") | path join $config_subdir
  let stem = ($config_filename | path parse | get stem)
  let ext = ($config_filename | path parse | get extension)
  let source = $"($config_dir)/($stem)-($mode).($ext)"
  let target = $"($config_dir)/($config_filename)"

  if ($source | path exists) {
    open $source --raw | save --force $target
  }
}

#!/usr/bin/env nu

# Switch Helix theme by copying the right config template.
# New Helix instances will use the copied config.
# Running instances need manual switching via :theme command.

export def main [
  theme_name: string
  mode: string
] {
  let config_dir = ($env.XDG_CONFIG_HOME? | default $"($env.HOME)/.config") | path join "helix"
  let source = $"($config_dir)/config-($mode).toml"
  let target = $"($config_dir)/config.toml"

  if ($source | path exists) {
    open $source --raw | save --force $target
  }
}

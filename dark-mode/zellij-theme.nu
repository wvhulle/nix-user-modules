#!/usr/bin/env nu

# Switch Zellij theme by copying the right config template.
# Zellij auto-reloads config.kdl when its contents change.

export def main [
  theme_name: string
  mode: string
] {
  let config_dir = ($env.XDG_CONFIG_HOME? | default $"($env.HOME)/.config") | path join "zellij"
  let source = $"($config_dir)/config-($mode).kdl"
  let target = $"($config_dir)/config.kdl"

  if ($source | path exists) {
    open $source --raw | save --force $target
  }
}

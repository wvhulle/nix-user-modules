#!/usr/bin/env nu

# Set Zellij theme for new sessions
# Note: Zellij doesn't support runtime theme switching for existing sessions
# This script updates the theme marker file that zellij-extended reads at startup

export def main [
  theme_name: string
  mode: string
] {
  print $"Setting Zellij theme to ($mode): ($theme_name)"

  let xdg_config = ($env.XDG_CONFIG_HOME? | default $"($env.HOME)/.config")
  let zellij_dir = $"($xdg_config)/zellij"
  let theme_marker = $"($zellij_dir)/current-theme"

  # Ensure directory exists
  mkdir $zellij_dir

  # Write the current theme name
  $theme_name | save --force $theme_marker

  print $"Theme marker updated: ($theme_marker)"
  print "New Zellij sessions will use this theme"
}

#!/usr/bin/env nu

# Switch Helix theme
export def main [
  theme_name?: string
] {
  if ($theme_name | is-empty) {
    print "Usage: helix-theme-nu <theme>"
    print "Example base16 themes: base16_default_light, base16_default_dark"
  } else {
    set-helix-theme $theme_name
  }
}

export def set-helix-theme [
  theme_name: string
] {
  print $"Switching Helix to theme: ($theme_name)"

  let config_file = get-helix-config-path

  if not ($config_file | path exists) {
    print $"Error: Helix config file not found: ($config_file)"
    return
  }

  try {
    # Check if config is a symlink (managed by home-manager)
    let is_symlink = ($config_file | path type) == "symlink"

    # Read the current config
    let config = open $config_file

    if $is_symlink {
      # Remove symlink and create real file
      rm $config_file
      print "Removed home-manager symlink, creating editable config"
    }

    # Update the theme in the config
    let updated_config = ($config | upsert theme $theme_name)

    # Write back the config
    $updated_config | save --force $config_file

    print $"Successfully set Helix theme to ($theme_name)"
    print "Note: This breaks home-manager management. To restore, run: home-manager switch"
  } catch {|err|
    print $"Error switching Helix theme: ($err.msg)"
  }
}

def get-helix-config-path []: nothing -> path {
  let xdg_config = ($env.XDG_CONFIG_HOME? | default $"($env.HOME)/.config")
  $"($xdg_config)/helix/config.toml"
}

# List available base16 themes for Helix
export def list-base16-themes []: nothing -> list<string> {
  [
    "base16_default_dark"
    "base16_default_light"
    "base16_terminal"
    "base16_transparent"
  ]
}

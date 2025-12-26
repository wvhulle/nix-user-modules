#!/usr/bin/env nu

# Switch Kitty theme using auto theme files
# Kitty automatically detects OS color scheme and loads the appropriate theme
export def main [
  theme_name?: string
] {
  if ($theme_name | is-empty) {
    print "Usage: kitty-theme-nu <theme>"
    print "Example themes: light, dark"
  } else {
    set-kitty-theme $theme_name
  }
}

export def set-kitty-theme [
  theme_name: string
] {
  print $"Switching Kitty to theme: ($theme_name)"

  let theme_file = get-theme-path $theme_name

  if not ($theme_file | path exists) {
    print $"Error: Theme file not found: ($theme_file)"
    return
  }

  try {
    # Create the auto theme file that kitty will load based on OS color scheme
    let auto_theme_file = get-auto-theme-path $theme_name

    # Copy the theme to the auto theme file
    open $theme_file | save --force $auto_theme_file

    print $"Successfully set Kitty auto-theme to ($theme_name)"
    print "Kitty will automatically reload the theme"
  } catch {|err|
    print $"Error switching Kitty theme: ($err.msg)"
  }
}

def get-theme-path [theme_name: string]: nothing -> path {
  let xdg_config = ($env.XDG_CONFIG_HOME? | default $"($env.HOME)/.config")
  let theme_dir = $"($xdg_config)/kitty/themes"
  $"($theme_dir)/($theme_name).conf"
}

def get-auto-theme-path [theme_name: string]: nothing -> path {
  let xdg_config = ($env.XDG_CONFIG_HOME? | default $"($env.HOME)/.config")
  let kitty_dir = $"($xdg_config)/kitty"

  # Map theme names to auto theme files
  # dark -> dark-theme.auto.conf
  # light -> light-theme.auto.conf or no-preference-theme.auto.conf
  match $theme_name {
    "dark" => $"($kitty_dir)/dark-theme.auto.conf"
    "light" => $"($kitty_dir)/light-theme.auto.conf"
    _ => $"($kitty_dir)/($theme_name)-theme.auto.conf"
  }
}

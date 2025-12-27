#!/usr/bin/env nu

# Switch Kitty theme using auto theme files
# Kitty automatically detects OS color scheme and loads the appropriate theme
export def main [
  mode?: string
  theme_name?: string
] {
  if ($mode | is-empty) {
    print "Usage: kitty-theme-nu <mode> <theme>"
    print "Example: kitty-theme-nu dark Catppuccin-Mocha"
  } else if ($theme_name | is-empty) {
    print "Usage: kitty-theme-nu <mode> <theme>"
    print "Example: kitty-theme-nu dark Catppuccin-Mocha"
  } else {
    set-kitty-theme $mode $theme_name
  }
}

export def set-kitty-theme [
  mode: string
  theme_name: string
] {
  print $"Switching Kitty to ($mode) theme: ($theme_name)"

  let theme_file = get-theme-path $theme_name

  if not ($theme_file | path exists) {
    print $"Error: Theme file not found: ($theme_file)"
    return
  }

  try {
    # Create the auto theme file that kitty will load based on OS color scheme
    let auto_theme_file = get-auto-theme-path $mode

    # Copy the theme to the auto theme file
    open $theme_file | save --force $auto_theme_file

    print $"Successfully set Kitty ($mode) auto-theme to ($theme_name)"
    print "Kitty will automatically reload the theme"
  } catch {|err|
    print $"Error switching Kitty theme: ($err.msg)"
  }
}

def get-theme-path [theme_name: string]: nothing -> path {
  let xdg_config = ($env.XDG_CONFIG_HOME? | default $"($env.HOME)/.config")

  let user_theme = $"($xdg_config)/kitty/themes/($theme_name).conf"
  if ($user_theme | path exists) {
    return $user_theme
  }

  let nix_themes = (glob /nix/store/*-kitty-themes-*/share/kitty-themes/themes | first)
  if ($nix_themes | path exists) {
    let nix_theme = $"($nix_themes)/($theme_name).conf"
    if ($nix_theme | path exists) {
      return $nix_theme
    }
  }

  $user_theme
}

def get-auto-theme-path [mode: string]: nothing -> path {
  let xdg_config = ($env.XDG_CONFIG_HOME? | default $"($env.HOME)/.config")
  let kitty_dir = $"($xdg_config)/kitty"

  # Map mode to auto theme files
  # dark -> dark-theme.auto.conf
  # light -> light-theme.auto.conf
  match $mode {
    "dark" => $"($kitty_dir)/dark-theme.auto.conf"
    "light" => $"($kitty_dir)/light-theme.auto.conf"
    _ => $"($kitty_dir)/($mode)-theme.auto.conf"
  }
}

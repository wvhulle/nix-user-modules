#!/usr/bin/env nu

# Switch GTK theme
export def main [
  theme_name: string
  mode?: string
] {
  print $"Switching GTK to ($theme_name) (mode: ($mode))"

  let color_scheme = if $mode == "dark" { "prefer-dark" } else { "prefer-light" }

  try {
    ^gsettings set org.gnome.desktop.interface gtk-theme $theme_name
    ^gsettings set org.gnome.desktop.interface color-scheme $color_scheme
    print $"Successfully set GTK theme to ($theme_name) with color-scheme ($color_scheme)"
  } catch {|err|
    print $"Error switching GTK theme: ($err.msg)"
  }
}

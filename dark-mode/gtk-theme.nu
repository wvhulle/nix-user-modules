#!/usr/bin/env nu

# Switch GTK theme
export def main [
  theme_name: string
  mode?: string
] {
  print $"Switching GTK to ($theme_name)"

  try {
    ^gsettings set org.gnome.desktop.interface gtk-theme $theme_name
    print $"Successfully set GTK theme to ($theme_name)"
  } catch {|err|
    print $"Error switching GTK theme: ($err.msg)"
  }
}

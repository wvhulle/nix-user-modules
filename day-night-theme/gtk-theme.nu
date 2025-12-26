#!/usr/bin/env nu

# Switch GTK theme
export def main [
  theme_name?: string
] {
  if ($theme_name | is-empty) {
    print "Usage: gtk-theme <theme>"
  } else {
    set-gtk-theme $theme_name
  }
}

export def set-gtk-theme [
  theme_name: string
] {
  print $"Switching GTK to ($theme_name)"

  try {
    ^gsettings set org.gnome.desktop.interface gtk-theme $theme_name
    print $"Successfully set GTK theme to ($theme_name)"
  } catch {|err|
    print $"Error switching GTK theme: ($err.msg)"
  }
}

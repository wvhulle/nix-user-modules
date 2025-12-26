#!/usr/bin/env nu

# Switch cursor theme
export def main [
  theme_name?: string
] {
  if ($theme_name | is-empty) {
    print "Usage: cursor-theme <theme>"
  } else {
    set-cursor-theme $theme_name
  }
}

export def set-cursor-theme [
  theme_name: string
] {
  print $"Switching cursor to ($theme_name)"

  try {
    ^gsettings set org.gnome.desktop.interface cursor-theme $theme_name
    print $"Successfully set cursor theme to ($theme_name)"
  } catch {|err|
    print $"Error switching cursor theme: ($err.msg)"
  }
}

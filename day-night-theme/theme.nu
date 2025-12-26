#!/usr/bin/env nu

# Helper to list items from directories
def list_from_dirs [dirs: list<string> filter?: closure] {
  $dirs
  | where {|dir| $dir | path exists }
  | each {|dir|
    try {
      let items = ls $dir | where type == dir | get name | path basename
      if $filter == null { $items } else { $items | where $filter }
    } catch { [] }
  }
  | flatten
  | uniq
  | sort
}

# Completion function for GTK themes
def complete_gtk_themes [] {
  list_from_dirs [
    "/run/current-system/sw/share/themes"
    ("~/.themes" | path expand)
    ("~/.local/share/themes" | path expand)
  ]
}

# Completion function for cursor themes
def complete_cursor_themes [] {
  list_from_dirs [
    "/run/current-system/sw/share/icons"
    ("~/.icons" | path expand)
    ("~/.local/share/icons" | path expand)
  ]
}

# Completion function for Plasma look-and-feel packages
def complete_plasma_lookandfeel [] {
  let result = do { ^plasma-apply-lookandfeel --list } | complete

  if $result.exit_code == 0 {
    $result.stdout | lines | each {|line| $line | str trim } | where {|x| $x != "" }
  } else {
    ["org.kde.breeze.desktop" "org.kde.breezetwilight.desktop" "org.kde.breezedark.desktop"]
  }
}

# Completion function for Plasma color schemes
def complete_plasma_colorschemes [] {
  let result = do { ^plasma-apply-colorscheme --list-schemes } | complete

  if $result.exit_code == 0 {
    $result.stdout
    | lines
    | skip 1
    | each {|line| $line | str trim | str replace --regex '^\* ' '' | str replace --regex ' \(current color scheme\)$' '' }
    | where {|x| $x != "" }
  } else {
    ["BreezeLight" "BreezeDark" "BreezeClassic"]
  }
}

# Completion function for Konsole themes
def complete_konsole_themes [] {
  [("~/.local/share/konsole" | path expand) "/run/current-system/sw/share/konsole"]
  | where {|dir| $dir | path exists }
  | each {|dir|
    try {
      ls $dir | where name =~ '\.profile$' | get name | path basename | str replace '.profile' ''
    } catch { [] }
  }
  | flatten
  | uniq
  | sort
}

# Helper to run external command with error handling
def run_theme_command [
  name: string
  command: closure
] {
  print -e $"Theme: ($name)"

  let result = do $command | complete

  if $result.exit_code != 0 {
    print -e $"Theme: Failed - ($name)"
    print -e $"Error: ($result.stderr)"
    error make {msg: $"Failed: ($name)"}
  }

  print -e $"Theme: Success - ($name)"
}

# Switch GTK theme
export def "theme gtk" [
  theme_name?: string@complete_gtk_themes
] {
  if $theme_name == null {
    print "Available GTK themes:"
    complete_gtk_themes | print
  } else {
    run_theme_command $"Switching GTK to ($theme_name)" {
      ^gsettings set org.gnome.desktop.interface gtk-theme $theme_name
    }
  }
}

# Switch cursor theme  
export def "theme cursor" [
  theme_name?: string@complete_cursor_themes
] {
  if $theme_name == null {
    print "Available cursor themes:"
    complete_cursor_themes | print
  } else {
    run_theme_command $"Switching cursor to ($theme_name)" {
      ^gsettings set org.gnome.desktop.interface cursor-theme $theme_name
    }
  }
}

# Switch Plasma theme
export def "theme plasma" [
  lookandfeel?: string@complete_plasma_lookandfeel
  colorscheme?: string@complete_plasma_colorschemes
] {
  if $lookandfeel == null {
    print "Available Plasma look-and-feel packages:"
    complete_plasma_lookandfeel | print
    return
  }

  if $colorscheme == null {
    print "Available Plasma color schemes:"
    complete_plasma_colorschemes | print
    return
  }

  run_theme_command $"Applying lookandfeel ($lookandfeel)" {
    ^plasma-apply-lookandfeel --apply $lookandfeel
  }

  run_theme_command $"Applying colorscheme ($colorscheme)" {
    ^plasma-apply-colorscheme $colorscheme
  }
}

# Switch Konsole theme
export def "theme konsole" [
  theme_name?: string@complete_konsole_themes
] {
  if $theme_name == null {
    print "Available Konsole themes:"
    complete_konsole_themes | print
  } else {
    run_theme_command $"Switching Konsole to ($theme_name)" {
      konsole-theme-nu $theme_name
    }
  }
}

# Main entry point for standalone script execution
def main [...args] {
  if ($args | is-empty) {
    print "Usage: theme.nu <subcommand> [args]"
    print ""
    print "Subcommands:"
    print "  gtk [name]              - Switch or list GTK themes"
    print "  cursor [name]           - Switch or list cursor themes"
    print "  plasma [look] [color]   - Switch or list Plasma themes"
    print "  konsole [name]          - Switch or list Konsole themes"
    return
  }

  let script_path = $env.CURRENT_FILE
  nu -c $'use "($script_path)" *; theme ($args | str join " ")'
}

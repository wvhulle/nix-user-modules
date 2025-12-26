#!/usr/bin/env nu

# Switch Claude Code theme
export def main [
  theme_name?: string
] {
  if ($theme_name | is-empty) {
    print "Usage: claude-code-theme-nu <theme>"
    print "Available themes: dark, light"
  } else {
    set-claude-code-theme $theme_name
  }
}

export def set-claude-code-theme [
  theme_name: string
] {
  print $"Switching Claude Code to theme: ($theme_name)"

  let config_file = get-claude-config-path

  if not ($config_file | path exists) {
    print $"Error: Claude Code config file not found: ($config_file)"
    return
  }

  try {
    # Read the current config
    let config = (open $config_file)

    # Update the theme in the config
    let updated_config = ($config | upsert theme $theme_name)

    # Write back the config atomically using a temp file
    let temp_file = $"($config_file).tmp"
    $updated_config | to json | save --force $temp_file
    mv $temp_file $config_file

    print $"Successfully set Claude Code theme to ($theme_name)"
  } catch {|err|
    print $"Error switching Claude Code theme: ($err.msg)"
  }
}

def get-claude-config-path []: nothing -> path {
  let home = $env.HOME
  $"($home)/.claude.json"
}

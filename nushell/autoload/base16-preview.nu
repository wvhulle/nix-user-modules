# Base16 theme previewer using true-color escape sequences
# Works inside Zellij (unlike base16-shell-preview which uses OSC palette redefinition)

# Get themes directory from environment or find in nix store (cached)
def themes-dir [] {
  if ($env.BASE16_THEMES? | is-not-empty) {
    return $env.BASE16_THEMES
  }
  # Fallback: find in nix store
  let store_paths = glob "/nix/store/*base16-schemes*/share/themes" | sort -r
  if ($store_paths | is-empty) {
    error make {msg: "base16-schemes not found. Set BASE16_THEMES env var or install base16-schemes."}
  }
  $store_paths | first
}

# Convert hex color (e.g., "#1d2021") to RGB tuple
def hex-to-rgb [hex: string] {
  let h = $hex | str replace '#' ''
  let r = $h | str substring 0..<2 | into int -r 16
  let g = $h | str substring 2..<4 | into int -r 16
  let b = $h | str substring 4..<6 | into int -r 16
  [$r $g $b]
}

# Generate true-color background escape sequence
def bg-color [hex: string] {
  let rgb = hex-to-rgb $hex
  $"\e[48;2;($rgb.0);($rgb.1);($rgb.2)m"
}

# Render a color swatch with label
def render-swatch [label: string, hex: string] {
  $"(bg-color $hex)    \e[0m ($label) ($hex)"
}

# Display a single theme from a parsed record
def display-theme [theme: record] {
  let p = $theme.palette
  let name = $theme.name
  let width = 53

  print $"╭─($name)('─' | fill -c '─' -w ($width - 3 - ($name | str length)))╮"

  # Color rows - pair base0X with base0(X+8)
  for pair in [[base00 base08] [base01 base09] [base02 base0A] [base03 base0B]
               [base04 base0C] [base05 base0D] [base06 base0E] [base07 base0F]] {
    let left = render-swatch $pair.0 ($p | get $pair.0)
    let right = render-swatch $pair.1 ($p | get $pair.1)
    print $"│ ($left)  ($right) │"
  }

  print $"╰('─' | fill -c '─' -w ($width - 2))╯"
  print ""
}

# Parse and display theme from path
def show-theme-path [path: path] {
  let content = open $path
  let name = $path | path basename | str replace '.yaml' ''
  display-theme { name: $name, palette: ($content | get palette) }
}

# List all theme names
export def "base16-preview list" [] {
  let dir = themes-dir
  glob $"($dir)/*.yaml" | sort | each { path basename | str replace '.yaml' '' }
}

# Show a single theme by name
export def "base16-preview show" [name: string] {
  let path = $"(themes-dir)/($name).yaml"
  if not ($path | path exists) {
    error make {msg: $"Theme not found: ($name)"}
  }
  show-theme-path $path
}

# Search themes by pattern and display matches
export def "base16-preview search" [pattern: string] {
  let dir = themes-dir
  let matches = glob $"($dir)/*.yaml" | sort | where { ($in | path basename) =~ $pattern }

  if ($matches | is-empty) {
    print $"No themes matching '($pattern)'"
    return
  }

  print $"Found ($matches | length) themes matching '($pattern)':\n"
  $matches | each { show-theme-path $in }
  null
}

# Display all themes (paginated)
export def "base16-preview all" [--limit: int = 10] {
  let dir = themes-dir
  let paths = glob $"($dir)/*.yaml" | sort
  let total = $paths | length

  print $"Showing ($limit) of ($total) themes. Use --limit to show more.\n"
  $paths | first $limit | each { show-theme-path $in }
  null
}

# Main entry point
export def "base16-preview" [] {
  print "Base16 Theme Previewer (true-color)

Commands:
  base16-preview list              - List all available theme names
  base16-preview show <name>       - Display a single theme
  base16-preview search <pattern>  - Filter and display themes by name
  base16-preview all [--limit N]   - Display all themes (default: 10)
"
  print $"Themes directory: (themes-dir)"
}

#!/usr/bin/env nu

# Switch Plasma color scheme
export def main [
  colorscheme: string
  mode?: string
] {
  print $"Applying Plasma color scheme: ($colorscheme)"

  try {
    ^plasma-apply-colorscheme $colorscheme
    print $"Successfully applied color scheme ($colorscheme)"
  } catch {|err|
    print $"Error applying color scheme: ($err.msg)"
  }
}

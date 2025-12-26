#!/usr/bin/env nu

# Switch Plasma theme
export def main [
  lookandfeel?: string
  colorscheme?: string
] {
  if ($lookandfeel | is-empty) {
    print "Usage: plasma-theme <lookandfeel> <colorscheme>"
  } else if ($colorscheme | is-empty) {
    print "Usage: plasma-theme <lookandfeel> <colorscheme>"
  } else {
    set-plasma-theme $lookandfeel $colorscheme
  }
}

export def set-plasma-theme [
  lookandfeel: string
  colorscheme: string
] {
  print $"Applying Plasma lookandfeel: ($lookandfeel)"

  try {
    ^plasma-apply-lookandfeel --apply $lookandfeel
    print $"Successfully applied lookandfeel ($lookandfeel)"
  } catch {|err|
    print $"Error applying lookandfeel: ($err.msg)"
  }

  print $"Applying Plasma colorscheme: ($colorscheme)"

  try {
    ^plasma-apply-colorscheme $colorscheme
    print $"Successfully applied colorscheme ($colorscheme)"
  } catch {|err|
    print $"Error applying colorscheme: ($err.msg)"
  }
}

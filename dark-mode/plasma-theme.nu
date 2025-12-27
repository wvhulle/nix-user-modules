#!/usr/bin/env nu

# Switch Plasma theme
export def main [
  lookandfeel: string

  mode?: string
] {
  print $"Applying Plasma lookandfeel: ($lookandfeel)"

  try {
    plasma-apply-lookandfeel --apply $lookandfeel
    print $"Successfully applied lookandfeel ($lookandfeel)"
  } catch {|err|
    print $"Error applying lookandfeel: ($err.msg)"
  }
}

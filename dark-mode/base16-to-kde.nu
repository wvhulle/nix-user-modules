#!/usr/bin/env nu

# Convert a base16 YAML color scheme to KDE .colors format
# Usage: base16-to-kde.nu <input.yaml> <scheme-name>

def hex-to-rgb [hex: string] {
  let clean = $hex | str replace '#' ''
  let r = ($clean | str substring 0..<2 | into int --radix 16)
  let g = ($clean | str substring 2..<4 | into int --radix 16)
  let b = ($clean | str substring 4..<6 | into int --radix 16)
  $"($r),($g),($b)"
}

def main [input_file: path, scheme_name: string] {
  let palette = open $input_file | get palette

  let c = {
    base00: (hex-to-rgb $palette.base00)
    base01: (hex-to-rgb $palette.base01)
    base02: (hex-to-rgb $palette.base02)
    base03: (hex-to-rgb $palette.base03)
    base04: (hex-to-rgb $palette.base04)
    base05: (hex-to-rgb $palette.base05)
    base06: (hex-to-rgb $palette.base06)
    base07: (hex-to-rgb $palette.base07)
    base08: (hex-to-rgb $palette.base08)
    base09: (hex-to-rgb $palette.base09)
    base0A: (hex-to-rgb $palette.base0A)
    base0B: (hex-to-rgb $palette.base0B)
    base0C: (hex-to-rgb $palette.base0C)
    base0D: (hex-to-rgb $palette.base0D)
    base0E: (hex-to-rgb $palette.base0E)
    base0F: (hex-to-rgb $palette.base0F)
  }

  # KDE color scheme template
  # Reference: https://github.com/nix-community/stylix/blob/master/modules/kde/hm.nix
  $"[ColorEffects:Disabled]
Color=($c.base01)
ColorAmount=0
ColorEffect=0
ContrastAmount=0.65
ContrastEffect=1
IntensityAmount=0.1
IntensityEffect=2

[ColorEffects:Inactive]
ChangeSelectionColor=true
Color=($c.base01)
ColorAmount=0.025
ColorEffect=2
ContrastAmount=0.1
ContrastEffect=2
Enable=false
IntensityAmount=0
IntensityEffect=0

[Colors:Button]
BackgroundAlternate=($c.base02)
BackgroundNormal=($c.base01)
DecorationFocus=($c.base0D)
DecorationHover=($c.base0D)
ForegroundActive=($c.base0D)
ForegroundInactive=($c.base04)
ForegroundLink=($c.base0D)
ForegroundNegative=($c.base08)
ForegroundNeutral=($c.base09)
ForegroundNormal=($c.base05)
ForegroundPositive=($c.base0B)
ForegroundVisited=($c.base0E)

[Colors:Complementary]
BackgroundAlternate=($c.base01)
BackgroundNormal=($c.base00)
DecorationFocus=($c.base0D)
DecorationHover=($c.base0D)
ForegroundActive=($c.base0D)
ForegroundInactive=($c.base04)
ForegroundLink=($c.base0D)
ForegroundNegative=($c.base08)
ForegroundNeutral=($c.base09)
ForegroundNormal=($c.base05)
ForegroundPositive=($c.base0B)
ForegroundVisited=($c.base0E)

[Colors:Header]
BackgroundAlternate=($c.base01)
BackgroundNormal=($c.base00)
DecorationFocus=($c.base0D)
DecorationHover=($c.base0D)
ForegroundActive=($c.base0D)
ForegroundInactive=($c.base04)
ForegroundLink=($c.base0D)
ForegroundNegative=($c.base08)
ForegroundNeutral=($c.base09)
ForegroundNormal=($c.base05)
ForegroundPositive=($c.base0B)
ForegroundVisited=($c.base0E)

[Colors:Header][Inactive]
BackgroundAlternate=($c.base01)
BackgroundNormal=($c.base00)
DecorationFocus=($c.base0D)
DecorationHover=($c.base0D)
ForegroundActive=($c.base0D)
ForegroundInactive=($c.base04)
ForegroundLink=($c.base0D)
ForegroundNegative=($c.base08)
ForegroundNeutral=($c.base09)
ForegroundNormal=($c.base05)
ForegroundPositive=($c.base0B)
ForegroundVisited=($c.base0E)

[Colors:Selection]
BackgroundAlternate=($c.base0D)
BackgroundNormal=($c.base0D)
DecorationFocus=($c.base0D)
DecorationHover=($c.base0D)
ForegroundActive=($c.base00)
ForegroundInactive=($c.base00)
ForegroundLink=($c.base00)
ForegroundNegative=($c.base08)
ForegroundNeutral=($c.base09)
ForegroundNormal=($c.base00)
ForegroundPositive=($c.base0B)
ForegroundVisited=($c.base0E)

[Colors:Tooltip]
BackgroundAlternate=($c.base01)
BackgroundNormal=($c.base00)
DecorationFocus=($c.base0D)
DecorationHover=($c.base0D)
ForegroundActive=($c.base0D)
ForegroundInactive=($c.base04)
ForegroundLink=($c.base0D)
ForegroundNegative=($c.base08)
ForegroundNeutral=($c.base09)
ForegroundNormal=($c.base05)
ForegroundPositive=($c.base0B)
ForegroundVisited=($c.base0E)

[Colors:View]
BackgroundAlternate=($c.base01)
BackgroundNormal=($c.base00)
DecorationFocus=($c.base0D)
DecorationHover=($c.base0D)
ForegroundActive=($c.base0D)
ForegroundInactive=($c.base04)
ForegroundLink=($c.base0D)
ForegroundNegative=($c.base08)
ForegroundNeutral=($c.base09)
ForegroundNormal=($c.base05)
ForegroundPositive=($c.base0B)
ForegroundVisited=($c.base0E)

[Colors:Window]
BackgroundAlternate=($c.base01)
BackgroundNormal=($c.base00)
DecorationFocus=($c.base0D)
DecorationHover=($c.base0D)
ForegroundActive=($c.base0D)
ForegroundInactive=($c.base04)
ForegroundLink=($c.base0D)
ForegroundNegative=($c.base08)
ForegroundNeutral=($c.base09)
ForegroundNormal=($c.base05)
ForegroundPositive=($c.base0B)
ForegroundVisited=($c.base0E)

[General]
ColorScheme=($scheme_name)
Name=($scheme_name)
shadeSortColumn=true

[KDE]
contrast=4

[WM]
activeBackground=($c.base00)
activeBlend=($c.base05)
activeForeground=($c.base05)
inactiveBackground=($c.base01)
inactiveBlend=($c.base04)
inactiveForeground=($c.base04)
"
}

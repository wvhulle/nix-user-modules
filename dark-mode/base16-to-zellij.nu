#!/usr/bin/env nu

# Convert a base16 YAML color scheme to Zellij component-based KDL theme format
# Usage: base16-to-zellij.nu <input.yaml> <theme-name>
#
# Base16 palette roles:
#   base00 = default background       base08 = red (variables, errors)
#   base01 = lighter background        base09 = orange (constants)
#   base02 = selection background      base0A = yellow (classes)
#   base03 = comments/invisibles       base0B = green (strings)
#   base04 = dark foreground           base0C = cyan (support, regex)
#   base05 = default foreground        base0D = blue (functions)
#   base06 = light foreground          base0E = magenta (keywords)
#   base07 = light background          base0F = brown (deprecated)

def hex-to-rgb [hex: string]: nothing -> string {
  let h = ($hex | str replace '#' '')
  let r = ($h | str substring 0..<2 | into int --radix 16)
  let g = ($h | str substring 2..<4 | into int --radix 16)
  let b = ($h | str substring 4..<6 | into int --radix 16)
  $"($r) ($g) ($b)"
}

def main [input_file: path, theme_name: string] {
  let p = open $input_file | get palette

  let bg      = hex-to-rgb $p.base00
  let bg1     = hex-to-rgb $p.base01
  let sel     = hex-to-rgb $p.base02
  let fg_dark = hex-to-rgb $p.base04
  let fg      = hex-to-rgb $p.base05
  let red     = hex-to-rgb $p.base08
  let orange  = hex-to-rgb $p.base09
  let yellow  = hex-to-rgb $p.base0A
  let green   = hex-to-rgb $p.base0B
  let cyan    = hex-to-rgb $p.base0C
  let blue    = hex-to-rgb $p.base0D
  let magenta = hex-to-rgb $p.base0E
  let brown   = hex-to-rgb $p.base0F

  # Component-based format for Zellij ≥ 0.41
  $'themes {
    ($theme_name) {
        text_unselected {
            base ($fg)
            background ($bg)
            emphasis_0 ($orange)
            emphasis_1 ($cyan)
            emphasis_2 ($green)
            emphasis_3 ($magenta)
        }
        text_selected {
            base ($fg)
            background ($sel)
            emphasis_0 ($orange)
            emphasis_1 ($cyan)
            emphasis_2 ($green)
            emphasis_3 ($magenta)
        }
        ribbon_selected {
            base ($bg)
            background ($blue)
            emphasis_0 ($red)
            emphasis_1 ($orange)
            emphasis_2 ($magenta)
            emphasis_3 ($cyan)
        }
        ribbon_unselected {
            base ($fg_dark)
            background ($bg1)
            emphasis_0 ($red)
            emphasis_1 ($fg)
            emphasis_2 ($blue)
            emphasis_3 ($magenta)
        }
        table_title {
            base ($blue)
            background 0
            emphasis_0 ($orange)
            emphasis_1 ($cyan)
            emphasis_2 ($green)
            emphasis_3 ($magenta)
        }
        table_cell_selected {
            base ($fg)
            background ($sel)
            emphasis_0 ($orange)
            emphasis_1 ($cyan)
            emphasis_2 ($green)
            emphasis_3 ($magenta)
        }
        table_cell_unselected {
            base ($fg)
            background ($bg)
            emphasis_0 ($orange)
            emphasis_1 ($cyan)
            emphasis_2 ($green)
            emphasis_3 ($magenta)
        }
        list_selected {
            base ($fg)
            background ($sel)
            emphasis_0 ($orange)
            emphasis_1 ($cyan)
            emphasis_2 ($green)
            emphasis_3 ($magenta)
        }
        list_unselected {
            base ($fg)
            background ($bg)
            emphasis_0 ($orange)
            emphasis_1 ($cyan)
            emphasis_2 ($green)
            emphasis_3 ($magenta)
        }
        frame_selected {
            base ($blue)
            background 0
            emphasis_0 ($orange)
            emphasis_1 ($cyan)
            emphasis_2 ($magenta)
            emphasis_3 0
        }
        frame_highlight {
            base ($orange)
            background 0
            emphasis_0 ($magenta)
            emphasis_1 ($orange)
            emphasis_2 ($orange)
            emphasis_3 ($orange)
        }
        exit_code_success {
            base ($green)
            background 0
            emphasis_0 ($cyan)
            emphasis_1 ($bg)
            emphasis_2 ($magenta)
            emphasis_3 ($blue)
        }
        exit_code_error {
            base ($red)
            background 0
            emphasis_0 ($yellow)
            emphasis_1 0
            emphasis_2 0
            emphasis_3 0
        }
        multiplayer_user_colors {
            player_1 ($magenta)
            player_2 ($blue)
            player_3 ($green)
            player_4 ($yellow)
            player_5 ($cyan)
            player_6 ($orange)
            player_7 ($red)
            player_8 ($brown)
            player_9 0
            player_10 0
        }
    }
}
'
}

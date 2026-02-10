#!/usr/bin/env nu

# Convert a base16 YAML color scheme to Zellij KDL theme format
# Usage: base16-to-zellij.nu <input.yaml> <theme-name>
# Reference: https://github.com/ralsina/base16-zellij

def main [input_file: path, theme_name: string] {
  let palette = open $input_file | get palette

  # Zellij KDL theme format
  $'themes {
    ($theme_name) {
        fg "($palette.base05)"
        bg "($palette.base00)"
        black "($palette.base00)"
        red "($palette.base08)"
        green "($palette.base0B)"
        yellow "($palette.base0A)"
        blue "($palette.base0D)"
        magenta "($palette.base0E)"
        cyan "($palette.base0C)"
        white "($palette.base05)"
        orange "($palette.base09)"
    }
}
'
}

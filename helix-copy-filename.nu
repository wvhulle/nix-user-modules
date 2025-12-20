#!/usr/bin/env nu

# Wraps base64-encoded data in an OSC 52 terminal escape sequence for clipboard operations
#
# OSC 52 is a standard ANSI sequence that allows terminal applications to interact
# with the system clipboard without requiring external tools (xclip, pbcopy, etc).
#
# Sequence format: ESC ] 52 ; clipboard ; data BEL
# - \e (ESC): starts escape sequence (ASCII 27)
# - ]52: Operating System Command 52 (clipboard manipulation)
# - ;;: clipboard selection (empty = default) and action (empty = set)
# - data: base64-encoded content to copy
# - \a (BEL): terminates OSC sequence (ASCII 7)
#
# Works in modern terminals: kitty, WezTerm, iTerm2, Konsole, Windows Terminal
# Works over SSH and inside tmux/screen sessions
def osc52_clipboard_sequence [data: string]: nothing -> string {
  $"\e]52;;($data)\a"
}

# Copy filename to clipboard using OSC 52 escape sequence
# Usage: helix-copy-filename.nu <filename>
def main [filename: string] {
  let encoded = $filename | encode base64
  osc52_clipboard_sequence $encoded | save --force /dev/tty
}

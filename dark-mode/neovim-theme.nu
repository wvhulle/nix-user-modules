#!/usr/bin/env nu

# Switch Neovim theme by writing to a state file and notifying running instances
# Neovim reads this file on startup and on FocusGained
export def main [
  theme_name: string
  mode: string
] {
  print $"Switching Neovim to ($mode) theme: ($theme_name)"

  let state_dir = get-state-dir
  let theme_file = $"($state_dir)/theme"

  # Ensure state directory exists
  if not ($state_dir | path exists) {
    mkdir $state_dir
  }

  try {
    # Write the theme name to the state file
    $theme_name | save --force $theme_file

    # Notify running neovim instances via socket
    notify-running-instances $theme_name

    print $"Successfully set Neovim theme to ($theme_name)"
  } catch {|err|
    print $"Error switching Neovim theme: ($err.msg)"
  }
}

def get-state-dir []: nothing -> path {
  let xdg_state = ($env.XDG_STATE_HOME? | default $"($env.HOME)/.local/state")
  $"($xdg_state)/nvim"
}

# Send colorscheme command to all running neovim instances
def notify-running-instances [theme_name: string] {
  let runtime_dir = $env.XDG_RUNTIME_DIR? | default "/tmp"

  # Find nvim sockets
  let sockets = (glob $"($runtime_dir)/nvim.*/0" | append (glob $"($runtime_dir)/nvim/*/nvim.*"))

  for socket in $sockets {
    if ($socket | path exists) {
      try {
        # Use nvim --server to send remote command
        ^nvim --server $socket --remote-send $"<Cmd>colorscheme ($theme_name)<CR>"
        print $"  Notified: ($socket)"
      } catch {
        # Socket might be stale, ignore
      }
    }
  }
}

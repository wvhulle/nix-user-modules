# Consolidated Nushell Configuration

# Check if command is interactive and shouldn't trigger notifications
export def is-interactive-command [command: string] {
  # Skip notifications for commands that users typically run and cancel themselves
  $command in ["top" "htop" "btop" "watch" "vim" "nvim" "nano" "less" "man" "ssh" "zellij"]
}

# Notify for long-running failed commands
export def notify-long-command [] {
  const NOTIFICATION_THRESHOLD = 10sec
  const SOUNDS_DIR = "/run/current-system/sw/share/sounds/freedesktop/stereo"

  # Skip notifications if explicitly disabled
  if ($env.DISABLE_COMMAND_NOTIFICATIONS? | default false) {
    return
  }

  let cmd_duration = (($env.CMD_DURATION_MS? | default "0") | into int | into duration -u ms)

  # Only notify for failures (non-zero exit code) that took more than 10 seconds
  if $cmd_duration > $NOTIFICATION_THRESHOLD {
    let exit_code = ($env.LAST_EXIT_CODE? | default 0)
    let last_command = try { (history | last | get command | split row ' ' | first) } catch { "" }

    # Only notify on failures
    if $exit_code == 0 {
      return
    }

    # Skip notifications for interrupted/cancelled commands or interactive commands
    if $exit_code in [130 143] or (is-interactive-command $last_command) {
      return
    }

    # Play simple warning sound for background process failures
    try { ^pw-play $"($SOUNDS_DIR)/dialog-warning.oga" } catch { ^paplay $"($SOUNDS_DIR)/dialog-warning.oga" }
  }
}

# =============================================================================
# THEME COMMANDS
# =============================================================================

# Refresh nushell theme based on system dark/light mode
export def refresh-theme [] {
  use std/config light-theme
  use std/config dark-theme

  let current_theme = (^darkman get | str trim)

  match $current_theme {
    "dark" => {
      $env.config = ($env.config | merge {color_config: (dark-theme)})
    }
    "light" => {
      $env.config = ($env.config | merge {color_config: (light-theme)})
    }
    _ => {
      $env.config = ($env.config | merge {color_config: (dark-theme)})
    }
  }
}

# Main nushell configuration
$env.config = (
  $env.config | merge {
    hooks: {
      command_not_found: {|command_name|
        command-not-found $command_name | str trim | print
      }
      pre_prompt: [
        {||
          refresh-theme
          notify-long-command
        }
      ]
    }
  }
)

# Check if command is interactive and shouldn't trigger notifications
export def is-interactive-command [command: string] {
  $command in ["top" "htop" "btop" "watch" "vim" "nvim" "nano" "less" "man" "ssh" "zellij"]
}

export def notify-long-command [] {
  const NOTIFICATION_THRESHOLD = 10sec
  const SOUNDS_DIR = "/run/current-system/sw/share/sounds/freedesktop/stereo"

  if ($env.DISABLE_COMMAND_NOTIFICATIONS? | default false) {
    return
  }

  let cmd_duration = (($env.CMD_DURATION_MS? | default "0") | into int | into duration -u ms)

  if $cmd_duration > $NOTIFICATION_THRESHOLD {
    let exit_code = ($env.LAST_EXIT_CODE? | default 0)
    let last_command = try { (history | last | get command | split row ' ' | first) } catch { "" }

    if $exit_code == 0 {
      return
    }

    if $exit_code in [130 143] or (is-interactive-command $last_command) {
      return
    }

    try { ^pw-play $"($SOUNDS_DIR)/dialog-warning.oga" } catch { ^paplay $"($SOUNDS_DIR)/dialog-warning.oga" }
  }
}

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

$env.config = ($env.config | default {} hooks)
$env.config.hooks = ($env.config.hooks | default {} command_not_found)
$env.config.hooks.command_not_found = {|command_name|
  command-not-found $command_name
}

$env.config.hooks = ($env.config.hooks | default [] pre_prompt)
$env.config.hooks.pre_prompt = (
  $env.config.hooks.pre_prompt
  | append {|| refresh-theme; notify-long-command }
)

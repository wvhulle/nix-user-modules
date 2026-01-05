# Command completion notifications

const INTERACTIVE_COMMANDS = ["top" "htop" "btop" "watch" "vim" "nvim" "nano" "less" "man" "ssh" "zellij" "hx" "lazygit"]
const NOTIFICATION_THRESHOLD = 10sec
const SOUNDS_DIR = "/run/current-system/sw/share/sounds/freedesktop/stereo"

export def notify-long-command [] {
  if ($env.DISABLE_COMMAND_NOTIFICATIONS? | default false) { return }

  let duration = ($env.CMD_DURATION_MS? | default "0") | into int | into duration -u ms
  if $duration <= $NOTIFICATION_THRESHOLD { return }

  let exit_code = $env.LAST_EXIT_CODE? | default 0
  if $exit_code == 0 { return }
  if $exit_code in [130 143] { return }

  let last_cmd = try { history | last | get command | split row ' ' | first } catch { "" }
  if $last_cmd in $INTERACTIVE_COMMANDS { return }

  try { ^pw-play $"($SOUNDS_DIR)/dialog-warning.oga" } catch { ^paplay $"($SOUNDS_DIR)/dialog-warning.oga" }
}

export-env {
  $env.config.hooks.pre_prompt = (
    ($env.config.hooks.pre_prompt? | default [])
    ++ [{|| notify-long-command }]
  )
}

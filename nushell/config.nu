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

export def --env refresh-theme [] {
  use std/config light-theme
  use std/config dark-theme

  let theme = match (darkman get | str trim) {
    "light" => (light-theme)
    _ => (dark-theme)
  }
  $env.config.color_config = $theme
}

def --env direnv-hook [] {
  if (which direnv | is-empty) { return }
  let result = direnv export json | complete
  if ($result.stderr | is-not-empty) { print -e $result.stderr }
  if $result.exit_code != 0 or ($result.stdout | is-empty) { return }
  $result.stdout | from json | default {} | load-env
  if ($env.PATH | describe) == "string" {
    $env.PATH = $env.PATH | split row (char esep)
  }
}

def --env zoxide-z [...rest: string] {
  let arg0 = ($rest | append '~').0
  let path = if ($rest | length) <= 1 and ($arg0 == '~' or ($arg0 | path expand | path type) == dir) {
    $arg0
  } else {
    zoxide query --exclude $env.PWD -- ...$rest | str trim -r -c "\n"
  }
  cd $path
}

def --env zoxide-zi [...rest: string] {
  cd (zoxide query -i -- ...$rest | str trim -r -c "\n")
}

alias z = zoxide-z
alias zi = zoxide-zi

# Atuin integration
source ~/.local/share/atuin/init.nu

# Configure new pipefail-like option that shows which pipeline element errored
$env.config.display_errors.exit_code = true

# Configure hooks
$env.config.hooks = $env.config.hooks? | default {}
$env.config.hooks.command_not_found = {|cmd| command-not-found $cmd }
$env.config.hooks.env_change = $env.config.hooks.env_change? | default {}
$env.config.hooks.env_change.PWD = (
  ($env.config.hooks.env_change.PWD? | default [])
  ++ [{|| direnv-hook }]
  ++ [{|_ after| zoxide add -- $after }]
)
$env.config.hooks.pre_prompt = (
  ($env.config.hooks.pre_prompt? | default [])
  ++ [{|| refresh-theme; notify-long-command; }]
)

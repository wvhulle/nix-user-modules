const INTERACTIVE_COMMANDS = ["top" "htop" "btop" "watch" "vim" "nvim" "nano" "less" "man" "ssh" "zellij" "hx" "lazygit"]
const NOTIFICATION_THRESHOLD = 10sec
const SOUNDS_DIR = "/run/current-system/sw/share/sounds/freedesktop/stereo"

def set-terminal-title [] {
  # Set terminal title via kitty remote control, bypassing zellij's title interception
  let dir_name = $env.PWD | path basename
  # Use kitty @ to set title directly if KITTY_LISTEN_ON is set
  if ($env.KITTY_LISTEN_ON? | is-not-empty) {
    try { kitty @ set-window-title $dir_name } catch { }
  }
}

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

# Atuin nushell integration
$env.ATUIN_SESSION = (atuin uuid)
hide-env --ignore-errors ATUIN_HISTORY_ID

let keybinding_token = $"# (random uuid)"

def --env atuin-pre-execution [] {
  let history_enabled = $nu | get -o history-enabled | default false
  if not $history_enabled { return }

  let cmd = commandline
  if ($cmd | is-empty) { return }
  if ($cmd | str starts-with $keybinding_token) { return }

  $env.ATUIN_HISTORY_ID = (atuin history start -- $cmd)
}

def --env atuin-pre-prompt [] {
  if 'ATUIN_HISTORY_ID' not-in $env { return }

  let exit_code = $env.LAST_EXIT_CODE
  with-env {ATUIN_LOG: error} {
    atuin history end $'--exit=($exit_code)' -- $env.ATUIN_HISTORY_ID | complete
  }
  hide-env ATUIN_HISTORY_ID
}

def atuin-search-cmd [...flags: string]: nothing -> string {
  let quoted_flags = $flags
    | append '--interactive'
    | each { $'"($in)"' }
    | str join ' '

  let search_line = 'let output = (run-external atuin search ' + $quoted_flags + ' e>| str trim)'
  let search_body = [
    $search_line
    'if ($output | str starts-with "__atuin_accept__:") {'
    '    commandline edit --accept ($output | str replace "__atuin_accept__:" "")'
    '} else {'
    '    commandline edit $output'
    '}'
  ] | str join "\n"

  [
    $keybinding_token
    'with-env { ATUIN_LOG: error, ATUIN_QUERY: (commandline), ATUIN_SHELL: nu } {'
    $search_body
    '}'
  ] | str join "\n"
}

$env.config.hooks = $env.config.hooks? | default {}
$env.config = $env.config
  | default {} hooks
  | upsert hooks.pre_execution { $in | default [] | append {|| atuin-pre-execution } }
  | upsert hooks.pre_prompt { $in | default [] | append {|| atuin-pre-prompt } }
  | default [] keybindings
  | upsert keybindings {
    $in | append {
      name: atuin
      modifier: control
      keycode: char_r
      mode: [emacs vi_normal vi_insert]
      event: {send: executehostcommand cmd: (atuin-search-cmd)}
    }
  }

# Configure new pipefail-like option that shows which pipeline element errored
$env.config.display_errors.exit_code = true

# Configure hooks
$env.config.hooks.command_not_found = {|cmd| command-not-found $cmd }
$env.config.hooks.env_change = $env.config.hooks.env_change? | default {}
$env.config.hooks.env_change.PWD = (
  ($env.config.hooks.env_change.PWD? | default [])
  ++ [{|| direnv-hook }]
  ++ [{|_ after| zoxide add -- $after }]
)
$env.config.hooks.pre_prompt = (
  ($env.config.hooks.pre_prompt? | default [])
  ++ [{|| set-terminal-title; refresh-theme; notify-long-command; }]
)

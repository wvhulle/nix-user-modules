# Command completion notifications

const INTERACTIVE_COMMANDS = ["top" "htop" "btop" "watch" "vim" "nvim" "nano" "less" "man" "ssh" "zellij" "hx" "lazygit"]
const NOTIFICATION_THRESHOLD = 10sec

def exit-code-to-urgency [exit_code: int]: nothing -> string {
  match $exit_code {
    1..2 => "normal"
    126..127 => "normal"
    _ => "critical"
  }
}

def send-notification [title: string body: string --urgency: string = "normal"]: nothing -> nothing {
  try {
    notify-send $"--urgency=($urgency)" --app-name="nushell" --icon=dialog-error --hint=string:sound-name:dialog-error $title $body
  } catch {|err|
    print $"Failed to send notification: ($err.msg)"
  }
}

export def create-desktop-notification [command: string exit_code: int --duration: duration = 0sec]: nothing -> nothing {
  let urgency = exit-code-to-urgency $exit_code
  let title = $"Command failed: ($command)"
  let body = $"Exit code: ($exit_code)\nDuration: ($duration)"
  send-notification $title $body --urgency $urgency
}

def is-interactive-command [command: string]: nothing -> bool {
  $command in $INTERACTIVE_COMMANDS
}

def is-user-interrupt [exit_code: int]: nothing -> bool {
  $exit_code in [130 143]
}

def get-last-command []: nothing -> string {
  try { history | last | get command | split row ' ' | first } catch { "" }
}

def get-command-duration []: nothing -> duration {
  ($env.CMD_DURATION_MS? | default "0") | into int | into duration -u ms
}

export def notify-long-command []: nothing -> nothing {
  if ($env.DISABLE_COMMAND_NOTIFICATIONS? | default false) { return }

  let duration = get-command-duration
  if $duration <= $NOTIFICATION_THRESHOLD { return }

  let exit_code = $env.LAST_EXIT_CODE? | default 0
  if $exit_code == 0 { return }
  if (is-user-interrupt $exit_code) { return }

  let command = get-last-command
  if (is-interactive-command $command) { return }

  create-desktop-notification $command $exit_code --duration $duration
}

export-env {
  $env.config.hooks.pre_prompt = (
    ($env.config.hooks.pre_prompt? | default [])
    ++ [{|| notify-long-command }]
  )
}

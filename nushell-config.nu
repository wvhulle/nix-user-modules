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
# Declarative integrations using official methods

# Atuin integration - source official init script
source ~/.local/share/atuin/init.nu

# Zoxide integration
def --env __zoxide_z [...rest: string] {
  let arg0 = ($rest | append '~').0
  let path = if (($rest | length) <= 1) and ($arg0 == '~' or ($arg0 | path expand | path type) == dir) {
    $arg0
  } else {
    (zoxide query --exclude $env.PWD -- ...$rest | str trim -r -c "\n")
  }
  cd $path
}

def --env __zoxide_zi [...rest: string] {
  cd $"(zoxide query -i -- ...$rest | str trim -r -c "\n")"
}

alias z = __zoxide_z
alias zi = __zoxide_zi

# Setup hooks using idiomatic nushell pattern
$env.config = (
  $env.config | upsert hooks {
    # Preserve existing hooks and add new ones
    let current_hooks = ($env.config.hooks? | default {})

    $current_hooks | upsert env_change {
      let current_env_change = ($current_hooks.env_change? | default {})

      $current_env_change | upsert PWD (
        ($current_env_change.PWD? | default [])
        | append {||
          # Direnv hook
          if (which direnv | is-empty) {
            return
          }
          direnv export json | from json | default {} | load-env
        }
        | append {||
          # Zoxide database update
          zoxide add -- $env.PWD
        }
      )
    } | upsert pre_prompt (
      ($current_hooks.pre_prompt? | default [])
      | append {|| refresh-theme; notify-long-command }
    )
  }
)

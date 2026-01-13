# Starship prompt initialization
export-env {
  $env.STARSHIP_SHELL = "nu"
  $env.STARSHIP_SESSION_KEY = (random chars --length 16)
  $env.PROMPT_MULTILINE_INDICATOR = (starship prompt --continuation)
  $env.PROMPT_INDICATOR = ""

  $env.PROMPT_COMMAND = {||
    let cmd_duration = if $env.CMD_DURATION_MS == "0823" { 0 } else { $env.CMD_DURATION_MS }
    starship prompt --cmd-duration $cmd_duration $"--status=($env.LAST_EXIT_CODE)" --terminal-width (term size).columns ...(
      if (which "job list" | where type == built-in | is-not-empty) {
        ["--jobs" (job list | length)]
      } else {
        []
      }
    )
  }

  $env.PROMPT_COMMAND_RIGHT = {||
    let cmd_duration = if $env.CMD_DURATION_MS == "0823" { 0 } else { $env.CMD_DURATION_MS }
    starship prompt --right --cmd-duration $cmd_duration $"--status=($env.LAST_EXIT_CODE)" --terminal-width (term size).columns ...(
      if (which "job list" | where type == built-in | is-not-empty) {
        ["--jobs" (job list | length)]
      } else {
        []
      }
    )
  }

  $env.config = (
    $env.config | merge {
      render_right_prompt_on_last_line: true
    }
  )
}

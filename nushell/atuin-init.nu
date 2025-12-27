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

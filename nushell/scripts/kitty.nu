# Kitty terminal integration

export def set-terminal-title [] {
  let dir_name = $env.PWD | path relative-to ~
  if ($env.KITTY_LISTEN_ON? | is-not-empty) {
    try { kitty @ set-window-title $dir_name } catch { }
  }
}

export-env {
  $env.config.hooks.pre_prompt = (
    ($env.config.hooks.pre_prompt? | default [])
    ++ [{|| set-terminal-title }]
  )
}

# Dynamic theme switching based on darkman

export def --env refresh-theme [] {
  use std/config light-theme
  use std/config dark-theme

  let theme = match (darkman get | str trim) {
    "light" => (light-theme)
    _ => (dark-theme)
  }
  $env.config.color_config = $theme
}

export-env {
  $env.config.hooks.pre_prompt = (
    ($env.config.hooks.pre_prompt? | default [])
    ++ [{|| refresh-theme }]
  )
}

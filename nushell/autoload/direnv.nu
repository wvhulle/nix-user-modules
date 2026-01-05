# Direnv integration

export def --env direnv-hook [] {
  if (which direnv | is-empty) { return }
  let result = direnv export json | complete
  if ($result.stderr | is-not-empty) { print -e $result.stderr }
  if $result.exit_code != 0 or ($result.stdout | is-empty) { return }
  $result.stdout | from json | default {} | load-env
  if ($env.PATH | describe) == "string" {
    $env.PATH = $env.PATH | split row (char esep)
  }
}

export-env {
  $env.config.hooks.env_change = $env.config.hooks.env_change? | default {}
  $env.config.hooks.env_change.PWD = (
    ($env.config.hooks.env_change.PWD? | default [])
    ++ [{|| direnv-hook }]
  )
}

#!/usr/bin/env nu

# Solar-based brightness manager
# Hardware-agnostic with automatic backend detection and smooth transitions

use std assert

const PI = 3.14159265359

# Detect brightness control backend
def detect-backend [] {
  if (do { ^ddcutil detect err> /dev/null | complete } | get exit_code) == 0 {
    {name: "DDC/CI" type: "ddcci"}
  } else if (do { ^ls /sys/class/backlight/ err> /dev/null | complete } | get exit_code) == 0 {
    {name: "Backlight" type: "backlight" device: (ls /sys/class/backlight/ | first | get name)}
  } else {
    error make {msg: "No brightness control backend found (tried DDC/CI and backlight)"}
  }
}

# Extract time from heliocron output line
def extract-time [line: string] {
  $line | parse -r '.+(\d{2}:\d{2}:\d{2}).+' | first | get capture0
}

# Get dawn/dusk lines based on twilight type
def get-twilight-lines [lines: list<string> twilight: string] {
  match $twilight {
    "civil" => {
      dawn: ($lines | where {|l| $l | str contains "Civil dawn is at:" } | first)
      dusk: ($lines | where {|l| $l | str contains "Civil dusk is at:" } | first)
    }
    "nautical" => {
      dawn: ($lines | where {|l| $l | str contains "Nautical dawn is at:" } | first)
      dusk: ($lines | where {|l| $l | str contains "Nautical dusk is at:" } | first)
    }
    "astronomical" => {
      dawn: ($lines | where {|l| $l | str contains "Astronomical dawn is at:" } | first)
      dusk: ($lines | where {|l| $l | str contains "Astronomical dusk is at:" } | first)
    }
    _ => {
      dawn: ($lines | where {|l| $l | str contains "Sunrise is at:" } | first)
      dusk: ($lines | where {|l| $l | str contains "Sunset is at:" } | first)
    }
  }
}

# Get solar times from heliocron
def get-solar-times [--latitude: float --longitude: float --twilight-type: string] {
  let output = (^heliocron --latitude $latitude --longitude $longitude report | complete)

  if $output.exit_code != 0 {
    error make {msg: $"Failed to get solar times: ($output.stderr)"}
  }

  let lines = ($output.stdout | lines)
  let twilight = (get-twilight-lines $lines $twilight_type)

  {
    dawn: (extract-time $twilight.dawn)
    sunrise: (extract-time ($lines | where {|l| $l | str contains "Sunrise is at:" } | first))
    solar_noon: (extract-time ($lines | where {|l| $l | str contains "Solar noon is at:" } | first))
    sunset: (extract-time ($lines | where {|l| $l | str contains "Sunset is at:" } | first))
    dusk: (extract-time $twilight.dusk)
  }
}

# Convert time string (HH:MM:SS) to hours since midnight
def time-to-hours [] {
  $in | split row ":" | take 2 | zip [1 0.0166667] | each {|p| ($p.0 | into float) * $p.1 } | math sum
}

# Calculate smooth transition progress using cosine interpolation
def smooth-step [progress: float] {
  (1.0 - (($progress * $PI) | math cos)) / 2.0
}

# Calculate brightness based on solar position
def calculate-brightness [
  current: float
  times: record
  --min: float
  --max: float
  --offset: int
] {
  let offset_hours = $offset / 60.0
  let dawn = ($times.dawn | time-to-hours) + $offset_hours
  let sunrise = ($times.sunrise | time-to-hours) + $offset_hours
  let sunset = ($times.sunset | time-to-hours) + $offset_hours
  let dusk = ($times.dusk | time-to-hours) + $offset_hours
  let range = $max - $min

  # Night time (before dawn or after dusk)
  if $current < $dawn or $current > $dusk {
    return $min
  }

  # Dawn transition (dawn -> sunrise)
  if $current < $sunrise {
    let progress = ($current - $dawn) / ($sunrise - $dawn)
    return ($min + ($range * 0.3 * (smooth-step $progress)))
  }

  # Daytime (sunrise -> sunset): sine curve based on sun position
  if $current < $sunset {
    let day_length = $sunset - $sunrise
    let sun_angle = (($current - $sunrise) / $day_length) * $PI
    return ($min + ($range * ($sun_angle | math sin)))
  }

  # Dusk transition (sunset -> dusk)
  let progress = ($current - $sunset) / ($dusk - $sunset)
  $min + ($range * 0.3 * (1.0 - (smooth-step $progress)))
}

# Get current brightness (0.0-1.0)
def get-brightness [backend: record] {
  if $backend.type == "ddcci" {
    let percent = (
      ^ddcutil getvcp 10
      | complete
      | get stdout
      | parse -r 'current value =\s*(\d+)'
      | first
      | get capture0
      | into int
    )
    {normalized: ($percent / 100.0) percent: $percent}
  } else if $backend.type == "backlight" {
    let current = (open $"($backend.device)/brightness" | into int)
    let max = (open $"($backend.device)/max_brightness" | into int)
    let normalized = $current / $max
    {normalized: $normalized percent: ($normalized * 100 | math round)}
  } else {
    error make {msg: $"Unknown backend type: ($backend.type)"}
  }
}

# Set brightness (0.0-1.0)
def set-brightness [target: float backend: record] {
  if $backend.type == "ddcci" {
    let percent = ($target * 100 | math round | into int)
    ^ddcutil setvcp 10 $percent | complete | null
    $percent
  } else if $backend.type == "backlight" {
    let max = (open $"($backend.device)/max_brightness" | into int)
    let value = ($target * $max | math round | into int)
    $value | save --force $"($backend.device)/brightness"
    ($target * 100 | math round | into int)
  } else {
    error make {msg: $"Unknown backend type: ($backend.type)"}
  }
}

# Smoothly transition brightness
def transition-brightness [
  current: float
  target: float
  backend: record
  --max-step: float = 0.05
  --step-delay: int = 200
] {
  let diff = $target - $current
  let abs_diff = ($diff | math abs)

  if $abs_diff <= $max_step {
    set-brightness $target $backend | null
  } else {
    let steps = ($abs_diff / $max_step | math ceil | into int)
    let step_size = $diff / $steps

    print $"<7>Transitioning in ($steps) steps"

    1..$steps | each {|step|
      let unclamped = $current + ($step_size * $step)
      let clamped_min = if $unclamped < 0.0 { 0.0 } else { $unclamped }
      let new_level = if $clamped_min > 1.0 { 1.0 } else { $clamped_min }
      set-brightness $new_level $backend | null
      if $step < $steps { sleep ($step_delay * 1ms) }
    } | null

    set-brightness $target $backend | null
  }
}

# Run all tests
def main [
  --test # Run tests instead of brightness adjustment
  --min-brightness (-m): float = 0.1
  --max-brightness (-M): float = 0.8
  --latitude (-a): float = 51.4769
  --longitude (-g): float = -0.0005
  --twilight-type (-t): string = "civil"
  --solar-offset (-o): int = 0
  --transition-max-step (-s): float = 0.05
  --transition-step-delay (-d): int = 200
] {
  if $test {
    print "Running tests..."

    let test_commands = (
      scope commands
      | where ($it.type == "custom")
      and ($it.name | str starts-with "test ")
      and not ($it.description | str starts-with "ignore")
      | get name
      | each {|test| [$"print 'Running test: ($test)'" $test] }
      | flatten
      | str join "; "
    )

    nu --commands $"source ($env.CURRENT_FILE); ($test_commands)"
    print "Tests completed successfully"
    return
  }

  # Normal brightness adjustment mode
  let backend = (detect-backend)
  let now = (date now)
  let current_time = ($now | format date "%H.%M" | into float)

  print $"<6>Solar brightness manager (($backend.name)): ($now | format date '%H:%M')"
  print $"<7>Backend: ($backend.type), Config: min=($min_brightness), max=($max_brightness)"

  try {
    let solar_times = (get-solar-times --latitude $latitude --longitude $longitude --twilight-type $twilight_type)
    print $"<7>Solar: dawn=($solar_times.dawn), sunrise=($solar_times.sunrise), sunset=($solar_times.sunset), dusk=($solar_times.dusk)"

    let target = (calculate-brightness $current_time $solar_times --min $min_brightness --max $max_brightness --offset $solar_offset)
    let current = (get-brightness $backend)
    let diff = (($target - $current.normalized) | math abs)

    print $"<7>Brightness: current=($current.normalized), target=($target), diff=($diff)"

    if $diff > 0.01 {
      print $"<6>Adjusting ($current.normalized) -> ($target)"
      transition-brightness $current.normalized $target $backend --max-step $transition_max_step --step-delay $transition_step_delay
      print $"<6>Transition complete"
    } else {
      print $"<7>Already at target level"
    }
  } catch {|err|
    print $"<3>Error: ($err.msg)"
    exit 1
  }
}

# Tests

export def "test extract-time" [] {
  assert equal (extract-time "Sunrise is at: 08:21:51 UTC") "08:21:51"
  assert equal (extract-time "Civil dawn is at: 07:44:37 UTC") "07:44:37"
  assert equal (extract-time "Sunset is at: 17:08:05 UTC") "17:08:05"
}

export def "test time-to-hours" [] {
  assert equal ("00:00:00" | time-to-hours) 0.0
  assert equal ("12:00:00" | time-to-hours) 12.0

  let result = "06:30:00" | time-to-hours
  assert ((($result - 6.5) | math abs) < 0.001) "06:30 should be approximately 6.5 hours"

  let result = "18:15:00" | time-to-hours
  assert ((($result - 18.25) | math abs) < 0.001) "18:15 should be approximately 18.25 hours"
}

export def "test smooth-step" [] {
  assert equal (smooth-step 0.0) 0.0
  assert equal (smooth-step 1.0) 1.0
  let mid = smooth-step 0.5
  assert ($mid > 0.4 and $mid < 0.6)
}

export def "test get-twilight-lines civil" [] {
  let lines = [
    "Sunrise is at: 08:00:00 UTC"
    "Civil dawn is at: 07:30:00 UTC"
    "Civil dusk is at: 18:30:00 UTC"
    "Nautical dawn is at: 07:00:00 UTC"
    "Nautical dusk is at: 19:00:00 UTC"
    "Astronomical dawn is at: 06:30:00 UTC"
    "Astronomical dusk is at: 19:30:00 UTC"
    "Sunset is at: 18:00:00 UTC"
  ]

  let civil = get-twilight-lines $lines "civil"
  assert str contains $civil.dawn "Civil dawn"
  assert str contains $civil.dusk "Civil dusk"
}

export def "test get-twilight-lines nautical" [] {
  let lines = [
    "Sunrise is at: 08:00:00 UTC"
    "Civil dawn is at: 07:30:00 UTC"
    "Civil dusk is at: 18:30:00 UTC"
    "Nautical dawn is at: 07:00:00 UTC"
    "Nautical dusk is at: 19:00:00 UTC"
    "Astronomical dawn is at: 06:30:00 UTC"
    "Astronomical dusk is at: 19:30:00 UTC"
    "Sunset is at: 18:00:00 UTC"
  ]

  let nautical = get-twilight-lines $lines "nautical"
  assert str contains $nautical.dawn "Nautical dawn"
  assert str contains $nautical.dusk "Nautical dusk"
}

export def "test get-twilight-lines astronomical" [] {
  let lines = [
    "Sunrise is at: 08:00:00 UTC"
    "Civil dawn is at: 07:30:00 UTC"
    "Civil dusk is at: 18:30:00 UTC"
    "Nautical dawn is at: 07:00:00 UTC"
    "Nautical dusk is at: 19:00:00 UTC"
    "Astronomical dawn is at: 06:30:00 UTC"
    "Astronomical dusk is at: 19:30:00 UTC"
    "Sunset is at: 18:00:00 UTC"
  ]

  let astronomical = get-twilight-lines $lines "astronomical"
  assert str contains $astronomical.dawn "Astronomical dawn"
  assert str contains $astronomical.dusk "Astronomical dusk"
}

export def "test get-twilight-lines default" [] {
  let lines = [
    "Sunrise is at: 08:00:00 UTC"
    "Civil dawn is at: 07:30:00 UTC"
    "Civil dusk is at: 18:30:00 UTC"
    "Sunset is at: 18:00:00 UTC"
  ]

  let default = get-twilight-lines $lines "unknown"
  assert str contains $default.dawn "Sunrise"
  assert str contains $default.dusk "Sunset"
}

export def "test calculate-brightness night before-dawn" [] {
  let times = {
    dawn: "07:00:00"
    sunrise: "08:00:00"
    sunset: "18:00:00"
    dusk: "19:00:00"
  }

  let brightness = calculate-brightness 6.0 $times --min 0.1 --max 0.8 --offset 0
  assert equal $brightness 0.1
}

export def "test calculate-brightness night after-dusk" [] {
  let times = {
    dawn: "07:00:00"
    sunrise: "08:00:00"
    sunset: "18:00:00"
    dusk: "19:00:00"
  }

  let brightness = calculate-brightness 20.0 $times --min 0.1 --max 0.8 --offset 0
  assert equal $brightness 0.1
}

export def "test calculate-brightness dawn transition" [] {
  let times = {
    dawn: "07:00:00"
    sunrise: "08:00:00"
    sunset: "18:00:00"
    dusk: "19:00:00"
  }

  let brightness = calculate-brightness 7.0 $times --min 0.1 --max 0.8 --offset 0
  assert ($brightness >= 0.1 and $brightness < 0.4)

  let brightness = calculate-brightness 7.5 $times --min 0.1 --max 0.8 --offset 0
  assert ($brightness > 0.1 and $brightness < 0.5)
}

export def "test calculate-brightness daytime" [] {
  let times = {
    dawn: "07:00:00"
    sunrise: "08:00:00"
    sunset: "18:00:00"
    dusk: "19:00:00"
  }

  let brightness = calculate-brightness 13.0 $times --min 0.1 --max 0.8 --offset 0
  assert ($brightness > 0.7 and $brightness <= 0.9)

  let brightness = calculate-brightness 10.0 $times --min 0.1 --max 0.8 --offset 0
  assert ($brightness > 0.3 and $brightness < 0.8)
}

export def "test calculate-brightness dusk transition" [] {
  let times = {
    dawn: "07:00:00"
    sunrise: "08:00:00"
    sunset: "18:00:00"
    dusk: "19:00:00"
  }

  # At sunset, brightness should be starting to decrease but still relatively high
  let brightness = calculate-brightness 18.0 $times --min 0.1 --max 0.8 --offset 0
  assert ($brightness >= 0.1 and $brightness < 0.6) "Brightness at sunset should be between 0.1 and 0.6"

  # Mid dusk - brightness should be lower
  let brightness = calculate-brightness 18.5 $times --min 0.1 --max 0.8 --offset 0
  assert ($brightness >= 0.1 and $brightness < 0.4) "Brightness at mid-dusk should be between 0.1 and 0.4"
}

export def "test calculate-brightness with-offset" [] {
  let times = {
    dawn: "07:00:00"
    sunrise: "08:00:00"
    sunset: "18:00:00"
    dusk: "19:00:00"
  }

  let brightness = calculate-brightness 6.5 $times --min 0.1 --max 0.8 --offset 30
  assert ($brightness >= 0.1 and $brightness < 0.4)
}

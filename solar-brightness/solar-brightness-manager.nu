#!/usr/bin/env nu

# Solar-based brightness manager
# Hardware-agnostic with automatic backend detection and smooth transitions

use std assert

const PI = 3.14159265359

# Detect brightness control backend
def detect-backend [] {
  if (^ddcutil detect err> /dev/null | complete | get exit_code) == 0 {
    {name: "DDC/CI" type: "ddcci"}
  } else if (^ls /sys/class/backlight/ err> /dev/null | complete | get exit_code) == 0 {
    {name: "Backlight" type: "backlight" device: (ls /sys/class/backlight/ | first | get name)}
  } else {
    error make {msg: "No brightness control backend found (tried DDC/CI and backlight)"}
  }
}

# Extract time from heliocron output line
def extract-time [] {
  parse "{label} is at: {rest}" | get rest.0 | split row " " | get 1
}

# Get dawn/dusk lines based on twilight type
def get-twilight-lines [lines: list<string> twilight: string] {
  let prefix = match $twilight {
    "civil" => "Civil"
    "nautical" => "Nautical"
    "astronomical" => "Astronomical"
    _ => ""
  }

  if $prefix == "" {
    {
      dawn: ($lines | where $it =~ "Sunrise is at:" | first)
      dusk: ($lines | where $it =~ "Sunset is at:" | first)
    }
  } else {
    {
      dawn: ($lines | where $it =~ $"($prefix) dawn is at:" | first)
      dusk: ($lines | where $it =~ $"($prefix) dusk is at:" | first)
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
    dawn: ($twilight.dawn | extract-time)
    sunrise: ($lines | where $it =~ "Sunrise is at:" | first | extract-time)
    solar_noon: ($lines | where $it =~ "Solar noon is at:" | first | extract-time)
    sunset: ($lines | where $it =~ "Sunset is at:" | first | extract-time)
    dusk: ($twilight.dusk | extract-time)
  }
}

# Convert time string (HH:MM:SS) to hours since midnight
def time-to-hours [] {
  let parts = $in | split row ":"
  let hours = $parts | first | into float
  let minutes = $parts | get 1 | into float
  $hours + ($minutes / 60.0)
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
  --offset: duration
] {
  let offset_hours = ($offset / 1hr)
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
      | parse "VCP code {code} ({name}): current value = {value}, max value = {max}"
      | first
      | get value
      | str trim
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
  --step-delay: duration = 200ms
] {
  let diff = $target - $current
  let abs_diff = $diff | math abs

  if $abs_diff <= $max_step {
    set-brightness $target $backend | null
    return
  }

  let steps = $abs_diff / $max_step | math ceil | into int
  let step_size = $diff / $steps

  print $"<7>Transitioning in ($steps) steps"

  1..$steps | each {|step|
    let new_level = ($current + $step_size * $step) | clamp 0.0 1.0
    set-brightness $new_level $backend | null
    if $step < $steps { sleep $step_delay }
  } | null

  set-brightness $target $backend | null
}

# Run all tests in the script
def run-all-tests [] {
  print "Running tests..."

  test extract-time
  test time-to-hours
  test smooth-step
  test get-twilight-lines civil
  test get-twilight-lines nautical
  test get-twilight-lines astronomical
  test get-twilight-lines default
  test calculate-brightness night before-dawn
  test calculate-brightness night after-dusk
  test calculate-brightness dawn transition
  test calculate-brightness daytime
  test calculate-brightness dusk transition
  test calculate-brightness with-offset

  print "Tests completed successfully"
}

# Run brightness adjustment based on solar position
def run-brightness-adjustment [config: record] {
  let solar_times = get-solar-times --latitude $config.location.latitude --longitude $config.location.longitude --twilight-type $config.twilight_type
  print $"<7>Solar: dawn=($solar_times.dawn), sunrise=($solar_times.sunrise), sunset=($solar_times.sunset), dusk=($solar_times.dusk)"

  let target = calculate-brightness $config.current_time $solar_times --min $config.brightness.min --max $config.brightness.max --offset $config.solar_offset
  let current = get-brightness $config.backend
  let diff = ($target - $current.normalized) | math abs

  print $"<7>Brightness: current=($current.normalized), target=($target), diff=($diff)"

  if $diff > 0.01 {
    print $"<6>Adjusting ($current.normalized) -> ($target)"
    transition-brightness $current.normalized $target $config.backend --max-step $config.transition.max_step --step-delay $config.transition.step_delay
    print $"<6>Transition complete"
  } else {
    print $"<7>Already at target level"
  }
}

# Show debug information
def show-debug-info [config: record] {
  let solar_times = get-solar-times --latitude $config.location.latitude --longitude $config.location.longitude --twilight-type $config.twilight_type
  let now = date now
  let current_time_str = $now | format date '%H:%M:%S'

  let target = calculate-brightness $config.current_time $solar_times --min $config.brightness.min --max $config.brightness.max --offset $config.solar_offset
  let current = get-brightness $config.backend
  let diff = ($target - $current.normalized) | math abs

  print $"Solar Brightness Debug Information"
  print $"=================================="
  print ""
  print $"Current Time: ($current_time_str)"
  print $"Backend: ($config.backend.name) \(($config.backend.type))"
  print ""
  print $"Location:"
  print $"  Latitude:  ($config.location.latitude)°"
  print $"  Longitude: ($config.location.longitude)°"
  print ""
  print $"Configuration:"
  print $"  Twilight Type: ($config.twilight_type)"
  print $"  Solar Offset:  ($config.solar_offset)"
  print $"  Min Brightness: ($config.brightness.min) \(($config.brightness.min * 100 | math round)%)"
  print $"  Max Brightness: ($config.brightness.max) \(($config.brightness.max * 100 | math round)%)"
  print ""
  print $"Solar Times \(UTC):"
  print $"  Dawn:        ($solar_times.dawn)"
  print $"  Sunrise:     ($solar_times.sunrise)"
  print $"  Solar Noon:  ($solar_times.solar_noon)"
  print $"  Sunset:      ($solar_times.sunset)"
  print $"  Dusk:        ($solar_times.dusk)"
  print ""
  print $"Brightness:"
  print $"  Current:  ($current.normalized | math round -p 3) \(($current.percent)%)"
  print $"  Target:   ($target | math round -p 3) \(($target * 100 | math round)%)"
  print $"  Diff:     ($diff | math round -p 3) \(($diff * 100 | math round)%)"
  print ""

  if $diff > 0.01 {
    print $"Status: Brightness adjustment needed"
  } else {
    print $"Status: Already at target level"
  }

  # Calculate and show next scheduled changes
  print ""
  print $"Scheduled Transitions:"
  let offset_hours = ($config.solar_offset / 1hr)
  let dawn_hour = ($solar_times.dawn | time-to-hours) + $offset_hours
  let sunrise_hour = ($solar_times.sunrise | time-to-hours) + $offset_hours
  let sunset_hour = ($solar_times.sunset | time-to-hours) + $offset_hours
  let dusk_hour = ($solar_times.dusk | time-to-hours) + $offset_hours

  let current_hour = $config.current_time

  if $current_hour < $dawn_hour {
    print $"  Next: Dawn transition starts at ($solar_times.dawn)"
  } else if $current_hour < $sunrise_hour {
    print $"  Current: In dawn transition"
    print $"  Next: Sunrise at ($solar_times.sunrise)"
  } else if $current_hour < $sunset_hour {
    print $"  Current: Daytime"
    print $"  Next: Sunset at ($solar_times.sunset)"
  } else if $current_hour < $dusk_hour {
    print $"  Current: In dusk transition"
    print $"  Next: Night at ($solar_times.dusk)"
  } else {
    print $"  Current: Night"
    print $"  Next: Dawn tomorrow"
  }
}

def main [
  --test # Run tests instead of brightness adjustment
  --debug # Show debug information without adjusting brightness
  --min-brightness (-m): float = 0.1
  --max-brightness (-M): float = 0.8
  --latitude (-a): float = 51.4769
  --longitude (-g): float = -0.0005
  --twilight-type (-t): string = "civil"
  --solar-offset (-o): duration = 0min
  --transition-max-step (-s): float = 0.05
  --transition-step-delay (-d): duration = 200ms
] {
  if $test {
    run-all-tests
    return
  }

  let backend = detect-backend
  let now = date now
  let current_time = $now | format date "%H.%M" | into float

  let config = {
    backend: $backend
    current_time: $current_time
    location: {latitude: $latitude longitude: $longitude}
    twilight_type: $twilight_type
    brightness: {min: $min_brightness max: $max_brightness}
    solar_offset: $solar_offset
    transition: {max_step: $transition_max_step step_delay: $transition_step_delay}
  }

  if $debug {
    try {
      show-debug-info $config
    } catch {|err|
      print $"Error: ($err.msg)"
      exit 1
    }
    return
  }

  print $"<6>Solar brightness manager (($backend.name)): ($now | format date '%H:%M')"
  print $"<7>Backend: ($backend.type), Config: min=($min_brightness), max=($max_brightness)"

  try {
    run-brightness-adjustment $config
  } catch {|err|
    print $"<3>Error: ($err.msg)"
    exit 1
  }
}

# Tests

export def "test extract-time" [] {
  assert equal ("Sunrise is at: 2025-11-20 08:21:51 +01:00" | extract-time) "08:21:51"
  assert equal ("Civil dawn is at: 2025-11-20 07:44:37 +01:00" | extract-time) "07:44:37"
  assert equal ("Sunset is at: 2025-11-20 17:08:05 +01:00" | extract-time) "17:08:05"
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

  let brightness = calculate-brightness 6.0 $times --min 0.1 --max 0.8 --offset 0min
  assert equal $brightness 0.1
}

export def "test calculate-brightness night after-dusk" [] {
  let times = {
    dawn: "07:00:00"
    sunrise: "08:00:00"
    sunset: "18:00:00"
    dusk: "19:00:00"
  }

  let brightness = calculate-brightness 20.0 $times --min 0.1 --max 0.8 --offset 0min
  assert equal $brightness 0.1
}

export def "test calculate-brightness dawn transition" [] {
  let times = {
    dawn: "07:00:00"
    sunrise: "08:00:00"
    sunset: "18:00:00"
    dusk: "19:00:00"
  }

  let brightness = calculate-brightness 7.0 $times --min 0.1 --max 0.8 --offset 0min
  assert ($brightness >= 0.1 and $brightness < 0.4)

  let brightness = calculate-brightness 7.5 $times --min 0.1 --max 0.8 --offset 0min
  assert ($brightness > 0.1 and $brightness < 0.5)
}

export def "test calculate-brightness daytime" [] {
  let times = {
    dawn: "07:00:00"
    sunrise: "08:00:00"
    sunset: "18:00:00"
    dusk: "19:00:00"
  }

  let brightness = calculate-brightness 13.0 $times --min 0.1 --max 0.8 --offset 0min
  assert ($brightness > 0.7 and $brightness <= 0.9)

  let brightness = calculate-brightness 10.0 $times --min 0.1 --max 0.8 --offset 0min
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
  let brightness = calculate-brightness 18.0 $times --min 0.1 --max 0.8 --offset 0min
  assert ($brightness >= 0.1 and $brightness < 0.6) "Brightness at sunset should be between 0.1 and 0.6"

  # Mid dusk - brightness should be lower
  let brightness = calculate-brightness 18.5 $times --min 0.1 --max 0.8 --offset 0min
  assert ($brightness >= 0.1 and $brightness < 0.4) "Brightness at mid-dusk should be between 0.1 and 0.4"
}

export def "test calculate-brightness with-offset" [] {
  let times = {
    dawn: "07:00:00"
    sunrise: "08:00:00"
    sunset: "18:00:00"
    dusk: "19:00:00"
  }

  let brightness = calculate-brightness 6.5 $times --min 0.1 --max 0.8 --offset 30min
  assert ($brightness >= 0.1 and $brightness < 0.4)
}

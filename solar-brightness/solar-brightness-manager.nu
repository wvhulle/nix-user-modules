#!/usr/bin/env nu

# Solar-based brightness manager
# Hardware-agnostic with automatic backend detection and smooth transitions

use std assert

# Clamp a value between min and max bounds
def clamp [min_val: float max_val: float]: float -> float {
  let clamped_low = ([$min_val $in] | math max)
  [$clamped_low $max_val] | math min
}

const PI = 3.14159265359
const SERVICE_NAME = "solar-brightness.service"
const TIMER_NAME = "solar-brightness.timer"

# Parse DDC/CI displays from ddcutil detect output
def parse-ddc-displays [output: string]: nothing -> list {
  let lines = $output | lines
  mut displays = []
  mut current_display = null
  mut current_model = null

  for line in $lines {
    if ($line | str starts-with "Display ") {
      # Save previous display if exists
      if $current_display != null and $current_model != null {
        $displays = ($displays | append {display: $current_display model: $current_model})
      }
      $current_display = ($line | parse "Display {num}" | get num.0 | into int)
      $current_model = null
    } else if ($line | str contains "Model:") {
      $current_model = ($line | str replace "Model:" "" | str trim)
    }
  }

  # Don't forget the last display
  if $current_display != null and $current_model != null {
    $displays = ($displays | append {display: $current_display model: $current_model})
  }

  $displays
}

# Detect all brightness control backends (supports multiple screens)
def detect-backends []: nothing -> list {
  mut backends = []

  # Detect DDC/CI displays
  let ddc_result = ddcutil detect | complete
  if $ddc_result.exit_code == 0 {
    let displays = parse-ddc-displays $ddc_result.stdout

    for display in $displays {
      $backends = (
        $backends | append {
          name: $"DDC/CI ($display.model)"
          type: "ddcci"
          display: $display.display
        }
      )
    }
  }

  # Detect KDE PowerManagement brightness control (for OLED panels etc.)
  # Check this BEFORE backlight since KDE handles the actual display on some systems
  let kde_result = qdbus org.kde.Solid.PowerManagement /org/kde/Solid/PowerManagement/Actions/BrightnessControl brightness | complete
  let has_kde = $kde_result.exit_code == 0
  if $has_kde {
    $backends = (
      $backends | append {
        name: "KDE PowerManagement"
        type: "kde"
      }
    )
  }

  # Detect backlight devices (skip if KDE is available - KDE handles the panel)
  if not $has_kde {
    let backlight_path = "/sys/class/backlight"
    if ($backlight_path | path exists) {
      let devices = ls $backlight_path | get name
      for device in $devices {
        $backends = (
          $backends | append {
            name: $"Backlight ($device | path basename)"
            type: "backlight"
            device: $device
          }
        )
      }
    }
  }

  if ($backends | length) == 0 {
    error make {msg: "No brightness control backend found"}
  }

  $backends
}

# Extract time from heliocron output line
def extract-time []: string -> any {
  let parsed = $in | parse "{label} is at: {rest}"
  let rest = $parsed | get rest.0
  # Split by spaces and filter out empty strings to handle extra whitespace
  let split = $rest | split row " " | where $it != ""
  $split | get 1 # First element is date, second is time
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

# Get current brightness (0.0-1.0) for a single backend
def get-brightness [backend: record] {
  if $backend.type == "ddcci" {
    let display_arg = if ($backend | get -o display) != null { $backend.display } else { 1 }
    let result = ddcutil getvcp 10 --display $display_arg | complete
    if $result.exit_code != 0 {
      return {normalized: 0.0 percent: 0 error: $"Failed to get brightness: ($result.stderr)"}
    }
    let percent = (
      $result.stdout
      | parse "VCP code {code} ({name}): current value = {value}, max value = {max}"
      | first
      | get value
      | str trim
      | into int
    )
    {normalized: ($percent / 100.0) percent: $percent}
  } else if $backend.type == "backlight" {
    let device_name = $backend.device | path basename
    let result = brightnessctl -d $device_name info | complete
    if $result.exit_code != 0 {
      return {normalized: 0.0 percent: 0 error: $"Failed to get brightness: ($result.stderr)"}
    }
    let parsed = $result.stdout | parse --regex "Current brightness: (\\d+) \\((\\d+)%\\)"
    let percent = $parsed | first | get capture1 | into int
    {normalized: ($percent / 100.0) percent: $percent}
  } else if $backend.type == "kde" {
    let result = qdbus org.kde.Solid.PowerManagement /org/kde/Solid/PowerManagement/Actions/BrightnessControl brightness | complete
    if $result.exit_code != 0 {
      return {normalized: 0.0 percent: 0 error: $"Failed to get KDE brightness: ($result.stderr)"}
    }
    let value = $result.stdout | str trim | into int
    let percent = ($value / 100) | into int
    {normalized: ($value / 10000.0) percent: $percent}
  } else {
    error make {msg: $"Unknown backend type: ($backend.type)"}
  }
}

# Get brightness for all backends
def get-all-brightness [backends: list] {
  $backends | each {|backend|
    let brightness = get-brightness $backend
    {backend: $backend brightness: $brightness}
  }
}

# Set brightness (0.0-1.0) for a single backend
def set-brightness [target: float backend: record] {
  if $backend.type == "ddcci" {
    let percent = ($target * 100 | math round | into int)
    let display_arg = if ($backend | get -o display) != null { $backend.display } else { 1 }
    # Use --noverify to skip verification read (much faster)
    let result = ddcutil setvcp 10 $percent --display $display_arg --noverify | complete
    if $result.exit_code != 0 {
      print $"<warning>DDC/CI set failed: ($result.stderr | str trim)"
    }
    $percent
  } else if $backend.type == "backlight" {
    let percent = ($target * 100 | math round | into int)
    let device_name = $backend.device | path basename
    let result = brightnessctl -d $device_name set $"($percent)%" | complete
    if $result.exit_code != 0 {
      print $"<warning>Backlight set failed: ($result.stderr | str trim)"
    }
    $percent
  } else {
    error make {msg: $"Unknown backend type: ($backend.type)"}
  }
}

# Set brightness for all backends
def set-all-brightness [target: float backends: list] {
  $backends | each {|backend|
    set-brightness $target $backend
  }
}

# Smoothly transition brightness for a single backend
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

  print $"<7>Transitioning ($backend.name) in ($steps) steps"

  1..$steps | each {|step|
    let new_level = ($current + $step_size * $step) | clamp 0.0 1.0
    set-brightness $new_level $backend | null
    if $step < $steps { sleep $step_delay }
  } | null

  set-brightness $target $backend | null
}

# Set brightness for all backends directly (no smooth transition)
def set-all-brightness-direct [backends_with_current: list target: float] {
  for item in $backends_with_current {
    print $"<7>Setting ($item.backend.name) to ($target | math round -p 2)"
    let percent = ($target * 100 | math round | into int)
    if $item.backend.type == "ddcci" {
      let display_arg = if ($item.backend | get -o display) != null { $item.backend.display } else { 1 }
      ddcutil setvcp 10 $percent --display $display_arg --noverify | complete | ignore
    } else if $item.backend.type == "backlight" {
      let device_name = $item.backend.device | path basename
      brightnessctl -d $device_name set $"($percent)%" | complete | ignore
    } else if $item.backend.type == "kde" {
      let kde_value = ($target * 10000 | math round | into int)
      qdbus org.kde.Solid.PowerManagement /org/kde/Solid/PowerManagement/Actions/BrightnessControl setBrightness $kde_value | complete | ignore
    }
  }
}

# Check if the timer is stopped (postponed)
def is-timer-stopped [] {
  let result = ^systemctl --user is-active $TIMER_NAME err> /dev/null | complete
  $result.stdout | str trim | $in != "active"
}

# Stop the timer to postpone adjustments
def stop-timer [] {
  let result = ^systemctl --user stop $TIMER_NAME | complete
  $result.exit_code == 0
}

# Start the timer to resume adjustments
def start-timer [] {
  let was_stopped = is-timer-stopped
  if $was_stopped {
    ^systemctl --user start $TIMER_NAME | complete | null
  }
  $was_stopped
}

# Run brightness adjustment based on solar position for all screens
def run-brightness-adjustment [config: record] {
  let solar_times = get-solar-times --latitude $config.location.latitude --longitude $config.location.longitude --twilight-type $config.twilight_type
  print $"<7>Solar: dawn=($solar_times.dawn), sunrise=($solar_times.sunrise), sunset=($solar_times.sunset), dusk=($solar_times.dusk)"

  let target = calculate-brightness $config.current_time $solar_times --min $config.brightness.min --max $config.brightness.max --offset $config.solar_offset

  # Get current brightness for all backends
  let backends_with_current = $config.backends | each {|backend|
    let brightness = get-brightness $backend
    print $"<7>($backend.name): current=($brightness.normalized | math round -p 2), target=($target | math round -p 2)"
    {backend: $backend current: $brightness.normalized}
  }

  # Check if any screen needs adjustment
  let needs_adjustment = $backends_with_current | any {|item|
    let diff = ($target - $item.current) | math abs
    $diff > 0.01
  }

  if $needs_adjustment {
    let screen_count = $backends_with_current | length
    print $"<6>Adjusting ($screen_count) screens to target ($target | math round -p 2)"
    set-all-brightness-direct $backends_with_current $target
    print $"<6>Adjustment complete for all screens"
  } else {
    print $"<7>All screens already at target level"
  }
}

# Get systemd service configuration details
def get-service-config [] {
  let service_status = (^systemctl --user show solar-brightness.service --property=ExecStart | complete)
  if $service_status.exit_code != 0 {
    return {latitude: null longitude: null next_update: null error: "Service not found"}
  }

  let exec_start = ($service_status.stdout | str trim)

  # Extract latitude and longitude from the service command
  let lat_match = ($exec_start | parse --regex "--latitude ([0-9.-]+)")
  let lon_match = ($exec_start | parse --regex "--longitude ([0-9.-]+)")

  let latitude = if ($lat_match | length) > 0 {
    $lat_match | get capture0 | first | into float
  } else {
    null
  }

  let longitude = if ($lon_match | length) > 0 {
    $lon_match | get capture0 | first | into float
  } else {
    null
  }

  # Get next timer trigger
  let timer_status = (^systemctl --user list-timers solar-brightness.timer --no-pager | complete)
  let next_trigger = if $timer_status.exit_code == 0 {
    let timer_lines = ($timer_status.stdout | lines | where $it != "" | skip 1)
    if ($timer_lines | length) > 0 {
      $timer_lines | first | str trim | split row " " | first
    } else {
      "No timer found"
    }
  } else {
    "Timer not found"
  }

  {
    latitude: $latitude
    longitude: $longitude
    next_update: $next_trigger
    error: null
  }
}

# Show information about solar brightness status
# Format brightness info for a single backend
def format-backend-brightness [backend: record target: float]: nothing -> string {
  let brightness = get-brightness $backend
  let diff = ($target - $brightness.normalized) | math abs
  $"  ($backend.name):
    Current: ($brightness.normalized | math round -p 3) \(($brightness.percent)%)
    Diff:    ($diff | math round -p 3) \(($diff * 100 | math round)%)"
}

# Build transitions section based on current time
def build-transitions-section [current_hour: float solar_times: record offset_hours: float]: nothing -> string {
  let dawn_hour = ($solar_times.dawn | time-to-hours) + $offset_hours
  let sunrise_hour = ($solar_times.sunrise | time-to-hours) + $offset_hours
  let sunset_hour = ($solar_times.sunset | time-to-hours) + $offset_hours
  let dusk_hour = ($solar_times.dusk | time-to-hours) + $offset_hours

  if $current_hour < $dawn_hour {
    $"  Next: Dawn transition starts at ($solar_times.dawn)"
  } else if $current_hour < $sunrise_hour {
    $"  Current: In dawn transition\n  Next: Sunrise at ($solar_times.sunrise)"
  } else if $current_hour < $sunset_hour {
    $"  Current: Daytime\n  Next: Sunset at ($solar_times.sunset)"
  } else if $current_hour < $dusk_hour {
    $"  Current: In dusk transition\n  Next: Night at ($solar_times.dusk)"
  } else {
    "  Current: Night\n  Next: Dawn tomorrow"
  }
}

# Show information about solar brightness status
def show-info [config: record] {
  let now = date now
  let current_time_str = $now | format date '%H:%M:%S'
  let service_config = get-service-config
  let is_stopped = is-timer-stopped

  let effective_lat = if $service_config.error == null and $service_config.latitude != null {
    $service_config.latitude
  } else {
    $config.location.latitude
  }

  let effective_lon = if $service_config.error == null and $service_config.longitude != null {
    $service_config.longitude
  } else {
    $config.location.longitude
  }

  let solar_times = get-solar-times --latitude $effective_lat --longitude $effective_lon --twilight-type $config.twilight_type
  let target = calculate-brightness $config.current_time $solar_times --min $config.brightness.min --max $config.brightness.max --offset $config.solar_offset

  # Build backends section
  let backends_info = $config.backends | each {|backend| format-backend-brightness $backend $target } | str join "\n"
  let backend_names = $config.backends | get name | str join ", "

  let location_section = if $service_config.error == null and $service_config.latitude != null {
    $"Location: ($service_config.latitude)°, ($service_config.longitude)°"
  } else {
    $"Location \(fallback): ($config.location.latitude)°, ($config.location.longitude)°"
  }

  let any_needs_adjustment = $config.backends | any {|backend|
    let brightness = get-brightness $backend
    let diff = ($target - $brightness.normalized) | math abs
    $diff > 0.01
  }

  let status = if $is_stopped {
    "Adjustments postponed (timer stopped)"
  } else if $any_needs_adjustment {
    "Brightness adjustment needed"
  } else { "All screens at target level" }

  let next_update = if $is_stopped {
    "Disabled (timer stopped)"
  } else if $service_config.next_update != null and $service_config.next_update != "Unknown" {
    $service_config.next_update
  } else { "Unknown (check timer status)" }

  let offset_hours = ($config.solar_offset / 1hr)
  let transitions = build-transitions-section $config.current_time $solar_times $offset_hours

  let postponed_note = if $is_stopped { "\nRun 'solar-brightness resume' to restart" } else { "" }

  print $"Solar Brightness Information
============================
Time: ($current_time_str) | ($location_section)
Backends: ($backend_names)

Solar Times: Dawn ($solar_times.dawn) | Sunrise ($solar_times.sunrise) | Sunset ($solar_times.sunset) | Dusk ($solar_times.dusk)
Target Brightness: ($target | math round -p 3) \(($target * 100 | math round)%)

Screen Brightness:($backends_info)

Status: ($status)
Next Update: ($next_update)
Transitions:($transitions)($postponed_note)"
}

# Build config record from common parameters
def build-config [
  --latitude (-a): float = 51.4769
  --longitude (-g): float = -0.0005
  --twilight-type (-t): string = "civil"
  --solar-offset (-o): duration = 0min
  --min-brightness (-m): float = 0.1
  --max-brightness (-M): float = 0.8
  --transition-max-step (-s): float = 0.05
  --transition-step-delay (-d): duration = 200ms
  --with-backends
] {
  let now = date now
  let time_str = $now | format date "%H:%M:%S"
  let current_time = $time_str | time-to-hours

  {
    backends: (if $with_backends { detect-backends } else { [] })
    current_time: $current_time
    location: {latitude: $latitude longitude: $longitude}
    twilight_type: $twilight_type
    brightness: {min: $min_brightness max: $max_brightness}
    solar_offset: $solar_offset
    transition: {max_step: $transition_max_step step_delay: $transition_step_delay}
  }
}

# Solar-based brightness manager
def main [] {
  print "Solar-based brightness manager"
  print "Use --help to see available subcommands"
}

# Adjust brightness based on solar position
def "main adjust" [
  --min-brightness (-m): float = 0.1
  --max-brightness (-M): float = 0.8
  --latitude (-a): float = 51.4769
  --longitude (-g): float = -0.0005
  --twilight-type (-t): string = "civil"
  --solar-offset (-o): duration = 0min
  --transition-max-step (-s): float = 0.05
  --transition-step-delay (-d): duration = 200ms
]: nothing -> any {
  let config = (
    build-config
    --with-backends
    --latitude $latitude
    --longitude $longitude
    --twilight-type $twilight_type
    --solar-offset $solar_offset
    --min-brightness $min_brightness
    --max-brightness $max_brightness
    --transition-max-step $transition_max_step
    --transition-step-delay $transition_step_delay
  )

  let now = date now
  let backend_names = $config.backends | get name | str join ", "
  print $"<6>Solar brightness manager: ($now | format date '%H:%M')"
  print $"<7>Backends: ($backend_names)"
  print $"<7>Config: min=($min_brightness), max=($max_brightness)"

  try {
    run-brightness-adjustment $config
  } catch {|err|
    print $"<3>Error: ($err.msg)"
    exit 1
  }
}

# Show current status and target brightness without adjusting
def "main info" [
  --min-brightness (-m): float = 0.1
  --max-brightness (-M): float = 0.8
  --latitude (-a): float = 51.4769
  --longitude (-g): float = -0.0005
  --twilight-type (-t): string = "civil"
  --solar-offset (-o): duration = 0min
] {
  let config = (
    build-config
    --with-backends
    --latitude $latitude
    --longitude $longitude
    --twilight-type $twilight_type
    --solar-offset $solar_offset
    --min-brightness $min_brightness
    --max-brightness $max_brightness
  )

  try {
    show-info $config
  } catch {|err|
    print $"Error: ($err.msg)"
    exit 1
  }
}

# Postpone adjustments by stopping the systemd timer
def "main postpone" [] {
  if (stop-timer) {
    print "Timer stopped - brightness adjustments postponed"
    print "Run 'solar-brightness resume' to restart and resume adjustments"
  } else {
    print "Failed to stop timer"
    exit 1
  }
}

# Clear postpone and immediately adjust brightness
def "main resume" [
  --min-brightness (-m): float = 0.1
  --max-brightness (-M): float = 0.8
  --latitude (-a): float = 51.4769
  --longitude (-g): float = -0.0005
  --twilight-type (-t): string = "civil"
  --solar-offset (-o): duration = 0min
  --transition-max-step (-s): float = 0.05
  --transition-step-delay (-d): duration = 200ms
] {
  if (start-timer) {
    print "Timer started, brightness adjustments resumed"

    let config = (
      build-config
      --with-backends
      --latitude $latitude
      --longitude $longitude
      --twilight-type $twilight_type
      --solar-offset $solar_offset
      --min-brightness $min_brightness
      --max-brightness $max_brightness
      --transition-max-step $transition_max_step
      --transition-step-delay $transition_step_delay
    )

    try {
      run-brightness-adjustment $config
    } catch {|err|
      print $"<3>Error during adjustment: ($err.msg)"
    }
  } else {
    print "Timer was already running"
  }
}

# Tests

def "main tests" [] {
  print "Running tests..."

  tests extract-time
  tests time-to-hours
  tests smooth-step
  tests get-twilight-lines-civil
  tests get-twilight-lines-nautical
  tests get-twilight-lines-astronomical
  tests get-twilight-lines-default
  tests calculate-brightness-night-before-dawn
  tests calculate-brightness-night-after-dusk
  tests calculate-brightness-dawn-transition
  tests calculate-brightness-daytime
  tests calculate-brightness-dusk-transition
  tests calculate-brightness-with-offset

  print "Tests completed successfully"
}

def "tests extract-time" [] {
  assert equal ("Sunrise is at: 2025-11-20 08:21:51 +01:00" | extract-time) "08:21:51"
  assert equal ("Civil dawn is at: 2025-11-20 07:44:37 +01:00" | extract-time) "07:44:37"
  assert equal ("Sunset is at: 2025-11-20 17:08:05 +01:00" | extract-time) "17:08:05"
}

def "tests time-to-hours" [] {
  assert equal ("00:00:00" | time-to-hours) 0.0
  assert equal ("12:00:00" | time-to-hours) 12.0

  let result = "06:30:00" | time-to-hours
  assert ((($result - 6.5) | math abs) < 0.001) "06:30 should be approximately 6.5 hours"

  let result = "18:15:00" | time-to-hours
  assert ((($result - 18.25) | math abs) < 0.001) "18:15 should be approximately 18.25 hours"
}

def "tests smooth-step" [] {
  assert equal (smooth-step 0.0) 0.0
  assert equal (smooth-step 1.0) 1.0
  let mid = smooth-step 0.5
  assert ($mid > 0.4 and $mid < 0.6)
}

def "tests get-twilight-lines-civil" [] {
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

def "tests get-twilight-lines-nautical" [] {
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

def "tests get-twilight-lines-astronomical" [] {
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

def "tests get-twilight-lines-default" [] {
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

def "tests calculate-brightness-night-before-dawn" [] {
  let times = {
    dawn: "07:00:00"
    sunrise: "08:00:00"
    sunset: "18:00:00"
    dusk: "19:00:00"
  }

  let brightness = calculate-brightness 6.0 $times --min 0.1 --max 0.8 --offset 0min
  assert equal $brightness 0.1
}

def "tests calculate-brightness-night-after-dusk" [] {
  let times = {
    dawn: "07:00:00"
    sunrise: "08:00:00"
    sunset: "18:00:00"
    dusk: "19:00:00"
  }

  let brightness = calculate-brightness 20.0 $times --min 0.1 --max 0.8 --offset 0min
  assert equal $brightness 0.1
}

def "tests calculate-brightness-dawn-transition" [] {
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

def "tests calculate-brightness-daytime" [] {
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

def "tests calculate-brightness-dusk-transition" [] {
  let times = {
    dawn: "07:00:00"
    sunrise: "08:00:00"
    sunset: "18:00:00"
    dusk: "19:00:00"
  }

  let brightness = calculate-brightness 18.0 $times --min 0.1 --max 0.8 --offset 0min
  assert ($brightness >= 0.1 and $brightness < 0.6) "Brightness at sunset should be between 0.1 and 0.6"

  let brightness = calculate-brightness 18.5 $times --min 0.1 --max 0.8 --offset 0min
  assert ($brightness >= 0.1 and $brightness < 0.4) "Brightness at mid-dusk should be between 0.1 and 0.4"
}

def "tests calculate-brightness-with-offset" [] {
  let times = {
    dawn: "07:00:00"
    sunrise: "08:00:00"
    sunset: "18:00:00"
    dusk: "19:00:00"
  }

  let brightness = calculate-brightness 6.5 $times --min 0.1 --max 0.8 --offset 30min
  assert ($brightness >= 0.1 and $brightness < 0.4)
}

#!/usr/bin/env nu

# Solar-based brightness manager
# Hardware-agnostic with automatic backend detection

use std assert

use std/math [ PI ]

use std/math

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
    } else if $line =~ "Model:" {
      $current_model = ($line | str replace "Model:" "" | str trim)
    }
  }

  # Don't forget the last display
  if $current_display != null and $current_model != null {
    $displays = ($displays | append {display: $current_display model: $current_model})
  }

  $displays
}

# Detect DDC/CI backends from ddcutil
def detect-ddcci-backends []: nothing -> list<record> {
  let result = ddcutil detect | complete
  if $result.exit_code != 0 {
    if ($result.stderr | str trim) != "" {
      error make {msg: $"<warning>ddcutil detect failed: ($result.stderr | str trim)"}
    }
    return []
  }

  parse-ddc-displays $result.stdout | each {|display|
    {name: $"DDC/CI ($display.model)" type: ddcci display: $display.display}
  }
}

# Detect KDE PowerManagement backend
def detect-kde-backend []: nothing -> list<record> {
  let result = qdbus org.kde.Solid.PowerManagement /org/kde/Solid/PowerManagement/Actions/BrightnessControl brightness | complete
  if $result.exit_code == 0 {
    [
      {name: "KDE PowerManagement" type: kde}
    ]
  } else {
    []
  }
}

# Detect backlight backends from sysfs
def detect-backlight-backends []: nothing -> list<record> {
  let backlight_path = "/sys/class/backlight"
  if not ($backlight_path | path exists) { return [] }

  ls $backlight_path | get name | each {|device|
    {name: $"Backlight ($device | path basename)" type: backlight device: $device}
  }
}

# Detect all brightness control backends (supports multiple screens)
def detect-backends []: nothing -> list<record> {
  let ddcci = detect-ddcci-backends
  let kde = detect-kde-backend
  # Skip backlight if KDE is available (KDE handles the panel directly)
  let backlight = if ($kde | is-empty) { detect-backlight-backends } else { [] }

  let backends = $ddcci | append $kde | append $backlight

  if ($backends | is-empty) {
    error make {
      msg: "No brightness control backend found"
      label: {text: "backend detection failed" span: (metadata $backends).span}
      help: "Ensure ddcutil, brightnessctl, or KDE PowerManagement is available"
    }
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
def get-twilight-lines [lines: list<string> twilight: string]: nothing -> record {
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
def get-solar-times [--latitude: float --longitude: float --twilight-type: string]: nothing -> record {
  let output = (heliocron --latitude $latitude --longitude $longitude report | complete)

  if $output.exit_code != 0 {
    error make {
      msg: $"Failed to get solar times: ($output.stderr)"
      label: {text: "heliocron command failed" span: (metadata $latitude).span}
      help: "Check that heliocron is installed and latitude/longitude are valid"
    }
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
def time-to-hours []: string -> float {
  let parts = $in | split row ":"
  let hours = $parts | first | into float
  let minutes = $parts | get 1 | into float
  $hours + ($minutes / 60.0)
}

# Calculate smooth transition progress using cosine interpolation
def smooth-step [progress: float]: nothing -> float {
  (1.0 - (($progress * $PI) | $math.cos)) / 2.0
}

# Calculate brightness based on solar position
def calculate-brightness [
  current: float
  times: record
  --min: float
  --max: float
  --offset: duration
]: nothing -> float {
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

# Brightness result record type helper
def brightness-error [msg: string]: nothing -> record {
  {
    normalized: 0.0
    percent: 0
    error: $msg
  }
}

# Get DDC/CI brightness
def get-ddcci-brightness [backend: record]: nothing -> record {
  let display_arg = $backend | get -o display | default 1
  let result = ddcutil getvcp 10 --display $display_arg | complete
  if $result.exit_code != 0 {
    return (brightness-error $"Failed to get DDC/CI brightness: ($result.stderr)")
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
}

# Get backlight brightness
def get-backlight-brightness [backend: record]: nothing -> record {
  let device_name = $backend.device | path basename
  let result = brightnessctl -d $device_name info | complete
  if $result.exit_code != 0 {
    return (brightness-error $"Failed to get backlight brightness: ($result.stderr)")
  }
  let parsed = $result.stdout | parse --regex "Current brightness: (\\d+) \\((\\d+)%\\)"
  let percent = $parsed | first | get capture1 | into int
  {normalized: ($percent / 100.0) percent: $percent}
}

# Get KDE PowerManagement brightness
def get-kde-brightness []: nothing -> record {
  let result = qdbus org.kde.Solid.PowerManagement /org/kde/Solid/PowerManagement/Actions/BrightnessControl brightness | complete
  if $result.exit_code != 0 {
    return (brightness-error $"Failed to get KDE brightness: ($result.stderr)")
  }
  let value = $result.stdout | str trim | into int
  let percent = ($value / 100) | into int
  {normalized: ($value / 10000.0) percent: $percent}
}

# Get current brightness (0.0-1.0) for a single backend
def get-brightness [backend: record]: nothing -> record {
  match $backend.type {
    "ddcci" => { get-ddcci-brightness $backend }
    "backlight" => { get-backlight-brightness $backend }
    "kde" => { get-kde-brightness }
    _ => {
      error make {
        msg: $"Unknown backend type: ($backend.type)"
        label: {text: "unsupported type" span: (metadata $backend).span}
        help: "Supported types: ddcci, backlight, kde"
      }
    }
  }
}

# Set brightness for all backends directly (no smooth transition)
def set-all-brightness-direct [backends_with_current: list target: float] {
  let percent = ($target * 100 | math round | into int)
  for item in $backends_with_current {
    print -e $"Setting ($item.backend.name) to ($target | math round -p 2)"
    match $item.backend.type {
      "ddcci" => {
        let display_arg = if ($item.backend | get -o display) != null { $item.backend.display } else { 1 }
        let ddc_result = ddcutil setvcp 10 $percent --display $display_arg --noverify | complete
        if $ddc_result.exit_code != 0 and ($ddc_result.stderr | str trim) != "" {
          print -e $"<warning>ddcutil setvcp failed for display ($display_arg): ($ddc_result.stderr | str trim)"
        }
      }
      "backlight" => {
        let device_name = $item.backend.device | path basename
        brightnessctl -d $device_name set $"($percent)%" | complete | null
      }
      "kde" => {
        let kde_value = ($target * 10000 | math round | into int)
        qdbus org.kde.Solid.PowerManagement /org/kde/Solid/PowerManagement/Actions/BrightnessControl setBrightness $kde_value | complete | null
      }
      _ => { }
    }
  }
}

# Check if the timer is stopped (postponed)
def is-timer-stopped []: nothing -> bool {
  let result = systemctl --user is-active $TIMER_NAME | complete
  $result.stdout | str trim | $in != "active"
}

# Stop the timer to postpone adjustments
def stop-timer []: nothing -> bool {
  let result = systemctl --user stop $TIMER_NAME | complete
  $result.exit_code == 0
}

# Start the timer to resume adjustments
def start-timer []: nothing -> bool {
  let was_stopped = is-timer-stopped
  if $was_stopped {
    systemctl --user start $TIMER_NAME | complete | null
  }
  $was_stopped
}

# Run brightness adjustment based on solar position for all screens
def run-brightness-adjustment [config: record] {
  let solar_times = get-solar-times --latitude $config.location.latitude --longitude $config.location.longitude --twilight-type $config.twilight_type
  print $"<debug>Solar: dawn=($solar_times.dawn), sunrise=($solar_times.sunrise), sunset=($solar_times.sunset), dusk=($solar_times.dusk)"

  let target = calculate-brightness $config.current_time $solar_times --min $config.brightness.min --max $config.brightness.max --offset $config.solar_offset

  # Get current brightness for all backends
  let backends_with_current = $config.backends | each {|backend|
      let brightness = get-brightness $backend
      print $"<debug>($backend.name): current=($brightness.normalized | math round -p 2), target=($target | math round -p 2)"
      {backend: $backend current: $brightness.normalized}
    }

  # Check if any screen needs adjustment
  let needs_adjustment = $backends_with_current | any {|item|
      let diff = ($target - $item.current) | math abs
      $diff > 0.01
    }

  if $needs_adjustment {
    let screen_count = $backends_with_current | length
    print $"<info>Adjusting ($screen_count) screens to target ($target | math round -p 2)"
    set-all-brightness-direct $backends_with_current $target
    print $"<info>Adjustment complete for all screens"
  } else {
    print $"<debug>All screens already at target level"
  }
}

# Get systemd service configuration details
# Parse latitude from service ExecStart string
def parse-service-latitude [exec_start: string]: nothing -> any {
  let match = $exec_start | parse --regex "--latitude ([0-9.-]+)"
  if ($match | is-not-empty) { $match | get capture0 | first | into float } else { null }
}

# Parse longitude from service ExecStart string
def parse-service-longitude [exec_start: string]: nothing -> any {
  let match = $exec_start | parse --regex "--longitude ([0-9.-]+)"
  if ($match | is-not-empty) { $match | get capture0 | first | into float } else { null }
}

# Get next timer trigger time
def get-next-timer-trigger []: nothing -> string {
  let result = systemctl --user list-timers solar-brightness.timer --no-pager | complete
  if $result.exit_code != 0 { return "Timer not found" }

  let timer_lines = $result.stdout | lines | where $it != "" | skip 1
  if ($timer_lines | is-empty) { return "No timer found" }
  $timer_lines | first | str trim | split row " " | first
}

# Get systemd service configuration details
def get-service-config []: nothing -> record {
  let result = systemctl --user show solar-brightness.service --property=ExecStart | complete
  if $result.exit_code != 0 {
    return {latitude: null longitude: null next_update: null error: "Service not found"}
  }

  let exec_start = $result.stdout | str trim
  {
    latitude: (parse-service-latitude $exec_start)
    longitude: (parse-service-longitude $exec_start)
    next_update: (get-next-timer-trigger)
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
def build-transitions-section [current_hour: float solar_times: record --offset-hours: float]: nothing -> string {
  let dawn_hour = ($solar_times.dawn | time-to-hours) + $offset_hours
  let sunrise_hour = ($solar_times.sunrise | time-to-hours) + $offset_hours
  let sunset_hour = ($solar_times.sunset | time-to-hours) + $offset_hours
  let dusk_hour = ($solar_times.dusk | time-to-hours) + $offset_hours

  if $current_hour < $dawn_hour {
    $"  Next: Dawn transition starts at ($solar_times.dawn)"
  } else if $current_hour < $sunrise_hour {
    $"  Current: In dawn transition\n  Next: Sunrise at ($solar_times.sunrise)"
  } else if $current_hour < $dusk_hour {
    $"  Current: Daytime\n  Next: Sunset at ($solar_times.sunset)"
  } else {
    "  Current: Night\n  Next: Dawn tomorrow"
  }
}

# Get effective location from service config or fallback
def get-effective-location [service_config: record fallback: record]: nothing -> record {
  let latitude = if $service_config.error == null and $service_config.latitude != null {
    $service_config.latitude
  } else {
    $fallback.latitude
  }
  let longitude = if $service_config.error == null and $service_config.longitude != null {
    $service_config.longitude
  } else {
    $fallback.longitude
  }
  {latitude: $latitude longitude: $longitude}
}

# Format location section for display
def format-location-section [service_config: record fallback: record]: nothing -> string {
  if $service_config.error == null and $service_config.latitude != null {
    $"Location: ($service_config.latitude)°, ($service_config.longitude)°"
  } else {
    $"Location \(fallback): ($fallback.latitude)°, ($fallback.longitude)°"
  }
}

# Determine adjustment status message
def get-adjustment-status [is_stopped: bool backends: list --target: float]: nothing -> string {
  if $is_stopped { return "Adjustments postponed (timer stopped)" }

  let any_needs_adjustment = $backends | any {|backend|
      let brightness = get-brightness $backend
      (($target - $brightness.normalized) | math abs) > 0.01
    }

  if $any_needs_adjustment { "Brightness adjustment needed" } else { "All screens at target level" }
}

# Show information about solar brightness status
def show-info [config: record] {
  let now = date now
  let service_config = get-service-config
  let is_stopped = is-timer-stopped

  let effective = get-effective-location $service_config $config.location
  let solar_times = get-solar-times --latitude $effective.latitude --longitude $effective.longitude --twilight-type $config.twilight_type
  let target = calculate-brightness $config.current_time $solar_times --min $config.brightness.min --max $config.brightness.max --offset $config.solar_offset

  let backends_info = $config.backends | each {|backend| format-backend-brightness $backend $target } | str join "\n"
  let status = get-adjustment-status $is_stopped $config.backends --target $target
  let next_update = if $is_stopped { "Disabled (timer stopped)" } else { $service_config.next_update | default "Unknown" }
  let transitions = build-transitions-section $config.current_time $solar_times --offset-hours ($config.solar_offset / 1hr)
  let postponed_note = if $is_stopped { "\nRun 'solar-brightness resume' to restart" } else { "" }

  let time_str = $now | format date '%H:%M:%S'
  let location_str = format-location-section $service_config $config.location
  let backend_names = $config.backends | get name | str join ", "
  let target_rounded = $target | math round -p 3
  let target_percent = $target * 100 | math round

  print $"<info>Solar Brightness Information
============================
Time: ($time_str) | ($location_str)
Backends: ($backend_names)

Solar Times: Dawn ($solar_times.dawn) | Sunrise ($solar_times.sunrise) | Sunset ($solar_times.sunset) | Dusk ($solar_times.dusk)
Target Brightness: ($target_rounded) \(($target_percent)%)

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
]: nothing -> record {
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
  print "<info>Solar-based brightness manager"
  print "<info>Use --help to see available subcommands"
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
  print -e $"Solar brightness manager: ($now | format date '%H:%M')"
  print -e $"Backends: ($backend_names)"
  print -e $"Config: min=($min_brightness), max=($max_brightness)"

  run-brightness-adjustment $config
}

# Show current status and target brightness without adjusting
def "main info" [
  --min-brightness (-m): float = 0.1
  --max-brightness (-M): float = 0.8
  --latitude (-a): float = 51.4769
  --longitude (-g): float = -0.0005
  --twilight-type (-t): string = "civil"
  --solar-offset (-o): duration = 0min
]: nothing -> nothing {
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

  show-info $config
}

# Postpone adjustments by stopping the systemd timer
def "main postpone" [] {
  if (stop-timer) {
    print "<info>Timer stopped - brightness adjustments postponed"
    print "<info>Run 'solar-brightness resume' to restart and resume adjustments"
  } else {
    error make {
      msg: "Failed to stop timer"
      label: {text: "timer stop failed" span: (metadata stop-timer).span}
      help: "Check systemctl --user status solar-brightness.timer"
    }
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
]: nothing -> nothing {
  if (start-timer) {
    print "<info>Timer started, brightness adjustments resumed"

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
      run-brightness-adjustment $config | null
    } catch {|err|
      print $"<err>Error during adjustment: ($err.msg)"
    }
  } else {
    print "<info>Timer was already running"
  }
}

# Tests

def "main tests" [] {
  print "<info>Running tests..."

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

  print "<info>Tests completed successfully"
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

#!/usr/bin/env nu

# Dell U4323QE Solar-based Brightness Manager
# Automatically adjusts screen brightness based on natural light cycles

# Get solar times from heliocron
def get_solar_times [
  latitude: float
  longitude: float
  twilight_type: string
] {
  let heliocron_result = (
    ^heliocron
    --latitude $latitude
    --longitude $longitude
    report
    | complete
  )

  if $heliocron_result.exit_code != 0 {
    error make {msg: $"Failed to get solar times: ($heliocron_result.stderr)"}
  }

  # Parse heliocron output to extract times
  let lines = ($heliocron_result.stdout | lines)

  # Extract the times we need based on twilight type
  let sunrise_line = ($lines | where {|line| $line | str contains "Sunrise is at:" } | first)
  let sunset_line = ($lines | where {|line| $line | str contains "Sunset is at:" } | first)
  let solar_noon_line = ($lines | where {|line| $line | str contains "Solar noon is at:" } | first)

  # Extract dawn/dusk times based on twilight type
  let dawn_dusk_lines = match $twilight_type {
    "civil" => {
      dawn: ($lines | where {|line| $line | str contains "Civil dawn is at:" } | first)
      dusk: ($lines | where {|line| $line | str contains "Civil dusk is at:" } | first)
    }
    "nautical" => {
      dawn: ($lines | where {|line| $line | str contains "Nautical dawn is at:" } | first)
      dusk: ($lines | where {|line| $line | str contains "Nautical dusk is at:" } | first)
    }
    "astronomical" => {
      dawn: ($lines | where {|line| $line | str contains "Astronomical dawn is at:" } | first)
      dusk: ($lines | where {|line| $line | str contains "Astronomical dusk is at:" } | first)
    }
    _ => {
      dawn: $sunrise_line
      dusk: $sunset_line
    }
  }

  # Helper function to extract time from heliocron output line
  def extract_time_from_line [line: string] {
    # Extract the time part - format is like "Sunrise is at:            2025-11-12 08:13:18 +01:00"
    # Use regex to find the time pattern HH:MM:SS
    let parsed = ($line | parse -r '.+(\d{2}:\d{2}:\d{2}).+')
    if ($parsed | length) == 0 {
      error make {msg: $"Could not parse time from line: ($line)"}
    }
    ($parsed | first | get capture0)
  }

  {
    dawn: (extract_time_from_line $dawn_dusk_lines.dawn)
    sunrise: (extract_time_from_line $sunrise_line)
    solar_noon: (extract_time_from_line $solar_noon_line)
    sunset: (extract_time_from_line $sunset_line)
    dusk: (extract_time_from_line $dawn_dusk_lines.dusk)
  }
}

# Convert time string to hours since midnight (decimal)
def time_to_hours [time_str: string] {
  let parts = ($time_str | split row ":")
  let hour = ($parts.0 | into float)
  let minute = ($parts.1 | into float)
  # Ignore seconds for simplicity
  $hour + ($minute / 60.0)
}

# Calculate brightness based on solar position
def calculate_solar_brightness [
  current_time: float
  solar_times: record
  min_brightness: float
  max_brightness: float
  solar_offset: int
] {
  # Convert solar times to hours with offset applied
  let offset_hours = ($solar_offset / 60.0)
  let dawn_hours = (time_to_hours $solar_times.dawn) + $offset_hours
  let sunrise_hours = (time_to_hours $solar_times.sunrise) + $offset_hours
  let solar_noon_hours = (time_to_hours $solar_times.solar_noon) + $offset_hours
  let sunset_hours = (time_to_hours $solar_times.sunset) + $offset_hours
  let dusk_hours = (time_to_hours $solar_times.dusk) + $offset_hours

  let brightness_range = $max_brightness - $min_brightness

  # Calculate brightness based on current solar phase
  if $current_time < $dawn_hours or $current_time > $dusk_hours {
    # Night time - use minimum brightness
    $min_brightness
  } else if $current_time >= $dawn_hours and $current_time < $sunrise_hours {
    # Dawn transition - gradual increase
    let transition_progress = ($current_time - $dawn_hours) / ($sunrise_hours - $dawn_hours)
    let cos_value = (($transition_progress * 3.14159265359) | math cos)
    let smooth_progress = (1.0 - $cos_value) / 2.0
    $min_brightness + ($brightness_range * 0.3 * $smooth_progress)
  } else if $current_time >= $sunrise_hours and $current_time <= $sunset_hours {
    # Daylight hours - brightness follows sun elevation
    let day_length = $sunset_hours - $sunrise_hours
    let time_since_sunrise = $current_time - $sunrise_hours

    # Peak at solar noon, use sine curve for natural light progression
    let sun_angle = ($time_since_sunrise / $day_length) * 3.14159265359
    let sun_elevation = ($sun_angle | math sin)

    # Scale to full brightness range during daylight
    $min_brightness + ($brightness_range * $sun_elevation)
  } else if $current_time >= $sunset_hours and $current_time <= $dusk_hours {
    # Dusk transition - gradual decrease
    let transition_progress = ($current_time - $sunset_hours) / ($dusk_hours - $sunset_hours)
    let cos_value = (($transition_progress * 3.14159265359) | math cos)
    let smooth_progress = ($cos_value + 1.0) / 2.0
    $min_brightness + ($brightness_range * 0.3 * $smooth_progress)
  } else {
    # Fallback to minimum brightness
    $min_brightness
  }
}

def get_current_brightness [] {
  let result = (^ddcutil getvcp 10 | complete)
  if $result.exit_code != 0 {
    error make {msg: $"Failed to get current brightness: ($result.stderr)"}
  }

  let brightness_percent = (
    $result.stdout
    | lines
    | first
    | split column "current value ="
    | get column2.0
    | split column ","
    | get column1.0
    | str trim
    | into int
  )

  {
    percent: $brightness_percent
    normalized: ($brightness_percent / 100.0)
  }
}

def set_brightness [target_brightness: float] {
  let target_percent = ($target_brightness * 100 | math round)
  let result = (^ddcutil setvcp 10 $target_percent | complete)

  if $result.exit_code != 0 {
    error make {msg: $"Failed to set brightness: ($result.stderr)"}
  }

  $target_percent
}

def main [
  --min-brightness (-m): float = 0.1 # Minimum brightness level (0.0-1.0)
  --max-brightness (-M): float = 0.8 # Maximum brightness level (0.0-1.0)
  --latitude (-a): float = 51.4769 # Latitude in decimal degrees (positive = north)
  --longitude (-g): float = -0.0005 # Longitude in decimal degrees (positive = east)
  --twilight-type (-t): string = "civil" # Twilight calculation type
  --solar-offset (-o): int = 0 # Offset in minutes for solar calculations
] {
  let current_time = (date now | format date "%H.%M" | into float)
  let current_hour = (date now | format date "%H" | into int)
  let current_minute = (date now | format date "%M" | into int)

  print $"<6>Dell solar brightness manager: Current time is ($current_hour):($current_minute)"
  print $"<7>Configuration: min=($min_brightness), max=($max_brightness), location=($latitude),($longitude), twilight=($twilight_type), offset=($solar_offset)min"

  # Get solar times for today
  try {
    let solar_times = (get_solar_times $latitude $longitude $twilight_type)
    print $"<7>Solar times: dawn=($solar_times.dawn), sunrise=($solar_times.sunrise), noon=($solar_times.solar_noon), sunset=($solar_times.sunset), dusk=($solar_times.dusk)"

    # Calculate target brightness based on solar position
    let target_brightness = (calculate_solar_brightness $current_time $solar_times $min_brightness $max_brightness $solar_offset)
    print $"<7>Calculated solar brightness: ($target_brightness)"

    # Get current brightness and adjust if needed
    try {
      let current = (get_current_brightness)
      print $"<7>Current brightness: ($current.normalized) [($current.percent)%]"

      # Only adjust if difference is significant (avoid unnecessary changes)
      let target_percent = ($target_brightness * 100 | math round)
      let brightness_diff = (($target_brightness - $current.normalized) | math abs)

      if $brightness_diff > 0.01 {
        # Only change if difference > 1%
        print $"<6>Adjusting brightness from ($current.normalized) to ($target_brightness)"

        try {
          let new_percent = (set_brightness $target_brightness)
          print $"<6>Successfully set brightness to ($target_brightness) [($new_percent)%]"
        } catch {
          print $"<3>Error: Failed to set brightness: ($in)"
          exit 1
        }
      } else {
        print $"<7>Brightness already at target level ($target_brightness) [($target_percent)%]"
      }
    } catch {
      print $"<3>Error: Failed to get current brightness: ($in)"
      exit 1
    }
  } catch {
    print $"<3>Error: Failed to get solar times: ($in)"
    exit 1
  }
}

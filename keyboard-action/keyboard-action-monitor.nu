#!/usr/bin/env nu

# Keyboard Action Monitor
# Monitors keyboard events and triggers actions on specific key combinations
#
# Usage: keyboard-action-monitor.nu <trigger-key> [<modifier1> <modifier2> ...] --action <command> [--description <desc>]
# Example: keyboard-action-monitor.nu "KEY_F23" "KEY_LEFTMETA" "KEY_LEFTSHIFT" --action "kitty" --description "Copilot Button"

# Check if a device has extensive keyboard capabilities
def is-keyboard-device [event_path: string]: nothing -> bool {
  let event_name = $event_path | path basename
  let cap_path = $"/sys/class/input/($event_name)/device/capabilities/key"

  if not ($cap_path | path exists) {
    return false
  }

  let capabilities = open $cap_path | lines | first | str trim
  let hex_values = $capabilities | split row ' '
    | where $it != ''
    | each {|hex| '0x' + $hex }

  # Count total bits set across all hex values
  # A real keyboard has many keys (100+), so we expect many bits set
  let total_bits = $hex_values
    | each {|hex_str|
        try {
          # Count bits in the hex value
          let num = $hex_str | into int
          mut count = 0
          mut n = $num
          while $n > 0 {
            $count = $count + ($n mod 2)
            $n = ($n // 2)
          }
          $count
        } catch { 0 }
      }
    | math sum

  # Keyboards typically have 100+ keys, so require at least 50 capability bits
  $total_bits > 50
}

# Find the first keyboard device
def find-keyboard [] {
  let event_devices = ls /dev/input/event* | get name

  let keyboards = $event_devices
    | where {|device| is-keyboard-device $device }
    | each {|device|
        let event_name = $device | path basename
        let device_name_path = $"/sys/class/input/($event_name)/device/name"
        if ($device_name_path | path exists) {
          let device_name = open $device_name_path | str trim
          {path: $device, name: $device_name}
        } else {
          null
        }
      }
    | compact

  if ($keyboards | is-empty) {
    error make {
      msg: "No keyboard device found"
      help: "Ensure a keyboard is connected and has proper permissions"
      url: "https://www.kernel.org/doc/html/latest/input/input.html"
    }
  } else {
    let keyboard = $keyboards | first
    print $"<6>Found keyboard: ($keyboard.name) at ($keyboard.path)"
    $keyboard.path
  }
}

# Normalize a key name to Linux event format (add KEY_ prefix if missing, uppercase)
def normalize-key-name []: string -> string {
  let key = $in | str upcase
  if ($key | str starts-with "KEY_") {
    $key
  } else {
    $"KEY_($key)"
  }
}

# Derive a short name from a Linux event name
def derive-key-name []: string -> string {
  str replace "KEY_" "" | str downcase
}

# Parse key spec: either "name:EVENT_NAME" or just "EVENT_NAME"
def parse-key [spec: string]: nothing -> record<name: string, event: string> {
  let parts = $spec | split row ":"
  if ($parts | length) == 1 {
    {name: ($parts.0 | derive-key-name) event: $parts.0}
  } else {
    {name: $parts.0 event: $parts.1}
  }
}

# Check if line contains a key event with specific value
def has-key-event [event: string value: string]: string -> bool {
  let line = $in
  ($line | str contains $event) and ($line | str contains $"value ($value)")
}

# Update modifier state based on keyboard event
def update-modifier-state [
  line: string
  --mod: record<name: string, event: string>
  --pressed: record
]: nothing -> record {
  if ($line | str contains $mod.event) {
    if ($line | has-key-event $mod.event "1") {
      print $"<7>($mod.name) pressed"
      $pressed | update $mod.name true
    } else if ($line | has-key-event $mod.event "0") {
      print $"<7>($mod.name) released"
      $pressed | update $mod.name false
    } else {
      $pressed
    }
  } else {
    $pressed
  }
}

# Execute action when trigger detected
def execute-action [action: string desc: string]: nothing -> nothing {
  if ($action | is-empty) {
    print $"<4>($desc) detected - no action configured"
  } else {
    print $"<5>($desc) detected - executing: ($action)"
    systemd-run --user --no-block --collect nu --login -c $action
  }
}

# Main entry point
def main [
  trigger: string # Trigger key event name (e.g., KEY_F23)
  ...modifiers: string # Modifier key event names (e.g., KEY_LEFTMETA)
  --action (-a): string # Command to execute (required)
  --description (-d): string # Human-readable key combination description
] {
  let keyboard = find-keyboard
  let normalized_trigger = $trigger | normalize-key-name
  let mods = $modifiers | each {|m| parse-key ($m | normalize-key-name) }
  let desc = $description | default $"($normalized_trigger) combo"

  print $"<6>Monitoring ($keyboard) for ($desc)
<6>Trigger: ($normalized_trigger) 
<6>Modifiers: ($mods | each {|m| $m.name } | str join ', ')"

  # Track pressed state for each modifier
  mut pressed = ($mods | reduce -f {} {|mod acc| $acc | insert $mod.name false })

  # Process keyboard events
  for line in (evtest $keyboard | lines) {
    # Debug: show key events
    if ($line | str contains "EV_KEY") {
      print $"<7>Event: ($line)"
    }

    # Update modifier states
    for mod in $mods {
      $pressed = (update-modifier-state $line --mod $mod --pressed $pressed)
    }

    # Check for trigger key release
    if ($line | has-key-event $normalized_trigger "0") {
      print $"<6>Trigger released. Modifier states: ($pressed)"
      let all_mods_pressed = $pressed | values | all {|v| $v }
      if $all_mods_pressed {
        if $action == null {
          print "No action configured"
        } else {

          execute-action $action $desc
        }
      } else {
        print $"<6>Not all modifiers pressed"
      }
    }
  }
}

#!/usr/bin/env nu

# Keyboard Action Monitor
# Monitors keyboard events and triggers actions on specific key combinations
#
# Usage: keyboard-action-monitor.nu <trigger-key> [<modifier1> <modifier2> ...] --action <command> [--description <desc>]
# Example: keyboard-action-monitor.nu "KEY_F23" "meta:KEY_LEFTMETA:125" "shift:KEY_LEFTSHIFT:42" --action "kitty" --description "Copilot Button"

# Find the first keyboard device
def find-keyboard [] {
  let devices = ls /dev/input/by-path/ | where name =~ "kbd"
  if ($devices | is-empty) {
    error make {msg: "No keyboard device found"}
  }
  $devices | get name | first
}

# Parse key spec: "name:EVENT_NAME:code" -> {name, event, code}
def parse-key [spec: string] {
  let parts = $spec | split row ":"
  {name: $parts.0 event: $parts.1 code: ($parts.2 | into int)}
}

# Check if line contains a key event with specific value
def has-key-event [event: string value: string] {
  let line = $in
  ($line | str contains $event) and ($line | str contains $"value ($value)")
}

# Main entry point
def main [
  trigger: string # Trigger key event name (e.g., KEY_F23)
  ...modifiers: string # Modifier key specs (name:EVENT:code)
  --action (-a): string # Command to execute (required)
  --description (-d): string # Human-readable key combination description
] {
  let keyboard = find-keyboard
  let mods = $modifiers | each {|m| parse-key $m }
  let desc = $description | default $"($trigger) combo"

  print $"<6>Monitoring ($keyboard) for ($desc)"
  print $"<6>Trigger: ($trigger) | Action: ($action)"
  print $"<6>Modifiers: ($mods | each {|m| $m.name } | str join ', ')"

  # Track pressed state for each modifier
  mut pressed = ($mods | reduce -f {} {|mod acc| $acc | insert $mod.name false })

  # Process keyboard events
  for line in (^evtest $keyboard err> /dev/null | lines) {
    # Update modifier states
    for mod in $mods {
      if ($line | str contains $mod.event) {
        if ($line | has-key-event $mod.event "1") {
          $pressed = ($pressed | update $mod.name true)
          print $"<7>($mod.name) pressed"
        } else if ($line | has-key-event $mod.event "0") {
          $pressed = ($pressed | update $mod.name false)
          print $"<7>($mod.name) released"
        }
      }
    }

    # Check for trigger key release
    if ($line | has-key-event $trigger "0") {
      let all_mods_pressed = $pressed | values | all {|v| $v }

      if $all_mods_pressed {
        print $"<5>($desc) detected - executing action"

        # Launch app in background using systemd-run without blocking
        # Using a transient service (not scope) allows fire-and-forget behavior
        # The --no-block ensures we don't wait for the app to exit
        ^systemd-run --user --no-block --collect $action
      }
    }
  }
}

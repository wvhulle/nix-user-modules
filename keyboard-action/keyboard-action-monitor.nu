#!/usr/bin/env nu

# Keyboard Action Monitor
# Generic keyboard event monitor that triggers actions on specific key combinations
#
# Usage: keyboard-action-monitor.nu <key-description> <trigger-key-event> <action-command> <modifier1> [<modifier2> ...]
# Example: keyboard-action-monitor.nu "Meta+Shift+F23" "KEY_F23" "kitty" "meta:KEY_LEFTMETA:125" "shift:KEY_LEFTSHIFT:42"

# Find the keyboard device
def find-keyboard-device []: nothing -> string {
  let devices = (ls /dev/input/by-path/ | where name =~ "kbd")
  if ($devices | is-empty) {
    error make {
      msg: "No keyboard device found"
      label: {
        text: "No keyboard found in /dev/input/by-path/"
        span: (metadata $devices).span
      }
      help: "Ensure the keyboard is connected and accessible"
    }
  }
  $devices | get name | first
}

# Parse a key specification string like "meta:KEY_LEFTMETA:125"
def parse-key-spec [spec: string]: nothing -> record {
  let parts = ($spec | split row ":")
  {
    name: ($parts | get 0)
    event: ($parts | get 1)
    code: ($parts | get 2 | into int)
  }
}

# Main monitoring loop
def main [
  key_description: string
  trigger_key_event: string
  action_command: string
  ...modifiers: string
]: nothing -> nothing {
  let keyboard_device = (find-keyboard-device)
  print $"<6>Monitoring ($keyboard_device) for ($key_description)..."
  print $"<6>Trigger key: ($trigger_key_event)"
  print $"<6>Action command: ($action_command)"

  # Parse modifier specifications
  let modifier_keys = ($modifiers | each {|spec| parse-key-spec $spec })
  print $"<6>Modifier keys: ($modifier_keys | to json)"

  # Initialize state for each modifier
  mut key_states = (
    $modifier_keys | reduce -f {} {|key acc|
      $acc | insert $key.name false
    }
  )
  print $"<6>Initialized key states: ($key_states | to json)"

  print "<6>Event loop started, waiting for key events..."
  mut event_count = 0

  # Stream events from evtest directly (don't use complete, it waits for EOF)
  for line in (^evtest $keyboard_device | lines) {
    $event_count = $event_count + 1

    # Debug: Show every keyboard event
    if ($line | str contains "EV_KEY") {
      print $"<7>DEBUG: Event #($event_count): ($line)"
    }

    # Update modifier key states
    for key in $modifier_keys {
      if ($line | str contains $key.event) {
        if ($line | str contains "value 1") {
          print $"<6>DEBUG: Modifier ($key.name) pressed"
          $key_states = ($key_states | update $key.name true)
        } else if ($line | str contains "value 0") {
          print $"<6>DEBUG: Modifier ($key.name) released"
          $key_states = ($key_states | update $key.name false)
        }
        print $"<7>DEBUG: Current key states: ($key_states | to json)"
      }
    }

    # Check for trigger key release with all modifiers pressed
    if ($line | str contains $trigger_key_event) {
      print $"<6>DEBUG: Trigger key ($trigger_key_event) event detected"
      print $"<7>DEBUG: Line content: ($line)"

      if ($line | str contains "value 0") {
        print $"<6>DEBUG: Trigger key released, checking modifier states..."
        print $"<7>DEBUG: Key states at trigger: ($key_states | to json)"

        let all_pressed = ($key_states | values | all {|v| $v })
        print $"<6>DEBUG: All modifiers pressed? ($all_pressed)"

        if $all_pressed {
          print $"<5>SUCCESS: ($key_description) detected! Running action..."
          print $"<6>DEBUG: Executing: systemd-run --user --scope ($action_command)"
          let run_result = (^systemd-run --user --scope $action_command | complete)
          if $run_result.exit_code == 0 {
            print $"<6>DEBUG: Action executed successfully"
            print $"<7>DEBUG: Output: ($run_result.stdout)"
          } else {
            print $"<3>ERROR: Action failed with exit code ($run_result.exit_code)"
            print $"<3>ERROR: STDERR: ($run_result.stderr)"
          }
        } else {
          print "<7>DEBUG: Not all modifiers pressed, ignoring trigger"
        }
      } else if ($line | str contains "value 1") {
        print "<7>DEBUG: Trigger key pressed, waiting for release"
      }
    }
  }

  print "<3>ERROR: Event loop ended unexpectedly"
}

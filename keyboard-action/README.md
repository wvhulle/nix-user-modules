# Keyboard Action Module

A generalized NixOS user module for binding custom actions to keyboard shortcuts at the input event level.

## Overview

This module monitors keyboard events directly via `evtest` and triggers custom commands when specific key combinations are pressed. It works independently of desktop environment shortcuts and is particularly useful for:

- Hardware keys that don't work properly with desktop shortcuts (e.g., Copilot button)
- Custom keyboard combinations that need low-level handling
- Machine-specific key bindings

## Features

- **Desktop Environment Independent**: Works with any DE or window manager
- **Low-level Event Monitoring**: Uses `evtest` to capture keyboard events directly
- **Systemd Integration**: Runs as user services with automatic restart
- **Multiple Actions**: Configure multiple keyboard shortcuts per machine
- **Nushell Implementation**: Clean, maintainable Nushell scripts

## Prerequisites

**IMPORTANT**: Users must be members of the `input` group to access `/dev/input` devices.

Since this is a home-manager module, it cannot modify system-level group memberships. You must add users to the `input` group in your NixOS system configuration:

```nix
# In your machine-specific or system configuration:
users.users.youruser.extraGroups = [ "input" ];
```

After adding the group, you must **log out and log back in** for the group membership to take effect.

## Usage

### Basic Configuration

```nix
{
  programs.keyboard-action = {
    enable = true;
    
    actions = {
      my-shortcut = {
        keyDescription = "Super+Alt+T";
        
        keys = [
          {
            name = "super";
            eventName = "KEY_LEFTMETA";
            code = 125;
          }
          {
            name = "alt";
            eventName = "KEY_LEFTALT";
            code = 56;
          }
          {
            name = "t";
            eventName = "KEY_T";
            code = 20;
          }
        ];
        
        triggerKey = {
          name = "t";
          eventName = "KEY_T";
        };
        
        action = "${pkgs.kitty}/bin/kitty";
      };
    };
  };
}
```

### Finding Key Codes

Use `evtest` to find the event names and codes for your keys:

```bash
sudo evtest /dev/input/by-path/*kbd
# Press the key you want to use
# Look for lines like: "Event: ... EV_KEY, code 20 (KEY_T), value 1"
```

The output shows:

- `KEY_T` - this is the `eventName`
- `20` - this is the `code`

### Configuration Options

#### `programs.keyboard-action.enable`

Enable the keyboard action monitoring module.

#### `programs.keyboard-action.actions.<name>`

Define a keyboard action. Each action has:

- **`keyDescription`** (string): Human-readable description of the key combination
- **`keys`** (list): All keys involved (modifiers + trigger)
  - **`name`**: Variable name for the key (lowercase, unique)
  - **`eventName`**: Linux input event name (e.g., `KEY_LEFTMETA`)
  - **`code`**: Linux input event code (integer)
- **`triggerKey`**: The key whose release triggers the action
  - **`name`**: Must match one of the keys from the `keys` list
  - **`eventName`**: Linux event name for verification
- **`action`** (string): Command to execute when the combination is pressed

## Examples

### Machine-Specific Copilot Button

See `machines/x1/copilot-button.nix` for a complete example of binding the ThinkPad Copilot button.

### Media Keys

```nix
{
  programs.keyboard-action = {
    enable = true;
    actions = {
      calculator = {
        keyDescription = "Calculator Key";
        keys = [{
          name = "calc";
          eventName = "KEY_CALC";
          code = 140;
        }];
        triggerKey = {
          name = "calc";
          eventName = "KEY_CALC";
        };
        action = "${pkgs.gnome-calculator}/bin/gnome-calculator";
      };
    };
  };
}
```

## Implementation Details

### Architecture

1. **Base Monitor Script** (`keyboard-action-monitor.nu`): Generic Nushell script that monitors keyboard events
2. **Wrapper Scripts**: Per-action shell scripts that call the monitor with specific parameters
3. **Systemd Services**: User services that run the wrapper scripts

### How It Works

1. The module generates a systemd user service for each configured action
2. Each service runs a Nushell script that monitors keyboard input events
3. The script tracks the state of all modifier keys
4. When the trigger key is released and all required modifiers are pressed, the action is executed via `systemd-run --user --scope`

### Permissions

The user must be in the `input` group to read keyboard events without root:

```nix
users.users.<username>.extraGroups = [ "input" ];
```

## Troubleshooting

### Service Status

Check if the service is running:

```bash
systemctl --user --no-pager status keyboard-action-*
```

### Monitor Events

Test if keys are detected:

```bash
journalctl --user --no-pager -f -u keyboard-action-copilot-button
```

### Test Keyboard Device

Verify keyboard events are being captured:

```bash
sudo evtest /dev/input/by-path/*kbd
```

## Comparison with Other Solutions

### vs. KDE Custom Shortcuts (khotkeys)

- **khotkeys**: Deprecated in Plasma 6, GUI configuration only
- **keyboard-action**: Works in Plasma 6, declarative configuration, no DE dependency

### vs. keyd

- **keyd**: System-wide daemon, can cause issues with GUI apps
- **keyboard-action**: User-level, integrates with systemd user session

### vs. xbindkeys

- **xbindkeys**: X11 only, configuration file syntax
- **keyboard-action**: Works on Wayland and X11, Nix configuration

## Related Modules

- `user-modules/nushell-extended.nix` - Nushell configuration
- `system-config/users/*/` - User-specific imports

## Files

- `default.nix` - Module definition and systemd service generation
- `keyboard-action-monitor.nu` - Core Nushell monitoring script
- `README.md` - This file

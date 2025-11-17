# Solar Brightness Module

Hardware-agnostic solar-based automatic brightness control for NixOS.

## Overview

This module automatically adjusts screen brightness based on solar position and natural light cycles. It supports multiple hardware backends, auto-detects the appropriate control method, and provides smooth brightness transitions.

## Features

- **Hardware Agnostic**: Works with external monitors (DDC/CI) and laptop screens (backlight)
- **Auto-Detection**: Automatically detects available brightness control methods
- **Plugin Architecture**: Easy to extend with new backends
- **Solar Calculations**: Uses heliocron for accurate sunrise/sunset times
- **Smooth Transitions**: Gradual brightness changes to avoid abrupt adjustments
- **Configurable**: Adjust brightness ranges, update intervals, twilight types, and transition smoothness
- **Location-Aware**: Configure your geographic location for accurate solar times

## Supported Backends

### DDC/CI (External Monitors)

- Supports external monitors via DDC/CI protocol
- Requires i2c kernel modules and ddcutil
- System-level setup handled automatically

### Backlight (Laptop Screens)

- Supports laptop screens via sysfs backlight interface
- Works with `/sys/class/backlight/*` devices
- Requires appropriate udev rules for permissions

## Usage

```nix
{
  programs.solar-brightness = {
    enable = true;
    backend = "auto"; # or "ddcci", "backlight"
    interval = "*:0/15"; # Check every 15 minutes
    min-brightness = 0.05;
    max-brightness = 0.85;
    location = {
      latitude = 50.8476;
      longitude = 4.3572;
    };
    twilight-type = "civil";
    solar-offset = 0;
    transition = {
      max-step = 0.05; # 5% per step
      step-delay = 200; # 200ms between steps
    };
  };
}
```

## Configuration Options

- `enable`: Enable solar brightness control
- `backend`: Backend to use ("auto", "ddcci", "backlight")
- `interval`: systemd calendar interval for brightness checks
- `min-brightness`: Minimum brightness level (0.0-1.0)
- `max-brightness`: Maximum brightness level (0.0-1.0)
- `location.latitude`: Latitude in decimal degrees (positive = north)
- `location.longitude`: Longitude in decimal degrees (positive = east)
- `twilight-type`: Type of twilight ("civil", "nautical", "astronomical", "daylight")
- `solar-offset`: Offset in minutes to adjust solar calculations
- `transition.max-step`: Maximum brightness change per step (default 0.05 = 5%)
- `transition.step-delay`: Delay in milliseconds between transition steps (default 200ms)

## Architecture

### Files

- `default.nix`: Main module definition with configuration options
- `backends.nix`: Backend definitions and auto-detection logic
- `solar-brightness-manager.nu`: Complete standalone script with all functionality

The script includes:

- Solar time calculations using heliocron
- Brightness calculation algorithms based on time of day
- Hardware backend integration
- Smooth brightness transitions

### How It Works

1. Module loads backend definitions from `backends.nix`
2. Auto-detects available backend or uses specified one
3. Creates systemd user service and timer
4. Service runs periodically to:
   - Get current solar times based on location
   - Calculate target brightness based on time of day
   - Smoothly transition brightness if different from target

### Smooth Transitions

Instead of instantly changing brightness, the module transitions gradually:

- Calculates the difference between current and target brightness
- Divides the change into small steps (configurable via `transition.max-step`)
- Applies each step with a delay (configurable via `transition.step-delay`)
- This creates a smooth, natural-feeling brightness adjustment

## Migration from dell-brightness

The old `dell-brightness` module has been refactored into `solar-brightness`:

```nix
# Old
programs.dell-brightness = {
  enable = true;
  # ... options
};

# New
programs.solar-brightness = {
  enable = true;
  backend = "ddcci"; # Specify DDC/CI for Dell monitor
  # ... same options plus new transition settings
};
```

## Adding New Backends

To add a new backend, edit `backends.nix` and add:

```nix
mybackend = {
  name = "My Backend";
  description = "Description of the backend";
  detect = "detection command";
  getBrightness = "command to get brightness (outputs 0.0-1.0)";
  setBrightness = "command to set brightness (accepts 0.0-1.0 as $1)";
  packages = [required packages];
  systemSetup = { /* optional system config */ };
};
```

Then update the `detectBackend` function to include your new backend in the detection chain.

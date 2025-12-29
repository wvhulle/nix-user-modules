# Keyboard Action Module

A NixOS user module for binding custom actions to keyboard shortcuts at the input event level.

## Prerequisites

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

    actions.my-shortcut = {
      description = "Super+Alt+T";
      modifiers = [ "leftmeta" "leftalt" ];
      triggerKey = "t";
      action = "${pkgs.kitty}/bin/kitty";
    };
  };
}
```

### Finding Key Event Names

Use `evtest` to find the event names for your keys:

```bash
evtest /dev/input/by-path/*kbd
# Press the key you want to use
# Look for lines like: "Event: ... EV_KEY, code 20 (KEY_T), value 1"
```

The output shows `KEY_T` as the event name to use in your configuration.

## Troubleshooting

### Service Status

Check if the service is running:

```bash
systemctl --user --no-pager status keyboard-action-*
```

### Test Keyboard Device

Verify keyboard events are being captured:

```bash
evtest /dev/input/by-path/*kbd
```

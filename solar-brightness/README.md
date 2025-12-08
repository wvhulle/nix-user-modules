# Solar Brightness Control

Hardware-agnostic automatic brightness adjustment based on solar position.

## Configuration

```nix
{
  home-manager.sharedModules = [
    ../../user-modules/solar-brightness
    {
      programs.solar-brightness = {
        enable = true;
        interval-minutes = "15min";
        min-brightness = 0.05;
        max-brightness = 0.85;
        location = {
          latitude = 50.8476; # Your latitude
          longitude = 4.3572; # Your longitude
        };
        twilight-type = "civil";
        solar-offset = "0sec";
      };
    }
  ];
}
```

Supports DDC/CI monitors and backlight devices automatically.

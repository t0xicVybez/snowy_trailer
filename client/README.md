# Snowy Trailer

## Description
This script provides functionality for towing vehicles using a trailer in FiveM.

## Dependencies
- [`ox_lib`](https://github.com/overextended/ox_lib): for prints and data management
- [`ox_target`](https://github.com/overextended/ox_target): for targeting the trailer and vehicles.

## Exported Functions

### CreateTrailer
This function spawns a trailer and sets up the necessary interactions.

#### Usage
To create a trailer, use the following export in your script:

```lua
exports.snowy_trailer:CreateTrailer(position)
```
- `position`: A vector4 or table containing the x, y, z, w coordinates where the trailer should be spawned.
- returns the trailer entity.
## Configuration

### Debugging
To enable debugging, set `Debug` to `true` in `configs/client.lua`.

### Distance Settings
The following distance settings are available in `configs/client.lua`:

- `SecondaryRamp`: Distance from the rope where the vehicle stops when towed to the top.
- `MainRamp`: Distance from the rope where the vehicle stops when towed to the bottom.

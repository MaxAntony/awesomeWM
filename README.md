# deps

- pamixer
- jetbrains font
- picom-pijulius-git
- pavucontrol
- nitrogen
- polkit-gnome

## Patch

net-speed.lua

```lua
local function convert_to_h(bytes)
  local speed
  local dim
  local bits = bytes
  if bits < 1024 then
    speed = bits
    dim = 'b/s'
  elseif bits < 1024 * 1024 then
    speed = bits / 1024
    dim = 'kb/s'
  elseif bits < 1024 * 1024 * 1024 then
    speed = bits / (1024 * 1024)
    dim = 'mb/s'
  elseif bits < 1024 * 1024 * 1024 * 1024 then
    speed = bits / (1024 * 1024 * 1024)
    dim = 'gb/s'
  else
    speed = tonumber(bits)
    dim = 'b/s'
  end
  return math.floor(speed * 10) / 10 .. dim
end

```

-- hyprland-basic: appended to hyprland.lua after the shared config (see
-- basic.nix). waybar, fuzzel and swaylock come from basic.nix.
local mainMod = "SUPER"

-- Started once, when Hyprland starts (not on config reloads).
hl.on("hyprland.start", function()
    hl.exec_cmd("waybar")
end)

hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("fuzzel"))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("swaylock -f"))

-- Volume keys (PipeWire's wpctl, from the audio aspect).
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })

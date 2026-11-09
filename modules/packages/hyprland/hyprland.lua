-- Hyprland config, appended by Home Manager to ~/.config/hypr/hyprland.lua
-- (see hyprland.nix). A trimmed-down version of Hyprland's example config
-- (example/hyprland.lua in its source); the wiki has the rest:
-- https://wiki.hypr.land/configuring/

-- Any connected monitor, at its preferred mode and scale.
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})

-- Programs started by the keybindings below. fuzzel, swaylock and waybar come
-- from hyprland.nix, Ghostty from ghostty.nix.
local terminal = "ghostty"
local menu     = "fuzzel"
local locker   = "swaylock -f"

-- Started once, when Hyprland starts (not on config reloads).
hl.on("hyprland.start", function()
    hl.exec_cmd("waybar")
end)

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- Look and feel: Hyprland's defaults, minus the animations' fine-tuning.
hl.config({
    general = {
        gaps_in     = 5,
        gaps_out    = 20,
        border_size = 2,
        layout      = "dwindle",
    },

    decoration = {
        rounding = 10,
    },

    dwindle = {
        preserve_split = true,
    },

    misc = {
        -- No anime mascot wallpaper or Hyprland logo.
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
    },

    input = {
        kb_layout    = "us",
        follow_mouse = 1,
    },
})

-------------------
--- KEYBINDINGS ---
-------------------

-- See https://wiki.hypr.land/configuring/core/binds/
local mainMod = "SUPER"

hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal)) -- Hyprland's default terminal key
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd(locker))
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))

-- Exit Hyprland (back to the login screen).
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exit())

-- Move focus with mainMod + arrow keys.
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Switch workspaces with mainMod + [0-9]; move the active window to one with
-- mainMod + SHIFT + [0-9].
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Move/resize windows with mainMod + left/right mouse button and dragging.
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Volume keys (PipeWire's wpctl, from the audio aspect).
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })

--------------------
--- WINDOW RULES ---
--------------------

-- Ignore maximize requests from apps.
hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})

-- Fix some dragging issues with XWayland.
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

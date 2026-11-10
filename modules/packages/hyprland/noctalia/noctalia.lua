-- noctalia: appended to hyprland.lua after the shared config (see
-- noctalia.nix). From Noctalia's Hyprland guide:
-- https://docs.noctalia.dev/noctalia/compositor-settings/hyprland/

-- Started once, when Hyprland starts (not on config reloads).
hl.on("hyprland.start", function()
    hl.exec_cmd("noctalia")
end)

-- Window looks Noctalia is designed around (overrides the shared config).
hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 10,
    },

    decoration = {
        rounding       = 20,
        rounding_power = 2,

        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = 0xee1a1a1a,
        },

        blur = {
            enabled  = true,
            xray     = true,
            size     = 3,
            passes   = 2,
            vibrancy = 0.1696,
        },
    },
})

-- Border and group colors from the active palette (Dracula). Noctalia's
-- "hyprland" template writes ~/.config/hypr/noctalia.lua when the palette
-- changes; it can't add this include itself, since hyprland.lua is read-only.
-- pcall: the file doesn't exist until Noctalia first runs.
local config_home = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
local ok, theme = pcall(dofile, config_home .. "/hypr/noctalia.lua")
if ok and type(theme) == "table" and theme.apply_theme then
    theme.apply_theme()
end

-- Noctalia's default keybindings, through its IPC.
local mainMod = "SUPER"
local ipc     = "noctalia msg "

hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd(ipc .. "panel-toggle launcher"))
hl.bind(mainMod .. " + S",     hl.dsp.exec_cmd(ipc .. "panel-toggle control-center"))
hl.bind(mainMod .. " + comma", hl.dsp.exec_cmd(ipc .. "settings-toggle"))
hl.bind("ALT + Tab",           hl.dsp.exec_cmd(ipc .. "window-switcher hold"))

-- Media keys, with Noctalia's on-screen display.
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd(ipc .. "volume-up"))
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd(ipc .. "volume-down"))
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd(ipc .. "volume-mute"))
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(ipc .. "brightness-up"))
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(ipc .. "brightness-down"))

-- The settings window floats.
hl.window_rule({
    name  = "noctalia-settings",
    match = { class = "dev.noctalia.Noctalia" },

    float = true,
    size  = { 1080, 920 },
})

-- Blur behind the bar, panels, dock and notifications; Noctalia animates them
-- itself, so Hyprland's layer animations are off for them.
hl.layer_rule({
    name  = "noctalia",
    match = {
        namespace = "^noctalia-(bar-.+|notification|dock|panel|attached-panel|osd|window-switcher)$",
    },

    no_anim      = true,
    ignore_alpha = 0.5,
    blur         = true,
    blur_popups  = true,
})

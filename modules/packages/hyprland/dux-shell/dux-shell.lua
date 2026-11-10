-- dux-shell: appended to hyprland.lua after the shared config (see
-- dux-shell.nix). Ported from the Hyprland Lua that `dms setup` would install
-- (core/internal/config/embedded/ in Dux Shell's source): its keybindings,
-- layer rules and the files its settings window writes. Our hyprland.lua is
-- read-only, so `dms setup` can't install its own (dux-shell.nix blocks it).
--
-- Dux Shell itself is started by its systemd user service (dms.service), not
-- from here; Home Manager's systemd integration at the top of hyprland.lua
-- starts graphical-session.target, which wants it.

-- Hyprland emits no event when a window is moved or resized, so Dux wraps these
-- dispatchers to announce one (its dock's smart auto-hide listens for it). Only
-- the binds below use the wrapped versions; the shared config's are untouched.
if hl.dsp.event then
    for _, name in ipairs({ "move", "resize", "center" }) do
        local raw = hl.dsp.window[name]
        hl.dsp.window[name] = function(...)
            -- The argument-less resize is the mouse drag bind, which needs the
            -- native dispatcher.
            if name == "resize" and select("#", ...) == 0 then
                return raw()
            end
            local dispatcher = raw(...)
            return function()
                hl.dispatch(dispatcher)
                hl.dispatch(hl.dsp.event("dms:geometry"))
            end
        end
    end
end

-- Dux animates its own surfaces (the bar, panels, launcher, notifications), so
-- Hyprland's layer animations are off for them.
hl.layer_rule({
    name  = "dux-shell-quickshell",
    match = { namespace = "^(quickshell)$" },

    no_anim = true,
})
hl.layer_rule({
    name  = "dux-shell-surfaces",
    match = { namespace = "^dms:.*" },

    no_anim = true,
})

-------------------
--- KEYBINDINGS ---
-------------------

-- Dux Shell's default keybindings (its dms/binds.lua), through its IPC. Left
-- out, because the shared config already binds the key or the action: the
-- terminal (SUPER+T, SUPER+Return), SUPER+V (clipboard), SUPER+Q (close),
-- SUPER+F and SUPER+SHIFT+F (fullscreen), SUPER+SHIFT+T (float),
-- SUPER+SHIFT+E (power menu), focus with SUPER+arrows and SUPER+H/J/K/L,
-- SUPER+[1-9] and SUPER+SHIFT+[1-9], SUPER+R (toggle split) and the mouse
-- move/resize binds. Written out one per line, without a mainMod variable, so
-- Dux's keybind cheat sheet and editor can read them.

-- === Application Launchers ===
hl.bind("SUPER + space", hl.dsp.exec_cmd("dms ipc call spotlight toggle"))
hl.bind("ALT + space", hl.dsp.exec_cmd("dms ipc call spotlight-bar toggle"))
hl.bind("SUPER + M", hl.dsp.exec_cmd("dms ipc call dash toggle media"))
hl.bind("SUPER + comma", hl.dsp.exec_cmd("dms ipc call settings focusOrToggle"))
hl.bind("SUPER + N", hl.dsp.exec_cmd("dms ipc call notepad toggle"))
hl.bind("SUPER + SHIFT + N", hl.dsp.exec_cmd("dms ipc call notepad toggleExpand"))
hl.bind("SUPER + CTRL + N", hl.dsp.exec_cmd("dms ipc call notifications toggle"))
hl.bind("SUPER + Y", hl.dsp.exec_cmd("dms ipc call dash toggle wallpaper"))
hl.bind("SUPER + TAB", hl.dsp.exec_cmd("dms ipc call hypr toggleOverview"))
hl.bind("SUPER + O", hl.dsp.exec_cmd("dms ipc call hypr toggleOverview"))
hl.bind("SUPER + X", hl.dsp.exec_cmd("dms ipc call powermenu toggle"))
hl.bind("SUPER + A", hl.dsp.exec_cmd("dms ipc call control-center toggle"))
hl.bind("SUPER + D", hl.dsp.exec_cmd([[dms ipc call dash toggle ""]]))
hl.bind("SUPER + SHIFT + C", hl.dsp.exec_cmd("dms ipc call color-picker toggle"))
hl.bind("SUPER + ALT + N", hl.dsp.exec_cmd("dms ipc call night toggle"))
hl.bind("SUPER + ALT + I", hl.dsp.exec_cmd("dms ipc call inhibit toggle"))

-- === Cheat sheet ===
hl.bind("SUPER + SHIFT + Slash", hl.dsp.exec_cmd("dms ipc call keybinds toggle hyprland"))

-- === Security ===
hl.bind("SUPER + ALT + L", hl.dsp.exec_cmd("dms ipc call lock lock"))
hl.bind("CTRL + ALT + Delete", hl.dsp.exec_cmd("dms ipc call processlist focusOrToggle"))
hl.bind("CTRL + ALT + M", hl.dsp.exec_cmd("dms ipc call processlist focusOrToggle"))

-- === Audio Controls ===
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("dms ipc call audio increment 3"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("dms ipc call audio decrement 3"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("dms ipc call audio mute"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("dms ipc call audio micmute"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("dms ipc call mpris playPause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("dms ipc call mpris playPause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("dms ipc call mpris previous"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("dms ipc call mpris next"), { locked = true })
hl.bind("CTRL + XF86AudioRaiseVolume", hl.dsp.exec_cmd("dms ipc call mpris increment 3"), { locked = true, repeating = true })
hl.bind("CTRL + XF86AudioLowerVolume", hl.dsp.exec_cmd("dms ipc call mpris decrement 3"), { locked = true, repeating = true })

-- === Brightness Controls ===
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd([[dms ipc call brightness increment 5 ""]]), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd([[dms ipc call brightness decrement 5 ""]]), { locked = true, repeating = true })

-- === Window Management ===
hl.bind("SUPER + W", hl.dsp.group.toggle())
hl.bind("SUPER + SHIFT + W", hl.dsp.exec_cmd("dms ipc call window-rules toggle"))
hl.bind("SUPER + CTRL + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "set" }))

-- === Window Movement ===
hl.bind("SUPER + SHIFT + left", hl.dsp.window.move({ direction = "l" }))
hl.bind("SUPER + SHIFT + down", hl.dsp.window.move({ direction = "d" }))
hl.bind("SUPER + SHIFT + up", hl.dsp.window.move({ direction = "u" }))
hl.bind("SUPER + SHIFT + right", hl.dsp.window.move({ direction = "r" }))
hl.bind("SUPER + SHIFT + H", hl.dsp.window.move({ direction = "l" }))
hl.bind("SUPER + SHIFT + J", hl.dsp.window.move({ direction = "d" }))
hl.bind("SUPER + SHIFT + K", hl.dsp.window.move({ direction = "u" }))
hl.bind("SUPER + SHIFT + L", hl.dsp.window.move({ direction = "r" }))

-- === Column Navigation ===
hl.bind("SUPER + Home", hl.dsp.focus({ window = "first" }))
hl.bind("SUPER + End", hl.dsp.focus({ window = "last" }))

-- === Monitor Navigation ===
hl.bind("SUPER + CTRL + left", hl.dsp.focus({ monitor = "l" }))
hl.bind("SUPER + CTRL + right", hl.dsp.focus({ monitor = "r" }))
hl.bind("SUPER + CTRL + H", hl.dsp.focus({ monitor = "l" }))
hl.bind("SUPER + CTRL + J", hl.dsp.focus({ monitor = "d" }))
hl.bind("SUPER + CTRL + K", hl.dsp.focus({ monitor = "u" }))
hl.bind("SUPER + CTRL + L", hl.dsp.focus({ monitor = "r" }))

-- === Move to Monitor ===
hl.bind("SUPER + SHIFT + CTRL + left", hl.dsp.window.move({ monitor = "l" }))
hl.bind("SUPER + SHIFT + CTRL + down", hl.dsp.window.move({ monitor = "d" }))
hl.bind("SUPER + SHIFT + CTRL + up", hl.dsp.window.move({ monitor = "u" }))
hl.bind("SUPER + SHIFT + CTRL + right", hl.dsp.window.move({ monitor = "r" }))
hl.bind("SUPER + SHIFT + CTRL + H", hl.dsp.window.move({ monitor = "l" }))
hl.bind("SUPER + SHIFT + CTRL + J", hl.dsp.window.move({ monitor = "d" }))
hl.bind("SUPER + SHIFT + CTRL + K", hl.dsp.window.move({ monitor = "u" }))
hl.bind("SUPER + SHIFT + CTRL + L", hl.dsp.window.move({ monitor = "r" }))

-- === Workspace Navigation ===
hl.bind("SUPER + Page_Down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind("SUPER + Page_Up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind("SUPER + U", hl.dsp.focus({ workspace = "e+1" }))
hl.bind("SUPER + I", hl.dsp.focus({ workspace = "e-1" }))
hl.bind("SUPER + CTRL + down", hl.dsp.window.move({ workspace = "e+1" }))
hl.bind("SUPER + CTRL + up", hl.dsp.window.move({ workspace = "e-1" }))
hl.bind("SUPER + CTRL + U", hl.dsp.window.move({ workspace = "e+1" }))
hl.bind("SUPER + CTRL + I", hl.dsp.window.move({ workspace = "e-1" }))

-- === Workspace Management ===
hl.bind("SUPER + ALT + R", hl.dsp.exec_cmd("dms ipc call workspace-rename open"))

-- === Scratchpad ===
hl.bind("SUPER + S", hl.dsp.workspace.toggle_special())
hl.bind("SUPER + SHIFT + S", hl.dsp.window.move({ workspace = "special", follow = false }))
hl.bind("SUPER + CTRL + S", hl.dsp.window.move({ workspace = "+0" }))

-- === Move Workspaces ===
hl.bind("SUPER + SHIFT + Page_Down", hl.dsp.window.move({ workspace = "e+1" }))
hl.bind("SUPER + SHIFT + Page_Up", hl.dsp.window.move({ workspace = "e-1" }))
hl.bind("SUPER + SHIFT + U", hl.dsp.window.move({ workspace = "e+1" }))
hl.bind("SUPER + SHIFT + I", hl.dsp.window.move({ workspace = "e-1" }))

-- === Mouse Wheel Navigation ===
hl.bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind("SUPER + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind("SUPER + CTRL + mouse_down", hl.dsp.window.move({ workspace = "e+1" }))
hl.bind("SUPER + CTRL + mouse_up", hl.dsp.window.move({ workspace = "e-1" }))

-- === Touchpad Gestures ===
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- === Column Management ===
hl.bind("SUPER + bracketleft", hl.dsp.layout("preselect l"))
hl.bind("SUPER + bracketright", hl.dsp.layout("preselect r"))

-- === Manual Sizing ===
hl.bind("SUPER + minus", hl.dsp.window.resize({ x = -100, y = 0, relative = true }), { repeating = true })
hl.bind("SUPER + equal", hl.dsp.window.resize({ x = 100, y = 0, relative = true }), { repeating = true })
hl.bind("SUPER + SHIFT + minus", hl.dsp.window.resize({ x = 0, y = -100, relative = true }), { repeating = true })
hl.bind("SUPER + SHIFT + equal", hl.dsp.window.resize({ x = 0, y = 100, relative = true }), { repeating = true })

-- === Screenshots ===
hl.bind("Print", hl.dsp.exec_cmd("dms screenshot"))
hl.bind("CTRL + Print", hl.dsp.exec_cmd("dms screenshot full"))
hl.bind("ALT + Print", hl.dsp.exec_cmd("dms screenshot window"))

-- === Display Profiles ===
hl.bind("SUPER + P", hl.dsp.exec_cmd("dms ipc outputs cycleProfile"))

-- === System Controls ===
hl.bind("SUPER + SHIFT + P", hl.dsp.dpms({ action = "toggle" }))

------------------------------
--- DUX SHELL'S OWN CONFIG ---
------------------------------

-- Dux's settings window writes these to ~/.config/hypr/dms/ and reloads
-- Hyprland: border colors from the theme, monitor layout, gaps and rounding,
-- cursor, mouse and keyboard, the keybind editor's binds and window rules.
-- Hyprland puts ~/.config/hypr/?.lua on package.path, so require("dms.x")
-- loads ~/.config/hypr/dms/x.lua, and Hyprland re-runs it on every reload.
--
-- Each file only exists once Dux has written it, and Hyprland's require raises
-- an error for a missing module, so each is wrapped in pcall. Errors inside an
-- existing file don't need it: Hyprland reports those and carries on. The
-- require("dms.x") calls are written out in full because that is how Dux checks
-- that hyprland.lua loads its files; otherwise its settings pages offer to add
-- them, which fails on the read-only file. dms/binds.lua (Dux's stock binds,
-- ported above) is not loaded: only `dms setup` writes it, and it would bring
-- back the binds left out above.
pcall(function() require("dms.colors") end)
pcall(function() require("dms.outputs") end)
pcall(function() require("dms.layout") end)
pcall(function() require("dms.cursor") end)
pcall(function() require("dms.input") end)

-- dms/input.lua can turn natural scrolling off (from Dux's mouse and touchpad
-- settings), and the last value set wins. Natural scrolling stays on, as in the
-- shared config: set it again after Dux's input settings.
hl.config({
    input = {
        natural_scroll = true,
        touchpad = {
            natural_scroll = true,
        },
    },
})

-- Loaded last so they win: binds from Dux's keybind editor and window rules
-- from its settings.
pcall(function() require("dms.binds-user") end)
pcall(function() require("dms.windowrules") end)

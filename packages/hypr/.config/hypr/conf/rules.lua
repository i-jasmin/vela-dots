-- Window and layer rules

-- ------------------------------------------------------------ window rules --

-- Apps that maximise themselves on launch should not.
hl.window_rule({ match = { class = ".*" }, suppress_event = "maximize" })

-- The empty-class, empty-title XWayland window some toolkits map briefly.
-- Focusing it steals input from whatever the user is actually using.
hl.window_rule({
    match = { class = "^$", title = "^$", xwayland = 1, float = 1, fullscreen = 0, pin = 0 },
    no_focus = true
})

-- Sizes and places are expressions, in pixels of the window's monitor
-- (`monitor_w`, `monitor_h`; places are from its top left). Hyprland has no
-- percentages here: "60%" is not an expression, and a rule written with one
-- is logged as an error and skipped.

-- Portals: file pickers and screen-share choosers. The screen-share chooser
-- is not the portal's own window but a program it runs,
-- hyprland-share-picker.
hl.window_rule({ match = { class = "^(xdg-desktop-portal-gtk|xdg-desktop-portal-hyprland|hyprland-share-picker)$" }, float = true, center = true })
hl.window_rule({ match = { class = "^(xdg-desktop-portal-gtk)$" }, size = { "monitor_w*0.6", "monitor_h*0.6" } })

-- File dialogs, matched by title because every toolkit uses a different class.
hl.window_rule({
    match = { title = "^(Open|Open File|Open Folder|Save|Save As|Save File|Choose Files|File Upload|Select a File|Export)(.*)$" },
    float = true,
    center = true
})

-- Authentication prompts must keep focus: losing it mid-prompt is how you end
-- up typing a password into whatever was behind it.
hl.window_rule({
    match = { class = "^(org\\.kde\\.polkit-kde-authentication-agent-1|polkit-gnome-authentication-agent-1|hyprpolkitagent)$" },
    float = true,
    center = true,
    stay_focused = true
})

-- Small settings utilities are more usable floating.
hl.window_rule({
    match = { class = "^(pavucontrol|org\\.pulseaudio\\.pavucontrol|blueman-manager|nm-connection-editor|org\\.gnome\\.Calculator|galculator|org\\.kde\\.kcalc|file-roller|org\\.gnome\\.FileRoller)$" },
    float = true,
    center = true
})
hl.window_rule({
    match = { class = "^(pavucontrol|org\\.pulseaudio\\.pavucontrol|blueman-manager|nm-connection-editor)$" },
    size = { "monitor_w*0.4", "monitor_h*0.5" }
})

-- `kitty --class floatterm` for a quick scratch terminal.
hl.window_rule({ match = { class = "^(floatterm)$" }, float = true, center = true, size = { "monitor_w*0.5", "monitor_h*0.45" } })

-- Picture-in-picture: floating, pinned across workspaces, bottom right.
hl.window_rule({
    match = { title = "^([Pp]icture[- ][Ii]n[- ][Pp]icture)$" },
    float = true,
    pin = true,
    keep_aspect_ratio = true,
    size = { "monitor_w*0.25", "monitor_h*0.25" }
})
hl.window_rule({ match = { title = "^([Pp]icture[- ][Ii]n[- ][Pp]icture)$" }, move = { "monitor_w*0.74", "monitor_h*0.71" } })

-- Blurring behind a fullscreen window is wasted GPU time.
hl.window_rule({ match = { fullscreen = 1 }, no_blur = true })

-- ------------------------------------------------------------- layer rules --

-- vela's own surfaces. ignore_alpha keeps the blur from bleeding through the
-- fully transparent parts of a panel window, which is most of its area: a
-- pixel less opaque than it gets no blur behind it.
hl.layer_rule({ match = { namespace = "^(vela-.*)$" }, blur = true })

-- The bar's window, the overlays with a full-screen dim the design asks to be
-- blurred (clipboard, sessions, what changed, window picker, capture,
-- cheatsheet), and the overview as it was. 0.4 blurs the bar down to the
-- dimmed one on an unfocused monitor (~0.43) and every dim (0.52 and up), and
-- stays above the strongest shadow in the bar's window (0.38, under a drawer).
hl.layer_rule({ match = { namespace = "^(vela-(shell|clipboard|sessions|what-changed|window-picker|capture|keybinds|overview))$" }, ignore_alpha = 0.4 })

-- The floating panels with nothing behind them but their shadow. A shadow is
-- 0.55 opaque at a panel's edge, so at 0.4 its darkest band had the wallpaper
-- blurred under it, ending in a hard line where it fell below 0.4. And as a
-- panel faded in, the blur behind it came on all at once as it passed 0.4.
-- 0.75 is above every shadow and below every panel (0.78 at the lowest
-- opacity the settings allow), so the blur stays under the panel, and comes
-- on only once the panel is three quarters there.
hl.layer_rule({ match = { namespace = "^(vela-(calendar|wallpaper|osd|notifications|dock))$" }, ignore_alpha = 0.75 })

-- Settings is opaque: blur behind it is never seen, and only showed as a jump
-- in the frame its fade passed the threshold.
hl.layer_rule({ match = { namespace = "^(vela-settings)$" }, blur = false })

-- These animate themselves in QML; letting Hyprland animate them too gives a
-- visible double movement. Keep this in step with the `WlrLayershell.namespace`
-- values in the shell: a namespace missing here gets Hyprland's full-screen
-- slide on top of its own animation. vela-shell is the bar and everything that
-- hangs off it -- dashboard, popouts, launcher, power menu -- in one window;
-- vela-bar-zone is the empty window that reserves the bar's space.
hl.layer_rule({ match = { namespace = "^(vela-(background|shell|bar-zone|osd|notifications|overview|dock|settings|wallpaper|calendar|clipboard|capture|window-picker|sessions|what-changed|keybinds|recolour))$" }, no_anim = true })

-- The wallpaper must not be blurred: it sits below everything, so blurring it
-- would blur the desktop itself.
hl.layer_rule({ match = { namespace = "^(vela-background)$" }, blur = false })

-- Nor the frames a retint crossfades windows through (the shell's
-- modules/overlays/Recolour.qml): a full-screen layer over every window, so
-- blur behind it would blur the whole desktop for as long as it is up.
hl.layer_rule({ match = { namespace = "^(vela-recolour)$" }, blur = false })

-- fuzzel, kept as a fallback launcher.
hl.layer_rule({ match = { namespace = "^(launcher)$" }, blur = true })
hl.layer_rule({ match = { namespace = "^(launcher)$" }, ignore_alpha = 0.3 })

-- --------------------------------------------------------- workspace rules --

-- Scratchpad: wide gaps so it reads as an overlay, and a terminal when empty.
hl.workspace_rule({
    workspace = "special:scratch",
    gaps_out = 60,
    gaps_in = 5,
    on_created_empty = "kitty"
})

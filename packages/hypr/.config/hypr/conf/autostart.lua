-- Autostart
--
-- Everything inside hl.on("hyprland.start") is the Lua equivalent of
-- exec-once: it runs when the compositor comes up, not on every reload.

hl.on("hyprland.start", function()
    -- The shell. Owns the bar, wallpaper, notifications, OSD, launcher and
    -- lock screen, which is why nothing else here starts a notification
    -- daemon or a wallpaper setter.
    --
    -- Through `vela shell start` rather than `qs -c vela`, so it starts with
    -- the icon theme chosen in Settings (Appearance, App icons): Quickshell
    -- reads that once, as it starts. Should the script be missing, the shell
    -- still comes up, with its own symbols.
    hl.exec_cmd("vela shell start || qs -c vela -n")

    hl.exec_cmd("hypridle")

    -- Make the session's variables visible to user services and portals.
    -- Without this, screen sharing and file pickers launched from a systemd
    -- unit come up with no WAYLAND_DISPLAY.
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE")

    -- Polkit agent: first one that exists wins. Without an agent, anything
    -- asking for authentication fails silently rather than prompting.
    hl.exec_cmd("sh -c 'for a in hyprpolkitagent /usr/libexec/hyprpolkitagent /usr/libexec/kf6/polkit-kde-authentication-agent-1 /usr/libexec/polkit-gnome-authentication-agent-1; do command -v \"$a\" >/dev/null 2>&1 && exec \"$a\"; done'")

    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")

    -- Clipboard history, read by the shell's clipboard panel (SUPER+V).
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")

    -- XCURSOR_* covers XWayland and GTK; this sets Hyprland's own cursor.
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Classic 24")
end)

-- Not started here, deliberately:
--
--   xdg-desktop-portal-hyprland   D-Bus activated, starts itself on demand
--   a notification daemon         the shell is one
--   a wallpaper daemon            the shell draws the wallpaper itself, from
--                                 the same path matugen generated the palette
--                                 from, so the two cannot drift apart

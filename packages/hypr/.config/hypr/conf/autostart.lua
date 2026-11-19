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

    -- Make the session's variables visible to user services and portals,
    -- then bring up the session target (~/.config/systemd/user/
    -- hyprland-session.target), which starts graphical-session.target with
    -- it. Fedora 45's xdg-desktop-portal Requires that target, so without it
    -- the portal never starts: no file pickers, no screen sharing.
    --
    -- One shell, in this order: two separate exec_cmd calls run side by side,
    -- and the portal must not start before WAYLAND_DISPLAY is exported.
    hl.exec_cmd("sh -c 'dbus-update-activation-environment --systemd --all; systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE; systemctl --user start hyprland-session.target'")

    -- Polkit agent: first one that exists wins. Without an agent, anything
    -- asking for authentication fails silently rather than prompting.
    hl.exec_cmd("sh -c 'for a in hyprpolkitagent /usr/libexec/hyprpolkitagent /usr/libexec/kf6/polkit-kde-authentication-agent-1 /usr/libexec/polkit-gnome-authentication-agent-1; do command -v \"$a\" >/dev/null 2>&1 && exec \"$a\"; done'")

    -- The keyring (calendar passwords live in it). Fedora 45 replaced
    -- gnome-keyring with oo7: at login, GDM's pam_oo7 hands the password to an
    -- oo7-daemon-login helper that waits 120 s for the daemon to collect it,
    -- and the upgrade leaves the daemon's unit disabled -- measured: "Timed
    -- out after 120s, no daemon connected", and no keyring for the session.
    -- Starting it here lands well inside that window. gnome-keyring is the
    -- fallback where oo7 does not exist.
    hl.exec_cmd("sh -c 'systemctl --user start oo7-daemon.service 2>/dev/null || exec gnome-keyring-daemon --start --components=secrets'")

    -- Clipboard history, read by the shell's clipboard panel (SUPER+V).
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")

    -- XCURSOR_* covers XWayland and GTK; this sets Hyprland's own cursor.
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Classic 24")
end)

-- Take the session target down with the compositor, so the next login starts
-- graphical-session.target afresh rather than finding a stale one still up.
hl.on("hyprland.shutdown", function()
    hl.exec_cmd("systemctl --user stop hyprland-session.target")
end)

-- Not started here, deliberately:
--
--   xdg-desktop-portal-hyprland   D-Bus activated, starts itself on demand
--   a notification daemon         the shell is one
--   a wallpaper daemon            the shell draws the wallpaper itself, from
--                                 the same path matugen generated the palette
--                                 from, so the two cannot drift apart

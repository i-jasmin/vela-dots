-- Environment
--
-- These only affect processes Hyprland starts, which is what we want: nothing
-- leaks into a TTY or another session.

-- ---------------------------------------------------------------- graphics --
-- Nothing is set here for any graphics card: Hyprland chooses the card it
-- draws on by itself, which is right on most machines. The NVIDIA driver, and
-- anything it needs outside Hyprland (kernel options, module settings), is not
-- this file's business: https://vela.ijasmin.it/help/nvidia/ links the guides.
--
-- NVIDIA ONLY -- every monitor plugged into an NVIDIA card, as on most PCs
-- with one. These are the lines the Hyprland wiki's NVIDIA page gives
-- (https://wiki.hypr.land/Nvidia/); read its notes on each, then uncomment:
-- hl.env("LIBVA_DRIVER_NAME", "nvidia")
-- hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")

-- BUILT-IN GRAPHICS AND NVIDIA -- Intel or AMD graphics in the processor and
-- an NVIDIA card beside them: most laptops with NVIDIA, and PCs with monitors
-- on both the motherboard and the card. Leave the two lines above commented.
-- Hyprland usually draws on the built-in graphics here, and the NVIDIA card
-- can sleep until something asks for it; both lines send work to it instead:
--
--   LIBVA_DRIVER_NAME=nvidia            moves video decoding to NVIDIA. Unset,
--                                       libva picks the driver for the card
--                                       that draws.
--   __GLX_VENDOR_LIBRARY_NAME=nvidia    forces GLX/XWayland apps onto NVIDIA,
--                                       waking it for everything and breaking
--                                       screen sharing. It belongs on the
--                                       *single app* you want there -- see
--                                       the `nv` function in config.fish.
--
-- If an external monitor is laggy or blank, or the wrong card draws, see
-- https://wiki.hypr.land/Configuring/Advanced-and-Cool/Multi-GPU/. Aquamarine's
-- escape hatch for it stops forcing linear modifiers on buffers passed between
-- the cards:
-- hl.env("AQ_FORCE_LINEAR_BLIT", "0")
--
-- Notes from one such laptop (Intel Alder Lake-P Iris Xe at 00:02.0, GeForce
-- RTX 3050 Mobile at 01:00.0), read with `ls /sys/class/drm`:
--
--     card1 (i915)       eDP-1, DP-1 .. DP-4     <- the internal panel
--     card0 (nvidia-drm) HDMI-A-1                <- the HDMI port only
--
-- So the laptop display is physically wired to the Intel graphics and cannot
-- be driven by the NVIDIA card at all, while an HDMI monitor can only be
-- driven by the NVIDIA card. Both have to stay available; this is not a
-- "disable the NVIDIA card" setup.
--
-- AQ_DRM_DEVICES is intentionally NOT set. Aquamarine already elects the
-- Intel card as the primary renderer on its own -- from the live log:
--
--     drm: Starting backend for /dev/dri/card1, with driver i915
--     drm: gpu /dev/dri/card1 becomes primary drm
--     drm: Starting backend for /dev/dri/card0, with driver nvidia-drm
--          with primary /dev/dri/card1
--
-- which is exactly the wanted arrangement: compositing on the Intel graphics
-- (cheap, no NVIDIA quirks) with the NVIDIA card kept as a secondary device so
-- HDMI and PRIME offload still work. Setting the variable would only pin an
-- ordering we already get, at the cost of hardcoding card numbers -- and card
-- numbering is assigned at boot and does swap. /dev/dri/by-path/ names are
-- stable but unusable here: they contain colons (pci-0000:00:02.0-card) and
-- colon is the list separator for this variable.
--
-- If the ordering ever comes out wrong, make a stable symlink first:
--
--     printf 'KERNEL=="card*", KERNELS=="0000:00:02.0", SUBSYSTEM=="drm", \
--     SUBSYSTEMS=="pci", SYMLINK+="dri/intel-igpu"\n' \
--       | sudo tee /etc/udev/rules.d/99-intel-igpu.rules
--     sudo udevadm control --reload && sudo udevadm trigger
--
-- and then uncomment, Intel first, NVIDIA second so HDMI keeps working:
-- hl.env("AQ_DRM_DEVICES", "/dev/dri/intel-igpu:/dev/dri/nvidia-dgpu")

-- Left out, though older guides give them:
--
--   GBM_BACKEND=nvidia-drm              sends every GBM client to NVIDIA's GBM
--                                       implementation. With built-in graphics
--                                       as well, that includes the ones drawing
--                                       on them: Mesa clients break, and the
--                                       whole session can fail to start.
--   NVD_BACKEND=direct                  only means something to NVIDIA's own
--                                       VA-API driver.
--   WLR_NO_HARDWARE_CURSORS=1           wlroots-era, Hyprland has used
--                                       Aquamarine since 0.40. The equivalent
--                                       is `cursor:no_hardware_cursors`, whose
--                                       default (auto) already does the right
--                                       thing.

-- ------------------------------------------------------------------ toolkits
-- Qt: Wayland first, X11 only as a fallback for apps with no Wayland plugin.
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
-- No platform theme is forced. qt6ct (in the sdegler/hyprland COPR) is the
-- neutral choice; `kde` is right only if the Plasma integration is installed.
-- hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

-- GTK/SDL/Firefox: prefer Wayland, keep X11 reachable.
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("MOZ_ENABLE_WAYLAND", "1")

-- Electron/CEF apps default to XWayland, where they flicker on NVIDIA and
-- scale badly. `auto` makes them pick Wayland natively.
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- ----------------------------------------------------------------------- PATH
-- Hyprland is started by the display manager, not a login shell, so the
-- session PATH is just /usr/local/bin:/usr/bin. Anything installed under
-- ~/.local/bin -- including `vela` itself -- is invisible to keybinds and to
-- everything the shell spawns unless it is added here. Prepended, not
-- replaced, so the system prefix still wins for system tools.
--
-- Only once: `hl.env` sets the variable in Hyprland's own environment, so on
-- a reload -- every `vela wallpaper` is one -- PATH already starts with it,
-- and prepending again grew it by another copy each time.
local home = os.getenv("HOME")
local path = os.getenv("PATH") or "/usr/local/bin:/usr/bin"
local localBin = home .. "/.local/bin"
if not (":" .. path .. ":"):find(":" .. localBin .. ":", 1, true) then
    hl.env("PATH", localBin .. ":" .. path)
end

-- --------------------------------------------------------------- session bits
-- Portals and anything that asks "which desktop is this" key off these.
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- Cursor. XCURSOR_* is what XWayland and GTK read; Hyprland falls back to the
-- same theme for its own cursor when no hyprcursor theme is installed.
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "24")

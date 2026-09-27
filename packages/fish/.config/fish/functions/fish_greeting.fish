# The greeting a new terminal opens with: `vela greet`, which is fastfetch in
# the wallpaper's palette, information only.
#
# Once per terminal window. VELA_GREETED is exported, so a shell started
# inside this one -- `fish`, `bash`, the subshell an editor runs -- stays
# quiet, while a new kitty window, which starts from kitty's own environment,
# greets again. Not on a Linux console, which has no font for it.
#
# `set -Ux VELA_GREETING off` turns it off for good.
function fish_greeting
    test "$VELA_GREETING" = off; and return
    set -q VELA_GREETED; and return
    set -gx VELA_GREETED 1
    test "$TERM" = linux; and return
    type -q vela; and vela greet
end

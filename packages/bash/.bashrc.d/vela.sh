# vela -- bash
#
# Fedora's stock ~/.bashrc sources everything in ~/.bashrc.d, so this file is
# additive: it never edits ~/.bashrc and disappears cleanly when unstowed.

# ~/.local/bin holds the `vela` command. Hyprland exports this too (see
# conf/env.lua), but a bash started from a TTY or an SSH session does not
# inherit that, so set it here as well.
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) PATH="$HOME/.local/bin:$PATH" ;;
esac

# Everything below is interactive-only: sourcing this from a script must not
# print anything or cost time.
[[ $- == *i* ]] || return

# The greeting: `vela greet`, fastfetch in the wallpaper's palette,
# information only. Once per terminal window -- VELA_GREETED is
# exported, so a shell started inside this one stays quiet -- and never on a
# Linux console. The same as fish's (functions/fish_greeting.fish), so it
# greets once whichever of the two the terminal starts. VELA_GREETING=off in
# the environment turns it off.
if [ "${VELA_GREETING:-}" != off ] && [ -z "${VELA_GREETED:-}" ] && [ "$TERM" != linux ] &&
    command -v vela >/dev/null 2>&1; then
    export VELA_GREETED=1
    vela greet
fi

# starship, when it is installed and the terminal can draw it. A Linux VT has
# no Nerd Font, so the powerline glyphs there come out as boxes.
if command -v starship >/dev/null 2>&1 && [ "$TERM" != "linux" ]; then
    eval "$(starship init bash)"
fi

alias ls='ls --color=auto'
alias ll='ls -lh'
alias la='ls -lha'
alias grep='grep --color=auto'
alias g='git'
alias gs='git status --short --branch'

# `mkcd foo` makes the directory and steps into it.
mkcd() { mkdir -p -- "$1" && cd -- "$1" || return; }

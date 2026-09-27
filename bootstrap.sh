#!/usr/bin/env bash
# Bootstrap vela on a fresh Fedora install.
#
#   ./bootstrap.sh            install packages, then link every package
#   ./bootstrap.sh --packages install packages only, no linking
#   ./bootstrap.sh --link     link only, no package installation
#   ./bootstrap.sh --unlink   remove all links
#   ./bootstrap.sh --targets  print the paths in $HOME that vela links
#
# install.sh is the one-line way in: it clones the repo and runs this.
#
# Linking is GNU Stow: each directory under packages/ mirrors $HOME, so
# `stow -d packages -t ~ hypr` puts packages/hypr/.config/hypr at
# ~/.config/hypr as a symlink. Edits to the linked files edit the repo.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES=(vela quickshell bin hypr kitty fish fuzzel bash starship)

# COPRs. Fedora ships neither quickshell nor matugen.
#   sdegler/hyprland       hyprland, hyprsunset, matugen, cliphist,
#                          hyprpolkitagent
#   atim/starship          starship, the prompt config.fish sets up
#   ririko66z/dots-hyprland  JetBrainsMono Nerd, Rubik, Material Symbols and
#                          the Bibata cursors. end-4's COPR, used only for
#                          fonts and cursors: Fedora's own jetbrains-mono-fonts
#                          has no Nerd glyphs, which the prompt and the bar need.
COPRS=(
    errornointernet/quickshell
    sdegler/hyprland
    atim/starship
    ririko66z/dots-hyprland
)

# Everything the shell and the configs call. A package missing here is a
# feature that silently does nothing, so each non-obvious one says who needs it.
DNF_PACKAGES=(
    stow python3 xdg-utils
    gtk3                        # gtk-launch: super + B opens the default browser
    hyprland hyprlock hypridle hyprpicker hyprpolkitagent
    hyprsunset                  # evening warmth (services/NightLight.qml)
    quickshell matugen
    kitty fish fuzzel starship
    fastfetch                   # the terminal greeting (`vela greet`)
    grim slurp wl-clipboard cliphist
    wtype                       # clipboard panel and launcher emoji: type into the focused window
    psmisc                      # fuser: the privacy capsule's camera check
    wf-recorder                 # capture: record and GIF
    swappy                      # capture: annotate
    tesseract tesseract-langpack-eng    # capture: OCR
    ImageMagick                 # wallpaper switcher thumbnails and sizes
    brightnessctl playerctl cava wireplumber
    khal                        # the dashboard's day and Home's month
    vdirsyncer                  # fetches the calendars added in Settings, Calendars
    libsecret                   # secret-tool: their passwords and links, kept in the keyring
    python3-icalendar           # `vela calendar event`: events written from Home's month
    wlogout nautilus gnome-keyring
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    adw-gtk3-theme              # the gtk-theme `vela theme` switches between
    google-noto-emoji-fonts rsms-inter-fonts
    jetbrains-mono-nerd-fonts google-rubik-vf-fonts
    google-material-symbols-vf-rounded-fonts
    bibata-cursor-theme
)

# What must be there after the install for the desktop to come up at all. A
# COPR with no build for this Fedora release fails quietly under
# --skip-unavailable, so these are checked by name afterwards.
# Each is a command, and the package it comes from.
ESSENTIAL=(Hyprland:hyprland qs:quickshell matugen:matugen hypridle:hypridle hyprlock:hyprlock kitty:kitty stow:stow)

# The Lua config manager hyprland.lua is written for.
HYPRLAND_MIN=0.56

if [ -t 1 ]; then M=$'\033[1;35m' Y=$'\033[1;33m' R=$'\033[1;31m' N=$'\033[0m'; else M="" Y="" R="" N=""; fi
log()  { printf '%s::%s %s\n' "$M" "$N" "$1"; }
warn() { printf '%s!!%s %s\n' "$Y" "$N" "$1" >&2; }
die()  { printf '%sxx%s %s\n' "$R" "$N" "$1" >&2; exit 1; }

# Directories vela links into but does not own: they exist on every account,
# and other programs keep things in them.
SHARED=(.config .local .local/bin .local/share .local/state .config/quickshell .bashrc.d)

# The paths in $HOME that vela owns, one per line: whatever sits directly
# inside a shared directory (or at the top of a package). ~/.config/hypr is
# one, ~/.config is not.
targets() {
    local pkg rel parent
    for pkg in "${PACKAGES[@]}"; do
        while IFS= read -r rel; do
            rel="${rel#./}"
            [[ " ${SHARED[*]} " == *" $rel "* ]] && continue
            parent="$(dirname "$rel")"
            if [ "$parent" = "." ] || [[ " ${SHARED[*]} " == *" $parent "* ]]; then
                printf '%s\n' "$rel"
            fi
        done < <(cd "$REPO/packages/$pkg" && find . -mindepth 1)
    done
}

install_packages() {
    command -v dnf >/dev/null || die "this script targets Fedora (no dnf found)"

    log "Enabling COPR repositories"
    for copr in "${COPRS[@]}"; do
        sudo dnf -y copr enable "$copr"
    done

    # --skip-unavailable: one renamed package should cost that one feature,
    # not abort the whole transaction and leave nothing linked. The ones the
    # desktop cannot do without are checked by name straight after.
    log "Installing packages"
    sudo dnf install -y --skip-unavailable "${DNF_PACKAGES[@]}"

    local missing=() entry
    for entry in "${ESSENTIAL[@]}"; do
        command -v "${entry%%:*}" >/dev/null 2>&1 || missing+=("${entry#*:}")
    done
    if [ "${#missing[@]}" -gt 0 ]; then
        die "these did not install: ${missing[*]}. The ones from a COPR (Hyprland's tools, quickshell, matugen) may have no build for Fedora $(rpm -E %fedora) yet -- see \`dnf copr list\` and the COPR pages, then run this again."
    fi

    # hyprland.lua needs the Lua config manager. Fedora's own repositories can
    # carry an older Hyprland than the COPR; dnf takes the newest, but say so
    # if that is still too old rather than leave a login that loads nothing.
    local version
    version="$(Hyprland --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 || true)"
    if [ -n "$version" ] && [ "$(printf '%s\n%s\n' "$HYPRLAND_MIN" "$version" | sort -V | head -1)" != "$HYPRLAND_MIN" ]; then
        warn "Hyprland $version is installed; vela's config needs $HYPRLAND_MIN or newer (the Lua config)."
    fi

    # Material Symbols is the icon font the shell draws every glyph with. The
    # ririko66z COPR packages it; this is the fallback if that ever fails.
    #
    # The font list is read whole before it is searched. Piped straight into
    # `grep -q`, grep stops at the first match, fc-list dies writing the rest,
    # and under pipefail an installed font read as missing.
    local families
    families="$(fc-list : family)"
    if ! grep -q "Material Symbols Rounded" <<<"$families"; then
        log "Installing Material Symbols Rounded"
        local dir="$HOME/.local/share/fonts"
        mkdir -p "$dir"
        # A failed download costs the icons, not the run: under `set -e` it
        # used to stop here, before anything was linked.
        if curl -fsSL -o "$dir/MaterialSymbolsRounded.ttf" \
            "https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf"; then
            fc-cache -f "$dir"
        else
            rm -f "$dir/MaterialSymbolsRounded.ttf"
            printf '\033[1;33m!!\033[0m %s\n' "Could not download Material Symbols Rounded; the shell's icons will be missing" >&2
        fi
    fi
}

link() {
    command -v stow >/dev/null || die "stow is not installed (run without --link first)"

    # Stow "folds": if a directory it links into does not exist yet, it links
    # the whole directory instead of the files in it. On a fresh account that
    # makes ~/.local a symlink into this repo, and every program that then
    # writes to ~/.local/share or ~/.local/state -- the shell's own state
    # included -- writes into the working tree. Directories that are shared
    # with the rest of the system are created first, so only vela's own
    # directories (~/.config/hypr, ~/.config/quickshell/vela, ...) are linked
    # whole.
    mkdir -p "$HOME/.local/bin" "$HOME/.local/share" "$HOME/.local/state" \
        "$HOME/.config/quickshell" "$HOME/.bashrc.d"

    # Stow refuses to link over a file it does not own, and says so in a way
    # that is easy to miss. So anything already at one of vela's paths -- a
    # kitty.conf from before, the hyprland.conf Hyprland writes on its first
    # start -- is moved aside first, whole, into one dated folder. A link that
    # already points into this repo is vela's own and stays.
    local rel target backup=""
    while IFS= read -r rel; do
        target="$HOME/$rel"
        [ -e "$target" ] || [ -L "$target" ] || continue
        if [ -L "$target" ] && [[ "$(readlink -f "$target")" == "$REPO"/* ]]; then
            continue
        fi
        if [ -z "$backup" ]; then
            backup="$HOME/.local/state/vela/backup-$(date +%Y%m%d-%H%M%S)"
            mkdir -p "$backup"
        fi
        mkdir -p "$backup/$(dirname "$rel")"
        mv "$target" "$backup/$rel"
    done < <(targets)
    [ -n "$backup" ] && log "Moved your existing configs aside, to $backup"

    log "Linking packages: ${PACKAGES[*]}"
    stow -d "$REPO/packages" -t "$HOME" --restow "${PACKAGES[@]}"
}

unlink_all() {
    command -v stow >/dev/null || die "stow is not installed"
    log "Removing links: ${PACKAGES[*]}"
    stow -d "$REPO/packages" -t "$HOME" --delete "${PACKAGES[@]}"
}

case "${1:-}" in
    --packages) install_packages ;;
    --link)    link ;;
    --unlink)  unlink_all ;;
    --targets) targets ;;
    "")       install_packages; link
              log "Done. Set a wallpaper to generate the palette:"
              printf '\n    vela wallpaper ~/Pictures/Wallpapers/your-wallpaper.png\n    vela shell start\n\n' ;;
    *)        die "unknown option: $1" ;;
esac

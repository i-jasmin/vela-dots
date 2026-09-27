#!/usr/bin/env bash
# Bootstrap vela on a fresh Fedora install.
#
#   ./bootstrap.sh            install packages, then link every package
#   ./bootstrap.sh --link     link only, no package installation
#   ./bootstrap.sh --unlink   remove all links
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

log()  { printf '\033[1;35m::\033[0m %s\n' "$1"; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$1" >&2; exit 1; }

install_packages() {
    command -v dnf >/dev/null || die "this script targets Fedora (no dnf found)"

    log "Enabling COPR repositories"
    for copr in "${COPRS[@]}"; do
        sudo dnf -y copr enable "$copr"
    done

    # --skip-unavailable: one renamed package should cost that one feature,
    # not abort the whole transaction and leave nothing linked.
    log "Installing packages"
    sudo dnf install -y --skip-unavailable "${DNF_PACKAGES[@]}"

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

    log "Linking packages: ${PACKAGES[*]}"
    stow -d "$REPO/packages" -t "$HOME" --restow "${PACKAGES[@]}"
}

unlink_all() {
    command -v stow >/dev/null || die "stow is not installed"
    log "Removing links: ${PACKAGES[*]}"
    stow -d "$REPO/packages" -t "$HOME" --delete "${PACKAGES[@]}"
}

case "${1:-}" in
    --link)   link ;;
    --unlink) unlink_all ;;
    "")       install_packages; link
              log "Done. Set a wallpaper to generate the palette:"
              printf '\n    vela wallpaper ~/Pictures/Wallpapers/your-wallpaper.png\n    vela shell start\n\n' ;;
    *)        die "unknown option: $1" ;;
esac

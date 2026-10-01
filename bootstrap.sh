#!/usr/bin/env bash
# Bootstrap vela on a fresh Fedora install.
#
#   ./bootstrap.sh            install packages, then link every package
#   ./bootstrap.sh --packages install packages only, no linking
#   ./bootstrap.sh --link     link only, no package installation
#   ./bootstrap.sh --unlink   remove all links
#   ./bootstrap.sh --targets  print the paths in $HOME that vela links
#   ./bootstrap.sh --matugen  install vela's matugen, if what is there is older
#   ./bootstrap.sh --unfold   only move your files out of the repo (see unfold)
#
# install.sh is the one-line way in: it clones the repo and runs this.
#
# Linking is GNU Stow: each directory under packages/ mirrors $HOME. Most
# packages are linked whole -- ~/.config/quickshell/vela is one link into the
# repo. The ones in UNFOLDED are linked file by file into real folders, because
# those folders also hold your own files. Edits to a linked file edit the repo;
# your own files never live there.
set -euo pipefail

# install.sh runs the next version of this script, before updating to it,
# against the clone it is about to update: that is the one case where this
# file is not in the repo it works on.
REPO="${VELA_BOOTSTRAP_REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
PACKAGES=(vela quickshell bin hypr kitty fish fuzzel bash starship)

# Packages whose folders hold your own files as well as vela's: your settings,
# the palette made from your wallpaper, Hyprland's idle times, fish's
# variables, anything another program keeps there. Each folder is a real one
# in your home with vela's files linked into it one by one (stow
# --no-folding), so what is written there stays in your home. Linked whole,
# it was written into the repo, and `git pull` -- every update -- refused to
# run over it.
UNFOLDED=(vela hypr kitty fish fuzzel)

# The files in those folders that are yours: written as you go, by the shell,
# by matugen, by fish. None of them is in packages/ any more; the copy of each
# that vela starts you with is under defaults/ (seed_defaults). They are named
# here for installs made before that, where these were tracked in the repo and
# unfolding has to take them along as yours rather than link them.
USER_FILES=(
    .config/vela/shell.json
    .config/vela/keybinds.json
    .config/hypr/hypridle.conf
    .config/hypr/colours.conf
    .config/hypr/conf/colours.lua
    .config/hypr/conf/local.lua
    .config/kitty/colours.conf
    .config/fuzzel/colours.ini
    .config/fish/fish_variables
)

# COPRs, for what Fedora itself does not ship, or ships older than vela needs.
#   errornointernet/quickshell  quickshell, the shell itself
#   sdegler/hyprland       hyprland, hyprsunset, cliphist, hyprpolkitagent
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
    quickshell
    matugen                     # Fedora's; replaced by vela's own when older (install_matugen)
    kitty fish fuzzel starship  # kitty opens fish (kitty.conf)
    fastfetch                   # the terminal greeting (`vela greet`)
    grim slurp wl-clipboard cliphist
    wtype                       # clipboard panel and launcher emoji: type into the focused window
    psmisc                      # fuser: the privacy capsule's camera check
    wf-recorder                 # capture: record and GIF
    swappy                      # capture: annotate
    tesseract tesseract-langpack-eng    # capture: OCR
    ImageMagick                 # wallpaper switcher thumbnails and sizes
    brightnessctl playerctl cava wireplumber
    bluez                       # bluetoothd, which the Bluetooth popout talks to
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
ESSENTIAL=(Hyprland:hyprland qs:quickshell matugen:matugen hypridle:hypridle hyprlock:hyprlock kitty:kitty fish:fish stow:stow)

# The Lua config manager hyprland.lua is written for.
HYPRLAND_MIN=0.56

# Where .github/workflows/packages.yml publishes what vela builds itself.
PACKAGES_URL="${VELA_PACKAGES_URL:-https://github.com/i-jasmin/vela-dots/releases/download/packages}"

if [ -t 1 ]; then M=$'\033[1;35m' Y=$'\033[1;33m' R=$'\033[1;31m' N=$'\033[0m'; else M="" Y="" R="" N=""; fi
# Run by install.sh, the steps and warnings also go into its install.log.
record() { if [ -n "${VELA_INSTALL_LOG:-}" ]; then printf '%s\n' "$1" >>"$VELA_INSTALL_LOG"; fi; }
log()  { printf '%s::%s %s\n' "$M" "$N" "$1"; record ":: $1"; }
warn() { printf '%s!!%s %s\n' "$Y" "$N" "$1" >&2; record "!! $1"; }
die()  { printf '%sxx%s %s\n' "$R" "$N" "$1" >&2; record "xx $1"; exit 1; }

# True when version $1 is $2 or newer.
version_ge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" = "$2" ]; }

# Directories vela links into but does not own: they exist on every account,
# and other programs keep things in them.
SHARED=(.config .local .local/bin .local/share .local/state .config/quickshell .bashrc.d)

unfolded() { [[ " ${UNFOLDED[*]} " == *" $1 "* ]]; }

is_user_file() { [[ " ${USER_FILES[*]} " == *" $1 "* ]]; }

# A package's own folders and files at the top: whatever sits directly inside
# a shared directory (or at the top of the package). ~/.config/hypr is one,
# ~/.config is not.
tops() {
    local rel parent
    while IFS= read -r rel; do
        rel="${rel#./}"
        [[ " ${SHARED[*]} " == *" $rel "* ]] && continue
        parent="$(dirname "$rel")"
        if [ "$parent" = "." ] || [[ " ${SHARED[*]} " == *" $parent "* ]]; then
            printf '%s\n' "$rel"
        fi
    done < <(cd "$REPO/packages/$1" && find . -mindepth 1)
}

# The paths in $HOME that are links into the repo once vela is linked, one
# per line: a package's top for the ones linked whole, and every file for the
# ones linked file by file. `vela doctor` checks each resolves into the repo.
targets() {
    local pkg
    for pkg in "${PACKAGES[@]}"; do
        if unfolded "$pkg"; then
            (cd "$REPO/packages/$pkg" && find . \( -type f -o -type l \) | sed 's|^\./||')
        else
            tops "$pkg"
        fi
    done
}

# Fedora's own matugen is older than vela is made for -- 3.1 on Fedora 44,
# and 4.0 is what added --source-color-index -- so vela builds its own from
# packaging/fedora/matugen.spec and installs that in its place. Only when
# what is there is older than the spec: a newer matugen from Fedora is left
# alone, and running this again after the spec moves on is the update.
#
# Missing costs little: an older matugen still makes a palette, from the
# wallpaper's dominant colour (vela retint), so a failed download warns and
# carries on.
install_matugen() {
    local spec="$REPO/packaging/fedora/matugen.spec" want release have rpm
    want="$(sed -n 's/^Version:[[:space:]]*//p' "$spec")"
    release="$(sed -n 's/^Release:[[:space:]]*//p' "$spec")"
    release="${release%%\%*}" # "1%{?dist}" is "1.fc44" once built
    have="$(matugen --version 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)+' | head -1 || true)"
    if [ -n "$have" ] && version_ge "$have" "$want"; then
        return 0
    fi
    rpm="matugen-$want-$release.fc$(rpm -E %fedora).$(uname -m).rpm"
    log "Installing matugen $want, vela's own build${have:+, over $have}"
    if ! sudo dnf install -y "$PACKAGES_URL/$rpm"; then
        warn "could not install $rpm: vela has no build of it for Fedora $(rpm -E %fedora) on $(uname -m) yet. Palettes still work, from the wallpaper's dominant colour; \`vela doctor\` says when to try again."
    fi
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
    install_matugen

    # The Bluetooth popout talks to bluetoothd. Fedora Workstation runs it;
    # other editions can leave the service off. A machine with no adapter
    # skips it on its own: the unit only starts when /sys/class/bluetooth is
    # there.
    if [ -d /run/systemd/system ] && systemctl cat bluetooth.service >/dev/null 2>&1 &&
        ! systemctl is-enabled --quiet bluetooth.service 2>/dev/null; then
        log "Turning on Bluetooth"
        sudo systemctl enable --now bluetooth.service || warn "could not turn on the Bluetooth service; the Bluetooth popout will be empty"
    fi

    local missing=() entry
    for entry in "${ESSENTIAL[@]}"; do
        command -v "${entry%%:*}" >/dev/null 2>&1 || missing+=("${entry#*:}")
    done
    if [ "${#missing[@]}" -gt 0 ]; then
        die "these did not install: ${missing[*]}. The ones from a COPR (Hyprland's tools, quickshell) may have no build for Fedora $(rpm -E %fedora) yet -- see \`dnf copr list\` and the COPR pages, then run this again."
    fi

    # hyprland.lua needs the Lua config manager. Fedora's own repositories can
    # carry an older Hyprland than the COPR; dnf takes the newest, but say so
    # if that is still too old rather than leave a login that loads nothing.
    local version
    version="$(Hyprland --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 || true)"
    if [ -n "$version" ] && ! version_ge "$version" "$HYPRLAND_MIN"; then
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
            warn "Could not download Material Symbols Rounded; the shell's icons will be missing"
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

    # Folders an older install linked whole, made real ones, your files kept.
    unfold_all

    # Stow refuses to link over a file it does not own, and says so in a way
    # that is easy to miss. So anything already at one of vela's paths -- a
    # kitty.conf from before, the hyprland.conf Hyprland writes on its first
    # start -- is moved aside first, into one dated folder. A folder of an
    # UNFOLDED package that was never vela's goes aside whole, so vela's files
    # and yours start in a clean one; one vela made stays, with whatever is in
    # it, and only a file in the way of one of vela's own goes aside.
    local pkg top rel
    for pkg in "${UNFOLDED[@]}"; do
        while IFS= read -r top; do
            [ -e "$HOME/$top" ] || [ -L "$HOME/$top" ] || continue
            if [ -d "$HOME/$top" ] && [ ! -L "$HOME/$top" ] && vela_folder "$top"; then
                continue
            fi
            move_aside "$top"
        done < <(tops "$pkg")
    done
    while IFS= read -r rel; do
        [ -e "$HOME/$rel" ] || [ -L "$HOME/$rel" ] || continue
        ours "$HOME/$rel" || move_aside "$rel"
    done < <(targets)
    [ -n "$BACKUP" ] && log "Moved your existing configs aside, to $BACKUP"

    local folded=()
    for pkg in "${PACKAGES[@]}"; do unfolded "$pkg" || folded+=("$pkg"); done
    log "Linking packages: ${PACKAGES[*]}"
    stow -d "$REPO/packages" -t "$HOME" --restow "${folded[@]}"
    stow -d "$REPO/packages" -t "$HOME" --restow --no-folding "${UNFOLDED[@]}"

    seed_defaults
    remember_folders
}

# readlink -f resolves every symlink on the way, so the repo's own path is
# resolved the same way before a link is compared with it. Otherwise a home
# or repo reached through a symlink (/home -> /var/home, say) makes vela's
# links look like someone else's, and every run would move them aside.
REAL="$(readlink -f "$REPO")"

# vela's own: a link into this repo, or anything reached through one -- an
# install old enough to have linked ~/.config/quickshell itself.
ours() { [[ "$(readlink -f "$1")" == "$REAL"/* ]]; }

# Everything at vela's paths that is not vela's goes aside, into one dated
# folder per run. Nothing is deleted.
BACKUP=""
move_aside() {
    if [ -z "$BACKUP" ]; then
        BACKUP="$HOME/.local/state/vela/backup-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$BACKUP"
    fi
    mkdir -p "$BACKUP/$(dirname "$1")"
    mv "$HOME/$1" "$BACKUP/$1"
}

# The folders of UNFOLDED packages that vela has made or unfolded, so a later
# run keeps them and what is yours in them -- after --unlink too, when no link
# of vela's is left inside to tell.
FOLDERS_RECORD="$HOME/.local/state/vela/folders"

# The folders named, or with none, every UNFOLDED package's.
remember_folders() {
    local pkg
    mkdir -p "$(dirname "$FOLDERS_RECORD")"
    {
        cat "$FOLDERS_RECORD" 2>/dev/null || true
        if [ "$#" -gt 0 ]; then
            printf '%s\n' "$@"
        else
            for pkg in "${UNFOLDED[@]}"; do tops "$pkg"; done
        fi
    } | sort -u >"$FOLDERS_RECORD.new"
    mv "$FOLDERS_RECORD.new" "$FOLDERS_RECORD"
}

vela_folder() {
    local l
    grep -qxF "$1" "$FOLDERS_RECORD" 2>/dev/null && return 0
    while IFS= read -r -d '' l; do
        ours "$l" && return 0
    done < <(find "$HOME/$1" -type l -print0 2>/dev/null)
    return 1
}

# Installs from before UNFOLDED had each of these folders as one link into
# the repo, so everything written in them -- your settings, every palette --
# was written into the repo. This turns such a link into a real folder:
# vela's files linked into it one by one, with the very links stow makes, and
# everything else in it copied across as it is, being yours. The folder is
# built beside the link and swapped in for it in one step, so nothing reading
# it (Hyprland, a running shell) finds it missing in between, and it holds
# the same files, so nothing changes under them either. Then the copies left
# in the repo go back to how the repo has them, or go, so an update can pull.
unfold() {
    local pkg="$1" top="$2" target="$HOME/$2" src tmp stowpath rel f up
    local mine=()
    tmp="$(dirname "$target")/.$(basename "$target").vela-unfold"
    # A run cut short between the two halves of the swap, or before the
    # repo was tidied after it: finish what it started.
    if [ ! -e "$target" ] && [ ! -L "$target" ] && [ -d "$tmp" ]; then
        mv "$tmp" "$target"
    fi
    if [ -f "$target/$PENDING" ]; then
        tidy_repo "$pkg" "$top"
        return 0
    fi
    src="$REAL/packages/$pkg/$top"
    [ -L "$target" ] && [ "$(readlink -f "$target")" = "$src" ] || return 0

    # What the repo has in this folder is vela's; the rest -- untracked,
    # ignored -- is yours, and so is anything in USER_FILES. In a copy of the
    # repo that is not a git clone, everything but USER_FILES is vela's.
    tracked_in "$pkg" "$top"
    stowpath="$(realpath --relative-to="$(readlink -f "$HOME")" "$REAL/packages")"

    rm -rf "$tmp"
    mkdir -p "$tmp"
    while IFS= read -r -d '' rel; do
        f="packages/$pkg/$top/$rel"
        if [ -d "$src/$rel" ] && [ ! -L "$src/$rel" ]; then
            mkdir -p "$tmp/$rel"
        elif ! is_user_file "$top/$rel" && { [ "$GIT" = 0 ] || [ -n "${TRACKED[$f]:-}" ]; }; then
            # Up to $HOME, then down into the package: stow's own link.
            up="$(dirname "$top/$rel" | awk -F/ '{ for (i = 1; i <= NF; i++) printf "%s..", (i > 1 ? "/" : "") }')"
            ln -s "$up/$stowpath/$pkg/$top/$rel" "$tmp/$rel"
        else
            cp -a "$src/$rel" "$tmp/$rel"
            mine+=("$rel")
        fi
    done < <(find "$src" -mindepth 1 -printf '%P\0')
    # What is left to tidy in the repo, kept in the folder itself until it
    # is done, so a run cut short anywhere after this is finished by the next.
    { [ "${#mine[@]}" -eq 0 ] || printf '%s\0' "${mine[@]}"; } >"$tmp/$PENDING"

    rm "$target"
    mv "$tmp" "$target"
    tidy_repo "$pkg" "$top"
}

# The copies unfold took across, as the repo has them again: a tracked one
# back to how it was committed, one the repo never had removed. Yours are in
# your home now.
PENDING=".vela-unfold-pending"

tidy_repo() {
    local pkg="$1" top="$2" src="$REAL/packages/$1/$2" rel f
    tracked_in "$pkg" "$top"
    while IFS= read -r -d '' rel; do
        f="packages/$pkg/$top/$rel"
        if [ -n "${TRACKED[$f]:-}" ]; then
            git -C "$REAL" checkout -q HEAD -- "$f"
        else
            rm -f "$src/$rel"
        fi
    done <"$HOME/$top/$PENDING"
    find "$src" -mindepth 1 -depth -type d -empty -delete
    rm "$HOME/$top/$PENDING"
    remember_folders "$top"
    # shellcheck disable=SC2088 # a path to show, not to use
    log "~/$top is a folder of its own now: your files in it, vela's linked in"
}

# The files the repo tracks in one package folder, into TRACKED; GIT is 0
# when the repo is not a git clone.
GIT=0
declare -A TRACKED=()
tracked_in() {
    local f
    TRACKED=()
    GIT=0
    git -C "$REAL" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
    GIT=1
    while IFS= read -r -d '' f; do
        TRACKED["$f"]=1
    done < <(git -C "$REAL" ls-files -z -- "packages/$1/$2")
}

unfold_all() {
    local pkg top
    for pkg in "${UNFOLDED[@]}"; do
        while IFS= read -r top; do
            unfold "$pkg" "$top"
        done < <(tops "$pkg")
    done
}

# Your files, the first time: the settings vela starts you with, Hyprland's
# idle times, and a palette that works before a wallpaper has made one.
# Copied from defaults/, never linked, and never over a file that is there:
# from then on each is yours, and no update touches it.
seed_defaults() {
    [ -d "$REPO/defaults" ] || return 0
    local rel seeded=()
    while IFS= read -r rel; do
        rel="${rel#./}"
        # A link from when this file was in the repo, left dangling.
        if [ -L "$HOME/$rel" ] && [ ! -e "$HOME/$rel" ] && ours "$HOME/$rel"; then
            rm "$HOME/$rel"
        fi
        [ -e "$HOME/$rel" ] || [ -L "$HOME/$rel" ] && continue
        mkdir -p "$HOME/$(dirname "$rel")"
        cp "$REPO/defaults/$rel" "$HOME/$rel"
        # shellcheck disable=SC2088 # a path to show, not to use
        seeded+=("~/$rel")
    done < <(cd "$REPO/defaults" && find . -type f | sort)
    [ "${#seeded[@]}" -eq 0 ] || log "Your own copies, yours to change: ${seeded[*]}"
}

# Your own files stay where they are: settings, palette, idle times.
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
    --matugen) install_matugen ;;
    --unfold)  unfold_all ;;
    "")       install_packages; link
              log "Done. Set a wallpaper to generate the palette:"
              printf '\n    vela wallpaper ~/Pictures/Wallpapers/your-wallpaper.png\n    vela shell start\n\n' ;;
    *)        die "unknown option: $1" ;;
esac

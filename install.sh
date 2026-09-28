#!/usr/bin/env bash
# Install vela on Fedora in one line:
#
#   curl -fsSL https://raw.githubusercontent.com/i-jasmin/vela-dots/main/install.sh | bash
#
# It clones the repo to ~/.local/share/vela-dots, installs the packages
# (bootstrap.sh), links the configs into place -- moving anything already
# there aside, never deleting it -- sets a first wallpaper so the palette
# exists, and checks the result with `vela doctor`. Run it again to update.
# ~/.local/state/vela/install.log keeps the steps and anything that went
# wrong, dnf's warnings included, for after the terminal has scrolled away.
#
# Settings, all optional:
#
#   VELA_DIR=~/src/vela-dots   where the repo lives (links point into it, so
#                              it has to stay where it is)
#   VELA_BRANCH=main           the branch to install
#   VELA_REPO=<url>            a fork, or a local clone
#   VELA_SKIP_PACKAGES=1       link only, install nothing
#
#   curl -fsSL .../install.sh | VELA_DIR=~/src/vela-dots bash
set -euo pipefail

REPO_URL="${VELA_REPO:-https://github.com/i-jasmin/vela-dots.git}"
DEST="${VELA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/vela-dots}"
BRANCH="${VELA_BRANCH:-main}"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/vela"
LOG="$STATE/install.log"

if [ -t 1 ]; then
    B=$'\033[1m' M=$'\033[1;35m' Y=$'\033[1;33m' R=$'\033[1;31m' G=$'\033[1;32m' N=$'\033[0m'
else
    B="" M="" Y="" R="" G="" N=""
fi
# Each step and warning also goes into install.log, once main() has started
# it; bootstrap.sh does the same through VELA_INSTALL_LOG.
record() { if [ -n "${VELA_INSTALL_LOG:-}" ]; then printf '%s\n' "$1" >>"$VELA_INSTALL_LOG"; fi; }
log()  { printf '%s::%s %s\n' "$M" "$N" "$1"; record ":: $1"; }
warn() { printf '%s!!%s %s\n' "$Y" "$N" "$1" >&2; record "!! $1"; }
die()  { printf '%sxx%s %s\n' "$R" "$N" "$1" >&2; record "xx $1"; exit 1; }

# dnf's part of the record, copied from its own log when the install ends,
# however it ends: each dnf command run since $1, and its warnings, errors
# and failed downloads -- the red lines among its progress bars, a mirror
# that timed out before it moved on to the next. Copied rather than caught
# as they happen, so dnf keeps the terminal and draws its progress as usual.
# dnf writes its log in UTC, whatever the local time zone.
finish_log() {
    [ -n "${VELA_INSTALL_LOG:-}" ] || return 0
    local files=() f lines
    for f in /var/log/dnf5.log.1 /var/log/dnf5.log; do [ -r "$f" ] && files+=("$f"); done
    [ "${#files[@]}" -gt 0 ] || return 0
    lines="$(awk -v t="$1" 'substr($1, 1, 19) >= t && (/DNF5 launched with arguments/ || / (WARNING|ERROR|CRITICAL) / || /\[librepo\] Error/)' "${files[@]}" || true)"
    if [ -n "$lines" ]; then
        printf '\n-- from dnf'"'"'s own log, /var/log/dnf5.log (times in UTC) --\n%s\n' "$lines" >>"$VELA_INSTALL_LOG"
    fi
}

# Everything runs from main(), called on the last line: piped from curl, bash
# would otherwise start running the script before it had all arrived, and a
# download cut short could run half of it.
main() {
    # ---- is this a machine vela can go on ------------------------------------------

    [ "$(id -u)" -ne 0 ] || die "run this as your own user, not root: it asks for sudo when it needs it."

    mkdir -p "$STATE"
    export VELA_INSTALL_LOG="$LOG"
    printf 'vela install, %s\n\n' "$(date)" >"$LOG"
    local started
    started="$(date -u +%Y-%m-%dT%H:%M:%S)"
    # shellcheck disable=SC2064 # $started is fixed now, on purpose
    trap "finish_log '$started'" EXIT

    [ -r /etc/os-release ] || die "no /etc/os-release; vela is for Fedora."
    # shellcheck disable=SC1091
    . /etc/os-release
    case "${ID:-}" in
        fedora) ;;
        *)
            if [[ " ${ID_LIKE:-} " == *" fedora "* ]]; then
                warn "${NAME:-this system} is Fedora-based, not Fedora. vela is only tested on Fedora; carrying on."
            else
                die "vela is for Fedora, and this is ${PRETTY_NAME:-something else}."
            fi
            ;;
    esac
    command -v dnf >/dev/null || die "no dnf found."
    if [ "${VERSION_ID:-0}" != "rawhide" ] && [ "${VERSION_ID:-0}" -lt 42 ] 2>/dev/null; then
        warn "Fedora ${VERSION_ID} is older than vela is tested on (42 and newer); some packages may not exist for it."
    fi

    # Asked once, up front, so the rest does not stop halfway for a password. sudo
    # reads it from the terminal even though this script arrives on a pipe.
    if [ "${VELA_SKIP_PACKAGES:-0}" != 1 ]; then
        log "Some steps need sudo (dnf, and enabling the COPR repositories)"
        sudo -v || die "sudo is needed to install packages; or run with VELA_SKIP_PACKAGES=1 to link only."
    fi

    # ---- the repo -----------------------------------------------------------------

    if ! command -v git >/dev/null; then
        [ "${VELA_SKIP_PACKAGES:-0}" != 1 ] || die "git is not installed."
        log "Installing git"
        sudo dnf install -y git
    fi

    if [ -d "$DEST/.git" ]; then
        log "Updating $DEST"
        if ! git -C "$DEST" pull --ff-only --quiet origin "$BRANCH"; then
            die "could not update $DEST (local changes, or a different history). Sort it out there with git, then run this again."
        fi
    elif [ -e "$DEST" ]; then
        die "$DEST exists and is not a git clone. Move it away, or set VELA_DIR to somewhere else."
    else
        log "Cloning vela into $DEST"
        mkdir -p "$(dirname "$DEST")"
        git clone --quiet --branch "$BRANCH" "$REPO_URL" "$DEST"
    fi

    # ---- packages and links ---------------------------------------------------------

    if [ "${VELA_SKIP_PACKAGES:-0}" = 1 ]; then
        "$DEST/bootstrap.sh" --link
    else
        "$DEST/bootstrap.sh" --packages
        "$DEST/bootstrap.sh" --link
    fi

    VELA="$DEST/packages/bin/.local/bin/vela"

    # ---- a first wallpaper ----------------------------------------------------------
    #
    # The palette every config reads is generated from the wallpaper, and there is
    # none yet on a fresh account. The ones that come with vela go into the
    # wallpaper folder only if it has no images of its own.
    if [ ! -f "$STATE/colours.json" ]; then
        walls="$HOME/Pictures/Wallpapers"
        mkdir -p "$walls"
        if ! find "$walls" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | grep -q .; then
            cp "$DEST"/wallpapers/*.jpg "$walls"/
        fi
        first="$(find "$walls" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | sort | head -1)"
        log "Generating the palette from $(basename "$first")"
        "$VELA" wallpaper "$first" >/dev/null 2>&1 || warn "could not generate the palette yet; after logging in, run: vela wallpaper \"$first\""
    fi

    # ---- how it went -----------------------------------------------------------------

    echo
    "$VELA" doctor || true

    # A graphics card the open driver cannot run: point at the driver rather than
    # install one blind -- it needs RPM Fusion, and Secure Boot has its own step.
    nvidia=0
    for dev in /sys/bus/pci/devices/*; do
        [ "$(cat "$dev/vendor" 2>/dev/null)" = 0x10de ] || continue
        case "$(cat "$dev/class" 2>/dev/null)" in 0x03*) nvidia=1 ;; esac
    done
    if [ "$nvidia" = 1 ] && ! modinfo nvidia >/dev/null 2>&1; then
        echo
        warn "This machine has an NVIDIA GPU and no NVIDIA driver. Hyprland runs best with it:"
        printf '     sudo dnf install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %%fedora).noarch.rpm \\\n'
        printf '                      https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %%fedora).noarch.rpm\n'
        printf '     sudo dnf install akmod-nvidia\n'
        printf '     (with Secure Boot on, see https://rpmfusion.org/Howto/Secure%%20Boot first)\n'
    fi

    echo
    printf '%sDone.%s ' "$G" "$N"
    if systemctl is-enabled --quiet gdm sddm lightdm greetd 2>/dev/null; then
        printf 'Log out, and pick %sHyprland%s on the login screen (the gear or session menu).\n' "$B" "$N"
    else
        printf 'There is no login screen to pick a session from: start %sHyprland%s from a console with `Hyprland`.\n' "$B" "$N"
    fi
    printf 'Inside, %ssuper + /%s (super + < on some layouts) shows every keybind.\n' "$B" "$N"
    printf 'Docs: https://i-jasmin.github.io/vela-dots\n'
    printf 'A record of this install, with any warnings: %s\n' "${LOG/#$HOME/\~}"
}

main "$@"

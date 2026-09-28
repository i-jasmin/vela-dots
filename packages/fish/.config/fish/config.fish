# vela -- fish
#
# The shell kitty opens (kitty.conf). The login shell stays whatever
# /etc/passwd says (bash, on a stock Fedora), set up alike by
# ~/.bashrc.d/vela.sh; nothing here changes that, and nothing here assumes a
# tool is installed. `chsh -s (which fish)` makes fish the login shell too.
#
# Fish sources this file for every shell, including non-interactive ones that
# scripts and editors spawn, so everything that prints, prompts or costs time
# lives inside the `status is-interactive` block.

# ~/.local/bin holds the `vela` command. -g so it is there for scripts too,
# and fish_add_path is idempotent, so no duplicate entries on every shell.
fish_add_path -g "$HOME/.local/bin"

if status is-interactive
    # The greeting is functions/fish_greeting.fish: `vela greet`.

    # ----------------------------------------------------------- prompt --
    # starship, if it is installed. The TERM check keeps a TTY (no font, no
    # colours) readable -- powerline glyphs there are just boxes.
    if type -q starship; and test "$TERM" != linux
        starship init fish | source
    end

    # Alt+S puts sudo in front of the line you already typed, or of the last
    # command when the line is empty -- the other half of the `sudo !!` habit.
    bind \es __vela_prepend_sudo

    # ------------------------------------------------------- navigation --
    abbr -a -- .. 'cd ..'
    abbr -a -- ... 'cd ../..'
    abbr -a -- .... 'cd ../../..'
    abbr -a md 'mkdir -p'
    abbr -a o xdg-open

    # -------------------------------------------------------------- git --
    abbr -a g git
    abbr -a gs 'git status --short --branch'
    abbr -a ga 'git add'
    abbr -a gaa 'git add --all'
    abbr -a gc 'git commit --verbose'
    abbr -a gca 'git commit --verbose --amend'
    abbr -a gco 'git checkout'
    abbr -a gsw 'git switch'
    abbr -a gd 'git diff'
    abbr -a gds 'git diff --staged'
    abbr -a gl 'git pull'
    abbr -a gp 'git push'
    abbr -a glog 'git log --oneline --graph --decorate -20'

    # ------------------------------------------------------------ vela --
    abbr -a v vela
    abbr -a vw 'vela wallpaper'
    abbr -a vr 'vela shell restart'
    abbr -a vlog 'vela shell log'
    abbr -a vipc 'qs -c vela ipc show'
    abbr -a hb 'hyprctl binds'
    abbr -a hc 'hyprctl clients'
    abbr -a hm 'hyprctl monitors'

    # ------------------------------------------------------- dnf, fedora --
    abbr -a dnfi 'sudo dnf install'
    abbr -a dnfr 'sudo dnf remove'
    abbr -a dnfu 'sudo dnf upgrade'
    abbr -a dnfs 'dnf search'
    abbr -a dnfq 'rpm -qf'

    # ------------------------------------------------ nicer defaults, if --
    # ------------------------------------------------ the tool is there  --
    if type -q eza
        alias ls 'eza --icons=auto --group-directories-first'
        alias ll 'eza --icons=auto --group-directories-first -l --git'
        alias la 'eza --icons=auto --group-directories-first -la --git'
        alias lt 'eza --icons=auto --tree --level=2'
    else
        alias ll 'ls -lh'
        alias la 'ls -lAh'
    end

    if type -q bat
        alias cat bat
    end

    # kitty leaves the scrollback behind on ctrl+l; wipe it properly.
    if test "$TERM" = xterm-kitty
        alias clear "printf '\033[2J\033[3J\033[1;1H'"
        type -q kitten; and alias ssh 'kitten ssh'
    end
end

# Run a single command on the NVIDIA dGPU instead of the Intel iGPU.
#
#   nv glxinfo -B
#   nv blender
#
# This is the per-app alternative to setting __GLX_VENDOR_LIBRARY_NAME
# globally, which on a hybrid laptop wakes the discrete card for everything
# and breaks screen sharing (see ~/.config/hypr/conf/env.lua).
function nv --description 'Run a command on the NVIDIA GPU (PRIME offload)'
    if not test -e /sys/module/nvidia/version
        echo "nv: no NVIDIA driver loaded" >&2
        return 1
    end
    __NV_PRIME_RENDER_OFFLOAD=1 \
        __GLX_VENDOR_LIBRARY_NAME=nvidia \
        __VK_LAYER_NV_optimus=NVIDIA_only \
        VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.x86_64.json \
        $argv
end

# mkdir and cd into it.
function mkcd --description 'Create a directory and enter it'
    mkdir -p -- $argv[1]; and cd -- $argv[1]
end

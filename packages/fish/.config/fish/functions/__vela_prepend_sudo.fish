function __vela_prepend_sudo --description "Prefix the command line with sudo"
    set -l line (commandline)
    if test -z "$line"
        set line $history[1]
    end
    test -z "$line"; and return

    if string match -qr '^sudo ' -- $line
        commandline -r (string replace -r '^sudo ' '' -- $line)
    else
        commandline -r "sudo $line"
    end
    commandline -f end-of-line
end

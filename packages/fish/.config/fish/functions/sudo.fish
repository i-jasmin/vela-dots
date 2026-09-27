function sudo --wraps sudo --description "sudo, with !! meaning the previous command"
    # fish has no history expansion, so `sudo !!` -- muscle memory from bash --
    # otherwise runs sudo against a file literally named "!!". This wrapper
    # substitutes the last command instead.
    if test (count $argv) -gt 0; and test "$argv[1]" = "!!"
        set -l previous $history[1]
        if test -z "$previous"
            echo "sudo: no previous command in history" >&2
            return 1
        end
        # Show what is about to run: silently escalating a command you only
        # half-remember typing is how accidents happen.
        echo "sudo $previous"
        eval command sudo $previous $argv[2..-1]
    else
        command sudo $argv
    end
end

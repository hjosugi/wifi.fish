function wifi --description 'Pick a Wi-Fi network with fzf and connect to it'
    switch "$argv[1]"
        case -h --help help
            echo 'Usage: wifi         pick a nearby network and connect to it'
            echo '       wifi auto    pick saved networks; enter toggles auto-connect,'
            echo '                    ctrl-p makes them the preferred ones'
            return 0
        case '' auto
        case '*'
            echo "wifi: unknown command: $argv[1] (see wifi --help)" >&2
            return 2
    end

    for dependency in nmcli fzf
        if not command -q $dependency
            echo "wifi: needs $dependency" >&2
            return 1
        end
    end

    if test "$argv[1]" = auto
        _wifi_auto
        return
    end

    # The list opens at once from NetworkManager's last scan. A fresh scan
    # starts as soon as it is loaded and replaces it when done, a few seconds
    # later; ctrl-r scans again. fzf runs the scan with $SHELL, which may not
    # be fish, so the command finds fish and _wifi_list through the
    # environment and quotes the same way in sh and in fish.
    set -lx __wifi_fish (status fish-path)
    set -lx __wifi_list_file (functions --details _wifi_list)
    set -l rescan '"$__wifi_fish" --no-config -c \'source "$__wifi_list_file"; _wifi_list --rescan\''

    set -l choice (_wifi_list | fzf \
        --height 60% \
        --reverse \
        --prompt 'wifi> ' \
        --header 'enter: connect   ctrl-r: scan again' \
        --delimiter \t \
        --with-nth 1 \
        --bind "load:reload-sync($rescan)+unbind(load)" \
        --bind "ctrl-r:reload-sync($rescan)")
    or return

    set -l ssid (string split --max 1 \t -- $choice)[2]
    if test (string sub --length 1 -- $choice) = '*'
        echo "wifi: already connected to $ssid"
        return 0
    end

    # nmcli reuses a saved connection for the SSID; --ask prompts for the
    # password only when there is none.
    nmcli --ask device wifi connect $ssid
end

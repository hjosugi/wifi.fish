function _wifi_list --description 'Print nearby Wi-Fi networks for wifi, one line per SSID'
    # Without --rescan nmcli answers at once from NetworkManager's last scan;
    # with it nmcli waits a few seconds for a fresh one. A refused or failed
    # scan falls back to the last one instead of printing nothing, which would
    # empty the list fzf is showing.
    set -l lines
    if contains -- --rescan $argv
        set lines (nmcli --terse --escape no --fields IN-USE,SIGNAL,BARS,SECURITY,SSID \
            device wifi list --rescan yes 2>/dev/null)
    end
    if test (count $lines) -eq 0
        set lines (nmcli --terse --escape no --fields IN-USE,SIGNAL,BARS,SECURITY,SSID \
            device wifi list --rescan no 2>/dev/null)
    end

    # SSID is the last field, so a colon inside it stays in it. nmcli lists
    # the connected network first and the rest strongest first; a network seen
    # on both bands or through several access points repeats, and only its
    # first line is kept. Hidden networks have no SSID to connect by.
    set -l seen
    for line in $lines
        set -l field (string split --max 4 : -- $line)
        set -l ssid $field[5]
        if test -z "$ssid"; or contains -- $ssid $seen
            continue
        end
        set -a seen $ssid

        set -l mark ' '
        if test "$field[1]" = '*'
            set mark '*'
        end
        set -l security $field[4]
        if test -z "$security"; or test "$security" = --
            set security open
        end

        # What fzf shows, a tab, then the SSID that wifi connects to.
        printf '%s %s %3s%%  %-12s %s\t%s\n' $mark $field[3] $field[2] $security $ssid $ssid
    end
end

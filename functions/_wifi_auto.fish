function _wifi_auto --description 'Choose which saved Wi-Fi networks join automatically'
    # Of the saved networks in range with auto-connect on, NetworkManager
    # joins the one with the highest priority (0 unless set; on a tie, the
    # one it used last).
    set -l rows
    for line in (nmcli --terse --escape no \
            --fields TYPE,AUTOCONNECT,AUTOCONNECT-PRIORITY,UUID,NAME connection show)
        set -l field (string split --max 4 : -- $line)
        test "$field[1]" = 802-11-wireless; or continue
        set -l state off
        if test "$field[2]" = yes
            set state on
        end
        # What fzf shows, then UUID, state, priority and name, tab-separated.
        set -a rows (printf '%-3s %4s  %s\t%s\t%s\t%s\t%s' \
            $state $field[3] $field[5] $field[4] $state $field[3] $field[5])
    end
    if test (count $rows) -eq 0
        echo 'wifi: no saved Wi-Fi networks' >&2
        return 1
    end

    # With --expect the first line is the key that closed fzf, empty for
    # enter; the rest are the chosen rows in the order they were chosen.
    set -l out (printf '%s\n' $rows | fzf \
        --height 60% \
        --reverse \
        --multi \
        --prompt 'auto> ' \
        --header 'tab: choose   enter: toggle auto-connect   ctrl-p: prefer' \
        --delimiter \t \
        --with-nth 1 \
        --expect ctrl-p)
    or return
    set -l key $out[1]
    set -l chosen $out[2..-1]

    if test "$key" != ctrl-p
        for row in $chosen
            set -l field (string split \t -- $row)
            set -l new yes
            set -l label on
            if test $field[3] = on
                set new no
                set label off
            end
            nmcli connection modify $field[2] connection.autoconnect $new
            and echo "$field[5]: auto-connect $label"
        end
        return
    end

    # The chosen networks go above every other saved one, the first chosen
    # highest, with auto-connect on. The maximum leaves the chosen ones out,
    # so preferring the same network again does not keep raising it.
    set -l chosen_uuids
    for row in $chosen
        set -a chosen_uuids (string split \t -- $row)[2]
    end
    set -l top
    for row in $rows
        set -l field (string split \t -- $row)
        contains -- $field[2] $chosen_uuids; and continue
        if test -z "$top"; or test $field[4] -gt $top
            set top $field[4]
        end
    end
    test -n "$top"; or set top 0

    set -l n (count $chosen)
    for row in $chosen
        set -l field (string split \t -- $row)
        # NetworkManager accepts priorities up to 999.
        set -l priority (math "min($top + $n, 999)")
        nmcli connection modify $field[2] \
            connection.autoconnect yes connection.autoconnect-priority $priority
        and echo "$field[5]: auto-connect on, priority $priority"
        set n (math $n - 1)
    end
end

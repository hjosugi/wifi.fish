# Run with `fish tests/wifi.fish`. nmcli and fzf are replaced by functions,
# so no Wi-Fi device or terminal is needed: the nmcli stub prints fixtures and
# records every `connection modify` and `device wifi connect`, and the fzf stub
# answers with whatever $fzf_answer holds.

set -l root (path resolve (status dirname)/..)
set -p fish_function_path $root/functions

# wifi checks that both commands exist before it runs them.
set -l bin (mktemp -d)
for name in nmcli fzf
    printf '#!/bin/sh\nexit 1\n' >$bin/$name
    chmod +x $bin/$name
end
set -gx PATH $bin $PATH

set -g failures 0
function check -a name expected actual
    if test "$expected" = "$actual"
        echo "ok   $name"
    else
        echo "FAIL $name"
        echo "     expected: "(string escape -- $expected)
        echo "     actual:   "(string escape -- $actual)
        set failures (math $failures + 1)
    end
end

set -g scan_cached \
    '*:72:▂▄▆_:WPA2:home' \
    ' :90:▂▄▆█:WPA2 WPA3:home' \
    ' :64:▂▄▆_:WPA2 802.1X:office:5G' \
    ' :40:▂▄__::cafe' \
    ' :35:▂▄__:--:station' \
    ' :30:▂___:WPA2:'
set -g scan_fresh ' :80:▂▄▆█:WPA3:fresh'
set -g scan_fails 0
set -g saved \
    '802-11-wireless:yes:0:u-home:home' \
    'loopback:yes:0:u-lo:lo' \
    '802-11-wireless:no:5:u-office:office:5G' \
    '802-11-wireless:yes:3:u-cafe:cafe'
set -g calls

function nmcli
    if contains -- connection $argv; and contains -- show $argv
        printf '%s\n' $saved
    else if contains -- list $argv
        if contains -- yes $argv
            test $scan_fails = 1; and return 1
            printf '%s\n' $scan_fresh
        else
            printf '%s\n' $scan_cached
        end
    else
        set -a calls (string join ' ' -- $argv)
    end
end

set -g fzf_answer
function fzf
    cat >/dev/null
    test (count $fzf_answer) -gt 0; or return 130
    printf '%s\n' $fzf_answer
end

# _wifi_list
set -l list (_wifi_list)
check 'one line per SSID, hidden left out' 4 (count $list)
check 'connected network marked' (printf '* ▂▄▆_  72%%  WPA2         home\thome') $list[1]
check 'colon inside an SSID kept' office:5G (string split \t -- $list[2])[2]
check 'no security shown as open' (printf '  ▂▄__  40%%  open         cafe\tcafe') $list[3]
check '-- shown as open' (printf '  ▂▄__  35%%  open         station\tstation') $list[4]
check 'rescan lists the fresh scan' fresh (string split \t -- (_wifi_list --rescan))[2]
set scan_fails 1
check 'failed rescan falls back to the last scan' 4 (count (_wifi_list --rescan))
set scan_fails 0

# wifi
wifi --help >/dev/null
check 'help exits 0' 0 $status
wifi nope 2>/dev/null
check 'unknown command exits 2' 2 $status

set calls
set fzf_answer (_wifi_list)[2]
wifi >/dev/null
check 'connects to the chosen SSID' '--ask device wifi connect office:5G' "$calls"

set calls
set fzf_answer (_wifi_list)[1]
check 'connected network is left alone' 'wifi: already connected to home' (wifi)
check 'no nmcli call for it' '' "$calls"

set calls
set fzf_answer
wifi
check 'escape exits non-zero' 130 $status
check 'escape connects nothing' '' "$calls"

# wifi auto: rows are "state priority  name<TAB>uuid<TAB>state<TAB>priority<TAB>name"
function row -a uuid state priority name
    printf '%-3s %4s  %s\t%s\t%s\t%s\t%s' $state $priority $name $uuid $state $priority $name
end

set calls
set fzf_answer '' (row u-home on 0 home) (row u-office off 5 office:5G)
set -l out (wifi auto)
check 'enter toggles each chosen network' \
    'connection modify u-home connection.autoconnect no|connection modify u-office connection.autoconnect yes' \
    (string join '|' -- $calls)
check 'toggle reports both' 'home: auto-connect off|office:5G: auto-connect on' (string join '|' -- $out)

set calls
set fzf_answer ctrl-p (row u-home on 0 home)
wifi auto >/dev/null
check 'ctrl-p goes above the others' \
    'connection modify u-home connection.autoconnect yes connection.autoconnect-priority 6' "$calls"

set calls
set fzf_answer ctrl-p (row u-cafe on 3 cafe) (row u-home on 0 home)
wifi auto >/dev/null
check 'ctrl-p orders several by choice' \
    'connection modify u-cafe connection.autoconnect yes connection.autoconnect-priority 7|connection modify u-home connection.autoconnect yes connection.autoconnect-priority 6' \
    (string join '|' -- $calls)

set calls
set fzf_answer ctrl-p (row u-office off 5 office:5G)
wifi auto >/dev/null
check 'ctrl-p ignores its own priority' \
    'connection modify u-office connection.autoconnect yes connection.autoconnect-priority 4' "$calls"

rm -r $bin
if test $failures -gt 0
    echo "$failures failed"
    exit 1
end
echo 'all passed'

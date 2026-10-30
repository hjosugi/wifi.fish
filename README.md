# wifi.fish

Pick a Wi-Fi network with fzf and connect to it, and choose which saved
networks join automatically. A [fish](https://fishshell.com) plugin for
NetworkManager.

```
wifi>
  enter: connect   ctrl-r: scan again
* ▂▄▆█ 100%  WPA2 WPA3    home
  ▂▄▆_  64%  WPA2         office
  ▂▄__  40%  open         cafe
```

## Install

```fish
fisher install hjosugi/wifi.fish
```

Needs `nmcli` (NetworkManager) and [fzf](https://github.com/junegunn/fzf)
0.36 or newer.

## Usage

### `wifi`

Lists the networks in range and connects to the one you pick. The list opens
at once from NetworkManager's last scan, and a fresh scan replaces it a few
seconds later; `ctrl-r` scans again. Each SSID appears once, strongest first,
with the connected one marked `*`. A saved network connects as it is; a new
one asks for its password.

### `wifi auto`

Lists the saved networks with their auto-connect state and priority.

- `enter` toggles auto-connect on the highlighted network, or on every network
  chosen with `tab`.
- `ctrl-p` makes the chosen networks the preferred ones: auto-connect on and a
  priority above every other saved network, the first chosen highest.

When several saved networks are in range, NetworkManager joins the one with the
highest priority. Preferring the router's own network over a range extender's,
for example, keeps a machine off the extender whenever the router is in reach.

## Tests

```fish
fish tests/wifi.fish
```

`nmcli` and `fzf` are stubbed, so the tests need neither a Wi-Fi device nor a
terminal.

## License

[MIT](LICENSE)

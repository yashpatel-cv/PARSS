# dmenu (Dynamic Menu)

dmenu is the application launcher and general-purpose selection menu used by PARSS.

## Launching

Press `Super + d` to open dmenu for launching applications.

## Usage

1. Start typing the program name
2. Use arrow keys or `Ctrl + n/p` to navigate
3. Press `Enter` to launch
4. Press `Escape` to cancel

## Keybindings

| Key | Action |
|-----|--------|
| `Ctrl + n` / `Down` | Next item |
| `Ctrl + p` / `Up` | Previous item |
| `Tab` | Autocomplete |
| `Ctrl + y` | Paste from clipboard |
| `Ctrl + Enter` | Print selection without closing |
| `Enter` | Select and execute |
| `Escape` | Cancel |

## Special dmenu Scripts

PARSS includes several dmenu-based scripts:

| Script | Shortcut | Purpose |
|--------|----------|---------|
| `dmenuunicode` | `Super + '` | Select emoji/unicode characters |
| `dmenurecord` | `Super + Print` | Screen recording options |
| `dmenupass` | `Super + Shift + d` | Password manager (pass) |
| `dmenumount` | `Super + F9` | Mount USB/external drives |
| `dmenuumount` | `Super + F10` | Unmount drives |
| `displayselect` | `Super + F3` | Multi-monitor configuration |
| `maimpick` | `Shift + Print` | Screenshot options |

## Customization

### Colors (via Xresources)

Edit `~/.config/x11/xresources`:

```
dmenu.font: monospace:size=10
dmenu.background: #000000
dmenu.foreground: #bdbdbd
dmenu.selbackground: #80a0ff
dmenu.selforeground: #000000
```

### Source Code Changes

For deeper customization:

```bash
cd ~/.local/src/dmenu
# Edit config.h
sudo make clean install
```

## Source Code

- [dmenu for LARBS/archrice](https://github.com/lukesmithxyz/dmenu)
- [Original dmenu](https://tools.suckless.org/dmenu/)

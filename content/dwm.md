# dwm (Dynamic Window Manager)

dwm is the window manager used by PARSS. It automatically tiles windows and is controlled entirely by keyboard.

## Launching

dwm starts automatically when you run `startx` after login.

## Basic Concepts

- **Master/Stack Layout**: One large "master" window on the left, other windows "stacked" on the right
- **Tags**: Like workspaces, but windows can be on multiple tags
- **Floating**: Windows can be floated (like traditional WMs) or tiled

## All Keybindings

### Window Management

| Key | Action |
|-----|--------|
| `Super + Enter` | Open terminal (st) |
| `Super + q` | Close focused window |
| `Super + j` | Focus next window |
| `Super + k` | Focus previous window |
| `Super + h` | Decrease master area size |
| `Super + l` | Increase master area size |
| `Super + Space` | Toggle focused window floating |
| `Super + Shift + Space` | Toggle all windows floating |
| `Super + s` | Toggle sticky (window visible on all tags) |
| `Super + f` | Toggle fullscreen |
| `Super + b` | Toggle status bar |

### Layout Control

| Key | Action |
|-----|--------|
| `Super + t` | Tiling layout (master/stack) |
| `Super + Shift + t` | Bottom stack layout |
| `Super + y` | Fibonacci spiral layout |
| `Super + Shift + y` | Fibonacci dwindle layout |
| `Super + u` | Centered master layout |
| `Super + Shift + u` | Centered floating master |
| `Super + i` | Increase number of master windows |
| `Super + Shift + i` | Decrease number of master windows |
| `Super + o` | Increase gaps |
| `Super + Shift + o` | Decrease gaps |
| `Super + a` | Toggle gaps |
| `Super + Shift + a` | Reset gaps to default |

### Tags (Workspaces)

| Key | Action |
|-----|--------|
| `Super + 1-9` | Switch to tag 1-9 |
| `Super + Shift + 1-9` | Move window to tag 1-9 |
| `Super + Tab` | Switch to previous tag |
| `Super + 0` | View all tags |
| `Super + Shift + 0` | Make window visible on all tags |
| `Super + g` | Go to tag with urgent window |

### Multi-Monitor

| Key | Action |
|-----|--------|
| `Super + .` | Focus next monitor |
| `Super + ,` | Focus previous monitor |
| `Super + Shift + .` | Move window to next monitor |
| `Super + Shift + ,` | Move window to previous monitor |

### Program Launchers

| Key | Action |
|-----|--------|
| `Super + d` | dmenu (application launcher) |
| `Super + r` | lf (file manager) |
| `Super + e` | neovim (text editor) |
| `Super + w` | Librewolf (web browser) |
| `Super + m` | ncmpcpp (music player) |
| `Super + n` | newsboat (RSS reader) |
| `Super + Shift + n` | nmtui (network manager) |
| `Super + Shift + w` | nmtui WiFi selection |
| `Super + c` | calcurse (calendar) |
| `Super + Shift + Enter` | Show/hide scratchpad terminal |
| `Super + '` | Show/hide calculator scratchpad |

### Media/Audio

| Key | Action |
|-----|--------|
| `Super + -` | Volume down 5% |
| `Super + Shift + -` | Volume down 15% |
| `Super + =` | Volume up 5% |
| `Super + Shift + =` | Volume up 15% |
| `Super + Shift + m` | Mute audio |
| `Super + p` | Pause/play mpd music |
| `Super + .` | Next track |
| `Super + ,` | Previous track |
| `Super + [` | Seek back 10 seconds |
| `Super + ]` | Seek forward 10 seconds |
| `Super + Shift + [` | Seek back 1 minute |
| `Super + Shift + ]` | Seek forward 1 minute |

### Screenshots & Recording

| Key | Action |
|-----|--------|
| `Print` | Screenshot selection |
| `Shift + Print` | Screenshot menu (maimpick) |
| `Super + Print` | Record screen (dmenurecord) |
| `Super + Delete` | Stop recording |
| `Super + Scroll Lock` | Toggle screenkey |

### System

| Key | Action |
|-----|--------|
| `Super + F1` | Show keybindings help |
| `Super + F2` | Watch tutorial videos |
| `Super + F3` | Display select (multi-monitor) |
| `Super + F4` | Suspend/hibernate menu |
| `Super + F9` | Mount USB/external drives |
| `Super + F10` | Unmount drives |
| `Super + F11` | View webcam |
| `Super + F12` | Rerun keyboard remaps |
| `Super + Backspace` | System power menu |
| `Super + Shift + Backspace` | Force kill dwm |
| `Super + Shift + q` | Quit dwm |
| `Super + x` | Lock screen (slock) |
| `Super + Shift + x` | Shutdown menu |

### Clipboard & Utilities

| Key | Action |
|-----|--------|
| `Super + Insert` | Show clipboard contents |
| `Super + Shift + d` | passmenu (password manager) |
| `Super + `\`` | Select emoji/unicode |
| `Super + Shift + `\`` | Insert emoji |

## Customization

Edit `~/.local/src/dwm/config.h` and rebuild:

```bash
cd ~/.local/src/dwm
sudo make clean install
```

Then restart dwm with `Super + Shift + q`.

## Source Code

- [dwm for LARBS/archrice](https://github.com/lukesmithxyz/dwm)
- [Original dwm](https://dwm.suckless.org)

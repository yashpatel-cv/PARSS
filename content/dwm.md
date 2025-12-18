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
| `Super + J` | Move window down in stack |
| `Super + K` | Move window up in stack |
| `Super + h` | Decrease master area size |
| `Super + l` | Increase master area size |
| `Super + Space` | Swap focused window with master |
| `Super + Shift + Space` | Toggle floating for focused window |
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
| `Super + u` | Deck layout |
| `Super + Shift + u` | Monocle layout (fullscreen stack) |
| `Super + i` | Centered master layout |
| `Super + Shift + i` | Centered floating master layout |
| `Super + Shift + f` | Floating layout |
| `Super + o` | Increase number of master windows |
| `Super + Shift + o` | Decrease number of master windows |

### Gaps

| Key | Action |
|-----|--------|
| `Super + a` | Toggle gaps on/off |
| `Super + Shift + a` | Reset gaps to default |
| `Super + z` | Increase gap size |
| `Super + x` | Decrease gap size |
| `Super + Shift + '` | Toggle smart gaps |

### Tags (Workspaces)

| Key | Action |
|-----|--------|
| `Super + 1-9` | Switch to tag 1-9 |
| `Super + Shift + 1-9` | Move window to tag 1-9 |
| `Super + 0` | View all tags |
| `Super + Shift + 0` | Make window visible on all tags |
| `Super + Tab` | Switch to previous tag |
| `Super + \` | Switch to previous tag |
| `Super + g` | Go to previous tag (shiftview) |
| `Super + ;` | Go to next tag (shiftview) |
| `Super + Shift + g` | Move window to previous tag |
| `Super + Shift + ;` | Move window to next tag |
| `Super + Page Up` | Go to previous tag |
| `Super + Page Down` | Go to next tag |
| `Super + Shift + Page Up` | Move window to previous tag |
| `Super + Shift + Page Down` | Move window to next tag |

### Multi-Monitor

| Key | Action |
|-----|--------|
| `Super + Left` | Focus previous monitor |
| `Super + Right` | Focus next monitor |
| `Super + Shift + Left` | Move window to previous monitor |
| `Super + Shift + Right` | Move window to next monitor |

### Program Launchers

| Key | Action |
|-----|--------|
| `Super + d` | dmenu (application launcher) |
| `Super + r` | lf file manager |
| `Super + Shift + r` | htop (system monitor) |
| `Super + e` | neomutt (email client) |
| `Super + Shift + e` | abook (address book) |
| `Super + w` | Librewolf (web browser) |
| `Super + Shift + w` | nmtui (network manager) |
| `Super + n` | vimwiki (notes/wiki) |
| `Super + Shift + n` | newsboat (RSS reader) |
| `Super + m` | ncmpcpp (music player) |
| `Super + c` | profanity (XMPP chat) |
| `Super + Shift + Enter` | Scratchpad terminal (toggle) |
| `Super + '` | Calculator scratchpad (toggle) |
| `Super + \`` | dmenuunicode (emoji picker) |

### Media/Audio

| Key | Action |
|-----|--------|
| `Super + -` | Volume down 5% |
| `Super + Shift + -` | Volume down 15% |
| `Super + =` | Volume up 5% |
| `Super + Shift + =` | Volume up 15% |
| `Super + Shift + m` | Mute/unmute audio |
| `Super + p` | Toggle mpd play/pause |
| `Super + Shift + p` | Pause mpd and all mpv instances |
| `Super + ,` | Previous track |
| `Super + Shift + ,` | Seek to 0% (restart track) |
| `Super + .` | Next track |
| `Super + Shift + .` | Toggle repeat mode |
| `Super + [` | Seek back 10 seconds |
| `Super + ]` | Seek forward 10 seconds |
| `Super + Shift + [` | Seek back 1 minute |
| `Super + Shift + ]` | Seek forward 1 minute |

### Media Keys (Laptop/Keyboard)

| Key | Action |
|-----|--------|
| `Audio Mute` | Mute/unmute |
| `Audio Raise/Lower` | Volume up/down |
| `Audio Play/Pause` | Toggle playback |
| `Audio Next/Prev` | Next/previous track |
| `Audio Rewind/Forward` | Seek ±10 seconds |
| `Calculator` | Open bc calculator |
| `WWW` | Open browser |
| `Mail` | Open email client |
| `Screen Saver` | Lock screen |

### Screenshots & Recording

| Key | Action |
|-----|--------|
| `Print` | Screenshot full screen |
| `Shift + Print` | Screenshot menu (maimpick) |
| `Super + Print` | Screen recording menu |
| `Super + Shift + Print` | Stop recording |
| `Super + Delete` | Stop recording |
| `Super + Scroll Lock` | Toggle screenkey display |

### Function Keys

| Key | Action |
|-----|--------|
| `Super + F1` | Show keybindings help (PDF) |
| `Super + F2` | Tutorial videos |
| `Super + F3` | Display select (multi-monitor) |
| `Super + F4` | Pulsemixer (audio control) |
| `Super + F5` | Reload Xresources |
| `Super + F6` | Tor browser wrapper |
| `Super + F7` | Transmission toggle |
| `Super + F8` | Mail sync |
| `Super + F9` | Mount drives (mounter) |
| `Super + F10` | Unmount drives |
| `Super + F11` | View webcam |
| `Super + F12` | Rerun keyboard remaps |

### System

| Key | Action |
|-----|--------|
| `Super + Backspace` | System action menu (shutdown, reboot, etc.) |
| `Super + Shift + Backspace` | System action menu |
| `Super + Shift + q` | System action menu |
| `Super + Shift + d` | passmenu (password manager) |
| `Super + Insert` | Insert snippet from dmenu |

## Customization

Edit `~/.local/src/dwm/config.h` and rebuild:

```bash
cd ~/.local/src/dwm
sudo make clean install
```

Then press `Super + Shift + q` to logout and restart dwm.

## Source Code

- [dwm for LARBS/archrice](https://github.com/lukesmithxyz/dwm)
- [Original dwm](https://dwm.suckless.org)

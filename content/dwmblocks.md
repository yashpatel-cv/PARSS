# dwmblocks (Status Bar)

dwmblocks is the modular status bar for dwm. Each module is a separate script that can be clicked for actions.

## Status Bar Modules

From left to right, the status bar typically shows:

| Module | Shows | Click Action |
|--------|-------|--------------|
| 📦 Updates | Available package updates | Open update list |
| 🔊 Volume | Current volume level | Open audio mixer |
| 🎵 Music | Current playing track | Open music player |
| 📶 Network | WiFi/Ethernet status | Open nmtui |
| 💾 Disk | Disk usage | Show disk details |
| 🧠 Memory | RAM usage | Open htop |
| 🖥️ CPU | CPU usage | Open htop |
| 🔋 Battery | Battery level (laptops) | Show power info |
| 📅 Date/Time | Current date and time | Open calendar |
| ❓ Help | Help icon | Show keybindings |

## Interacting with Modules

- **Left click**: Primary action
- **Middle click**: Secondary action
- **Right click**: Show help/info
- **Scroll**: Adjust values (volume, brightness)

## Status Bar Scripts

Scripts are located in `~/.local/bin/statusbar/`:

| Script | Purpose |
|--------|---------|
| `sb-clock` | Date and time |
| `sb-battery` | Battery status |
| `sb-volume` | Audio volume |
| `sb-disk` | Disk usage |
| `sb-memory` | RAM usage |
| `sb-cpu` | CPU usage |
| `sb-internet` | Network status |
| `sb-music` | MPD now playing |
| `sb-forecast` | Weather |
| `sb-mailbox` | Email count |
| `sb-news` | Unread RSS |
| `sb-help-icon` | Help button |

## Refreshing Modules

Modules update on their own schedule, but you can force refresh:

```bash
# Refresh a specific module (e.g., volume after changing it)
pkill -RTMIN+10 dwmblocks  # Volume module

# Kill and restart dwmblocks
killall dwmblocks; dwmblocks &
```

## Signal Numbers

Each module responds to a signal for refresh:

| Signal | Module |
|--------|--------|
| RTMIN+1 | Music |
| RTMIN+2 | Updates |
| RTMIN+3 | News |
| RTMIN+4 | Internet |
| RTMIN+5 | Memory |
| RTMIN+6 | CPU |
| RTMIN+9 | Battery |
| RTMIN+10 | Volume |

## Configuration

Edit `~/.local/src/dwmblocks/config.h`:

```c
static const Block blocks[] = {
    /*Icon    Command         Update interval    Signal */
    {"",      "sb-music",     0,                 1},
    {"",      "sb-volume",    0,                 10},
    {"",      "sb-battery",   5,                 9},
    {"",      "sb-clock",     60,                0},
};
```

After editing, rebuild:

```bash
cd ~/.local/src/dwmblocks
sudo make clean install
killall dwmblocks; dwmblocks &
```

## Creating Custom Modules

1. Create script in `~/.local/bin/statusbar/`:

```bash
#!/bin/sh
# sb-mymodule
echo "🔥 $(cat /sys/class/thermal/thermal_zone0/temp | cut -c1-2)°C"
```

2. Make executable: `chmod +x ~/.local/bin/statusbar/sb-mymodule`

3. Add to dwmblocks config.h and rebuild

## Source Code

- [dwmblocks for LARBS](https://github.com/LukeSmithxyz/dwmblocks)

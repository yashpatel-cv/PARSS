# Utility Scripts

PARSS includes many utility scripts in `~/.local/bin/`. Here's a reference.

## System Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `setbg` | Set wallpaper | `setbg image.png` or `setbg ~/Pictures/` |
| `remaps` | Apply keyboard remaps | Auto-runs on login |
| `remapd` | Daemon to rerun remaps on USB connect | Auto-runs |
| `shortcuts` | Generate shell shortcuts from bookmarks | `shortcuts` |
| `displayselect` | Multi-monitor configuration | `Super + F3` |
| `compiler` | Compile documents (LaTeX, groff, etc.) | `compiler file.tex` |
| `opout` | Open compiled output | `opout file.tex` |

## dmenu Scripts

| Script | Purpose | Shortcut |
|--------|---------|----------|
| `dmenuunicode` | Emoji/unicode picker | `Super + '` |
| `dmenurecord` | Screen recording menu | `Super + Print` |
| `dmenupass` | Password manager | `Super + Shift + d` |
| `maimpick` | Screenshot options | `Shift + Print` |
| `dmenumount` | Mount external drives | `Super + F9` |
| `dmenuumount` | Unmount drives | `Super + F10` |
| `dmenuhandler` | Handle URLs/files | Used by linkhandler |

## Media Scripts

| Script | Purpose |
|--------|---------|
| `linkhandler` | Open URLs in appropriate app |
| `pauseallmpv` | Pause all mpv instances |
| `rotdir` | Get images in directory for viewer |
| `qndl` | Queue download with notification |
| `queueandnotify` | Queue command and notify when done |

## File Management

| Script | Purpose |
|--------|---------|
| `mounter` | Interactive drive mounting |
| `lfub` | lf wrapper with image previews |
| `getcomproot` | Get root of compile project |
| `booksplit` | Split audiobooks by chapter |

## RSS & Podcasts

| Script | Purpose |
|--------|---------|
| `rssadd` | Add RSS feed to newsboat |
| `rssget` | Get RSS feed URL from page |
| `podentr` | Queue podcast episode |
| `qndl` | Queue download |

## Status Bar Scripts

Located in `~/.local/bin/statusbar/`:

| Script | Shows |
|--------|-------|
| `sb-clock` | Time and date |
| `sb-battery` | Battery level |
| `sb-volume` | Audio volume |
| `sb-brightness` | Screen brightness |
| `sb-disk` | Disk usage |
| `sb-memory` | RAM usage |
| `sb-cpu` | CPU usage |
| `sb-internet` | Network status |
| `sb-music` | Now playing |
| `sb-forecast` | Weather |
| `sb-mailbox` | Unread emails |
| `sb-news` | Unread RSS |
| `sb-help-icon` | Help button |
| `sb-doppler` | Radar map |
| `sb-iplocate` | IP location |
| `sb-kbselect` | Keyboard layout |

## Cron Scripts

Located in `~/.local/bin/cron/`:

| Script | Purpose |
|--------|---------|
| `checkup` | Check for package updates |
| `crontog` | Toggle cron job |
| `newsup` | Update news/RSS feeds |

## OTP & Security

| Script | Purpose |
|--------|---------|
| `otp` | One-time password generator |
| `dmenupass` | Password manager interface |

## Creating Custom Scripts

1. Create script in `~/.local/bin/`:
```bash
#!/bin/sh
# my-script
echo "Hello, world!"
```

2. Make executable:
```bash
chmod +x ~/.local/bin/my-script
```

3. Run from anywhere: `my-script`

All scripts in `~/.local/bin/` are in your PATH automatically.

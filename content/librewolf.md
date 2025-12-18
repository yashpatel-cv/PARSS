# Librewolf (Web Browser)

Librewolf is the privacy-focused web browser used by PARSS, based on Firefox with enhanced privacy settings.

## Launching

Press `Super + w` or type `librewolf` in terminal.

## Privacy Features

Librewolf comes pre-configured with:

- **uBlock Origin** — Ad and tracker blocking
- **Strict tracking protection** — Enhanced privacy
- **No telemetry** — Firefox telemetry disabled
- **Resistant fingerprinting** — Harder to track
- **HTTPS-only mode** — Secure connections

## Keybindings

### Navigation

| Key | Action |
|-----|--------|
| `Ctrl + l` | Focus address bar |
| `Ctrl + t` | New tab |
| `Ctrl + w` | Close tab |
| `Ctrl + Shift + t` | Reopen closed tab |
| `Ctrl + Tab` | Next tab |
| `Ctrl + Shift + Tab` | Previous tab |
| `Ctrl + 1-8` | Go to tab 1-8 |
| `Ctrl + 9` | Go to last tab |
| `Alt + Left` | Back |
| `Alt + Right` | Forward |
| `F5` / `Ctrl + r` | Reload |
| `Ctrl + Shift + r` | Hard reload (ignore cache) |

### Page Interaction

| Key | Action |
|-----|--------|
| `Ctrl + f` | Find on page |
| `Ctrl + g` | Find next |
| `Ctrl + Shift + g` | Find previous |
| `Escape` | Stop loading / close find bar |
| `Space` | Scroll down |
| `Shift + Space` | Scroll up |
| `j` / `k` | Scroll down/up (with vim keys enabled) |
| `Ctrl + +/-` | Zoom in/out |
| `Ctrl + 0` | Reset zoom |
| `F11` | Fullscreen |

### Bookmarks & History

| Key | Action |
|-----|--------|
| `Ctrl + d` | Bookmark page |
| `Ctrl + Shift + b` | Toggle bookmarks bar |
| `Ctrl + b` | Show bookmarks sidebar |
| `Ctrl + h` | Show history |
| `Ctrl + Shift + h` | Show all history |
| `Ctrl + Shift + Delete` | Clear recent history |

### Developer

| Key | Action |
|-----|--------|
| `F12` | Toggle developer tools |
| `Ctrl + Shift + i` | Toggle developer tools |
| `Ctrl + Shift + c` | Inspect element |
| `Ctrl + Shift + k` | Web console |
| `Ctrl + u` | View page source |

## Configuration

PARSS configures Librewolf with `larbs.js` for enhanced privacy:

Location: `~/.config/firefox/larbs.js` (copied to profile)

## Profile Location

`~/.librewolf/` contains your profile(s).

## Extensions Recommended

- **uBlock Origin** — Pre-installed
- **Dark Reader** — Dark mode for all sites
- **Vimium** — Vim keybindings

## Tips

- Use `Ctrl + Shift + Delete` regularly to clear data
- Check `about:config` for advanced settings
- Tor Browser is available for maximum privacy

## Source Code

- [Librewolf](https://librewolf.net/)
- Mozilla Public License

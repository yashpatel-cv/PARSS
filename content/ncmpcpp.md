# ncmpcpp (Music Player)

ncmpcpp is the terminal music player used by PARSS, built on MPD (Music Player Daemon).

## Launching

Press `Super + m` or type `ncmpcpp` in terminal.

## Keybindings

### Playback

| Key | Action |
|-----|--------|
| `p` | Play/pause |
| `s` | Stop |
| `>` | Next track |
| `<` | Previous track |
| `f` | Seek forward |
| `b` | Seek backward |
| `[` / `]` | Decrease/increase volume |
| `r` | Toggle repeat |
| `z` | Toggle random/shuffle |
| `y` | Toggle single mode |
| `R` | Toggle consume mode |
| `x` | Toggle crossfade |

### Navigation

| Key | Action |
|-----|--------|
| `j` / `Down` | Move down |
| `k` / `Up` | Move up |
| `h` / `Left` | Previous column |
| `l` / `Right` | Next column |
| `g` | Go to first item |
| `G` | Go to last item |
| `Ctrl + d/u` | Page down/up |
| `Enter` | Play selected |

### Views

| Key | Action |
|-----|--------|
| `1` | Playlist view |
| `2` | Browser view |
| `3` | Search view |
| `4` | Library view |
| `5` | Playlist editor |
| `6` | Tag editor |
| `7` | Output selector |
| `8` | Visualizer |
| `=` | Clock |
| `Tab` | Switch between panels |

### Playlist

| Key | Action |
|-----|--------|
| `a` | Add to playlist |
| `A` | Add to playlist (don't switch) |
| `d` | Delete from playlist |
| `c` | Clear playlist |
| `C` | Crop playlist (keep selected) |
| `m` | Move selected |
| `Space` | Select item |
| `i` | Show song info |

### Search

| Key | Action |
|-----|--------|
| `/` | Find forward |
| `?` | Find backward |
| `.` | Find next |
| `,` | Find previous |

## Configuration

| File | Purpose |
|------|---------|
| `~/.config/ncmpcpp/config` | Main config |
| `~/.config/ncmpcpp/bindings` | Custom keybindings |
| `~/.config/mpd/mpd.conf` | MPD config |

Quick access: `cfmc` (config) or `cfmb` (bindings)

## Music Directory

By default, MPD looks for music in `~/Music`.

## MPD Commands

```bash
# Check MPD status
mpc status

# Update music database
mpc update

# Toggle play/pause
mpc toggle
```

## DWM Integration

| Key | Action |
|-----|--------|
| `Super + p` | Toggle play/pause |
| `Super + ,` | Previous track |
| `Super + .` | Next track |
| `Super + [` | Seek back 10s |
| `Super + ]` | Seek forward 10s |

## Visualizer

Press `8` for the audio visualizer. It displays:
- Spectrum analyzer
- Waveform
- Ellipse

Cycle modes with `Space` in visualizer view.

## Source Code

- [ncmpcpp](https://github.com/ncmpcpp/ncmpcpp)
- GPL License

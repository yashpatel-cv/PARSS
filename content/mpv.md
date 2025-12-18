# mpv (Video Player)

mpv is the video player used by PARSS. It's lightweight, keyboard-driven, and highly configurable.

## Launching

- Open any video file (double-click or `Enter` in lf)
- Type `mpv filename.mp4` in terminal
- Use `linkhandler` script for URLs

## Keybindings

### Playback

| Key | Action |
|-----|--------|
| `Space` / `p` | Play/pause |
| `q` | Quit |
| `Q` | Quit and save position |
| `.` | Frame step forward |
| `,` | Frame step backward |
| `[` / `]` | Decrease/increase speed |
| `Backspace` | Reset speed |
| `l` | Set/clear A-B loop points |
| `L` | Toggle infinite loop |

### Seeking

| Key | Action |
|-----|--------|
| `Left` / `Right` | Seek ±5 seconds |
| `Up` / `Down` | Seek ±1 minute |
| `Shift + Left/Right` | Seek ±1 second (exact) |
| `Ctrl + Left/Right` | Seek to previous/next chapter |
| `0-9` | Seek to 0%-90% of video |

### Volume

| Key | Action |
|-----|--------|
| `m` | Mute |
| `9` / `0` | Volume down/up |
| `/` / `*` | Volume down/up (numpad) |

### Video

| Key | Action |
|-----|--------|
| `f` | Toggle fullscreen |
| `s` | Screenshot |
| `S` | Screenshot without subtitles |
| `Ctrl + s` | Screenshot (scaled) |
| `1` / `2` | Adjust contrast |
| `3` / `4` | Adjust brightness |
| `5` / `6` | Adjust gamma |
| `7` / `8` | Adjust saturation |
| `d` | Toggle deinterlace |
| `A` | Cycle aspect ratio |
| `_` | Cycle video track |

### Audio

| Key | Action |
|-----|--------|
| `#` | Cycle audio track |
| `Ctrl + +/-` | Audio delay adjust |

### Subtitles

| Key | Action |
|-----|--------|
| `v` | Toggle subtitle visibility |
| `j` / `J` | Cycle subtitle track |
| `z` / `Z` | Subtitle delay ±0.1s |
| `r` / `R` | Move subtitles up/down |
| `u` | Toggle subtitle style override |

### Playlist

| Key | Action |
|-----|--------|
| `>` / `<` | Next/previous in playlist |
| `Enter` | Next in playlist |

## Configuration

Config file: `~/.config/mpv/input.conf`

## YouTube and Streaming

mpv can play YouTube and other streaming sites via yt-dlp:

```bash
mpv "https://youtube.com/watch?v=..."
```

Or use the `linkhandler` script which is called when opening URLs.

## Source Code

- [mpv](https://mpv.io/)
- GPL/LGPL License

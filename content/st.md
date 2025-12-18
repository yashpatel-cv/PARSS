# st (Simple Terminal)

st is the terminal emulator used by PARSS. It's fast, minimal, and configured via Xresources.

## Launching

Press `Super + Enter` for a terminal window.

## Keybindings

### Scrolling

| Key | Action |
|-----|--------|
| `Alt + j` / `Alt + Down` | Scroll down |
| `Alt + k` / `Alt + Up` | Scroll up |
| `Alt + Mouse Wheel` | Scroll up/down |
| `Alt + u` / `Alt + Page Up` | Scroll up fast |
| `Alt + d` / `Alt + Page Down` | Scroll down fast |

### Font Size

| Key | Action |
|-----|--------|
| `Alt + Shift + k` | Increase font size |
| `Alt + Shift + j` | Decrease font size |
| `Alt + Home` | Reset font size |

### Copy/Paste

| Key | Action |
|-----|--------|
| `Alt + c` | Copy selected text |
| `Shift + Insert` | Paste from clipboard |
| `Alt + v` | Paste from clipboard |

### URLs & Output

| Key | Action |
|-----|--------|
| `Alt + l` | Open URL: Shows all URLs in terminal, select to open |
| `Alt + y` | Copy URL: Shows all URLs, select to copy |
| `Alt + o` | Copy command output: Copy output from a recent command |

### Transparency

| Key | Action |
|-----|--------|
| `Alt + a` | Decrease transparency (more opaque) |
| `Alt + s` | Increase transparency (more transparent) |

**Note**: Transparency is also set via Xresources and persists across sessions.

## Permanent Transparency Setting

Transparency is configured in `~/.config/x11/xresources`:

```
*.alpha: 0.85
st.alpha: 0.85
```

Values:
- `1.0` = fully opaque (no transparency)
- `0.85` = slight transparency (default)
- `0.7` = more transparent

After editing, reload with:
```bash
xrdb ~/.config/x11/xresources
```

New terminals will use the updated transparency.

## Font Configuration

Also in `~/.config/x11/xresources`:

```
*.font: monospace:size=10
st.font: monospace:size=10:antialias=true:autohint=true
```

## Colors

st uses the Moonfly color scheme defined in Xresources:
- Pure black background (`#000000`)
- Comfortable foreground (`#bdbdbd`)
- All 16 ANSI colors configured

## Readline (Shell Input)

The shell uses vim keybindings by default:
- Press `Escape` to enter normal mode
- `i` to return to insert mode
- Use `hjkl` to move in normal mode

To disable vim mode, remove `bindkey -v` from `~/.config/zsh/.zshrc`.

## Customization

### Via Xresources (Recommended)

Edit `~/.config/x11/xresources` for:
- Colors
- Font
- Transparency

### Via Source Code

For deeper changes, edit `~/.local/src/st/config.h` and rebuild:

```bash
cd ~/.local/src/st
sudo make clean install
```

## Source Code

- [st for LARBS/archrice](https://github.com/lukesmithxyz/st)
- [Original st](https://st.suckless.org)

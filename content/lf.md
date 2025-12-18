# lf (List Files)

lf is the terminal file manager used by PARSS. It's fast, keyboard-driven, and supports image previews.

## Launching

Press `Super + r` or type `lf` in terminal.

## Basic Navigation

| Key | Action |
|-----|--------|
| `h` | Go to parent directory |
| `j` | Move down |
| `k` | Move up |
| `l` / `Enter` | Open file/directory |
| `gg` / `g` | Go to top |
| `G` | Go to bottom |
| `Ctrl + d` | Page down |
| `Ctrl + u` | Page up |
| `H` | Go to home directory |

## File Operations

| Key | Action |
|-----|--------|
| `Space` | Select/toggle file |
| `y` | Yank (copy) selected files |
| `d` | Cut selected files |
| `p` | Paste files |
| `c` | Rename file |
| `D` | Delete file (with confirmation) |
| `Ctrl + n` | Create new directory |
| `V` | Create new file with neovim |

### Advanced Rename

| Key | Action |
|-----|--------|
| `A` | Rename, cursor at end |
| `a` | Rename, cursor after extension |
| `I` | Rename, cursor at beginning |
| `i` | Rename, cursor before extension |
| `B` | Bulk rename (vidir) |

### Move/Copy to Bookmarks

| Key | Action |
|-----|--------|
| `C` | Copy to bookmarked directory |
| `M` | Move to bookmarked directory |
| `Y` | Copy filenames to clipboard |
| `U` | Copy full paths to clipboard |

## Quick Actions

| Key | Action |
|-----|--------|
| `w` | Open shell in current directory |
| `W` | Open new terminal here |
| `b` | Set image as wallpaper |
| `T` | Open thumbnail view (nsxiv) |
| `x` | Execute file |
| `X` | Execute file with `!` (show output) |
| `o` | Open with mimeopen |
| `O` | Open with mimeopen --ask |

## View Options

| Key | Action |
|-----|--------|
| `z` + option | Toggle display options |
| `s` + option | Sort by different criteria |
| `Ctrl + s` | Toggle hidden files |
| `Ctrl + r` | Reload directory |

## Search & Filter

| Key | Action |
|-----|--------|
| `/` | Search files |
| `Ctrl + f` | fzf search |
| `J` | Jump to bookmarked directory (fzf) |

## Configuration Files

| File | Purpose |
|------|---------|
| `~/.config/lf/lfrc` | Main configuration |
| `~/.config/lf/scope` | Preview generation |
| `~/.config/lf/cleaner` | Preview cleanup |
| `~/.config/lf/icons` | File type icons |

## Image Previews

lf uses ueberzug for image previews. The actual command run is `lfub` (a wrapper script).

## Source Code

- [lf on GitHub](https://github.com/gokcehan/lf)
- MIT License

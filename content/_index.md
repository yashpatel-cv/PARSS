# PARSS Desktop Environment Guide

PARSS (Patel's Arch Rice Security Script) installs a complete, efficient desktop environment based on suckless tools and archrice dotfiles.

## Core Programs

| Program | Purpose | Quick Launch |
|---------|---------|--------------|
| [dwm](dwm.md) | Window manager | Auto-starts with `startx` |
| [st](st.md) | Terminal emulator | `Super + Enter` |
| [dmenu](dmenu.md) | Application launcher | `Super + d` |
| [dwmblocks](dwmblocks.md) | Status bar | Auto-starts |
| [lf](lf.md) | File manager | `Super + r` |
| [zsh](zsh.md) | Shell | Default shell |
| [neovim](neovim.md) | Text editor | `Super + e` or `v` |
| [newsboat](newsboat.md) | RSS reader | `Super + n` |
| [ncmpcpp](ncmpcpp.md) | Music player | `Super + m` |
| [mpv](mpv.md) | Video player | Opens video files |
| [zathura](zathura.md) | PDF viewer | Opens PDF files |
| [nsxiv](nsxiv.md) | Image viewer | Opens images |
| [Librewolf](librewolf.md) | Web browser | `Super + w` |

## Quick Reference

### Most Important Keybindings

| Key | Action |
|-----|--------|
| `Super + Enter` | Open terminal |
| `Super + d` | Open dmenu (app launcher) |
| `Super + q` | Close window |
| `Super + j/k` | Focus next/previous window |
| `Super + h/l` | Resize master area |
| `Super + Space` | Toggle window floating |
| `Super + F1` | Show all keybindings (help) |
| `Super + F2` | Watch tutorial videos |
| `Super + Shift + q` | Quit dwm |

### System Controls

| Key | Action |
|-----|--------|
| `Super + F4` | Suspend/hibernate menu |
| `Super + F9` | Mount USB/drives |
| `Super + F10` | Unmount drives |
| `Super + F11` | Webcam view |
| `Super + F12` | Rerun autostart (remaps) |

### Audio Controls

| Key | Action |
|-----|--------|
| `Super + -` | Volume down |
| `Super + =` | Volume up |
| `Super + Shift + m` | Mute |
| `Super + [` | Back 10 seconds (mpv/mpd) |
| `Super + ]` | Forward 10 seconds |
| `Super + Shift + [/]` | Back/forward 1 minute |

## Learning the System

1. **Press `Super + F1`** — Opens the built-in keybinding reference
2. **Read these docs** — Each program has detailed documentation
3. **Explore config files** — All configs are in `~/.config/`
4. **Check man pages** — `man dwm`, `man st`, etc.

## Configuration Files

| Config | Location |
|--------|----------|
| DWM | `~/.local/src/dwm/config.h` |
| ST | `~/.local/src/st/config.h` |
| Xresources | `~/.config/x11/xresources` |
| zsh | `~/.config/zsh/.zshrc` |
| neovim | `~/.config/nvim/init.vim` |
| lf | `~/.config/lf/lfrc` |

After editing suckless configs (dwm, st, dmenu), rebuild with:
```bash
cd ~/.local/src/dwm  # or st, dmenu
sudo make install
```

Then restart the program (or press `Super + Shift + q` to restart dwm).

# zsh (Z Shell)

zsh is the default shell in PARSS, configured with vim keybindings and useful shortcuts.

## Features

- Vim-style command line editing
- Syntax highlighting
- Auto-completion with menu selection
- Directory shortcuts and bookmarks

## Keybindings

### Vim Mode

The shell uses vim keybindings by default:

| Key | Mode | Action |
|-----|------|--------|
| `Escape` | Insert | Enter normal mode |
| `i` | Normal | Enter insert mode |
| `a` | Normal | Append after cursor |
| `A` | Normal | Append at end of line |
| `0` | Normal | Go to beginning of line |
| `$` | Normal | Go to end of line |
| `w/b` | Normal | Move word forward/backward |
| `dd` | Normal | Delete line |
| `cc` | Normal | Change line |
| `u` | Normal | Undo |

### Special Shortcuts

| Key | Action |
|-----|--------|
| `Ctrl + o` | Open lf, cd to selected directory on exit |
| `Ctrl + f` | fzf search, cd to file's directory |
| `Ctrl + a` | Open bc calculator |
| `Ctrl + e` | Edit current command in neovim |
| `Ctrl + l` | Clear screen |
| `Ctrl + r` | Search command history |

## Configuration Files

| File | Purpose |
|------|---------|
| `~/.config/zsh/.zshrc` | Main zsh config |
| `~/.config/shell/aliasrc` | Aliases (shared with bash) |
| `~/.config/shell/profile` | Environment variables (login) |
| `~/.config/shell/inputrc` | Readline configuration |
| `~/.zprofile` | Profile, starts X on tty1 |

## Quick Access Shortcuts

Type these in terminal to quickly edit configs:

| Command | Opens |
|---------|-------|
| `cfz` | zsh config |
| `cfa` | alias config |
| `cfv` | neovim config |
| `cfx` | Xresources |
| `cfb` | dwmblocks config |

## Useful Aliases

These are defined in `~/.config/shell/aliasrc`:

| Alias | Expands To |
|-------|------------|
| `v` / `e` | `$EDITOR` (neovim) |
| `p` | `pacman` |
| `g` | `git` |
| `ka` | `killall` |
| `sdn` | `shutdown -h now` |
| `z` | `zathura` |
| `lf` | `lfub` (lf with previews) |
| `ref` | Reload shell shortcuts |

## Directory Bookmarks

Bookmarks are defined in `~/.config/shell/bm-dirs`:

| Shortcut | Directory |
|----------|-----------|
| `h` | `$HOME` |
| `cf` | `~/.config` |
| `D` | `~/Downloads` |
| `d` | `~/Documents` |
| `pp` | `~/Pictures` |
| `vv` | `~/Videos` |
| `sc` | `~/.local/bin` |
| `src` | `~/.local/src` |

Usage: Type shortcut as command (e.g., `cf` goes to ~/.config).

## Prompt

The prompt shows:
- Username (yellow)
- @ symbol (green)
- Hostname (blue)
- Current directory (magenta)
- `$` for normal user, `#` for root

Example: `[user@hostname ~/.config]$`

## Source Code

- [zsh website](https://zsh.sourceforge.io/)

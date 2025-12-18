# Neovim

Neovim is the text editor used by PARSS, configured with the Moonfly color scheme and useful plugins.

## Launching

| Method | Command |
|--------|---------|
| From dwm | `Super + e` |
| From terminal | `v`, `vim`, or `nvim` |

## Basic Vim Keybindings

### Modes

| Key | Action |
|-----|--------|
| `i` | Insert mode (before cursor) |
| `a` | Insert mode (after cursor) |
| `o` | Insert new line below |
| `O` | Insert new line above |
| `v` | Visual mode (select) |
| `V` | Visual line mode |
| `Ctrl + v` | Visual block mode |
| `Escape` | Return to normal mode |
| `:` | Command mode |

### Movement

| Key | Action |
|-----|--------|
| `h/j/k/l` | Left/down/up/right |
| `w` | Next word |
| `b` | Previous word |
| `0` | Start of line |
| `$` | End of line |
| `gg` | Start of file |
| `G` | End of file |
| `Ctrl + d/u` | Page down/up |
| `{` / `}` | Previous/next paragraph |

### Editing

| Key | Action |
|-----|--------|
| `x` | Delete character |
| `dd` | Delete line |
| `yy` | Yank (copy) line |
| `p` | Paste after cursor |
| `P` | Paste before cursor |
| `u` | Undo |
| `Ctrl + r` | Redo |
| `.` | Repeat last action |

### Search & Replace

| Key | Action |
|-----|--------|
| `/pattern` | Search forward |
| `?pattern` | Search backward |
| `n` | Next match |
| `N` | Previous match |
| `:%s/old/new/g` | Replace all |
| `S` | Replace all (shortcut) |

## PARSS-Specific Keybindings

Leader key is `,` (comma).

### General

| Key | Action |
|-----|--------|
| `,o` | Toggle spell check |
| `,h` | Toggle hidden UI elements |
| `,c` | Compile document |
| `,p` | Open compiled PDF/preview |
| `,s` | Run shellcheck on script |

### Plugins

| Key | Action |
|-----|--------|
| `,n` | Toggle NERDTree (file browser) |
| `,f` | Toggle Goyo (focus mode) |
| `,v` | Open VimWiki index |
| `,,` | Jump to next `<++>` placeholder |

### Window Navigation

| Key | Action |
|-----|--------|
| `Ctrl + h/j/k/l` | Move between splits |
| `:vs` | Vertical split |
| `:sp` | Horizontal split |
| `Ctrl + w q` | Close split |

## Installed Plugins

| Plugin | Purpose |
|--------|---------|
| vim-surround | Surround text with quotes/brackets |
| NERDTree | File browser sidebar |
| goyo.vim | Distraction-free writing |
| vimagit | Git integration |
| vimwiki | Personal wiki |
| vim-airline | Status line |
| vim-commentary | Comment toggling (`gc`) |
| vim-css-color | Show CSS colors |
| vim-moonfly-colors | Color scheme |

## Configuration

Main config: `~/.config/nvim/init.vim`

Quick access: Type `cfv` in terminal.

### Theme

Moonfly dark theme with transparency support:
- Pure black background
- Comfortable contrast
- Terminal colors match

## Automatic Features

- Trailing whitespace removed on save
- Trailing newlines removed on save
- Xresources auto-reload on save
- dwmblocks auto-rebuild on config save
- Shortcuts regenerated on bookmark file save

## Source Code

- [Neovim](https://neovim.io/)
- [vim-plug](https://github.com/junegunn/vim-plug) (plugin manager)

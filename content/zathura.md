# zathura (PDF Viewer)

zathura is the keyboard-driven PDF and document viewer used by PARSS.

## Launching

- Open any PDF file
- Type `zathura file.pdf` or just `z file.pdf`

## Keybindings

### Navigation

| Key | Action |
|-----|--------|
| `j` / `Down` | Scroll down |
| `k` / `Up` | Scroll up |
| `h` / `Left` | Scroll left |
| `l` / `Right` | Scroll right |
| `Ctrl + d` | Page down |
| `Ctrl + u` | Page up |
| `Space` | Page down |
| `Shift + Space` | Page up |
| `gg` | Go to first page |
| `G` | Go to last page |
| `nG` | Go to page n |
| `J` | Next page |
| `K` | Previous page |

### Zoom

| Key | Action |
|-----|--------|
| `+` / `=` | Zoom in |
| `-` | Zoom out |
| `a` | Fit to width |
| `s` | Fit to page |
| `d` | Toggle dual page |
| `r` | Rotate 90° clockwise |
| `R` | Reload document |

### Search

| Key | Action |
|-----|--------|
| `/` | Search forward |
| `?` | Search backward |
| `n` | Next match |
| `N` | Previous match |

### Other

| Key | Action |
|-----|--------|
| `Tab` | Show index/outline |
| `o` | Open file |
| `f` | Follow links |
| `F` | Show links |
| `c` | Copy selection |
| `:` | Command mode |
| `q` | Quit |

## Marks

| Key | Action |
|-----|--------|
| `m + letter` | Set mark |
| `' + letter` | Go to mark |

## Configuration

Config file: `~/.config/zathura/zathurarc`

Colors follow the terminal theme by default.

## Supported Formats

- PDF
- PostScript
- DjVu
- Comic book formats (CBZ, CBR)

## Source Code

- [zathura](https://pwmt.org/projects/zathura/)
- zlib License

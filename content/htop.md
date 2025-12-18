# htop (System Monitor)

htop is the interactive system monitor used by PARSS.

## Launching

- Type `htop` in terminal
- Click on CPU/Memory in status bar

## Keybindings

### Navigation

| Key | Action |
|-----|--------|
| `Up` / `Down` / `j` / `k` | Select process |
| `Page Up` / `Page Down` | Scroll page |
| `Home` / `End` | First/last process |
| `Space` | Tag process |
| `c` | Tag process and children |
| `U` | Untag all |

### Process Actions

| Key | Action |
|-----|--------|
| `k` | Kill process (send signal) |
| `F9` | Kill process menu |
| `9` | Send SIGKILL |
| `t` | Toggle tree view |
| `H` | Toggle user threads |
| `K` | Toggle kernel threads |
| `p` | Toggle program path |

### Sorting

| Key | Action |
|-----|--------|
| `F6` / `>` | Sort by column |
| `P` | Sort by CPU% |
| `M` | Sort by memory% |
| `T` | Sort by time |
| `I` | Invert sort order |

### Search & Filter

| Key | Action |
|-----|--------|
| `F3` / `/` | Search |
| `F4` / `\` | Filter |
| `n` | Next match |
| `N` | Previous match |

### Display

| Key | Action |
|-----|--------|
| `F2` | Setup/configure |
| `F5` | Tree view |
| `F1` / `?` | Help |
| `q` / `F10` | Quit |

### Nice Value

| Key | Action |
|-----|--------|
| `F7` / `]` | Increase priority (lower nice) |
| `F8` / `[` | Decrease priority (higher nice) |

## Understanding the Display

### Header

- CPU bars: Usage per core
- Memory bar: RAM usage
- Swap bar: Swap usage
- Tasks: Running/total processes
- Load average: 1/5/15 minute averages
- Uptime

### Process Columns

| Column | Meaning |
|--------|---------|
| PID | Process ID |
| USER | Owner |
| PRI | Priority |
| NI | Nice value |
| VIRT | Virtual memory |
| RES | Resident memory |
| SHR | Shared memory |
| S | State (R/S/D/Z/T) |
| CPU% | CPU usage |
| MEM% | Memory usage |
| TIME+ | CPU time used |
| Command | Process command |

### Process States

| State | Meaning |
|-------|---------|
| R | Running |
| S | Sleeping |
| D | Disk sleep |
| Z | Zombie |
| T | Stopped |

## Configuration

Press `F2` to access setup menu for:
- Display options
- Meters (CPU, memory bars)
- Colors
- Columns

Config saved to: `~/.config/htop/htoprc`

## Source Code

- [htop](https://htop.dev/)
- GPL License

# newsboat (RSS Reader)

newsboat is the terminal RSS/Atom feed reader used by PARSS.

## Launching

Press `Super + n` or type `newsboat` in terminal.

## Keybindings

### Navigation

| Key | Action |
|-----|--------|
| `j` / `Down` | Next item |
| `k` / `Up` | Previous item |
| `J` | Next feed |
| `K` | Previous feed |
| `g` | Go to first item |
| `G` | Go to last item |
| `Enter` / `l` | Open feed/article |
| `q` / `h` | Go back / quit |

### Reading

| Key | Action |
|-----|--------|
| `o` | Open article in browser |
| `O` | Open article in browser (background) |
| `u` | Open article URL in browser |
| `n` | Mark as read, go to next unread |
| `N` | Toggle read/unread |
| `A` | Mark all as read |

### Feed Management

| Key | Action |
|-----|--------|
| `r` | Reload current feed |
| `R` | Reload all feeds |
| `Ctrl + r` | Reload all feeds (background) |
| `/` | Search |
| `?` | Search (reverse) |
| `#` | Go to article by number |

### Other

| Key | Action |
|-----|--------|
| `e` | Open article in editor |
| `E` | Open feed URL in editor |
| `s` | Save article |
| `Shift + d` | Delete article |
| `t` | Set tag filter |
| `Ctrl + t` | Clear tag filter |
| `:` | Command mode |

## Configuration

| File | Purpose |
|------|---------|
| `~/.config/newsboat/config` | Main config |
| `~/.config/newsboat/urls` | Feed URLs |

Quick access: `cfn` (config) or `cfu` (urls)

## Adding Feeds

Edit `~/.config/newsboat/urls`:

```
https://example.com/rss.xml "~Example Site" tech
https://news.ycombinator.com/rss "~Hacker News" tech news
```

Format: `URL "~Display Name" tag1 tag2`

## Quick Add Script

Use the `rssadd` script:

```bash
rssadd https://example.com/rss.xml
```

## Default Feeds

PARSS sets up some default feeds for:
- Tech news
- Linux/open source
- Privacy/security

## Podcast Support

newsboat can handle podcast feeds. Use `podentr` to queue episodes.

## Source Code

- [newsboat](https://newsboat.org/)
- MIT License

#!/usr/bin/env bash
set -euo pipefail

# PARSS Desktop Setup
# Installs desktop packages (optionally via CSV) and deploys dotfiles from archrice.
# Intended to be run on the *installed* system as a regular user with sudo access.

DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/yashpatel-01/archrice.git}"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.local/src/archrice}"
PROGS_FILE="${PROGS_FILE:-$DOTFILES_DIR/progs.csv}"

info()  { printf '\033[0;32m[INFO]\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
error() { printf '\033[0;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

require_not_root() {
    # Skip this check if running in chroot (arch-chroot sets this)
    if [[ -n "${PARSS_CHROOT_INSTALL:-}" ]]; then
        return 0
    fi
    
    if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
        error "Run this script as your regular user (with sudo), not as root."
    fi
}

require_cmd() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1 || error "Missing required command: $cmd"
}

clone_or_update_archrice() {
    info "Preparing archrice dotfiles repo..."
    if [[ -d "$DOTFILES_DIR/.git" ]]; then
        info "Found existing archrice repo, pulling latest changes..."
        git -C "$DOTFILES_DIR" pull --ff-only || warn "Could not pull latest changes; continuing with local copy."
    else
        mkdir -p "$(dirname "$DOTFILES_DIR")"
        info "Cloning archrice from $DOTFILES_REPO ..."
        git clone --depth 1 "$DOTFILES_REPO" "$DOTFILES_DIR"
    fi
}

install_from_csv() {
    if [[ ! -f "$PROGS_FILE" ]]; then
        warn "No progs.csv found at $PROGS_FILE; skipping package install."
        warn "Add a progs.csv to archrice to enable CSV-driven installation."
        return 0
    fi

    info "Installing packages from $PROGS_FILE ..."

    require_cmd sudo
    require_cmd pacman

    local line tag prog comment
    while IFS=, read -r tag prog comment; do
        # Skip comments/blank lines
        [[ -z "${tag}${prog}" ]] && continue
        [[ "$tag" =~ ^# ]] && continue

        case "$tag" in
            "" )
                info "[pacman] $prog - $comment"
                sudo pacman --noconfirm --needed -S "$prog" || warn "Failed to install $prog via pacman"
                ;;
            "G" )
                info "[git/make] $prog - $comment"
                local repodir="$HOME/.local/src"
                mkdir -p "$repodir"
                local name="${prog##*/}"
                name="${name%.git}"
                local dir="$repodir/$name"
                if [[ -d "$dir/.git" ]]; then
                    git -C "$dir" pull --ff-only || warn "Failed to update $prog; using existing copy."
                else
                    git clone --depth 1 "$prog" "$dir" || { warn "Clone failed for $prog"; continue; }
                fi
                ( cd "$dir" && make && sudo make install ) || warn "Build/install failed for $prog"
                ;;
            "A" )
                # AUR helper-based install (expects yay or paru, etc.)
                local aur_helper="${AUR_HELPER:-yay}"
                if command -v "$aur_helper" >/dev/null 2>&1; then
                    info "[AUR:$aur_helper] $prog - $comment"
                    "$aur_helper" --noconfirm --needed -S "$prog" || warn "Failed to install $prog via AUR ($aur_helper)"
                else
                    warn "Tag 'A' for $prog but no AUR helper ($aur_helper) found; skipping."
                fi
                ;;
            * )
                warn "Unknown tag '$tag' for $prog; skipping."
                ;;
        esac
    done < "$PROGS_FILE"
}

deploy_dotfiles() {
    info "Deploying archrice dotfiles into $HOME ..."

    # Use rsync if available to preserve attributes and avoid clobbering permissions unnecessarily.
    if command -v rsync >/dev/null 2>&1; then
        rsync -a --delete --exclude='.git' "$DOTFILES_DIR"/ "$HOME"/
    else
        warn "rsync not found; falling back to cp -r (may be less efficient)."
        cp -rf "$DOTFILES_DIR"/. "$HOME"/
    fi
}

main() {
    require_not_root
    require_cmd git

    info "PARSS Desktop Setup starting..."
    clone_or_update_archrice
    install_from_csv
    deploy_dotfiles

    info "Desktop setup complete. You may need to log out and back in or start X (e.g. with 'startx') to use your new environment."
}

main "$@"

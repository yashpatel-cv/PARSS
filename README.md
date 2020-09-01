# PARSS: Patel's Arch Rice Setup & Security

PARSS is an Arch Linux deployment toolkit that automates a **fully encrypted**, **BTRFS-based**, and **hardened** system install. It takes inspiration from LARBS, but focuses on:

- **Secure-by-default disk layout** (LUKS2 + BTRFS subvolumes)
- **Repeatable installs** with clear logging and state
- **Post-install health checks** and integrity tooling
- An **optional suckless/archrice desktop layer** you can apply after first boot

This repo currently contains a primary installer plus supporting tools and docs.

---

## 1. Components

- **Installer**
  - `scripts/arch-secure-deploy.sh` — stable, battle-tested installer.
- **Post-install tools**
  - `scripts/system-health.sh` — service, crypto, and BTRFS health dashboard.
  - `scripts/integrity-check.sh` — AIDE-based filesystem integrity checks.
  - `scripts/btrfs-dashboard.sh` — quick BTRFS layout/usage overview.
  - `scripts/desktop-setup.sh` — **optional** desktop/dotfiles setup using your `archrice` repo and an optional `progs.csv`.
- **Docs**
  - `docs/PARSS-MANUAL.md` — single F1-style manual (install recap, maintenance, recovery, health checks).
  - `docs/PARSS-CHANGES.md` — changelog / design history.

---

## 2. Quickstart Install (from Arch ISO)

1. **Boot the Arch ISO** (UEFI, x86_64).
2. **Connect to the network** (examples):
   ```bash
   iwctl          # Wi-Fi
   # or
   dhcpcd         # Ethernet
   ```
3. **Clone PARSS inside the ISO environment**:
   ```bash
   pacman -Sy git
   git clone https://github.com/yashpatel-01/PARSS.git
   cd PARSS/scripts
   ```
4. **Run the installer**:
   ```bash
   chmod +x arch-secure-deploy.sh
   ./arch-secure-deploy.sh
   ```

5. **Follow the prompts** for:
   - Hostname, primary user, encryption mapping names.
   - Disk/partition selection (this will **wipe** the chosen disk).
   - Single LUKS passphrase (used for both root and home).

6. Let all phases complete, then:
   ```bash
   reboot
   ```

7. At boot, enter your **single LUKS passphrase**, then log in as your primary user.

For a more detailed step-by-step description of the phases and expectations, see **Section 2** of `docs/PARSS-MANUAL.md`.

---

## 3. Optional Desktop & archrice Dotfiles

PARSS does **not** force a desktop environment during base install. Instead, after first boot you can layer on your desktop and dotfiles via `archrice` and an optional CSV package list.

On the **installed system**, as your primary user:

```bash
cd ~
git clone https://github.com/yashpatel-01/PARSS.git
cd PARSS/scripts
chmod +x desktop-setup.sh
./desktop-setup.sh
```

`desktop-setup.sh` will:

- Clone or update your **archrice** dotfiles repo (defaults to
  `https://github.com/yashpatel-01/archrice.git`).
- If `progs.csv` exists in that repo, read it and:
  - Install regular packages via `pacman`.
  - Optionally install AUR packages (tag `A`) using `$AUR_HELPER` (default `yay`).
  - Optionally build `git` sources (tag `G`) via `make && sudo make install`.
- Sync archrice files into `$HOME` (using `rsync` if available).

This gives you a **PARSS-style rice layer** (dwm/st/dmenu/slstatus, lf, neomutt, etc.) but sourced from your **own** archrice repo instead of Luke's voidrice.

You can customize behavior with environment variables:

- `DOTFILES_REPO` — override the archrice repo URL.
- `DOTFILES_DIR` — local clone path (defaults to `$HOME/.local/src/archrice`).
- `PROGS_FILE` — explicit path to a CSV file (defaults to `$DOTFILES_DIR/progs.csv`).
- `AUR_HELPER` — AUR helper command (default: `yay`).

If no CSV is present, the script will **only deploy dotfiles**, not packages.

---

## 4. Post-Install Health & Integrity

From the installed system:

- **System health dashboard**
  ```bash
  cd ~/PARSS/scripts
  ./system-health.sh
  ```
  Shows service status (NetworkManager, AppArmor, nftables, snapshot timer),
  LUKS/crypttab/GRUB configuration, and BTRFS subvolume layout.

- **Filesystem integrity (AIDE)**
  ```bash
  cd ~/PARSS/scripts
  ./integrity-check.sh
  ```
  Initializes AIDE if needed, then performs integrity checks on later runs.

- **BTRFS usage dashboard**
  ```bash
  cd ~/PARSS/scripts
  ./btrfs-dashboard.sh
  ```
  Summarizes devices, usage, subvolumes, snapshots, and mounts.

See `docs/PARSS-MANUAL.md` for maintenance cadence (weekly/monthly/quarterly) and
recovery procedures.

---

## 5. Documentation Layout

To avoid duplicated information, PARSS intentionally keeps docs minimal:

- **`README.md`** — what this repo is, quickstart usage, and an overview of
  installers and tools.
- **`docs/PARSS-MANUAL.md`** — single, indexed manual combining the previous
  INSTALLATION / MAINTENANCE / RECOVERY docs.
- **`docs/PARSS-CHANGES.md`** — changelog and design history.

Older standalone guides have been merged into `PARSS-MANUAL.md` and removed.

---

## 6. Licensing and Attribution

PARSS builds on ideas and code structure from:

- **LARBS** and **voidrice** by Luke Smith.
- Your customized **archrice** dotfiles.

The installer scripts are licensed under **GPL-3.0** (see `LICENSE`).

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
  - Phase 14 of `scripts/arch-secure-deploy.sh` — **optional** desktop/dotfiles setup using your `archrice` repo and an optional `progs.csv`.
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
   git clone https://github.com/yashpatel-cv/PARSS.git
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
git clone https://github.com/yashpatel-cv/PARSS.git
cd PARSS/scripts
chmod +x arch-secure-deploy.sh
./arch-secure-deploy.sh --phase 14
```

Phase 14 (desktop setup) will:

- Clone or update your **archrice** dotfiles repo (defaults to
  `https://github.com/yashpatel-cv/archrice.git`).
- If `progs.csv` exists in that repo, read it and:
  - Install regular packages via `pacman`.
  - Optionally install AUR packages (tag `A`) using `$AUR_HELPER` (default `yay`).
  - Optionally build `git` sources (tag `G`) via `make && sudo make install`.
- Sync archrice files into `$HOME` (using `rsync` if available).

This gives you a **PARSS-style rice layer** (dwm/st/dmenu/slstatus, lf, neomutt, etc.) sourced from your **archrice** dotfiles repo.

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

## 5. PARSS vs Other Arch Installers

PARSS is designed for **security-focused, repeatable installs** with optional desktop rice. Here's how it compares to official and community installers:

| Feature | **PARSS** | archinstall (Official) | LARBS |
|---------|-----------|------------------------|-------|
| **Runs from** | Arch ISO | Arch ISO | Already-installed Arch |
| **Disk partitioning** | ✅ Automated (EFI+root) | ✅ Interactive menu | ❌ Assumes done |
| **LUKS encryption** | ✅ Mandatory (LUKS2+Argon2id) | ✅ Optional | ❌ N/A |
| **Filesystem** | ✅ BTRFS with subvolumes | ✅ ext4/BTRFS/XFS/F2FS | ❌ N/A |
| **Base system** | ✅ Full pacstrap | ✅ Full pacstrap | ❌ Assumes done |
| **Bootloader** | ✅ GRUB | ✅ GRUB/systemd-boot | ❌ Assumes done |
| **Multi-boot (Windows)** | ✅ os-prober | ✅ os-prober | ❌ N/A |
| **Security hardening** | ✅ sysctl + kernel params | ❌ None | ❌ None |
| **BTRFS snapshots** | ✅ Automated weekly | ❌ Manual only | ❌ None |
| **Multi-kernel** | ✅ linux-zen + linux-lts | ❌ Single kernel | ❌ N/A |
| **Desktop profiles** | ❌ Optional post-install | ✅ KDE/GNOME/i3/etc. | ✅ dwm/i3 |
| **Dotfiles** | ✅ Via Phase 14 (desktop setup) | ❌ None | ✅ voidrice |
| **Secure Boot/TPM2** | ❌ Not implemented | ✅ Supported | ❌ N/A |
| **User interface** | Bash prompts | Python TUI menus | dialog TUI |
| **Automation level** | High (few prompts) | Medium (many menus) | High (automated rice) |

### When to use PARSS:
- **Frequent testing/reinstalls** → Automated, fast workflow
- **Security-focused** → Mandatory encryption + hardening
- **BTRFS users** → Snapshots, subvolumes, modern layout
- **Modular approach** → Base system separate from desktop

### When to use archinstall:
- **First-time Arch users** → Official support, extensive menus
- **Desktop profiles** → Want KDE/GNOME out-of-box
- **Secure Boot/TPM2** → Modern boot security required
- **Multiple filesystems** → Need ext4, XFS, etc.

### When to use LARBS:
- **Already have Arch** → Post-install rice automation
- **Minimal suckless setup** → Pre-configured terminal-centric workflow
- **Quick desktop** → Full environment in 10 minutes

### Do you need Secure Boot or TPM2?

**Short answer: Probably not.**

- **Secure Boot**: Prevents unauthorized bootloaders/kernels. Useful for:
  - Dual-boot with Windows 11 (requires Secure Boot)
  - Corporate/enterprise compliance
  - Protection against evil maid attacks on physical hardware
  
- **TPM2**: Hardware security module for storing encryption keys. Useful for:
  - Automatic LUKS unlock without passphrase (convenience vs security trade-off)
  - BitLocker integration on dual-boot systems
  - Enterprise key management

**For your use case (testing VMs, personal systems):**
- ❌ **Don't need Secure Boot** → PARSS's LUKS2 + Argon2id is secure enough
- ❌ **Don't need TPM2** → Passphrase-based LUKS is more secure than auto-unlock

**PARSS focuses on strong encryption + hardening**, which is more practical than Secure Boot for most users. If you need Secure Boot later, use `archinstall` or configure it manually.

---

## 6. Troubleshooting: Arch-Chroot for BTRFS + Encrypted Systems

If you need to troubleshoot or repair your PARSS installation from a live Arch ISO, follow these steps to properly mount and chroot into your encrypted BTRFS system.

### Step 1: Boot from Arch ISO

Boot from the same Arch installation media used during setup.

### Step 2: Unlock the Encrypted Root Partition

```bash
# Find your encrypted partition (usually the largest partition on your disk)
lsblk

# Unlock the LUKS partition (replace /dev/nvme0n1p2 with your root partition)
cryptsetup luksOpen /dev/nvme0n1p2 cryptroot

# If you have a separate encrypted home:
cryptsetup luksOpen /dev/nvme0n1p3 crypthome
```

### Step 3: Mount BTRFS Subvolumes

```bash
# Create mount point
mkdir -p /mnt

# Mount the root subvolume first
mount -o subvol=@,compress=zstd /dev/mapper/cryptroot /mnt

# Mount the remaining subvolumes
mount -o subvol=@home,compress=zstd /dev/mapper/cryptroot /mnt/home
mount -o subvol=@var,compress=zstd /dev/mapper/cryptroot /mnt/var
mount -o subvol=@snapshots,compress=zstd /dev/mapper/cryptroot /mnt/.snapshots

# Mount the EFI partition (replace /dev/nvme0n1p1 with your EFI partition)
mount /dev/nvme0n1p1 /mnt/boot/efi
```

### Step 4: Chroot into the System

```bash
# Use arch-chroot (handles /dev, /proc, /sys automatically)
arch-chroot /mnt

# You're now inside your installed system as root
# Run any repairs, reinstall packages, regenerate initramfs, etc.
```

### Common Repair Tasks

```bash
# Regenerate initramfs (if boot issues)
mkinitcpio -P

# Reinstall GRUB (if bootloader issues)
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Reinstall a package
pacman -S <package-name>

# Check filesystem
btrfs check /dev/mapper/cryptroot

# View BTRFS subvolumes
btrfs subvolume list /
```

### Step 5: Exit and Reboot

```bash
# Exit chroot
exit

# Unmount everything
umount -R /mnt

# Close encrypted volumes
cryptsetup luksClose cryptroot
cryptsetup luksClose crypthome  # if applicable

# Reboot
reboot
```

### Quick Reference: PARSS Default Layout

| Mount Point | BTRFS Subvolume | Purpose |
|-------------|-----------------|---------|
| `/` | `@` | Root filesystem |
| `/home` | `@home` | User data |
| `/var` | `@var` | Variable data, logs |
| `/.snapshots` | `@snapshots` | BTRFS snapshots |
| `/boot/efi` | (EFI partition) | UEFI bootloader |

---

## 7. Laptop/ThinkPad Support

PARSS includes special support for ThinkPad laptops (especially P1 Gen5 which is known for thermal issues):

### Packages Installed
- **thinkfan** — Intelligent fan control daemon
- **lm_sensors** — Hardware temperature monitoring
- **thermald** — Intel thermal daemon (prevents CPU throttling)
- **tlp** — Battery/power optimization
- **acpid** — ACPI event handling (lid close, power button)

### Fan Control Configuration

PARSS creates an aggressive cooling profile at `/etc/thinkfan.conf` optimized for ThinkPad P1 Gen5:
- Fan activates earlier (45°C instead of default 55°C)
- Full speed at 77°C (before thermal throttling kicks in at 80°C+)
- Supports both discrete GPU and CPU cooling

To adjust fan thresholds after installation:
```bash
sudo nvim /etc/thinkfan.conf
sudo systemctl restart thinkfan
```

To monitor temperatures:
```bash
sensors              # Current temps
watch -n 1 sensors   # Live monitoring
```

---

## 8. Documentation Layout

To avoid duplicated information, PARSS intentionally keeps docs minimal:

- **`README.md`** — what this repo is, quickstart usage, and an overview of
  installers and tools.
- **`docs/PARSS-MANUAL.md`** — single, indexed manual combining the previous
  INSTALLATION / MAINTENANCE / RECOVERY docs.
- **`docs/PARSS-CHANGES.md`** — changelog and design history.

Older standalone guides have been merged into `PARSS-MANUAL.md` and removed.

---

## 9. Licensing and Attribution

PARSS is built with:

- Secure Arch Linux base system installer
- Optional **archrice** dotfiles integration
- Security-first design principles

The installer scripts are licensed under **GPL-3.0** (see `LICENSE`).

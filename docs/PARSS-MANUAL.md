# PARSS Post-Install Manual

This manual is a single, indexed reference that combines the key content from:

- `INSTALLATION.md`
- `MAINTENANCE.md`
- `RECOVERY.md`
- the PARSS deployment scripts (health checks, integrity checks)

Use it after a successful installation as your F1-style help page.

---

## 1. First Boot Checklist

After the installer finishes and you reboot:

1. **Unlock encrypted root**
   - When prompted for the LUKS passphrase for the root volume (e.g. `yumraj`), enter the **same passphrase** you used in Phase 4.
   - If the installer self-test in Phase 4 passed, this should succeed.

2. **Log in as your primary user**
   - Username: the one you chose in Phase 1B (e.g. `patel`).
   - Shell: `zsh` (default).

3. **Update package database and system (optional but recommended)**
   ```bash
   sudo pacman -Syu
   ```

4. **Clone PARSS repo on the installed system (for scripts & docs)**
   ```bash
   cd ~
   git clone https://github.com/yashpatel-01/PARSS.git
   cd PARSS
   ```

5. **Run the system health dashboard**
   ```bash
   cd ~/PARSS/scripts
   chmod +x system-health.sh integrity-check.sh
   ./system-health.sh
   ```

6. **Run filesystem integrity check (AIDE)**
   ```bash
   ./integrity-check.sh
   ```

If any checks fail, see the Recovery and Maintenance sections below.

---

## 2. Installation Recap (from INSTALLATION.md)

### 2.1 Prerequisites

- **Hardware:** UEFI-compatible x86_64 system.
- **Storage:** Minimum ~71GB (1GB EFI + 50GB Root + 20GB Home; your home size may differ).
- **Network:** Active internet connection (Ethernet or Wi-Fi).
- **Media:** Latest Arch Linux ISO.

### 2.2 High-Level Install Flow

1. **Boot Arch ISO**.
2. **Connect to the internet** (Ethernet auto-DHCP, or Wi-Fi via `iwctl`).
3. **Clone PARSS repo inside the ISO environment**:
   ```bash
   pacman -Sy git
   git clone https://github.com/yashpatel-01/PARSS.git
   cd PARSS/scripts
   ```

4. **Run the deployment script**:
   ```bash
   chmod +x arch-secure-deploy.sh
   ./arch-secure-deploy.sh
   ```

5. **Answer interactive prompts** for hostname, user, encryption mapping names, partition sizes, etc.
6. **Confirm destructive operation**.
7. **Enter and confirm the single LUKS passphrase**.
8. **Pass the LUKS self-test in Phase 4** (you must successfully unlock `/dev/sda2` when prompted).
9. **Let all phases complete (1–13)**, then reboot.

---

## 3. Daily / Weekly / Monthly Maintenance (from MAINTENANCE.md)

### 3.1 Daily

- **General usage**
  - Use the system normally.
  - Keep an eye on disk space (especially snapshots and log volume) with:
    ```bash
    df -h
    btrfs filesystem usage / --human-readable | head -n 5
    ```

### 3.2 Weekly Tasks

- **System update:**
  ```bash
  sudo pacman -Syu
  ```

- **Snapshot check:**
  ```bash
  sudo btrfs subvolume list /.snapshots
  ```

### 3.3 Monthly Tasks

- **Integrity check (AIDE):**
  ```bash
  cd ~/PARSS/scripts
  ./integrity-check.sh
  ```

- **Clean package cache:**
  ```bash
  sudo pacman -Sc
  ```

### 3.4 Quarterly Tasks

- **Optional LUKS key rotation:**
  ```bash
  sudo cryptsetup luksChangeKey /dev/<root-partition>
  ```
  Replace `<root-partition>` with your actual root partition, e.g. `/dev/sda2`.

- **Backup LUKS headers:**
  ```bash
  sudo cryptsetup luksHeaderBackup /dev/<root-partition> \
      --header-backup-file root-header-$(date +%F).img
  ```
  Store header backups offline.

---

## 4. Recovery Procedures (from RECOVERY.md, adapted)

### 4.1 Emergency Access (Cannot Boot Normally)

1. **Boot from Arch ISO.**
2. **Open encrypted volumes** (adjust devices for your system):
   ```bash
   cryptsetup luksOpen /dev/sda2 root_crypt   # root
   cryptsetup luksOpen /dev/sda3 home_crypt   # home (if used)
   ```
3. **Mount filesystems (BTRFS subvolumes)**:
   ```bash
   mount -o subvol=@,compress=zstd /dev/mapper/root_crypt /mnt
   mount -o subvol=@home,compress=zstd /dev/mapper/root_crypt /mnt/home
   mount /dev/sda1 /mnt/boot
   ```
4. **Chroot into your system**:
   ```bash
   arch-chroot /mnt
   ```

From here you can:

- Reinstall GRUB.
- Regenerate `mkinitcpio` images.
- Fix configuration files (`/etc/default/grub`, `/etc/crypttab`, `/etc/fstab`).

### 4.2 LUKS Header Recovery

If you have a header backup and need to restore it:

```bash
sudo cryptsetup luksHeaderRestore /dev/<root-partition> \
    --header-backup-file header-backup.img
```

Be extremely careful: restoring the wrong header will destroy access to your data.

### 4.3 GRUB Repair

1. Follow “Emergency Access” steps to chroot into `/mnt`.
2. Reinstall GRUB:
   ```bash
   grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
   grub-mkconfig -o /boot/grub/grub.cfg
   ```

After repairs, exit the chroot, unmount, close LUKS, remove the ISO, and reboot.

---

## 5. System Health & Post-Install Checks

### 5.1 Run system-health dashboard

From the installed system:

```bash
cd ~/PARSS/scripts
./system-health.sh
```

This reports:

- Key service status (NetworkManager, AppArmor, nftables, snapshot timer, etc.).
- AppArmor presence.
- BTRFS disk usage summary.
- Snapshot count.
- `/etc/crypttab` presence and contents.
- `cryptdevice=` in `/etc/default/grub`.
- `cryptsetup status` for each entry in `/etc/crypttab`.
- BTRFS subvolume layout.

### 5.2 Run integrity-check (AIDE)

```bash
cd ~/PARSS/scripts
./integrity-check.sh
```

- On first run, it may install and initialize AIDE.
- On later runs, it will verify filesystem integrity and report deviations.

---

## 6. F1-Style Help Usage (Planned)

Currently, this `PARSS-MANUAL.md` lives in the `docs/` folder of the PARSS
repo. A future step will bind the F1 key (or another shortcut) in your window
manager to open this manual in a pager or terminal editor (e.g. `less`,
`nvim`).

For now, you can open it manually after login:

```bash
cd ~/PARSS/docs
less PARSS-MANUAL.md
```

Or with a GUI editor if installed.

---

## 7. Where to Go Next

- For **install details and phase overview**, see Sections 2 and 5 of this
  manual.
- For **ongoing maintenance**, see Section 3.
- For **emergencies and recovery**, see Section 4.
- For **runtime verification**, use `scripts/system-health.sh` and
  `scripts/integrity-check.sh`.
- For a high-level project overview and quickstart, see `README.md`.

This manual is designed to be your single, indexed reference after the first
boot, mirroring the spirit of earlier F1-style help pages while being tailored to PARSS.

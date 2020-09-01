# PARSS Change Log

## [v2.4] - 2025-11-26
### Added
- **Reliability:** Implemented robust network connectivity checks (multi-host).
- **Reliability:** Added `mount_btrfs_subvol` helper for consistent, DRY mount logic.
- **Reliability:** Added `--dry-run` mode for safe testing.
- **Security:** Integrated AppArmor with default profile loading.
- **Security:** Added nftables firewall with default-deny rules.
- **Security:** Added optional TPM2 support (`tpm2-tools`).
- **UX:** Added GRUB fallback logic for better bootloader reliability.

### Changed
- Refactored `arch-secure-deploy.sh` to `arch-secure-deploy-v2.sh`.
- Improved error handling with `trap` for secure keyfile cleanup.
- Updated package list to include security pillars (apparmor, iptables-nft).
- **Performance:** Removed ZRAM swap support to reduce CPU overhead (user request).

### Fixed
- Fixed redundant mount code blocks.
- Fixed potential keyfile leak in `/tmp` by adding exit traps.

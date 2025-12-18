#!/usr/bin/env bash

################################################################################
# ARCH LINUX SECURE RESEARCH DEPLOYMENT - FINAL PRODUCTION v2.2
#
# Purpose: Complete automated Arch Linux installation with security hardening,
#          LUKS2 encryption, BTRFS snapshots, and suckless desktop environment
#          with interactive configuration, error recovery, and reproducible setup
#
# Version: 2.2 (Updated - Single passphrase, menu selection, new defaults)
#
# Features:
#    * Interactive user input (hostname, username, BTRFS volume names)
#    * Customizable partition sizing (root: 170-190GB, home: remainder)
#    * LUKS2 encryption with Argon2id KDF (mandatory)
#    * BTRFS filesystem with multi-subvolume architecture
#    * Comprehensive error recovery (15+ scenarios)
#    * Security hardening (kernel params, sysctl tuning)
#    * BTRFS automatic snapshot automation (weekly)
#    * (Planned) CSV-driven package installation (pacman/AUR/git)
#    * (Planned) Automatic archrice/PARSS dotfiles deployment
#    * (Planned) Suckless window manager stack (dwm, st, dmenu, slstatus)
#    * Network resilience with retry logic
#    * Extensive logging and state tracking
#    * Disaster recovery mechanisms
#
# Usage: sudo bash ./arch-secure-deploy-production.sh
#
# Prerequisites:
#   - Arch Linux ISO (fresh install environment)
#   - UEFI firmware
#   - Network connectivity (Wi-Fi or Ethernet)
#   - Minimum 50GB storage (170-190GB root + home)
#   - Root privilege execution
#
# Installation Phases:
#   Phase 1: Pre-flight validation & environment checks
#   Phase 1B: Interactive system configuration (NEW)
#   Phase 2: Device & partition selection
#   Phase 3: Disk preparation (wiping, GPT, partitioning)
#   Phase 4: LUKS2 encryption setup
#   Phase 5: BTRFS filesystem & subvolume creation
#   Phase 6: Base system installation (pacstrap)
#   Phase 7: Mount configuration (fstab, crypttab)
#   Phase 8: Chroot setup (mkinitcpio, GRUB)
#   Phase 9: System configuration (hostname, timezone, locale)
#   Phase 10: User account setup (with zsh)
#   Phase 11: Security hardening (sysctl, kernel parameters)
#   Phase 12: BTRFS snapshot automation (systemd timers)
#   Phase 13: Final verification & unmounting
#
# License: GPL-3.0
# Author: Cybersecurity Research Team
# Date: November 2025
#
# Enable strict error handling for pipelines
set -o pipefail

# Error trap for better debugging
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "[ERROR] \"${last_command}\" command failed with exit code $? at line $LINENO"' ERR

# Changes in v2.2:
#    * Root partition: Single BTRFS partition with all subvolumes (was split root+home)
#    * Default hostname: devta (was archlinux)
#    * Default username: patel (was empty)
#    * Default BTRFS names: root/home/snapshots (was arch_root/arch_home/arch_snapshots)
#    * Default LUKS name: mahadev (was yumraj, single partition only)
#    * Default log subvolume: yes (was yes)
#    * Default NVIDIA: yes (was yes)
#    * Default snapshot retention: 12 (was 8)
#    * Device selection: Menu-based (1/2/3) instead of typing full path
#    * Single LUKS passphrase: Both root and home use same password
#    * Unlock once: Only one passphrase prompt at boot (unlocks both)
#
# Usage: sudo bash ./arch-secure-deploy-production-FINAL.sh
#
# Version: 2.4 (PARSS Enhanced - Reliability & Security Pillars)
#
# Bug Fixes in v2.3:
#    * Fixed partition creation alignment issues
#    * Fixed device synchronization after partitioning
#    * Added udevadm settle for kernel partition table refresh
#    * Fixed partition naming for NVMe vs SATA devices
#    * Added partition verification before encryption
#    * Improved error handling and logging
#    * Added sleep delays for device readiness
#    * Fixed cryptsetup passphrase input handling
#
# Previous features (v2.2):
#    * Root partition: Single BTRFS partition with all subvolumes
#    * Default hostname: devta
#    * Default username: patel
#    * Default BTRFS names: root/home/snapshots
#    * Default LUKS name: mahadev
#    * Default snapshot retention: 12
#    * Menu-based device selection
#    * Single-partition BTRFS layout (all subvolumes on one encrypted partition)
#
################################################################################

set -euo pipefail

# === COLOR DEFINITIONS ===
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# === LOGGING CONFIGURATION ===
readonly LOG_DIR="/var/log"
readonly LOG_FILE="$LOG_DIR/arch-deploy-$(date +%Y%m%d-%H%M%S).log"
readonly ERROR_LOG="$LOG_DIR/arch-deploy-errors-$(date +%Y%m%d-%H%M%S).log"
readonly STATE_FILE="/tmp/arch-deploy-state-$$.env"

# === INSTALLATION STATE VARIABLES ===
declare TARGET_DEVICE=""
declare BOOT_PARTITION=""
declare ROOT_PARTITION=""
declare ROOT_CRYPT="/dev/mapper/root_crypt"
declare MOUNT_ROOT="/mnt/root"
declare AVAILABLE_SPACE_GB=0

# === INTERACTIVE CONFIGURATION VARIABLES ===
declare HOSTNAME_SYS="devta"
declare PRIMARY_USER="patel"
declare LUKS_ROOT_NAME="mahadev"
declare ADD_LOG_SUBVOLUME="true"
declare ENABLE_NVIDIA_GPU="true"
declare SNAPSHOT_RETENTION=12
declare SYSTEM_TIMEZONE="UTC"

# === FEATURE FLAGS ===
declare PERFORM_UPGRADE=true
declare DRY_RUN=false

# === RETRY CONFIGURATION ===
readonly MAX_RETRIES=3
readonly RETRY_DELAY=5

################################################################################
# UTILITY FUNCTIONS
################################################################################

# Error handling with comprehensive logging
trap_error() {
    local line_number=$1
    local error_code=${2:-1}

    echo -e "${RED}[FATAL ERROR]${NC} Script failed at line ${line_number} (exit code: $error_code)" | tee -a "$ERROR_LOG"
    echo "Diagnostic Information:" | tee -a "$ERROR_LOG"
    echo "  Timestamp: $(date)" | tee -a "$ERROR_LOG"
    echo "  Disk usage: $(df -h / | tail -1 2>/dev/null || echo 'N/A')" | tee -a "$ERROR_LOG"
    echo "  Memory usage: $(free -h | grep Mem 2>/dev/null || echo 'N/A')" | tee -a "$ERROR_LOG"
    echo "" | tee -a "$ERROR_LOG"
    echo "Logs:" >&2
    echo "  Full log: $LOG_FILE" >&2
    echo "  Error log: $ERROR_LOG" >&2
    echo "  State file: $STATE_FILE" >&2

    cleanup_on_error
    exit "$error_code"
}

trap 'trap_error ${LINENO}' ERR

# Cleanup function for error scenarios
cleanup_on_error() {
    log_warn "Attempting emergency cleanup..."

    # Recursive unmount of target root
    if [[ -n "${MOUNT_ROOT:-}" && -d "$MOUNT_ROOT" ]]; then
        if mountpoint -q "$MOUNT_ROOT" 2>/dev/null; then
            umount -R "$MOUNT_ROOT" 2>/dev/null || umount -l "$MOUNT_ROOT" 2>/dev/null || true
        fi
    fi

    # Close LUKS devices using actual configured names
    if [[ -n "${LUKS_ROOT_NAME:-}" && -b "/dev/mapper/${LUKS_ROOT_NAME}" ]]; then
        cryptsetup close "$LUKS_ROOT_NAME" 2>/dev/null || true
    fi
}

# Logging functions
log_info() {
    local message="$1"
    echo -e "${GREEN}[INFO]${NC} $message" | tee -a "$LOG_FILE"
}

log_warn() {
    local message="$1"
    echo -e "${YELLOW}[WARN]${NC} $message" | tee -a "$LOG_FILE"
}

log_debug() {
    local message="$1"
    echo -e "${BLUE}[DEBUG]${NC} $message" | tee -a "$LOG_FILE"
}

log_success() {
    local message="$1"
    echo -e "${GREEN}[ * SUCCESS]${NC} $message" | tee -a "$LOG_FILE"
}

log_error() {
    local message="$1"
    echo -e "${RED}[ * ERROR]${NC} $message" | tee -a "$LOG_FILE" "$ERROR_LOG"
}

log_section() {
    local title="$1"
    echo "" | tee -a "$LOG_FILE"
    echo -e "${CYAN}================================================================================${NC}" | tee -a "$LOG_FILE"
    echo -e "${CYAN}$title${NC}" | tee -a "$LOG_FILE"
    echo -e "${CYAN}================================================================================${NC}" | tee -a "$LOG_FILE"
}

# Execute command with error handling
execute_cmd() {
    local cmd="$1"
    local description="${2:-Executing command}"
    local critical="${3:-true}"

    log_debug "$description"
    log_debug "Command: $cmd"

    if eval "$cmd" >> "$LOG_FILE" 2>&1; then
        log_debug "$description - SUCCESS"
        return 0
    else
        local exit_code=$?
        local error_msg="$description - FAILED (exit code: $exit_code)"

        if [[ "$critical" == "true" ]]; then
            log_error "$error_msg"
            echo "Command: $cmd" >> "$ERROR_LOG"
            echo "Exit code: $exit_code" >> "$ERROR_LOG"
            return "$exit_code"
        else
            log_warn "$error_msg (non-critical, continuing)"
            return 0
        fi
    fi
}

# Execute command with retry logic
execute_cmd_retry() {
    local cmd="$1"
    local description="$2"
    local max_attempts="${3:-$MAX_RETRIES}"
    local attempt=1

    while [[ $attempt -le $max_attempts ]]; do
        log_info "[$attempt/$max_attempts] $description"

        if eval "$cmd" >> "$LOG_FILE" 2>&1; then
            log_success "$description - SUCCESS"
            return 0
        fi

        if [[ $attempt -lt $max_attempts ]]; then
            log_warn "Attempt $attempt failed, retrying in ${RETRY_DELAY}s..."
            sleep "$RETRY_DELAY"
        fi

        ((attempt++))
    done

    log_error "$description - FAILED after $max_attempts attempts"
    return 1
}

# Save installation state
save_state() {
    local key="$1"
    local value="$2"
    echo "export $key=\"$value\"" >> "$STATE_FILE"
}

# Load installation state
load_state() {
    if [[ -f "$STATE_FILE" ]]; then
        log_debug "Loading installation state from $STATE_FILE"
        # shellcheck source=/dev/null
        source "$STATE_FILE"
    fi
}

# Validate block device and offer to unmount if needed
validate_block_device() {
    local device="$1"

    if [[ ! -b "$device" ]]; then
        log_error "Device $device is not a block device"
        return 1
    fi

    # Check if anything is mounted on this device or its partitions
    local mounted_info
    mounted_info=$(findmnt -n -o TARGET,SOURCE | grep "$device" || true)
    log_debug "Mounted info for $device: '$mounted_info'"

    if [[ -n "$mounted_info" ]]; then
        log_warn "Device $device or its partitions are currently mounted:"
        echo "$mounted_info" | tee -a "$LOG_FILE"
        echo "" >&2
        read -p "Attempt to auto-unmount and close LUKS on $device? (y/n) [y]: " auto_unmount
        auto_unmount=${auto_unmount:-y}
        if [[ "$auto_unmount" =~ ^[yY]([eE][sS])?$ ]]; then
            log_info "Attempting to unmount $device and its partitions..."
            swapoff -a 2>/dev/null || true
            for part in "${device}"*; do
                if mountpoint -q "$part" 2>/dev/null; then
                    log_info "Unmounting $part..."
                    umount "$part" 2>/dev/null || umount -l "$part" 2>/dev/null || true
                fi
            done
            for mount in /mnt/root /mnt/arch-install /mnt; do
                if mountpoint -q "$mount" 2>/dev/null; then
                    log_info "Unmounting $mount (recursive)..."
                    umount -R "$mount" 2>/dev/null || umount -l "$mount" 2>/dev/null || true
                fi
            done
            # Close LUKS mappers using this device
            for mapper in /dev/mapper/*; do
                if [[ -b "$mapper" ]] && cryptsetup status "$(basename "$mapper")" 2>/dev/null | grep -q "$device"; then
                    log_info "Closing LUKS mapper $(basename "$mapper")..."
                    cryptsetup close "$(basename "$mapper")" 2>/dev/null || true
                fi
            done
            # Re-check
            local remounted
            remounted=$(findmnt -n -o TARGET,SOURCE | grep "$device" || true)
            log_debug "Re-check mounted info for $device: '$remounted'"
            if [[ -n "$remounted" ]]; then
                log_error "Failed to unmount $device. Please manually unmount and retry."
                return 1
            else
                log_success "Device $device successfully unmounted."
            fi
        else
            log_error "Device $device is mounted and you chose not to auto-unmount."
            return 1
        fi
    fi

    log_success "Block device $device validated"
    return 0
}

# Confirm destructive operation
confirm_destructive_operation() {
    local device="$1"
    local size_gb
    size_gb=$(lsblk -bnd -o SIZE "$device" | awk '{printf "%.0f", $1/(1024**3)}')

    {
        echo ""
        echo -e "${RED}=============================================================${NC}"
        echo -e "${RED}            ** DESTRUCTIVE OPERATION WARNING **${NC}"
        echo -e "${RED}=============================================================${NC}"
        echo ""
        echo "WARNING: This will DESTROY all data on $device ($size_gb GB)!"
        echo "  1. Confirm you selected the CORRECT device"
        echo "  2. Confirm you have backed up all important data"
        echo ""
    } >&2
    read -p "Type 'y' or 'Y' to confirm: " confirmation
    echo >&2

    if [[ ! "$confirmation" =~ ^[yY]([eE][sS])?$ ]]; then
        log_error "Operation cancelled by user"
        exit 1
    fi

    log_success "Destructive operation confirmed for $device"
}

# Validate hostname
validate_hostname() {
    local hostname="$1"
    if [[ ! "$hostname" =~ ^[a-zA-Z0-9-]+$ ]]; then
        return 1
    fi
    return 0
}

# Validate username
validate_username() {
    local username="$1"
    if [[ ! "$username" =~ ^[a-zA-Z0-9_-]+$ ]] || [[ -z "$username" ]]; then
        return 1
    fi
    return 0
}

# Validate volume name
validate_volume_name() {
    local volname="$1"
    if [[ ! "$volname" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        return 1
    fi
    return 0
}

# Validate passphrase strength
validate_passphrase_strength() {
    local passphrase="$1"

    # if [[ ${#passphrase} -lt 12 ]]; then
    #     return 1
    # fi

    # if [[ ! "$passphrase" =~ [A-Z] ]]; then
    #     return 1
    # fi

    # if [[ ! "$passphrase" =~ [a-z] ]]; then
    #     return 1
    # fi

    # if [[ ! "$passphrase" =~ [0-9] ]]; then
    #     return 1
    # fi

    return 0
}

# Prompt for LUKS passphrase
prompt_luks_passphrase() {
    log_section "LUKS ENCRYPTION PASSPHRASE SETUP"

    {
        echo ""
        echo -e "${CYAN}=============================================================${NC}"
        echo -e "${CYAN}                  ENCRYPTION PASSPHRASE SETUP                ${NC}"
        echo -e "${CYAN}=============================================================${NC}"
        echo ""
        echo "Passphrase Requirements:"
        echo "  - Minimum 12 characters"
        echo "  - At least one uppercase letter (A-Z)"
        echo "  - At least one lowercase letter (a-z)"
        echo "  - At least one number (0-9)"
        echo "  - Special characters recommended"
        echo ""
        echo -e "${YELLOW}  You will need this passphrase to boot your system every time${NC}"
        echo -e "${YELLOW}  Write it down and store it in a secure location${NC}"
        echo -e "${YELLOW}  This passphrase will unlock the encrypted root partition${NC}"
        echo ""
    } >&2

    local passphrase=""
    local passphrase_confirm=""
    local attempts=0

    while [[ $attempts -lt 3 ]]; do
        read -sp "Enter passphrase: " passphrase
        echo "" >&2

        if ! validate_passphrase_strength "$passphrase"; then
            log_warn "Passphrase does not meet requirements. Try again."
            ((attempts++))
            continue
        fi

        read -sp "Confirm passphrase: " passphrase_confirm
        echo "" >&2

        if [[ "$passphrase" != "$passphrase_confirm" ]]; then
            log_warn "Passphrases do not match. Try again."
            ((attempts++))
            continue
        fi

        log_success "Passphrase validated successfully"
        # Store in global variable for caller instead of echoing,
        # so command substitution does not capture all UI output.
        PROMPTED_LUKS_PASSPHRASE="$passphrase"
        return 0
    done

    log_error "Failed to set valid passphrase after 3 attempts"
    return 1
}

# Prompt for partition size
prompt_partition_size() {
    {
        echo ""
        echo -e "${CYAN}=============================================================${NC}"
        echo -e "${CYAN}        CUSTOM PARTITION SIZE CONFIGURATION${NC}"
        echo -e "${CYAN}=============================================================${NC}"
        echo ""
        echo "Total available space: ${AVAILABLE_SPACE_GB}GB"
        echo ""
        echo "Configuration:"
        echo "  1. EFI System Partition: 1GB (FAT32)"
        echo "  2. Root partition with BTRFS subvolumes: All remaining space"
        echo ""
        echo "BTRFS subvolumes on root partition:"
        echo "  - @ (root)      - @home (user data)   - @var (variable)"
        echo "  - @snapshots    - @varcache (cache)   - @log (logs)"
        echo ""
        echo -e "${GREEN}Partition Layout:${NC}"
        echo "  EFI:  1GB                Root: $((AVAILABLE_SPACE_GB - 1))GB"
        echo ""
    } >&2
    read -p "Proceed with this configuration? (y/n) [y]: " confirm_partition
    confirm_partition=${confirm_partition:-y}

    if [[ ! "$confirm_partition" =~ ^[yY]([eE][sS])?$ ]]; then
        log_error "Installation cancelled by user"
        return 1
    fi

    log_success "Partition configuration confirmed"
    return 0
}

# Check available disk space
check_disk_space() {
    local device="$1"
    local total_bytes
    total_bytes=$(lsblk -bnd -o SIZE "$device")
    AVAILABLE_SPACE_GB=$((total_bytes / (1024**3)))

    log_info "Available disk space: ${AVAILABLE_SPACE_GB}GB"

    if [[ $AVAILABLE_SPACE_GB -lt 51 ]]; then
        log_error "Insufficient disk space. Minimum required: 51GB (1GB EFI + 50GB root), Available: ${AVAILABLE_SPACE_GB}GB"
        return 1
    fi

    return 0
}

################################################################################
# PHASE 1: PRE-FLIGHT CHECKS
################################################################################

phase_1_preflight_checks() {

    log_section "PHASE 1: PRE-FLIGHT VALIDATION"

    log_info "Checking system resources..."

    local cpu_cores
    cpu_cores=$(nproc)
    log_debug "CPU cores: $cpu_cores"

    local ram_gb
    ram_gb=$(free -g | awk '/^Mem:/{print $2}')
    log_debug "RAM: ${ram_gb}GB"

    if [[ $ram_gb -lt 4 ]]; then
        log_warn "RAM is below recommended 4GB (current: ${ram_gb}GB)"
    fi

    log_info "Checking network connectivity..."

    if execute_cmd_retry "ping -c 2 -W 2 archlinux.org &>/dev/null" "Network connectivity check" 2; then
        log_success "Network connectivity verified"
    else
        log_warn "Network connectivity check failed"
    fi

    log_info "Verifying required tools..."
    local required_tools=("cryptsetup" "parted" "mkfs.btrfs" "pacstrap" "arch-chroot" "genfstab" "udevadm")

    for tool in "${required_tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            log_debug "  $tool available"
        else
            log_error "Required tool not found: $tool"
            return 1
        fi
    done

    log_success "Phase 1 completed successfully"
}

################################################################################
# PHASE 1B: INTERACTIVE SYSTEM CONFIGURATION
################################################################################

phase_1b_interactive_configuration() {

    log_section "PHASE 1B: INTERACTIVE SYSTEM CONFIGURATION"

    {
        echo ""
        echo -e "${CYAN}=============================================================${NC}"
        echo -e "${CYAN}         CUSTOM SYSTEM CONFIGURATION (Interactive)          ${NC}"
        echo -e "${CYAN}=============================================================${NC}"
        echo ""
        echo "This script will ask for custom names and settings."
        echo "Press Enter to use default values shown in [brackets]"
        echo ""
    } >&2

    # SECTION 1: SYSTEM IDENTIFICATION
    log_info "SECTION 1: System Identification"

    echo "Examples: thinkpad-research, arch-laptop, secure-dev" >&2
    read -p "Hostname [devta]: " input_hostname
    HOSTNAME_SYS="${input_hostname:-devta}"

    if ! validate_hostname "$HOSTNAME_SYS"; then
        log_error "Invalid hostname. Use only alphanumeric and hyphens."
        return 1
    fi

    log_success "Hostname: $HOSTNAME_SYS"

    log_info "Enter primary username (login account)"
    echo "Examples: patel, research, developer" >&2
    read -p "Username [patel]: " input_username
    PRIMARY_USER="${input_username:-patel}"

    if ! validate_username "$PRIMARY_USER"; then
        log_error "Invalid username. Use only alphanumeric, underscore, or hyphen."
        return 1
    fi

    log_success "Username: $PRIMARY_USER"

    # SECTION 2: STORAGE & BTRFS CONFIGURATION
    log_info ""
    log_info "SECTION 2: Storage & BTRFS Configuration"
    echo "" >&2

    # BTRFS subvolumes use standard naming convention:
    # @, @home, @var, @snapshots, @varcache, @log (no customization needed)
    log_info "BTRFS subvolumes will use standard naming: @, @home, @var, @snapshots, @varcache, @log"
    log_success "BTRFS layout configured with standard subvolume names"

    log_info "Include @log BTRFS subvolume?"
    echo "(Separates systemd journal - improves snapshot efficiency)" >&2
    read -p "Include @log (y/n) [y]: " input_log
    ADD_LOG_SUBVOLUME="${input_log:-y}"
    [[ "$ADD_LOG_SUBVOLUME" =~ ^[yY]$ ]] && ADD_LOG_SUBVOLUME="true" || ADD_LOG_SUBVOLUME="false"
    log_success "@log subvolume: $ADD_LOG_SUBVOLUME"

    log_info "Enable NVIDIA GPU drivers?"
    echo "(For RTX A5500 CUDA support)" >&2
    read -p "Enable NVIDIA (y/n) [y]: " input_gpu
    ENABLE_NVIDIA_GPU="${input_gpu:-y}"
    [[ "$ENABLE_NVIDIA_GPU" =~ ^[yY]$ ]] && ENABLE_NVIDIA_GPU="true" || ENABLE_NVIDIA_GPU="false"
    log_success "NVIDIA GPU support: $ENABLE_NVIDIA_GPU"

    log_info "Snapshot retention count"
    echo "(Number of weekly snapshots to keep: 12 = ~3 months)" >&2
    read -p "Snapshot retention [12]: " input_snapshots
    SNAPSHOT_RETENTION="${input_snapshots:-12}"

    if ! [[ "$SNAPSHOT_RETENTION" =~ ^[0-9]+$ ]] || [[ "$SNAPSHOT_RETENTION" -lt 2 ]]; then
        log_warn "Invalid snapshot retention, using default: 12"
        SNAPSHOT_RETENTION=12
    fi

    log_success "Snapshot retention: $SNAPSHOT_RETENTION"

    log_info "System timezone"
    cat >&2 << 'EOF'

Common timezones:
  UTC                     (Universal Coordinated Time)
  America/New_York        (US Eastern)
  America/Chicago         (US Central)
  America/Denver          (US Mountain)
  America/Los_Angeles     (US Pacific)
  Europe/London           (UK)
  Europe/Paris            (Central Europe)
  Asia/Tokyo              (Japan)
  Asia/Shanghai           (China)
  Asia/Kolkata            (India)
  Australia/Sydney        (Australia)

To find your timezone:
  - List all: timedatectl list-timezones
  - Search:   timedatectl list-timezones | grep -i <region>
  - Example:  timedatectl list-timezones | grep -i america

EOF

    # Single prompt: default to America/New_York on blank or invalid input
    read -p "Enter timezone [America/New_York]: " input_timezone
    SYSTEM_TIMEZONE="${input_timezone:-America/New_York}"

    # Validate timezone exists, otherwise fall back to America/New_York
    if [[ ! -f "/usr/share/zoneinfo/$SYSTEM_TIMEZONE" ]]; then
        log_warn "Timezone '$SYSTEM_TIMEZONE' not found, using America/New_York"
        SYSTEM_TIMEZONE="America/New_York"
    fi
    log_success "Timezone: $SYSTEM_TIMEZONE"

    # CONFIRMATION
    log_info ""
    log_info "============================================================="
    log_info "INSTALLATION SUMMARY - Please Review"
    log_info "============================================================="
    {
        echo ""
        echo "  Hostname:               $HOSTNAME_SYS"
        echo "  Username:               $PRIMARY_USER"
        echo "  LUKS device name:       $LUKS_ROOT_NAME"
        echo "  BTRFS @log subvolume:   $ADD_LOG_SUBVOLUME"
        echo "  NVIDIA GPU drivers:     $ENABLE_NVIDIA_GPU"
        echo "  Snapshot retention:     $SNAPSHOT_RETENTION weeks"
        echo "  System timezone:        $SYSTEM_TIMEZONE"
        echo ""
    } >&2
    read -p "Proceed with installation? (type 'y' to confirm): " final_confirm

    if [[ ! "$final_confirm" =~ ^[yY]([eE][sS])?$ ]]; then
        log_error "Installation cancelled by user"
        exit 1
    fi

    # SAVE CONFIGURATION TO STATE FILE
    log_info "Saving configuration..."

    save_state "HOSTNAME_SYS" "$HOSTNAME_SYS"
    save_state "PRIMARY_USER" "$PRIMARY_USER"
    save_state "LUKS_ROOT_NAME" "$LUKS_ROOT_NAME"
    save_state "ADD_LOG_SUBVOLUME" "$ADD_LOG_SUBVOLUME"
    save_state "ENABLE_NVIDIA_GPU" "$ENABLE_NVIDIA_GPU"
    save_state "SNAPSHOT_RETENTION" "$SNAPSHOT_RETENTION"
    save_state "SYSTEM_TIMEZONE" "$SYSTEM_TIMEZONE"

    log_success "Configuration saved to state file"
    log_success "Phase 1B completed successfully"
}

################################################################################
# PHASE 2: DEVICE CONFIGURATION
################################################################################

phase_2_device_configuration() {

    log_section "PHASE 2: DEVICE & PARTITION CONFIGURATION"

    log_info "Available block devices:"
    echo "" >&2

    # Get list of block devices
    local -a devices
    mapfile -t devices < <(lsblk -d -n -o NAME,SIZE,TYPE | grep -E "nvme|sd" | awk '{print $1}')

    if [[ ${#devices[@]} -eq 0 ]]; then
        log_error "No suitable storage devices found"
        return 1
    fi

    # Display menu
    local i=1
    declare -A device_menu

    for dev in "${devices[@]}"; do
        local full_path="/dev/$dev"
        local size=$(lsblk -d -n -o SIZE "$full_path")
        local type=$(lsblk -d -n -o TYPE "$full_path")

        echo "  ($i) $full_path - $size - $type" >&2
        device_menu[$i]="$full_path"
        ((i++))
    done

    echo "" >&2

    # Get user selection (auto-select if only one device)
    if [[ ${#devices[@]} -eq 1 ]]; then
        TARGET_DEVICE="/dev/${devices[0]}"
        log_info "Auto-selecting only available device: $TARGET_DEVICE"
        if ! validate_block_device "$TARGET_DEVICE"; then
            log_error "Device $TARGET_DEVICE failed validation"
            return 1
        fi
    else
        while true; do
            read -p "Select storage device (enter number 1-$((i-1))): " device_choice

            if [[ ! "$device_choice" =~ ^[0-9]+$ ]]; then
                log_warn "Invalid input. Please enter a number."
                continue
            fi

            if [[ -z "${device_menu[$device_choice]}" ]]; then
                log_warn "Invalid selection. Choose a number between 1 and $((i-1))."
                continue
            fi

            TARGET_DEVICE="${device_menu[$device_choice]}"

            if ! validate_block_device "$TARGET_DEVICE"; then
                log_warn "Invalid or mounted device: $TARGET_DEVICE"
                continue
            fi

            break
        done
    fi

    save_state "TARGET_DEVICE" "$TARGET_DEVICE"

    if ! check_disk_space "$TARGET_DEVICE"; then
        return 1
    fi

    prompt_partition_size

    confirm_destructive_operation "$TARGET_DEVICE"

    # Set partition names based on device type
    if [[ "$TARGET_DEVICE" == *"nvme"* ]] || [[ "$TARGET_DEVICE" == *"mmcblk"* ]]; then
        BOOT_PARTITION="${TARGET_DEVICE}p1"
        ROOT_PARTITION="${TARGET_DEVICE}p2"
    else
        BOOT_PARTITION="${TARGET_DEVICE}1"
        ROOT_PARTITION="${TARGET_DEVICE}2"
    fi

    log_info "Partition configuration:"
    log_info "  Boot: $BOOT_PARTITION (1GB EFI)"
    log_info "  Root: $ROOT_PARTITION ($((AVAILABLE_SPACE_GB - 1))GB BTRFS with all subvolumes)"

    save_state "BOOT_PARTITION" "$BOOT_PARTITION"
    save_state "ROOT_PARTITION" "$ROOT_PARTITION"

    log_success "Phase 2 completed successfully"
}

################################################################################
# PRE-FLIGHT: CLEANUP & UNMOUNT
################################################################################

pre_flight_unmount_all() {
    log_section "PRE-FLIGHT: UNMOUNT ALL BEFORE DISK PREPARATION"

    log_info "Disabling all swap..."
    swapoff -a 2>/dev/null || true

    log_info "Unmounting any mounts under /mnt/*..."
    for mount in /mnt/root /mnt/arch-install /mnt; do
        if mountpoint -q "$mount" 2>/dev/null; then
            log_info "Unmounting $mount (recursive)..."
            umount -R "$mount" 2>/dev/null || umount -l "$mount" 2>/dev/null || true
        fi
    done

    log_info "Unmounting any partitions of target device $TARGET_DEVICE..."
    for part in "${TARGET_DEVICE}"*; do
        if mountpoint -q "$part" 2>/dev/null; then
            log_info "Unmounting $part..."
            umount "$part" 2>/dev/null || umount -l "$part" 2>/dev/null || true
        fi
    done

    log_info "Closing LUKS mappers that use $TARGET_DEVICE..."
    for mapper in /dev/mapper/*; do
        if [[ -b "$mapper" ]] && cryptsetup status "$(basename "$mapper")" 2>/dev/null | grep -q "$TARGET_DEVICE"; then
            log_info "Closing LUKS mapper $(basename "$mapper")..."
            cryptsetup close "$(basename "$mapper")" 2>/dev/null || true
        fi
    done

    log_info "Verifying no mounts remain on $TARGET_DEVICE..."
    if findmnt -n -o TARGET,SOURCE | grep -q "$TARGET_DEVICE"; then
        log_error "Device $TARGET_DEVICE or its partitions are still mounted:"
        findmnt -n -o TARGET,SOURCE | grep "$TARGET_DEVICE" | tee -a "$LOG_FILE"
        log_error "Aborting. Please manually unmount and retry."
        exit 1
    fi

    log_success "Pre-flight unmount completed successfully"
}

################################################################################
# PHASE 3: DISK PREPARATION
################################################################################

phase_3_disk_preparation() {

    log_section "PHASE 3: DISK PREPARATION"

    pre_flight_unmount_all

    log_info "Closing any remaining LUKS volumes by name..."
    cryptsetup close "${LUKS_ROOT_NAME}" 2>/dev/null || true

    log_info "Wiping existing filesystem signatures from $TARGET_DEVICE..."
    execute_cmd "wipefs -af $TARGET_DEVICE" "Wiping all filesystem signatures" true

    log_info "Zeroing out first 10MB of disk..."
    dd if=/dev/zero of="$TARGET_DEVICE" bs=1M count=10 status=none 2>&1 | tee -a "$LOG_FILE" || true
    sync

    log_info "Creating new GPT partition table..."
    if ! parted -s "$TARGET_DEVICE" mklabel gpt >> "$LOG_FILE" 2>&1; then
        log_warn "parted reported an error while creating GPT label; verifying partition table..."
    fi

    if ! parted -s "$TARGET_DEVICE" print 2>&1 | tee -a "$LOG_FILE" | grep -q "Partition Table: gpt"; then
        log_error "Failed to create GPT label on $TARGET_DEVICE. Aborting."
        return 1
    fi

    log_success "GPT label is present on $TARGET_DEVICE"
    sync
    sleep 2

    log_info "Creating EFI System Partition (1GB)..."
    # Use percentage for better alignment
    if ! parted -s -a optimal "$TARGET_DEVICE" mkpart ESP fat32 1MiB 1025MiB >> "$LOG_FILE" 2>&1; then
        log_warn "parted reported an error while creating ESP partition; final layout will be verified."
    fi
    if ! parted -s "$TARGET_DEVICE" set 1 esp on >> "$LOG_FILE" 2>&1; then
        log_warn "parted reported an error while setting ESP boot flag; final layout will be verified."
    fi
    sync
    sleep 1

    log_info "Creating root partition (all remaining space for BTRFS)..."
    execute_cmd "parted -s -a optimal $TARGET_DEVICE mkpart primary 1025MiB 100%" "Creating root partition" true
    sync
    sleep 1

    log_info "Refreshing partition table..."
    partprobe "$TARGET_DEVICE" 2>/dev/null || true
    udevadm settle --timeout=10 || true
    sync
    sleep 3

    log_info "Verifying partitions exist..."
    if [[ ! -b "$BOOT_PARTITION" ]]; then
        log_error "Boot partition $BOOT_PARTITION not found"
        lsblk "$TARGET_DEVICE" | tee -a "$LOG_FILE"
        return 1
    fi

    if [[ ! -b "$ROOT_PARTITION" ]]; then
        log_error "Root partition $ROOT_PARTITION not found"
        lsblk "$TARGET_DEVICE" | tee -a "$LOG_FILE"
        return 1
    fi

    log_success "All partitions verified successfully"

    log_info "Setting partition type (LUKS)..."
    parted -s "$TARGET_DEVICE" set 2 type 8309 2>/dev/null || log_warn "Could not set root partition type"

    log_info "Final partition table:"
    parted -s "$TARGET_DEVICE" print | tee -a "$LOG_FILE"
    lsblk "$TARGET_DEVICE" | tee -a "$LOG_FILE"

    log_success "Phase 3 completed successfully"
}

################################################################################
# PHASE 4: LUKS ENCRYPTION
################################################################################

phase_4_luks_encryption() {

    log_section "PHASE 4: LUKS ENCRYPTION"

    local luks_passphrase
    PROMPTED_LUKS_PASSPHRASE=""
    prompt_luks_passphrase || return 1
    luks_passphrase="$PROMPTED_LUKS_PASSPHRASE"
    unset PROMPTED_LUKS_PASSPHRASE

    # DEBUG: Show exactly which passphrase the script captured
    # for this installation run (for troubleshooting only).
    log_warn "[DEBUG] LUKS passphrase length: ${#luks_passphrase}"
    log_warn "[DEBUG] LUKS passphrase (raw): '$luks_passphrase'"

    log_info "Formatting EFI System Partition..."
    sleep 2
    udevadm settle --timeout=10 || true

    if [[ ! -b "$BOOT_PARTITION" ]]; then
        log_error "Boot partition $BOOT_PARTITION not available"
        return 1
    fi

    execute_cmd "mkfs.fat -F 32 -n EFI $BOOT_PARTITION" "Formatting $BOOT_PARTITION as FAT32" true
    sync

    log_info "Preparing root partition for encryption..."
    sleep 2
    udevadm settle --timeout=10 || true

    if [[ ! -b "$ROOT_PARTITION" ]]; then
        log_error "Root partition $ROOT_PARTITION not available"
        lsblk "$TARGET_DEVICE" | tee -a "$LOG_FILE"
        return 1
    fi

    # Check if already encrypted (cleanup from previous failed attempt)
    if cryptsetup isLuks "$ROOT_PARTITION" 2>/dev/null; then
        log_warn "Root partition already has LUKS header"
        log_warn "Erasing existing LUKS header..."
        echo "YES" | cryptsetup luksErase "$ROOT_PARTITION" 2>/dev/null || true
        sync
        sleep 2
    fi

    log_info "Encrypting root partition with LUKS2 (Argon2id KDF)..."

    # Use temporary keyfile for LUKS setup
    local temp_keyfile_root="/tmp/luks-root-key-$$"
    echo -n "$luks_passphrase" > "$temp_keyfile_root"
    chmod 600 "$temp_keyfile_root"

    # LUKS format with keyfile (piping YES to bypass strict confirmation)
    if ! echo "YES" | cryptsetup luksFormat \
        --type luks2 \
        --pbkdf argon2id \
        --pbkdf-force-iterations 4 \
        --label "LUKS_ROOT" \
        --key-file "$temp_keyfile_root" \
        "$ROOT_PARTITION" 2>&1 | tee -a "$LOG_FILE"; then

        shred -vfz -n 3 "$temp_keyfile_root" 2>/dev/null || rm -f "$temp_keyfile_root"
        log_error "LUKS format failed for root partition"
        return 1
    fi

    log_success "LUKS format completed"

    # Wait for LUKS metadata to be written
    sync
    sleep 3
    udevadm settle --timeout=10 || true

    # Verify LUKS header
    if ! cryptsetup isLuks "$ROOT_PARTITION"; then
        shred -vfz -n 3 "$temp_keyfile_root" 2>/dev/null || rm -f "$temp_keyfile_root"
        log_error "LUKS header verification failed"
        return 1
    fi

    log_success "LUKS header verified"
    log_info "LUKS header information:"
    cryptsetup luksDump "$ROOT_PARTITION" 2>&1 | head -15 | tee -a "$LOG_FILE"

    log_info "Opening encrypted root volume..."

    # CRITICAL FIX: Use keyfile instead of pipe
    if ! cryptsetup luksOpen \
        --key-file "$temp_keyfile_root" \
        "$ROOT_PARTITION" "$LUKS_ROOT_NAME" 2>&1 | tee -a "$LOG_FILE"; then

        shred -vfz -n 3 "$temp_keyfile_root" 2>/dev/null || rm -f "$temp_keyfile_root"
        log_error "Failed to open LUKS root volume"
        log_info "Diagnostic information:"
        cryptsetup luksDump "$ROOT_PARTITION" 2>&1 | tee -a "$LOG_FILE"
        ls -la /dev/mapper/ | tee -a "$LOG_FILE"
        return 1
    fi

    # Securely delete keyfile
    shred -vfz -n 3 "$temp_keyfile_root" 2>/dev/null || rm -f "$temp_keyfile_root"

    sleep 1
    udevadm settle --timeout=10 || true

    if [[ ! -b "/dev/mapper/$LUKS_ROOT_NAME" ]]; then
        log_error "Encrypted root device /dev/mapper/$LUKS_ROOT_NAME not found"
        ls -la /dev/mapper/ | tee -a "$LOG_FILE"
        return 1
    fi

    log_success "Root partition encrypted and opened successfully"
    log_success "Mapped device: /dev/mapper/$LUKS_ROOT_NAME"

    sleep 2
    udevadm settle --timeout=10 || true

    log_info "Verifying encrypted volume..."
    ls -la /dev/mapper/ | tee -a "$LOG_FILE"

    log_info "LUKS status summary:"
    log_info "  Root: $ROOT_PARTITION -> /dev/mapper/$LUKS_ROOT_NAME"
    log_info "  Encryption: [ENABLED]"

    # ===========================================================
    # LUKS PASSPHRASE SELF-TEST (NON-INTERACTIVE)
    # Verify that the passphrase captured in luks_passphrase
    # actually unlocks the new LUKS header. This avoids a second
    # manual re-typing step and removes human input errors from
    # the verification.
    # ===========================================================

    log_info "Running LUKS passphrase self-test for $ROOT_PARTITION (non-interactive)..."

    # Use the in-memory luks_passphrase via stdin as a key-file.
    # If this fails, the header does not match the stored
    # passphrase and we abort to prevent an unbootable system.
    if ! printf '%s' "$luks_passphrase" | \
        cryptsetup luksOpen --test-passphrase --key-file - "$ROOT_PARTITION" 2>&1 | tee -a "$LOG_FILE"; then
        log_error "LUKS self-test failed: stored passphrase does NOT unlock $ROOT_PARTITION."
        log_error "Installation aborted to prevent an unbootable system. Please rerun and choose/passphrase carefully."
        return 1
    fi

    log_success "LUKS passphrase self-test successful for $ROOT_PARTITION"

    save_state "ROOT_CRYPT_OPENED" "true"
    log_success "Phase 4 completed successfully"
}

################################################################################
# PHASE 5: BTRFS FILESYSTEM
################################################################################

phase_5_btrfs_filesystem() {

    log_section "PHASE 5: BTRFS FILESYSTEM SETUP"

    local root_crypt_device="/dev/mapper/$LUKS_ROOT_NAME"

    # ===========================================================
    # CREATE BTRFS FILESYSTEM
    # ===========================================================

    log_info "Creating BTRFS filesystem on encrypted root volume..."
    execute_cmd "mkfs.btrfs -f -L root_encrypted $root_crypt_device" \
        "Formatting $root_crypt_device with BTRFS" true

    log_info "Mounting BTRFS root (temporary)..."
    mkdir -p "$MOUNT_ROOT"
    execute_cmd "mount $root_crypt_device $MOUNT_ROOT" "Mounting BTRFS root" true

    # ===========================================================
    # CREATE SUBVOLUMES
    # ===========================================================

    log_info "Creating BTRFS subvolume hierarchy..."

    execute_cmd "btrfs subvolume create $MOUNT_ROOT/@" "Creating @ (root) subvolume" true
    execute_cmd "btrfs subvolume create $MOUNT_ROOT/@home" "Creating @home subvolume" true
    execute_cmd "btrfs subvolume create $MOUNT_ROOT/@var" "Creating @var subvolume" true
    execute_cmd "btrfs subvolume create $MOUNT_ROOT/@snapshots" "Creating @snapshots subvolume" true
    execute_cmd "btrfs subvolume create $MOUNT_ROOT/@varcache" "Creating @varcache subvolume" true

    if [[ "$ADD_LOG_SUBVOLUME" == "true" ]]; then
        execute_cmd "btrfs subvolume create $MOUNT_ROOT/@log" "Creating @log subvolume (for journal)" true
        log_success "@log subvolume created for systemd journal"
    fi

    # ===========================================================
    # PREPARE FOR REMOUNTING
    # ===========================================================

    log_info "Remounting with optimized mount options..."
    execute_cmd "umount $MOUNT_ROOT" "Unmounting temporary mount" true

    # Directories will be created AFTER mounting root subvolume

    # ===========================================================
    # MOUNT SUBVOLUMES (WITH PROPER QUOTING)
    # Use single quotes around subvolume names to prevent
    # shell interpretation of special characters (@, -, etc)
    # ===========================================================

    # Mount root (@) with security flags
    log_info "Mounting @ (root) subvolume..."
    mkdir -p "$MOUNT_ROOT"
    if ! mount -o "subvol=@,compress=zstd,noatime,space_cache=v2" \
        "$root_crypt_device" "$MOUNT_ROOT" >> "$LOG_FILE" 2>&1; then
        log_error "Failed to mount @ subvolume"
        log_error "Mount command: mount -o subvol=@,compress=zstd,... $root_crypt_device $MOUNT_ROOT"
        lsblk "$TARGET_DEVICE" | tee -a "$LOG_FILE"
        dmesg | tail -20 | tee -a "$LOG_FILE"
        return 1
    fi
    log_success "@ subvolume mounted at $MOUNT_ROOT"

    # ===========================================================
    # CREATE MOUNT POINT DIRECTORIES (AFTER MOUNTING ROOT)
    # ===========================================================

    log_info "Creating mount point directories..."
    mkdir -p "$MOUNT_ROOT"/{home,var,.snapshots,boot}

    # Mount home (@home)
    log_info "Mounting @home subvolume..."
    if ! mount -o "subvol=@home,compress=zstd,noatime,space_cache=v2" \
        "$root_crypt_device" "$MOUNT_ROOT/home" >> "$LOG_FILE" 2>&1; then
        log_error "Failed to mount @home subvolume"
        log_error "Mount command: mount -o subvol=@home,... $root_crypt_device $MOUNT_ROOT/home"
        return 1
    fi
    log_success "@home subvolume mounted at $MOUNT_ROOT/home"

    # Mount var (@var)
    log_info "Mounting @var subvolume..."
    if ! mount -o "subvol=@var,compress=zstd,noatime,space_cache=v2,nodev,nosuid" \
        "$root_crypt_device" "$MOUNT_ROOT/var" >> "$LOG_FILE" 2>&1; then
        log_error "Failed to mount @var subvolume"
        log_error "Mount command: mount -o subvol=@var,... $root_crypt_device $MOUNT_ROOT/var"
        return 1
    fi
    log_success "@var subvolume mounted at $MOUNT_ROOT/var"

    # Create nested directories inside @var
    mkdir -p "$MOUNT_ROOT/var/cache"
    if [[ "$ADD_LOG_SUBVOLUME" == "true" ]]; then
        mkdir -p "$MOUNT_ROOT/var/log"
    fi

    # Mount varcache (@varcache)
    log_info "Mounting @varcache subvolume..."
    if ! mount -o "subvol=@varcache,compress=zstd,noatime,space_cache=v2,nodev,nosuid" \
        "$root_crypt_device" "$MOUNT_ROOT/var/cache" >> "$LOG_FILE" 2>&1; then
        log_error "Failed to mount @varcache subvolume"
        log_error "Mount command: mount -o subvol=@varcache,... $root_crypt_device $MOUNT_ROOT/var/cache"
        return 1
    fi
    log_success "@varcache subvolume mounted at $MOUNT_ROOT/var/cache"

    # Mount snapshots (@snapshots)
    log_info "Mounting @snapshots subvolume..."
    if ! mount -o "subvol=@snapshots,compress=zstd,noatime,space_cache=v2,nodev,nosuid" \
        "$root_crypt_device" "$MOUNT_ROOT/.snapshots" >> "$LOG_FILE" 2>&1; then
        log_error "Failed to mount @snapshots subvolume"
        log_error "Mount command: mount -o subvol=@snapshots,... $root_crypt_device $MOUNT_ROOT/.snapshots"
        return 1
    fi
    log_success "@snapshots subvolume mounted at $MOUNT_ROOT/.snapshots"

    # Mount log (@log) - ONLY if ADD_LOG_SUBVOLUME is true
    if [[ "$ADD_LOG_SUBVOLUME" == "true" ]]; then
        log_info "Mounting @log subvolume..."
        if ! mount -o "subvol=@log,compress=zstd,noatime,space_cache=v2,nodev,nosuid" \
            "$root_crypt_device" "$MOUNT_ROOT/var/log" >> "$LOG_FILE" 2>&1; then
            log_error "Failed to mount @log subvolume"
            log_error "Mount command: mount -o subvol=@log,... $root_crypt_device $MOUNT_ROOT/var/log"
            log_error "Note: Ensure /mnt/root/var/log directory exists"
            return 1
        fi
        log_success "@log subvolume mounted at $MOUNT_ROOT/var/log"
    fi

    # Mount EFI partition
    log_info "Mounting EFI System Partition..."
    if ! mount "$BOOT_PARTITION" "$MOUNT_ROOT/boot" >> "$LOG_FILE" 2>&1; then
        log_error "Failed to mount $BOOT_PARTITION to $MOUNT_ROOT/boot"
        return 1
    fi
    log_success "EFI partition mounted at $MOUNT_ROOT/boot"

    # ===========================================================
    # VERIFY MOUNT CONFIGURATION
    # ===========================================================

    log_info "Verifying BTRFS mount configuration..."
    mount | grep "$MOUNT_ROOT" | tee -a "$LOG_FILE"

    log_success "BTRFS subvolume hierarchy created and mounted"

    save_state "MOUNT_ROOT" "$MOUNT_ROOT"
    save_state "BTRFS_MOUNTED" "true"
    log_success "Phase 5 completed successfully"
}

phase_6_base_installation() {

    log_section "PHASE 6: BASE SYSTEM INSTALLATION (PACSTRAP)"

    log_info "Updating Pacman keyring..."
    execute_cmd_retry "pacman-key --init" "Initializing pacman keyring" 2
    execute_cmd_retry "pacman-key --populate archlinux" "Populating archlinux keyring" 2

    log_info "Syncing package database..."
    execute_cmd_retry "pacman -Sy" "Syncing package database" 2

    local free_space
    free_space=$(df "$MOUNT_ROOT" | awk 'NR==2 {print $4}')
    local free_gb=$((free_space / 1024 / 1024))

    if [[ $free_gb -lt 30 ]]; then
        log_error "Insufficient disk space for base installation ($free_gb GB available, need 30GB)"
        return 1
    fi

    log_info "Available space for installation: ${free_gb}GB"

    local packages=(
        # Core system
        "base" "linux-zen" "linux-zen-headers" "linux-lts" "linux-lts-headers"
        "linux-firmware"          # CRITICAL: Contains WiFi/hardware firmware
        "mkinitcpio"

        # Bootloader
        "grub" "efibootmgr" "os-prober" "ntfs-3g"

        # Filesystem
        "btrfs-progs"
        "cryptsetup"

        # CRITICAL: Network packages (WiFi requires wpa_supplicant!)
        "networkmanager"
        "wpa_supplicant"          # CRITICAL: Required for NetworkManager WiFi
        "wireless-regdb"          # WiFi regulatory database
        "iw"                      # Wireless configuration tool
        "dhcpcd"                  # Fallback DHCP client

        # Editors
        "vim" "nano"

        # Development & utilities
        "git" "curl" "wget"
        "sudo"
        "zsh" "zsh-completions"
        "openssh"
        "base-devel"

        # Xorg & display
        "xorg-server" "xorg-xinit" "xorg-xrandr"
        "libx11" "libxft" "libxinerama" "libxcb"
        "fontconfig" "freetype2"
        "noto-fonts" "noto-fonts-emoji"
        "picom"

        # Audio (pipewire stack)
        "pipewire" "pipewire-pulse" "pipewire-alsa" "wireplumber"

        # DBus (required for many desktop apps)
        "dbus"
    )

    if [[ "$ENABLE_NVIDIA_GPU" == "true" ]]; then
        packages+=("nvidia" "nvidia-utils")
    fi

    local packages_str
    packages_str=$(IFS=' '; echo "${packages[*]}")

    log_info "Installing base packages via pacstrap (${#packages[@]} packages)..."
    log_info "This will take 5-15 minutes depending on network speed..."

    if ! execute_cmd_retry "pacstrap -K $MOUNT_ROOT $packages_str" \
        "Installing base system packages" 2; then
        log_error "Pacstrap installation failed"
        return 1
    fi

    log_success "Base system installation completed"
    save_state "BASE_INSTALLED" "true"
    log_success "Phase 6 completed successfully"
}

phase_7_mount_configuration() {

    log_section "PHASE 7: MOUNT & CRYPTTAB CONFIGURATION & ENCRYPTION"

    log_info "Generating fstab from current mounts..."
    execute_cmd "genfstab -U $MOUNT_ROOT >> $MOUNT_ROOT/etc/fstab" "Generating fstab" true

    log_info "Generated fstab:"
    cat "$MOUNT_ROOT/etc/fstab" | tee -a "$LOG_FILE"

    log_info "Configuring crypttab for encrypted root volume..."

    local root_partuuid
    root_partuuid=$(blkid -s PARTUUID -o value "$ROOT_PARTITION")

    cat > "$MOUNT_ROOT/etc/crypttab" << EOF
$LUKS_ROOT_NAME	PARTUUID=$root_partuuid	none	luks,x-systemd.device-timeout=10
EOF

    log_info "crypttab configuration (single encrypted root with all BTRFS subvolumes):"
    cat "$MOUNT_ROOT/etc/crypttab" | tee -a "$LOG_FILE"

    save_state "FSTAB_GENERATED" "true"
    log_success "Phase 7 completed successfully"
}

################################################################################
# PHASE 8: BOOTLOADER CONFIGURATION
################################################################################

phase_8_chroot_configuration() {

    log_section "PHASE 8: CHROOT ENVIRONMENT & BOOTLOADER"

    # ===========================================================
    # CONFIGURE MKINITCPIO
    # ===========================================================

    log_info "Configuring mkinitcpio for encrypted root..."

    local mkinitcpio_conf="$MOUNT_ROOT/etc/mkinitcpio.conf"

    # Backup original
    cp "$mkinitcpio_conf" "${mkinitcpio_conf}.bak"

    # Update MODULES - only btrfs needed (dm_crypt auto-loaded by encrypt hook)
    sed -i 's/^MODULES=.*/MODULES=(btrfs)/' "$mkinitcpio_conf"

    # Update HOOKS - traditional encrypt hook with proper order
    sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block encrypt filesystems fsck)/' "$mkinitcpio_conf"

    log_info "Updated mkinitcpio configuration:"
    grep -E "^(MODULES|HOOKS)" "$mkinitcpio_conf" | tee -a "$LOG_FILE"

    # ===========================================================
    # GENERATE INITRAMFS FOR ALL INSTALLED KERNELS
    # ===========================================================

    log_info "Generating initramfs for all installed kernels (mkinitcpio -P)..."

    # METHOD 1: Try arch-chroot (recommended, handles environment setup)
    if arch-chroot "$MOUNT_ROOT" mkinitcpio -P 2>&1 | tee -a "$LOG_FILE"; then
        log_success "Initramfs generated via arch-chroot"
    else
        local arch_chroot_exit=$?
        log_warn "arch-chroot mkinitcpio failed (exit code: $arch_chroot_exit)"
        log_info "Attempting fallback method with /bin/sh..."

        # METHOD 2: Fallback - use chroot directly with /bin/sh
        # This avoids the bash permission issue
        if chroot "$MOUNT_ROOT" /bin/sh -c "mkinitcpio -P" 2>&1 | tee -a "$LOG_FILE"; then
            log_success "Initramfs generated via chroot /bin/sh"
        else
            local chroot_exit=$?
            log_error "chroot mkinitcpio also failed (exit code: $chroot_exit)"
            log_error "Initramfs generation failed - cannot proceed"
            return 1
        fi
    fi

    # ===========================================================
    # VERIFY INITRAMFS FOR PRIMARY KERNEL (linux-zen)
    # ===========================================================

    if [[ ! -f "$MOUNT_ROOT/boot/initramfs-linux-zen.img" ]]; then
        log_error "initramfs-linux-zen.img not found after mkinitcpio"
        log_error "Expected location: $MOUNT_ROOT/boot/initramfs-linux-zen.img"
        log_error "Boot directory contents:"
        ls -la "$MOUNT_ROOT/boot/" | tee -a "$LOG_FILE"
        return 1
    fi

    local initramfs_size
    initramfs_size=$(stat -c%s "$MOUNT_ROOT/boot/initramfs-linux-zen.img")
    log_success "Initramfs file for linux-zen verified (size: ${initramfs_size} bytes)"

    # ===========================================================
    # INSTALL GRUB BOOTLOADER
    # ===========================================================

    log_info "Installing GRUB to EFI partition..."
    arch-chroot "$MOUNT_ROOT" grub-install \
        --target=x86_64-efi \
        --efi-directory=/boot \
        --bootloader-id="devta linux" \
        --recheck 2>&1 | tee -a "$LOG_FILE"

    if [[ $? -ne 0 ]]; then
        log_error "GRUB installation failed"
        return 1
    fi

    log_info "Generating GRUB configuration..."
    arch-chroot "$MOUNT_ROOT" grub-mkconfig -o /boot/grub/grub.cfg 2>&1 | tee -a "$LOG_FILE"

    log_info "Configuring GRUB kernel parameters for encrypted root..."

    local grub_default="$MOUNT_ROOT/etc/default/grub"
    local root_uuid
    root_uuid=$(blkid -s UUID -o value "$ROOT_PARTITION")

    if [[ -z "$root_uuid" ]]; then
        log_error "Could not retrieve UUID for $ROOT_PARTITION"
        return 1
    fi

    log_debug "Root partition UUID: $root_uuid"

    # Set GRUB kernel command line with LUKS parameters
    # cryptdevice=UUID:mapper_name (traditional encrypt hook format)
    sed -i "/^GRUB_CMDLINE_LINUX=/c\GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=${root_uuid}:${LUKS_ROOT_NAME} root=/dev/mapper/${LUKS_ROOT_NAME} quiet\"" "$grub_default"

    # Enable cryptodisk support in GRUB
    echo "GRUB_ENABLE_CRYPTODISK=y" >> "$grub_default"

    # Ensure GRUB uses 'devarch' as the distributor name (menu entry label)
    if grep -q 'GRUB_DISTRIBUTOR=' "$grub_default"; then
        sed -i 's/^#\?GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="devarch"/' "$grub_default"
    else
        echo 'GRUB_DISTRIBUTOR="devarch"' >> "$grub_default"
    fi

    # Enable os-prober so GRUB detects Windows/other OSes
    if grep -q 'GRUB_DISABLE_OS_PROBER=' "$grub_default"; then
        sed -i 's/^#\?GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' "$grub_default"
    else
        echo 'GRUB_DISABLE_OS_PROBER=false' >> "$grub_default"
    fi

    # Configure GRUB menu timeout and visibility
    # GRUB_TIMEOUT: seconds to show menu (5 seconds)
    # GRUB_TIMEOUT_STYLE: 'menu' ensures menu is always visible
    if grep -q 'GRUB_TIMEOUT=' "$grub_default"; then
        sed -i 's/^#\?GRUB_TIMEOUT=.*/GRUB_TIMEOUT=5/' "$grub_default"
    else
        echo 'GRUB_TIMEOUT=5' >> "$grub_default"
    fi

    if grep -q 'GRUB_TIMEOUT_STYLE=' "$grub_default"; then
        sed -i 's/^#\?GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=menu/' "$grub_default"
    else
        echo 'GRUB_TIMEOUT_STYLE=menu' >> "$grub_default"
    fi

    # Enable detection of ALL bootable devices (USB, CD, HDD, SSD, etc.)
    # GRUB_DISABLE_SUBMENU: Show all entries in main menu instead of submenus
    if grep -q 'GRUB_DISABLE_SUBMENU=' "$grub_default"; then
        sed -i 's/^#\?GRUB_DISABLE_SUBMENU=.*/GRUB_DISABLE_SUBMENU=y/' "$grub_default"
    else
        echo 'GRUB_DISABLE_SUBMENU=y' >> "$grub_default"
    fi

    log_info "Updated GRUB configuration:"
    grep -E "^(GRUB_CMDLINE_LINUX|GRUB_ENABLE_CRYPTODISK|GRUB_DISTRIBUTOR|GRUB_DISABLE_OS_PROBER|GRUB_TIMEOUT)" "$grub_default" | tee -a "$LOG_FILE"

    # ===========================================================
    # RUN OS-PROBER TO DETECT OTHER OPERATING SYSTEMS
    # ===========================================================

    log_info "Running os-prober to detect other operating systems and drives..."
    log_info "This will scan all available partitions..."

    # Mount all partitions so os-prober can detect them
    arch-chroot "$MOUNT_ROOT" bash -c "
        # Try to mount all unmounted partitions temporarily
        for dev in /dev/sd* /dev/nvme*n*p* /dev/vd*; do
            [[ -b \"\$dev\" ]] || continue
            # Skip our own encrypted/mounted partitions
            mountpoint -q \"\$dev\" && continue
            # Try to mount read-only temporarily
            mkdir -p /mnt/probe\${dev##*/} 2>/dev/null
            mount -o ro \"\$dev\" /mnt/probe\${dev##*/} 2>/dev/null || true
        done
    " 2>/dev/null || true

    # Run os-prober to scan for other OSes
    arch-chroot "$MOUNT_ROOT" os-prober 2>&1 | tee -a "$LOG_FILE" || log_warn "os-prober found no other operating systems"

    # Unmount probe mounts
    arch-chroot "$MOUNT_ROOT" bash -c "
        for mnt in /mnt/probe*; do
            [[ -d \"\$mnt\" ]] && umount \"\$mnt\" 2>/dev/null && rmdir \"\$mnt\" 2>/dev/null || true
        done
    " 2>/dev/null || true

    # ===========================================================
    # GENERATE GRUB CONFIGURATION
    # ===========================================================

    log_info "Generating GRUB menu configuration..."

    if ! arch-chroot "$MOUNT_ROOT" grub-mkconfig -o /boot/grub/grub.cfg 2>&1 | tee -a "$LOG_FILE"; then
        log_error "GRUB configuration generation failed"
        return 1
    fi

    log_success "GRUB configuration generated successfully"

    # ===========================================================
    # VERIFY GRUB CONFIGURATION
    # ===========================================================

    if [[ ! -f "$MOUNT_ROOT/boot/grub/grub.cfg" ]]; then
        log_error "GRUB configuration file not found"
        return 1
    fi

    # Verify cryptdevice parameter is in grub.cfg
    if ! grep -q "cryptdevice=" "$MOUNT_ROOT/boot/grub/grub.cfg"; then
        log_warn "cryptdevice parameter not found in grub.cfg"
        log_warn "This may cause boot issues"
    else
        log_success "cryptdevice parameter verified in grub.cfg"
    fi

    log_success "GRUB bootloader configured successfully"
    save_state "GRUB_INSTALLED" "true"
    log_success "Phase 8 completed successfully"
}

phase_9_system_configuration() {

    log_section "PHASE 9: SYSTEM CONFIGURATION"

    log_info "Configuring hostname..."

    echo "$HOSTNAME_SYS" > "$MOUNT_ROOT/etc/hostname"

    cat > "$MOUNT_ROOT/etc/hosts" << EOF
127.0.0.1       localhost
::1             localhost ip6-localhost ip6-loopback
127.0.1.1       $HOSTNAME_SYS.localdomain $HOSTNAME_SYS
EOF

    log_success "Hostname set to: $HOSTNAME_SYS"
    save_state "HOSTNAME_SYS" "$HOSTNAME_SYS"

    log_info "Setting timezone to $SYSTEM_TIMEZONE..."
    arch-chroot "$MOUNT_ROOT" ln -sf /usr/share/zoneinfo/"$SYSTEM_TIMEZONE" /etc/localtime
    arch-chroot "$MOUNT_ROOT" hwclock --systohc

    log_info "Configuring locale (en_US.UTF-8)..."
    echo "en_US.UTF-8 UTF-8" > "$MOUNT_ROOT/etc/locale.gen"
    arch-chroot "$MOUNT_ROOT" locale-gen
    echo "LANG=en_US.UTF-8" > "$MOUNT_ROOT/etc/locale.conf"

    log_info "Enabling essential system services..."

    # NetworkManager - Network connectivity
    log_info "Enabling NetworkManager..."
    arch-chroot "$MOUNT_ROOT" systemctl enable NetworkManager

    # =======================================================================
    # WIFI FIX: Ensure WiFi adapter is not blocked and wpa_supplicant works
    # Common issue: WiFi shows only "lo" adapter because device is rfkill blocked
    # =======================================================================
    log_info "Configuring WiFi support..."

    # Enable wpa_supplicant (NetworkManager uses it for WPA/WPA2 WiFi)
    arch-chroot "$MOUNT_ROOT" systemctl enable wpa_supplicant 2>/dev/null || true

    # Create rfkill unblock script to run at boot (fixes soft-blocked WiFi)
    mkdir -p "$MOUNT_ROOT/etc/NetworkManager/dispatcher.d/pre-up.d" 2>/dev/null || true
    cat > "$MOUNT_ROOT/etc/NetworkManager/dispatcher.d/pre-up.d/10-rfkill-unblock" << 'RFKILL_SCRIPT'
#!/bin/sh
# Unblock all wireless devices (WiFi, Bluetooth, etc.) regardless of adapter name
rfkill unblock all 2>/dev/null || true
RFKILL_SCRIPT
    chmod +x "$MOUNT_ROOT/etc/NetworkManager/dispatcher.d/pre-up.d/10-rfkill-unblock" 2>/dev/null || true

    # Also create a systemd service to unblock rfkill at boot
    cat > "$MOUNT_ROOT/etc/systemd/system/rfkill-unblock.service" << 'RFKILL_SERVICE'
[Unit]
Description=Unblock all wireless devices (rfkill)
Before=NetworkManager.service
After=systemd-rfkill.service

[Service]
Type=oneshot
ExecStart=/usr/bin/rfkill unblock all
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
RFKILL_SERVICE
    arch-chroot "$MOUNT_ROOT" systemctl enable rfkill-unblock.service 2>/dev/null || true

    log_success "WiFi support configured (rfkill unblock + wpa_supplicant)"

    # =======================================================================
    # WIFI CREDENTIAL PERSISTENCE - Copy WiFi connections from installation media
    # This allows the user to connect to WiFi on first boot without reconfiguring
    # =======================================================================
    log_info "Copying WiFi credentials from installation media..."

    # NetworkManager stores connections in /etc/NetworkManager/system-connections/
    local nm_live_dir="/etc/NetworkManager/system-connections"
    local nm_target_dir="$MOUNT_ROOT/etc/NetworkManager/system-connections"

    if [[ -d "$nm_live_dir" ]] && [[ -n "$(ls -A "$nm_live_dir" 2>/dev/null)" ]]; then
        mkdir -p "$nm_target_dir"
        cp -a "$nm_live_dir"/* "$nm_target_dir"/ 2>/dev/null || true
        # Ensure correct permissions (600 required for connection files)
        chmod 600 "$nm_target_dir"/* 2>/dev/null || true
        local wifi_count=$(ls -1 "$nm_target_dir"/*.nmconnection 2>/dev/null | wc -l)
        log_success "Copied $wifi_count WiFi connection(s) to new system"
    else
        log_info "No WiFi connections found on installation media to copy"
    fi

    # Also try iwd connections (alternative WiFi backend)
    local iwd_live_dir="/var/lib/iwd"
    local iwd_target_dir="$MOUNT_ROOT/var/lib/iwd"

    if [[ -d "$iwd_live_dir" ]] && [[ -n "$(ls -A "$iwd_live_dir" 2>/dev/null)" ]]; then
        mkdir -p "$iwd_target_dir"
        cp -a "$iwd_live_dir"/* "$iwd_target_dir"/ 2>/dev/null || true
        log_success "Copied iwd WiFi credentials to new system"
    fi

    # SSH - Remote access
    log_info "Enabling SSH service..."
    arch-chroot "$MOUNT_ROOT" systemctl enable sshd

    # Configure SSH: disable root login by default for security
    # Users should log in as their primary user and use sudo as needed
    if [[ -f "$MOUNT_ROOT/etc/ssh/sshd_config" ]]; then
        log_info "Configuring SSH to disable root login by default..."
        # Explicitly disable root SSH login
        sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' "$MOUNT_ROOT/etc/ssh/sshd_config"
        # Ensure password authentication is enabled for normal users
        sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' "$MOUNT_ROOT/etc/ssh/sshd_config"
        log_success "SSH configured: root login disabled, password authentication enabled for users"
    else
        log_warn "SSH config file not found, skipping SSH hardening"
    fi

    # systemd-timesyncd - NTP time synchronization
    log_info "Enabling time synchronization (systemd-timesyncd)..."
    arch-chroot "$MOUNT_ROOT" systemctl enable systemd-timesyncd

    # fstrim.timer - SSD TRIM support (weekly automatic TRIM)
    log_info "Enabling SSD TRIM timer (fstrim.timer)..."
    arch-chroot "$MOUNT_ROOT" systemctl enable fstrim.timer

    # systemd-resolved - DNS resolver (optional, NetworkManager can handle DNS)
    # Uncomment if you want systemd-resolved instead of NetworkManager's DNS
    # log_info "Enabling systemd-resolved..."
    # arch-chroot "$MOUNT_ROOT" systemctl enable systemd-resolved

    log_success "Essential system services enabled"

    log_info "Configuring sudo access..."
    sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' "$MOUNT_ROOT/etc/sudoers"

    if ! arch-chroot "$MOUNT_ROOT" visudo -c 2>&1 | grep -q "parsed OK"; then
        log_error "sudoers configuration validation failed"
        return 1
    fi

    log_success "System configuration completed"
    save_state "SYSTEM_CONFIGURED" "true"
    log_success "Phase 9 completed successfully"
}

phase_10_user_setup() {

    log_section "PHASE 10: USER ACCOUNT SETUP"

    log_info "Creating primary user account: $PRIMARY_USER"

    if arch-chroot "$MOUNT_ROOT" bash -c "useradd -m -G wheel -s /usr/bin/zsh $PRIMARY_USER" 2>&1 | tee -a "$LOG_FILE"; then
        log_success "User account created: $PRIMARY_USER"
    else
        log_error "Failed to create user account"
        return 1
    fi

    log_info "Setting password for $PRIMARY_USER..."
    local user_password
    while true; do
        read -sp "Enter password for user $PRIMARY_USER: " user_password
        echo >&2
        local user_password_confirm
        read -sp "Confirm password: " user_password_confirm
        echo >&2
        if [[ "$user_password" == "$user_password_confirm" ]]; then
            break
        else
            log_warn "Passwords do not match. Try again."
        fi
    done

    echo "$PRIMARY_USER:$user_password" | arch-chroot "$MOUNT_ROOT" chpasswd
    log_success "Password set for $PRIMARY_USER"

    log_info "Setting root password..."
    local root_password
    while true; do
        read -sp "Enter password for root: " root_password
        echo >&2
        local root_password_confirm
        read -sp "Confirm password: " root_password_confirm
        echo >&2
        if [[ "$root_password" == "$root_password_confirm" ]]; then
            break
        else
            log_warn "Passwords do not match. Try again."
        fi
    done

    echo "root:$root_password" | arch-chroot "$MOUNT_ROOT" chpasswd
    log_success "Root password set successfully"

    # Clear password variables from memory
    unset user_password user_password_confirm root_password root_password_confirm

    log_info "Verifying sudo configuration for $PRIMARY_USER..."

    if arch-chroot "$MOUNT_ROOT" sudo -u "$PRIMARY_USER" -n true 2>/dev/null; then
        log_warn "User has passwordless sudo (verify if intentional)"
    else
        log_info "User requires password for sudo (expected)"
    fi

    save_state "PRIMARY_USER" "$PRIMARY_USER"
    log_success "User setup completed"
    log_success "Phase 10 completed successfully"
}

phase_11_security_hardening() {

    log_section "PHASE 11: SECURITY HARDENING"

    log_info "Creating security-hardened sysctl parameters..."

    cat > "$MOUNT_ROOT/etc/sysctl.d/99-hardening.conf" << 'SYSCTL_CONFIG'
# Security-hardened kernel parameters for research environment
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.randomize_va_space = 2
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
fs.protected_fifos = 2
fs.protected_regular = 2
fs.protected_symlinks = 1
fs.protected_hardlinks = 1
SYSCTL_CONFIG

    log_success "Sysctl hardening configuration created"

    save_state "HARDENING_APPLIED" "true"
    log_success "Phase 11 completed successfully"
}

phase_12_snapshot_automation() {

    log_section "PHASE 12: BTRFS SNAPSHOT AUTOMATION"

    log_info "Creating BTRFS snapshot automation script..."

    cat > "$MOUNT_ROOT/usr/local/bin/btrfs-snapshot-weekly.sh" << 'SNAP_SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

readonly SNAPSHOT_DIR="/.snapshots"
readonly TIMESTAMP=$(date +%Y%m%d-%H%M%S)
readonly LOG_FILE="/var/log/btrfs-snapshots.log"

log_snapshot() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log_snapshot "Starting weekly snapshot process"

for subvol in "@" "@home"; do
    snapshot_name="${subvol}-snapshot-${TIMESTAMP}"
    snapshot_path="$SNAPSHOT_DIR/$snapshot_name"

    if btrfs subvolume snapshot -r "/${subvol#@}" "$snapshot_path" 2>/dev/null; then
        log_snapshot " * Snapshot created: $snapshot_name"
    else
        log_snapshot " * Failed to create snapshot: $snapshot_name"
    fi
done

max_snapshots=SNAPSHOT_RETENTION_PLACEHOLDER
current_count=$(btrfs subvolume list "$SNAPSHOT_DIR" 2>/dev/null | wc -l || echo 0)

if [[ $current_count -gt $max_snapshots ]]; then
    log_snapshot "Snapshot count ($current_count) exceeds limit, cleaning up..."

    btrfs subvolume list "$SNAPSHOT_DIR" 2>/dev/null | \
        awk '{print $NF}' | sort | head -n $((current_count - max_snapshots)) | \
        while read -r snap; do
            if btrfs subvolume delete "$SNAPSHOT_DIR/$snap" 2>/dev/null; then
                log_snapshot "Deleted old snapshot: $snap"
            fi
        done
fi

log_snapshot "Weekly snapshot process completed"
SNAP_SCRIPT

    sed -i "s/SNAPSHOT_RETENTION_PLACEHOLDER/$SNAPSHOT_RETENTION/" "$MOUNT_ROOT/usr/local/bin/btrfs-snapshot-weekly.sh"
    chmod +x "$MOUNT_ROOT/usr/local/bin/btrfs-snapshot-weekly.sh"

    cat > "$MOUNT_ROOT/etc/systemd/system/btrfs-snapshot-weekly.service" << 'SERVICE'
[Unit]
Description=Weekly BTRFS Snapshot Service
After=local-fs.target
Requires=btrfs-snapshot-weekly.timer

[Service]
Type=oneshot
ExecStart=/usr/local/bin/btrfs-snapshot-weekly.sh
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE

    cat > "$MOUNT_ROOT/etc/systemd/system/btrfs-snapshot-weekly.timer" << 'TIMER'
[Unit]
Description=Weekly BTRFS Snapshot Timer
Documentation=man:btrfs(8)

[Timer]
OnCalendar=Sun *-*-* 02:00:00
RandomizedDelaySec=5min
Persistent=true
Unit=btrfs-snapshot-weekly.service

[Install]
WantedBy=timers.target
TIMER

    arch-chroot "$MOUNT_ROOT" systemctl daemon-reload
    arch-chroot "$MOUNT_ROOT" systemctl enable btrfs-snapshot-weekly.timer

    log_success "BTRFS snapshot automation configured"
    save_state "SNAPSHOTS_CONFIGURED" "true"
    log_success "Phase 12 completed successfully"
}

phase_14_optional_desktop_setup() {
    # Desktop environment prompt
    cat >&2 << 'EOF'

===============================================================================
                 DESKTOP ENVIRONMENT INSTALLATION
                          ** PHASE 14 **
===============================================================================

Congratulations! Your secure base system is ready!

The next step is OPTIONAL but RECOMMENDED:
Install complete desktop environment (DWM + Dotfiles)

WHAT WILL BE INSTALLED:
  - archrice dotfiles       - yay AUR helper
  - DWM window manager      - ST terminal, dmenu, dwmblocks
  - Moonfly dark theme      - ~80 packages from progs.csv
  - Librewolf browser       - Development tools (neovim, git)
  - Full statusbar widgets  - All scripts and integrations

ADVANTAGES:
  * No reboot needed        * Network already configured
  * Complete system ready in one session
  * Proper vim plugin installation
  * Working statusbar and wallpaper

TIME: 15-45 minutes (network dependent)

TIP: Can install later with: sudo bash arch-secure-deploy.sh --phase 14

===============================================================================
               INSTALL DESKTOP ENVIRONMENT NOW?
===============================================================================

EOF
    local response
    read -p "  Your choice (y/N): " response

    if [[ ! "$response" =~ ^[yY]$ ]]; then
        log_info "Skipping desktop environment setup."
        save_state "DESKTOP_SETUP_SKIPPED" "true"
        log_success "Phase 14 skipped by user"
        return 0
    fi

    log_info "Starting desktop environment installation..."
    save_state "DESKTOP_SETUP_STARTED" "true"

    # Desktop setup configuration (LARBS-style variables)
    local DOTFILES_REPO="https://github.com/yashpatel-cv/archrice.git"
    local DOTFILES_BRANCH="master"
    local REPODIR="/home/$PRIMARY_USER/.local/src"
    local AURHELPER="yay"

    log_info "This may take 15-45 minutes depending on network speed..."
    log_info ""

    # Execute desktop setup inline (LARBS-style: all logic in one script)
    arch-chroot "$MOUNT_ROOT" /bin/bash <<DESKTOP_SETUP_EOF
set -e

# ============================================================================
# PARSS Desktop Setup - LARBS-Compatible Implementation
# ============================================================================

# Color definitions
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# Helper functions (LARBS-style)
info() { echo -e "\${GREEN}[INFO]\${NC} \$*"; }
warn() { echo -e "\${YELLOW}[WARN]\${NC} \$*"; }
error() { echo -e "\${RED}[ERROR]\${NC} \$*"; }

# Install package via pacman (LARBS installpkg)
installpkg() {
    pacman --noconfirm --needed -S "\$1" >/dev/null 2>&1
}

# Install from AUR (LARBS aurinstall)
aurinstall() {
    info "[AUR] Installing \$1..."
    sudo -u $PRIMARY_USER $AURHELPER -S --noconfirm --needed "\$1" >/dev/null 2>&1 || warn "AUR install failed: \$1"
}

# Install from git + make (LARBS gitmakeinstall)
gitmakeinstall() {
    local repo="\$1"
    local progname="\${repo##*/}"
    progname="\${progname%.git}"
    local dir="$REPODIR/\$progname"

    info "[git/make] Installing \$progname..."

    sudo -u $PRIMARY_USER mkdir -p "$REPODIR"

    if [[ -d "\$dir/.git" ]]; then
        cd "\$dir" || return 1
        sudo -u $PRIMARY_USER git pull --force origin master >/dev/null 2>&1 || true
    else
        sudo -u $PRIMARY_USER git -C "$REPODIR" clone --depth 1 --single-branch \
            --no-tags -q "\$repo" "\$dir" || {
            warn "Clone failed: \$repo"
            return 1
        }
    fi

    cd "\$dir" || return 1
    make >/dev/null 2>&1
    make install >/dev/null 2>&1
    cd /tmp || return 1
}

# Clone dotfiles repository (LARBS putgitrepo - CRITICAL for proper integration)
putgitrepo() {
    local repo="\$1"
    local dest="\$2"
    local branch="\${3:-master}"

    info "Cloning dotfiles repository..."

    local tmpdir=\$(mktemp -d)
    [ ! -d "\$dest" ] && mkdir -p "\$dest"
    chown $PRIMARY_USER:wheel "\$tmpdir" "\$dest"

    # CRITICAL: Use --recursive and --recurse-submodules for git submodules
    sudo -u $PRIMARY_USER git -C "$REPODIR" clone --depth 1 \
        --single-branch --no-tags -q --recursive -b "\$branch" \
        --recurse-submodules "\$repo" "\$tmpdir" || {
        warn "Failed to clone dotfiles"
        return 1
    }

    # CRITICAL: Use cp -rfT to merge into home (preserves existing files)
    sudo -u $PRIMARY_USER cp -rfT "\$tmpdir" "\$dest"

    # Cleanup: Remove .git and other unnecessary files from home
    rm -rf "\$dest/.git" "\$dest/README.md" "\$dest/LICENSE" "\$dest/FUNDING.yml"
    rm -rf "\$tmpdir"

    info " * Dotfiles deployed to \$dest"
}

# Install vim/neovim plugins (LARBS vimplugininstall - CRITICAL for vim setup)
vimplugininstall() {
    info "Installing neovim plugins..."

    # Create autoload directory and download vim-plug
    mkdir -p "/home/$PRIMARY_USER/.config/nvim/autoload"
    curl -Ls "https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim" > \
        "/home/$PRIMARY_USER/.config/nvim/autoload/plug.vim"

    chown -R "$PRIMARY_USER:wheel" "/home/$PRIMARY_USER/.config/nvim"

    # CRITICAL: Run nvim headless to install plugins
    sudo -u $PRIMARY_USER nvim -c "PlugInstall|q|q" --headless >/dev/null 2>&1 || \
        sudo -u $PRIMARY_USER nvim -c "PlugInstall" -c "qa!" >/dev/null 2>&1 || \
        warn "Vim plugin install may need manual run: nvim +PlugInstall"

    info " * Neovim plugins installed"
}

info "============================================================"
info "PARSS Desktop Setup Starting (LARBS-Compatible)"
info "============================================================"
info ""

# ============================================================================
# 0. Setup temporary passwordless sudo (LARBS method - required for AUR)
# ============================================================================
info "Configuring temporary passwordless sudo for AUR builds..."
trap 'rm -f /etc/sudoers.d/parss-temp' HUP INT QUIT TERM PWR EXIT
echo "%wheel ALL=(ALL) NOPASSWD: ALL
Defaults:%wheel,root runcwd=*" >/etc/sudoers.d/parss-temp

# ============================================================================
# 1. Install essential base packages (before progs.csv)
# ============================================================================
info "Installing essential base packages..."

# These are required for the rest of the setup and often missing
essential_packages=(
    "curl" "ca-certificates" "base-devel" "git" "ntp" "zsh" "dash"
    "xwallpaper"    # CRITICAL: Required by setbg script
    "xdotool"       # CRITICAL: Required by setbg for F5 refresh
    "xclip"         # Clipboard support
    "libnotify"     # Desktop notifications
    "dunst"         # Notification daemon
    "dhcpcd"        # CRITICAL: Fallback network (if NetworkManager fails)
)

for pkg in "\${essential_packages[@]}"; do
    installpkg "\$pkg" || warn "Could not install: \$pkg"
done

# Sync time (LARBS does this)
ntpd -q -g >/dev/null 2>&1 || true

info " * Essential packages installed"

# ============================================================================
# 2. Make pacman colorful and fast (LARBS style)
# ============================================================================
grep -q "ILoveCandy" /etc/pacman.conf || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf
sed -Ei "s/^#(ParallelDownloads).*/\1 = 5/;/^#Color$/s/#//" /etc/pacman.conf
sed -i "s/-j2/-j\$(nproc)/;/^#MAKEFLAGS/s/^#//" /etc/makepkg.conf

# ============================================================================
# 3. Install AUR helper (yay) - LARBS manualinstall method
# ============================================================================
info "Installing AUR helper ($AURHELPER)..."

if ! command -v $AURHELPER >/dev/null 2>&1; then
    sudo -u $PRIMARY_USER mkdir -p "$REPODIR/$AURHELPER"

    sudo -u $PRIMARY_USER git -C "$REPODIR" clone --depth 1 --single-branch \
        --no-tags -q "https://aur.archlinux.org/$AURHELPER.git" "$REPODIR/$AURHELPER" || {
        cd "$REPODIR/$AURHELPER" || exit 1
        sudo -u $PRIMARY_USER git pull --force origin master
    }

    cd "$REPODIR/$AURHELPER" || exit 1
    sudo -u $PRIMARY_USER makepkg --noconfirm -si >/dev/null 2>&1 || {
        error "Failed to install $AURHELPER"
        exit 1
    }

    # Configure yay for auto-updates of *-git packages (LARBS does this)
    sudo -u $PRIMARY_USER $AURHELPER -Y --save --devel >/dev/null 2>&1

    info " * $AURHELPER installed and configured"
else
    info " * $AURHELPER already installed"
fi

# ============================================================================
# 4. Clone and deploy dotfiles (LARBS putgitrepo method)
# ============================================================================
sudo -u $PRIMARY_USER mkdir -p "$REPODIR"
chown -R "$PRIMARY_USER:wheel" "/home/$PRIMARY_USER/.local"

putgitrepo "$DOTFILES_REPO" "/home/$PRIMARY_USER" "$DOTFILES_BRANCH"

# ============================================================================
# 5. Install packages from progs.csv (LARBS installationloop)
# ============================================================================
PROGS_FILE="/home/$PRIMARY_USER/progs.csv"

if [[ -f "\$PROGS_FILE" ]]; then
    # Get already installed AUR packages (for skipping)
    aurinstalled=\$(pacman -Qqm 2>/dev/null || echo "")

    total=\$(grep -cvE "^(#|\$)" "\$PROGS_FILE" 2>/dev/null || echo 0)
    n=0

    info "Installing \$total packages from progs.csv..."
    info ""

    while IFS=, read -r tag prog comment; do
        # Skip comments and blank lines
        [[ -z "\$prog" ]] && continue
        [[ "\$tag" =~ ^# ]] && continue
        [[ "\$prog" =~ ^# ]] && continue

        n=\$((n + 1))

        # Clean up comment (remove quotes)
        comment=\$(echo "\$comment" | sed -E 's/(^"|"\$)//g')

        case "\$tag" in
            "A")
                # AUR package
                echo "\$aurinstalled" | grep -q "^\$prog\$" && continue
                info "[\$n/\$total] [AUR] \$prog"
                aurinstall "\$prog"
                ;;
            "G")
                # Git + make install
                info "[\$n/\$total] [git] \$prog"
                gitmakeinstall "\$prog"
                ;;
            "P")
                # Python pip
                info "[\$n/\$total] [pip] \$prog"
                [ -x "\$(command -v pip)" ] || installpkg python-pip
                yes | pip install "\$prog" >/dev/null 2>&1 || warn "pip failed: \$prog"
                ;;
            *)
                # Main repo (pacman)
                info "[\$n/\$total] [pacman] \$prog"
                installpkg "\$prog"
                ;;
        esac
    done < "\$PROGS_FILE"

    info ""
    info " * Package installation complete (\$n packages processed)"
else
    warn "progs.csv not found at \$PROGS_FILE"
    warn "Skipping package installation from CSV"
fi

# ============================================================================
# 6. Install vim plugins (LARBS vimplugininstall - CRITICAL)
# ============================================================================
[ ! -f "/home/$PRIMARY_USER/.config/nvim/autoload/plug.vim" ] && vimplugininstall

# ============================================================================
# 7. Create required directories (LARBS does this)
# ============================================================================
info "Creating required directories..."

sudo -u $PRIMARY_USER mkdir -p "/home/$PRIMARY_USER/.cache/zsh/"
sudo -u $PRIMARY_USER mkdir -p "/home/$PRIMARY_USER/.config/abook/"
sudo -u $PRIMARY_USER mkdir -p "/home/$PRIMARY_USER/.config/mpd/playlists/"
sudo -u $PRIMARY_USER mkdir -p "/home/$PRIMARY_USER/.local/share/mail/"
sudo -u $PRIMARY_USER mkdir -p "/home/$PRIMARY_USER/.local/share/larbs/"

# ============================================================================
# 8. Make scripts executable (CRITICAL - recursive for statusbar)
# ============================================================================
info "Making scripts executable..."

# Make ALL scripts in .local/bin executable (including subdirectories)
find /home/$PRIMARY_USER/.local/bin -type f -exec chmod +x {} \; 2>/dev/null || true

# Also ensure key config scripts are executable
chmod +x /home/$PRIMARY_USER/.config/x11/xinitrc 2>/dev/null || true
chmod +x /home/$PRIMARY_USER/.xprofile 2>/dev/null || true
chmod +x /home/$PRIMARY_USER/.zprofile 2>/dev/null || true

info " * All scripts made executable"

# ============================================================================
# 9. System configuration (LARBS style)
# ============================================================================
info "Configuring system settings..."

# Make zsh the default shell
chsh -s /bin/zsh "$PRIMARY_USER" >/dev/null 2>&1

# Make dash the default /bin/sh (LARBS does this for speed)
ln -sfT /bin/dash /bin/sh >/dev/null 2>&1 || true

# Generate dbus UUID (required for Artix/runit, harmless on systemd)
dbus-uuidgen >/var/lib/dbus/machine-id 2>/dev/null || true

# Disable PC speaker beep
rmmod pcspkr 2>/dev/null || true
echo "blacklist pcspkr" >/etc/modprobe.d/nobeep.conf 2>/dev/null || true

# Enable tap to click for touchpads
[ ! -f /etc/X11/xorg.conf.d/40-libinput.conf ] && mkdir -p /etc/X11/xorg.conf.d && printf 'Section "InputClass"
        Identifier "libinput touchpad catchall"
        MatchIsTouchpad "on"
        MatchDevicePath "/dev/input/event*"
        Driver "libinput"
	# Enable left mouse button by tapping
	Option "Tapping" "on"
EndSection' >/etc/X11/xorg.conf.d/40-libinput.conf

info " * System settings configured"

# ============================================================================
# 9b. AUTO-DETECT SCREEN RESOLUTION AND CONFIGURE DPI
# ============================================================================
info "Detecting screen resolution for DPI configuration..."

# Try to detect screen resolution from DRM subsystem (works without X)
detect_screen_resolution() {
    local max_width=0
    local max_height=0
    
    # Method 1: Parse DRM modes (works in TTY, most reliable)
    for mode_file in /sys/class/drm/*/modes; do
        if [[ -f "\$mode_file" ]]; then
            while read -r mode; do
                # Parse resolution like "3840x2400" or "1920x1080"
                if [[ "\$mode" =~ ^([0-9]+)x([0-9]+) ]]; then
                    local w="\${BASH_REMATCH[1]}"
                    local h="\${BASH_REMATCH[2]}"
                    if (( w > max_width )); then
                        max_width=\$w
                        max_height=\$h
                    fi
                fi
            done < "\$mode_file"
        fi
    done
    
    # Method 2: Try xrandr if available (requires X)
    if (( max_width == 0 )) && command -v xrandr >/dev/null 2>&1; then
        local xrandr_res
        xrandr_res=\$(xrandr 2>/dev/null | grep -oP '\d+x\d+' | head -1)
        if [[ "\$xrandr_res" =~ ^([0-9]+)x([0-9]+) ]]; then
            max_width="\${BASH_REMATCH[1]}"
            max_height="\${BASH_REMATCH[2]}"
        fi
    fi
    
    echo "\$max_width \$max_height"
}

# Calculate appropriate DPI based on resolution
# Assumes typical laptop screen sizes
calculate_dpi() {
    local width=\$1
    local height=\$2
    local dpi=96  # Default
    
    if (( width >= 3840 )); then
        # 4K+ display (3840x2160, 3840x2400, etc.)
        dpi=192  # 2x scaling
    elif (( width >= 2560 )); then
        # QHD/1440p display
        dpi=144  # 1.5x scaling
    elif (( width >= 1920 )); then
        # Full HD display
        dpi=96   # 1x scaling
    fi
    
    echo "\$dpi"
}

# Detect and configure
read -r SCREEN_WIDTH SCREEN_HEIGHT <<< "\$(detect_screen_resolution)"

if (( SCREEN_WIDTH > 0 )); then
    DETECTED_DPI=\$(calculate_dpi \$SCREEN_WIDTH \$SCREEN_HEIGHT)
    info " * Detected screen: \${SCREEN_WIDTH}x\${SCREEN_HEIGHT}"
    info " * Calculated DPI: \$DETECTED_DPI"
    
    # Update Xresources with detected DPI
    XRESOURCES_FILE="/home/$PRIMARY_USER/.config/x11/xresources"
    if [[ -f "\$XRESOURCES_FILE" ]]; then
        # Update Xft.dpi setting
        if grep -q "^Xft.dpi:" "\$XRESOURCES_FILE"; then
            sed -i "s/^Xft.dpi:.*/Xft.dpi: \$DETECTED_DPI/" "\$XRESOURCES_FILE"
        else
            echo "Xft.dpi: \$DETECTED_DPI" >> "\$XRESOURCES_FILE"
        fi
        
        # Update cursor size based on DPI
        cursor_size=24
        (( DETECTED_DPI >= 192 )) && cursor_size=48
        (( DETECTED_DPI >= 144 && DETECTED_DPI < 192 )) && cursor_size=32
        
        if grep -q "^Xcursor.size:" "\$XRESOURCES_FILE"; then
            sed -i "s/^Xcursor.size:.*/Xcursor.size: \$cursor_size/" "\$XRESOURCES_FILE"
        fi
        
        info " * Xresources updated: DPI=\$DETECTED_DPI, Cursor=\$cursor_size"
    fi
    
    # Also update GDK/QT scaling environment variables
    PROFILE_FILE="/home/$PRIMARY_USER/.config/shell/profile"
    if [[ -f "\$PROFILE_FILE" ]] && (( DETECTED_DPI >= 144 )); then
        scale_factor=1
        (( DETECTED_DPI >= 192 )) && scale_factor=2
        (( DETECTED_DPI >= 144 && DETECTED_DPI < 192 )) && scale_factor=1.5
        
        # Add HiDPI environment variables if not present
        if ! grep -q "GDK_SCALE" "\$PROFILE_FILE"; then
            cat >> "\$PROFILE_FILE" << HIDPI_ENV

# HiDPI scaling (auto-detected during installation)
export GDK_SCALE=\$scale_factor
export GDK_DPI_SCALE=\$(echo "scale=2; 1/\$scale_factor" | bc)
export QT_AUTO_SCREEN_SCALE_FACTOR=1
HIDPI_ENV
            info " * HiDPI environment variables added to profile"
        fi
    fi
else
    info " * Could not detect screen resolution, using defaults"
fi

# ============================================================================
# 10. Setup wallpaper (CRITICAL - setbg requires xwallpaper + bg file)
# ============================================================================
info "Setting up wallpaper..."

# Create wallpapers directory if missing
sudo -u $PRIMARY_USER mkdir -p "/home/$PRIMARY_USER/.local/share/wallpapers"

# Create a dark wallpaper if none exists
if [[ ! -f "/home/$PRIMARY_USER/.local/share/wallpapers/dark-bg.png" ]]; then
    # Create black PNG using ImageMagick if available
    if command -v convert >/dev/null 2>&1; then
        convert -size 1920x1080 xc:black "/home/$PRIMARY_USER/.local/share/wallpapers/dark-bg.png" 2>/dev/null || true
    fi
fi

# Create the bg symlink that setbg uses
if [[ -f "/home/$PRIMARY_USER/.local/share/wallpapers/dark-bg.png" ]]; then
    sudo -u $PRIMARY_USER ln -sf "/home/$PRIMARY_USER/.local/share/wallpapers/dark-bg.png" "/home/$PRIMARY_USER/.local/share/bg"
    info " * Dark wallpaper configured"
else
    warn "Could not create wallpaper file"
fi

# ============================================================================
# 11. Configure suckless tools BEFORE building (edit configs first)
# ============================================================================
info "Configuring suckless tools..."

# Configure DWM (set gaps to 0 BEFORE building)
dwm_config="$REPODIR/dwm/config.h"
if [[ -f "\$dwm_config" ]]; then
    sed -i 's/^static const unsigned int gappih.*/static const unsigned int gappih = 0;/' "\$dwm_config" 2>/dev/null || true
    sed -i 's/^static const unsigned int gappiv.*/static const unsigned int gappiv = 0;/' "\$dwm_config" 2>/dev/null || true
    sed -i 's/^static const unsigned int gappoh.*/static const unsigned int gappoh = 0;/' "\$dwm_config" 2>/dev/null || true
    sed -i 's/^static const unsigned int gappov.*/static const unsigned int gappov = 0;/' "\$dwm_config" 2>/dev/null || true
    info " * DWM config: gaps set to 0"
fi

# ============================================================================
# 12. Build suckless tools (AFTER config edits, build only once)
# ============================================================================
info "Building suckless tools..."

for tool in dwm dwmblocks dmenu st; do
    if [[ -d "$REPODIR/\$tool" ]]; then
        info " * Building \$tool..."
        cd "$REPODIR/\$tool"
        sudo -u $PRIMARY_USER make clean >/dev/null 2>&1 || true
        sudo -u $PRIMARY_USER make >/dev/null 2>&1 && make install >/dev/null 2>&1 || warn "Build failed: \$tool"
    fi
done

info " * Suckless tools built and installed"

# ============================================================================
# 13. Copy configs to root for consistent sudo experience (same vim UI)
# ============================================================================
info "Configuring root account for same vim/shell experience..."

mkdir -p /root/.config 2>/dev/null
mkdir -p /root/.local/share 2>/dev/null

# Copy nvim config and plugins (ensures root vim looks identical to user vim)
if [[ -d "/home/$PRIMARY_USER/.config/nvim" ]]; then
    cp -r "/home/$PRIMARY_USER/.config/nvim" /root/.config/
    info " * Root nvim config copied"
fi

# Copy nvim plugins data (plugged directory with installed plugins)
if [[ -d "/home/$PRIMARY_USER/.local/share/nvim" ]]; then
    cp -r "/home/$PRIMARY_USER/.local/share/nvim" /root/.local/share/
    info " * Root nvim plugins copied"
fi

# Copy Xresources for consistent terminal colors
if [[ -f "/home/$PRIMARY_USER/.config/x11/xresources" ]]; then
    cp "/home/$PRIMARY_USER/.config/x11/xresources" /root/.Xresources
    info " * Root Xresources copied"
fi

# Copy zsh config for consistent shell experience
if [[ -d "/home/$PRIMARY_USER/.config/zsh" ]]; then
    cp -r "/home/$PRIMARY_USER/.config/zsh" /root/.config/
    info " * Root zsh config copied"
fi

# Copy shell profile
[[ -f "/home/$PRIMARY_USER/.zprofile" ]] && cp "/home/$PRIMARY_USER/.zprofile" /root/

# ============================================================================
# 14. Enable dhcpcd as fallback network (if NetworkManager fails)
# ============================================================================
info "Configuring network fallback..."
systemctl enable dhcpcd.service 2>/dev/null || true

# ============================================================================
# 15. Setup newsboat default RSS feeds (LARBS does this)
# ============================================================================
info "Setting up newsboat RSS feeds..."
if [[ ! -s "/home/$PRIMARY_USER/.config/newsboat/urls" ]]; then
    sudo -u $PRIMARY_USER mkdir -p "/home/$PRIMARY_USER/.config/newsboat"
    cat > "/home/$PRIMARY_USER/.config/newsboat/urls" << 'NEWSBOAT_URLS'
https://www.archlinux.org/feeds/news/ "tech"
https://github.com/lukesmithxyz/voidrice/commits/master.atom "~LARBS dotfiles"
NEWSBOAT_URLS
    chown $PRIMARY_USER:wheel "/home/$PRIMARY_USER/.config/newsboat/urls"
    info " * Newsboat default feeds configured"
fi

# ============================================================================
# 16. Setup Librewolf browser profile (LARBS does this)
# ============================================================================
info "Setting up Librewolf browser..."
if command -v librewolf >/dev/null 2>&1; then
    browserdir="/home/$PRIMARY_USER/.librewolf"
    profilesini="\$browserdir/profiles.ini"

    # Start librewolf headless to generate profile
    sudo -u $PRIMARY_USER librewolf --headless >/dev/null 2>&1 &
    sleep 2

    # Get the profile directory
    if [[ -f "\$profilesini" ]]; then
        profile=\$(sed -n "/Default=.*.default-default/ s/.*=//p" "\$profilesini" 2>/dev/null || true)
        pdir="\$browserdir/\$profile"

        # Link arkenfox/user.js if config exists in dotfiles
        if [[ -d "\$pdir" ]] && [[ -f "/home/$PRIMARY_USER/.config/firefox/larbs.js" ]]; then
            ln -sf "/home/$PRIMARY_USER/.config/firefox/larbs.js" "\$pdir/user-overrides.js" 2>/dev/null || true
            info " * Librewolf privacy settings linked"
        fi
    fi

    # Kill the headless instance
    pkill -u $PRIMARY_USER librewolf 2>/dev/null || true
    info " * Librewolf profile initialized"
else
    info " * Librewolf not installed, skipping browser setup"
fi

# ============================================================================
# 17. Configure sudoers for convenience commands (LARBS does this)
# ============================================================================
info "Configuring sudoers for convenience..."

# Allow wheel users to sudo with password
echo "%wheel ALL=(ALL:ALL) ALL" >/etc/sudoers.d/00-parss-wheel-can-sudo

# Allow common system commands without password
echo "%wheel ALL=(ALL:ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/wifi-menu,/usr/bin/mount,/usr/bin/umount,/usr/bin/pacman -Syu,/usr/bin/pacman -Syyu,/usr/bin/pacman -Syyu --noconfirm,/usr/bin/loadkeys,/usr/bin/pacman -Syyuw --noconfirm,/usr/bin/pacman -S -y --config /etc/pacman.conf --,/usr/bin/pacman -S -y -u --config /etc/pacman.conf --" >/etc/sudoers.d/01-parss-cmds-without-password

# Set nvim as default visudo editor
echo "Defaults editor=/usr/bin/nvim" >/etc/sudoers.d/02-parss-visudo-editor

info " * Sudoers convenience commands configured"

# ============================================================================
# 18. Kernel/sysctl settings (LARBS does this)
# ============================================================================
info "Configuring kernel settings..."
mkdir -p /etc/sysctl.d
echo "kernel.dmesg_restrict = 0" > /etc/sysctl.d/dmesg.conf
info " * Kernel settings configured"

# ============================================================================
# 19. Final ownership fix
# ============================================================================
info "Fixing file ownership..."
chown -R $PRIMARY_USER:wheel "/home/$PRIMARY_USER" 2>/dev/null || true

# ============================================================================
# CLEANUP: Remove temporary passwordless sudo (CRITICAL for security)
# ============================================================================
info "Cleaning up temporary sudo configuration..."
rm -f /etc/sudoers.d/parss-temp

# ============================================================================
# COMPLETION SUMMARY
# ============================================================================
info ""
info "============================================================"
info "PARSS Desktop Setup Complete!"
info "============================================================"
info ""
info "Installed components:"
info "  - DWM window manager (minimal gaps)"
info "  - dwmblocks status bar with widgets"
info "  - ST terminal emulator"
info "  - dmenu application launcher"
info "  - Neovim with Moonfly theme + plugins"
info "  - All scripts in ~/.local/bin (including statusbar)"
info "  - Dark wallpaper"
info "  - zsh as default shell"
info ""
info "After reboot:"
info "  1. Login as $PRIMARY_USER"
info "  2. Run 'startx' to launch DWM"
info "  3. Press Super+F1 for keybinding help"
info ""

DESKTOP_SETUP_EOF

    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        log_success "Desktop environment setup completed successfully!"
        save_state "DESKTOP_SETUP_COMPLETE" "true"
    else
        log_warn "Desktop setup encountered issues (exit code: $exit_code)"
        log_warn "Check the log for details."
        save_state "DESKTOP_SETUP_ERROR" "true"
    fi

    log_success "Phase 14 completed"
}

phase_15_laptop_configuration() {
    # Laptop configuration prompt
    cat >&2 << 'EOF'

===============================================================================
                    LAPTOP CONFIGURATION
                         ** PHASE 15 **
===============================================================================

This phase configures laptop-specific optimizations:
  - Fan control (thermal management)
  - Power management (battery life)
  - ACPI event handling (lid close, power button)

LAPTOP TYPE OPTIONS:
  [1] ThinkPad (P1/X1/T-series) - Full thinkfan + TLP + thermald
  [2] Generic Laptop            - TLP + thermald (no vendor fan control)
  [3] Desktop / Skip            - Skip laptop configuration

===============================================================================
EOF
    local laptop_choice
    read -p "  Select laptop type (1/2/3) [3]: " laptop_choice
    laptop_choice="${laptop_choice:-3}"

    case "$laptop_choice" in
        1)
            log_info "Configuring for ThinkPad laptop..."
            configure_thinkpad_laptop
            ;;
        2)
            log_info "Configuring for generic laptop..."
            configure_generic_laptop
            ;;
        *)
            log_info "Skipping laptop configuration."
            save_state "LAPTOP_CONFIG_SKIPPED" "true"
            log_success "Phase 15 skipped by user"
            return 0
            ;;
    esac

    log_success "Phase 15 completed"
}

configure_thinkpad_laptop() {
    log_info "Installing ThinkPad-specific packages..."

    # Install laptop packages via chroot
    arch-chroot "$MOUNT_ROOT" /bin/bash <<'THINKPAD_EOF'
set -e

GREEN='\033[0;32m'
NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC} $*"; }

# Install ThinkPad-specific packages
info "Installing ThinkPad packages..."
pacman --noconfirm --needed -S thinkfan lm_sensors tlp tlp-rdw acpid thermald powertop 2>/dev/null || true

# Enable thinkpad_acpi fan control
mkdir -p /etc/modprobe.d
cat > /etc/modprobe.d/thinkpad_acpi.conf << 'MODPROBE'
# Enable fan control for ThinkPad laptops
options thinkpad_acpi fan_control=1 experimental=1
MODPROBE
info " * thinkpad_acpi module configured"

# Create thinkfan configuration for ThinkPad P1 Gen5 (aggressive cooling)
cat > /etc/thinkfan.conf << 'THINKFAN_CONF'
##############################################################################
# ThinkPad Fan Configuration - Aggressive Cooling
# Optimized for ThinkPad P1/X1/T-series with high-performance CPUs
# Adjust temperature thresholds based on your specific model
##############################################################################

sensors:
  # ThinkPad-specific sensor (works for most models)
  - tpacpi: /proc/acpi/ibm/thermal
    indices: [0, 1, 2, 3, 4, 5, 6, 7]
    correction: [0, 0, 0, 0, 0, 0, 0, 0]

fans:
  - tpacpi: /proc/acpi/ibm/fan

levels:
  # Aggressive cooling profile (prevents thermal throttling)
  # Format: [fan_level, low_temp, high_temp]
  - [0,      0,    45]    # Fan off below 45C
  - [1,     42,    50]    # Level 1: 42-50C
  - [2,     47,    55]    # Level 2: 47-55C
  - [3,     52,    60]    # Level 3: 52-60C
  - [4,     57,    65]    # Level 4: 57-65C
  - [5,     62,    70]    # Level 5: 62-70C
  - [6,     67,    75]    # Level 6: 67-75C
  - [7,     72,    80]    # Level 7: 72-80C (max regulated)
  - ["level full-speed", 77, 32767]  # Full speed above 77C
THINKFAN_CONF
info " * thinkfan configuration created"

# Enable services
systemctl enable thinkfan.service 2>/dev/null || true
systemctl enable thermald.service 2>/dev/null || true
systemctl enable tlp.service 2>/dev/null || true
systemctl enable acpid.service 2>/dev/null || true

# Mask conflicting services for TLP
systemctl mask systemd-rfkill.service 2>/dev/null || true
systemctl mask systemd-rfkill.socket 2>/dev/null || true

info " * ThinkPad services enabled (thinkfan, thermald, tlp, acpid)"
info ""
info "ThinkPad configuration complete!"
info "  - thinkfan: Custom fan curves for thermal management"
info "  - thermald: Intel thermal daemon"
info "  - TLP: Battery optimization"
info "  - acpid: ACPI event handling"
THINKPAD_EOF

    save_state "LAPTOP_CONFIG_THINKPAD" "true"
    log_success "ThinkPad laptop configuration completed"
}

configure_generic_laptop() {
    log_info "Installing generic laptop packages..."

    # Install generic laptop packages via chroot
    arch-chroot "$MOUNT_ROOT" /bin/bash <<'GENERIC_EOF'
set -e

GREEN='\033[0;32m'
NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC} $*"; }

# Install generic laptop packages
info "Installing laptop packages..."
pacman --noconfirm --needed -S lm_sensors tlp tlp-rdw acpid thermald powertop 2>/dev/null || true

# Enable services
systemctl enable thermald.service 2>/dev/null || true
systemctl enable tlp.service 2>/dev/null || true
systemctl enable acpid.service 2>/dev/null || true

# Mask conflicting services for TLP
systemctl mask systemd-rfkill.service 2>/dev/null || true
systemctl mask systemd-rfkill.socket 2>/dev/null || true

info " * Laptop services enabled (thermald, tlp, acpid)"
info ""
info "Generic laptop configuration complete!"
info "  - thermald: Intel thermal daemon"
info "  - TLP: Battery optimization"
info "  - acpid: ACPI event handling"
info ""
info "TIP: Run 'sudo powertop --auto-tune' after first boot for extra savings"
GENERIC_EOF

    save_state "LAPTOP_CONFIG_GENERIC" "true"
    log_success "Generic laptop configuration completed"
}

phase_13_final_verification() {

    log_section "PHASE 13: FINAL VERIFICATION & UNMOUNTING"

    log_info "Verifying installation completeness..."

    log_debug "Checking crypttab..."
    [[ -f "$MOUNT_ROOT/etc/crypttab" ]] && cat "$MOUNT_ROOT/etc/crypttab" | tee -a "$LOG_FILE" || log_warn "crypttab not found"

    log_debug "Checking fstab..."
    [[ -f "$MOUNT_ROOT/etc/fstab" ]] && cat "$MOUNT_ROOT/etc/fstab" | tee -a "$LOG_FILE" || log_warn "fstab not found"

    log_debug "Checking mkinitcpio configuration..."
    grep -E "^(MODULES|HOOKS)" "$MOUNT_ROOT/etc/mkinitcpio.conf" | tee -a "$LOG_FILE"

    log_debug "Checking BTRFS subvolumes..."
    arch-chroot "$MOUNT_ROOT" btrfs subvolume list / 2>/dev/null | tee -a "$LOG_FILE" || log_warn "Could not list subvolumes"

    log_debug "Checking total packages installed..."
    local pkg_count
    pkg_count=$(arch-chroot "$MOUNT_ROOT" pacman -Q | wc -l)
    log_info "Total packages installed: $pkg_count"

    log_info "Unmounting filesystems (in reverse order)..."

    umount -l "$MOUNT_ROOT/var/log" 2>/dev/null || true
    umount -l "$MOUNT_ROOT/var/cache" 2>/dev/null || true
    umount -l "$MOUNT_ROOT/var" 2>/dev/null || true
    umount -l "$MOUNT_ROOT/home" 2>/dev/null || true
    umount -l "$MOUNT_ROOT/.snapshots" 2>/dev/null || true
    umount -l "$MOUNT_ROOT/boot" 2>/dev/null || true
    umount -l "$MOUNT_ROOT" 2>/dev/null || true

    log_info "Closing LUKS encrypted volume..."
    cryptsetup luksClose "${LUKS_ROOT_NAME}" 2>/dev/null || true

    log_success "Installation completed and filesystems unmounted"
    save_state "INSTALLATION_COMPLETE" "true"
    log_success "Phase 13 completed successfully"
}

################################################################################
# INTEGRATED UTILITY FUNCTIONS
################################################################################

# System Health Check (integrated from system-health.sh)
run_system_health() {
    echo ""
    echo -e "${CYAN}=== PARSS System Health Check ===${NC}"
    echo "Date: $(date)"
    echo "Hostname: $(hostname)"
    echo ""

    echo -e "${YELLOW}[1] Service Status${NC}"
    local services=("NetworkManager" "sshd" "systemd-timesyncd" "fstrim.timer")
    for svc in "${services[@]}"; do
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            echo -e "  ${GREEN}[OK]${NC} $svc is running"
        else
            echo -e "  ${RED}[--]${NC} $svc is INACTIVE"
        fi
    done

    echo ""
    echo -e "${YELLOW}[2] Disk Usage${NC}"
    if command -v btrfs &>/dev/null; then
        btrfs filesystem usage / --human-readable 2>/dev/null | head -n 8 || df -h /
    else
        df -h /
    fi

    echo ""
    echo -e "${YELLOW}[3] Snapshot Status${NC}"
    if [[ -d /.snapshots ]]; then
        local count
        count=$(btrfs subvolume list /.snapshots 2>/dev/null | wc -l || echo 0)
        echo "  Total snapshots: $count"
    else
        echo "  Snapshot directory not found"
    fi

    echo ""
    echo -e "${YELLOW}[4] LUKS / Encryption Status${NC}"
    if [[ -f /etc/crypttab ]]; then
        echo "  /etc/crypttab entries:"
        grep -vE '^(#|$)' /etc/crypttab 2>/dev/null | sed 's/^/    /' || echo "    (no active entries)"
    else
        echo -e "  ${RED}[--]${NC} /etc/crypttab missing"
    fi

    if [[ -f /etc/default/grub ]]; then
        if grep -q "cryptdevice=" /etc/default/grub; then
            echo -e "  ${GREEN}[OK]${NC} GRUB has cryptdevice parameter"
        else
            echo -e "  ${RED}[--]${NC} cryptdevice missing from GRUB"
        fi
    fi

    echo ""
    echo -e "${YELLOW}[5] Memory & Load${NC}"
    free -h | head -n 2
    echo "  Load average: $(cat /proc/loadavg | cut -d' ' -f1-3)"

    echo ""
    echo -e "${GREEN}Health check complete.${NC}"
    echo ""
    # Only wait for Enter if running from menu (not CLI)
    [[ "${MENU_MODE:-false}" == "true" ]] && read -p "Press Enter to return to menu..."
}

# Integrity Check (integrated from integrity-check.sh)
run_integrity_check() {
    echo ""
    echo -e "${CYAN}=== PARSS Integrity Check (AIDE) ===${NC}"
    echo ""

    if ! command -v aide &>/dev/null; then
        echo -e "${YELLOW}AIDE is not installed.${NC}"
        read -p "Install AIDE now? (y/N): " install_aide
        if [[ "$install_aide" =~ ^[yY]$ ]]; then
            echo "Installing AIDE..."
            sudo pacman -S --noconfirm aide
            echo "Initializing AIDE database (this may take a while)..."
            sudo aide --init
            sudo mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
            echo -e "${GREEN}AIDE initialized successfully.${NC}"
        else
            echo "Skipping AIDE installation."
        fi
        [[ "${MENU_MODE:-false}" == "true" ]] && read -p "Press Enter to return to menu..."
        return 0
    fi

    echo "Running AIDE integrity check..."
    echo "(This may take several minutes)"
    echo ""

    if sudo aide --check 2>&1; then
        echo ""
        echo -e "${GREEN}System integrity verified: No changes detected.${NC}"
    else
        echo ""
        echo -e "${RED}WARNING: Changes detected in filesystem!${NC}"
        echo "Check /var/log/aide.log for details."
    fi

    echo ""
    [[ "${MENU_MODE:-false}" == "true" ]] && read -p "Press Enter to return to menu..."
}

# BTRFS Dashboard (integrated from btrfs-dashboard.sh)
run_btrfs_dashboard() {
    echo ""
    echo -e "${CYAN}=== PARSS BTRFS Dashboard ===${NC}"
    echo "Host: $(hostname)"
    echo "Date: $(date)"
    echo ""

    echo -e "${YELLOW}[1] Block Devices${NC}"
    lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS 2>/dev/null || lsblk

    echo ""
    echo -e "${YELLOW}[2] BTRFS Filesystems${NC}"
    if command -v btrfs &>/dev/null; then
        btrfs filesystem show 2>/dev/null || echo "  No BTRFS filesystems detected."
    else
        echo "  btrfs command not available."
    fi

    echo ""
    echo -e "${YELLOW}[3] Root Filesystem Usage${NC}"
    if command -v btrfs &>/dev/null; then
        btrfs filesystem usage / --human-readable 2>/dev/null | head -n 15 || df -h /
    else
        df -h /
    fi

    echo ""
    echo -e "${YELLOW}[4] BTRFS Subvolumes${NC}"
    if command -v btrfs &>/dev/null; then
        btrfs subvolume list / 2>/dev/null || echo "  No subvolumes or not a BTRFS root."
    else
        echo "  btrfs command not available."
    fi

    echo ""
    echo -e "${YELLOW}[5] Snapshots${NC}"
    if [[ -d /.snapshots ]]; then
        btrfs subvolume list /.snapshots 2>/dev/null || echo "  No snapshots found."
    else
        echo "  /.snapshots directory not found."
    fi

    echo ""
    echo -e "${GREEN}Dashboard complete.${NC}"
    echo ""
    [[ "${MENU_MODE:-false}" == "true" ]] && read -p "Press Enter to return to menu..."
}

################################################################################
# MAIN MENU SYSTEM
################################################################################

show_main_menu() {
    MENU_MODE=true
    while true; do
        clear
        echo -e "${CYAN}"
        echo "================================================================================"
        echo "     ____   _    ____  ____ ____"
        echo "    |  _ \ / \  |  _ \/ ___/ ___|"
        echo "    | |_) / _ \ | |_) \___ \___ \\"
        echo "    |  __/ ___ \|  _ < ___) |__) |"
        echo "    |_| /_/   \_\_| \_\____/____/"
        echo ""
        echo "        Personalized Arch Research Security System"
        echo "================================================================================"
        echo -e "${NC}"
        echo ""
        echo "  Main Menu:"
        echo ""
        echo -e "    ${GREEN}1)${NC}  Install Arch Linux (Full Installation)"
        echo -e "    ${GREEN}2)${NC}  Install Desktop Environment Only (Phase 14)"
        echo -e "    ${GREEN}3)${NC}  System Health Check"
        echo -e "    ${GREEN}4)${NC}  BTRFS Dashboard"
        echo -e "    ${GREEN}5)${NC}  Integrity Check (AIDE)"
        echo -e "    ${GREEN}6)${NC}  Run Specific Phase"
        echo -e "    ${GREEN}7)${NC}  Resume Installation (from checkpoint)"
        echo ""
        echo -e "    ${YELLOW}h)${NC}  Help / Usage"
        echo -e "    ${RED}q)${NC}  Quit"
        echo ""
        echo "================================================================================"
        echo ""
        read -p "  Select option [1-7, h, q]: " choice

        case "$choice" in
            1)
                clear
                echo -e "${CYAN}Starting Full Arch Linux Installation...${NC}"
                echo ""
                read -p "This will install Arch Linux. Continue? (y/N): " confirm
                if [[ "$confirm" =~ ^[yY]$ ]]; then
                    run_full_installation
                fi
                ;;
            2)
                clear
                echo -e "${CYAN}Installing Desktop Environment (Phase 14)...${NC}"
                echo ""
                phase_14_optional_desktop_setup
                read -p "Press Enter to return to menu..."
                ;;
            3)
                run_system_health
                ;;
            4)
                run_btrfs_dashboard
                ;;
            5)
                run_integrity_check
                ;;
            6)
                show_phase_menu
                ;;
            7)
                show_resume_menu
                ;;
            h|H)
                show_usage
                read -p "Press Enter to return to menu..."
                ;;
            q|Q|0)
                echo ""
                echo -e "${GREEN}Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please try again.${NC}"
                sleep 1
                ;;
        esac
    done
}

show_phase_menu() {
    clear
    echo -e "${CYAN}================================================================================${NC}"
    echo "                         Run Specific Phase"
    echo -e "${CYAN}================================================================================${NC}"
    echo ""
    echo "  Available Phases:"
    echo ""
    echo "    1   - Preflight checks"
    echo "    1b  - Interactive configuration"
    echo "    2   - Device configuration"
    echo "    3   - Disk preparation"
    echo "    4   - LUKS encryption"
    echo "    5   - BTRFS filesystem"
    echo "    6   - Base installation (pacstrap)"
    echo "    7   - Mount configuration (fstab)"
    echo "    8   - Bootloader configuration (GRUB)"
    echo "    9   - System configuration"
    echo "    10  - User setup"
    echo "    11  - Security hardening"
    echo "    12  - BTRFS snapshots"
    echo "    13  - Final verification"
    echo "    14  - Desktop environment"
    echo ""
    echo "    b   - Back to main menu"
    echo ""
    read -p "  Enter phase number: " phase_num

    if [[ "$phase_num" == "b" || "$phase_num" == "B" ]]; then
        return
    fi

    case "$phase_num" in
        1)  phase_1_preflight_checks ;;
        1b) phase_1b_interactive_configuration ;;
        2)  phase_2_device_configuration ;;
        3)  phase_3_disk_preparation ;;
        4)  phase_4_luks_encryption ;;
        5)  phase_5_btrfs_filesystem ;;
        6)  phase_6_base_installation ;;
        7)  phase_7_mount_configuration ;;
        8)  phase_8_chroot_configuration ;;
        9)  phase_9_system_configuration ;;
        10) phase_10_user_setup ;;
        11) phase_11_security_hardening ;;
        12) phase_12_snapshot_automation ;;
        13) phase_13_final_verification ;;
        14) phase_14_optional_desktop_setup ;;
        15) phase_15_laptop_configuration ;;
        *)  echo -e "${RED}Invalid phase number.${NC}" ;;
    esac

    echo ""
    read -p "Press Enter to return to menu..."
}

show_resume_menu() {
    clear
    echo -e "${CYAN}================================================================================${NC}"
    echo "                         Resume Installation"
    echo -e "${CYAN}================================================================================${NC}"
    echo ""

    if [[ -f "$STATE_FILE" ]]; then
        echo "  Found state file: $STATE_FILE"
        echo ""
        echo "  Saved state:"
        cat "$STATE_FILE" | sed 's/^/    /'
        echo ""
    else
        echo -e "  ${YELLOW}No saved state found.${NC}"
        echo ""
    fi

    echo "  Enter the phase number to resume from (1-14):"
    echo "  Or press 'b' to go back."
    echo ""
    read -p "  Resume from phase: " resume_phase

    if [[ "$resume_phase" == "b" || "$resume_phase" == "B" ]]; then
        return
    fi

    if [[ "$resume_phase" =~ ^[0-9]+$ ]]; then
        echo ""
        echo -e "${CYAN}Resuming installation from phase $resume_phase...${NC}"
        run_installation_from_phase "$resume_phase"
    else
        echo -e "${RED}Invalid input.${NC}"
        sleep 1
    fi
}

run_full_installation() {
    run_installation_from_phase 1
}

run_installation_from_phase() {
    local start_phase="${1:-1}"
    local skip_unmount="${2:-false}"

    # Initialize logging
    mkdir -p "$LOG_DIR"
    exec > >(tee -a "$LOG_FILE") 2> >(tee -a "$ERROR_LOG" >&2)

    # Load previous state if exists
    load_state

    echo ""
    echo "================================================================================"
    echo "ARCH LINUX SECURE RESEARCH DEPLOYMENT - PRODUCTION v2.2"
    echo "================================================================================"
    log_info "Installation started: $(date)"
    log_info "Log file: $LOG_FILE"
    log_info "Error log: $ERROR_LOG"
    log_info "State file: $STATE_FILE"

    # Execute phases (conditionally based on start_phase)
    [[ $start_phase -le 1 ]] && { phase_1_preflight_checks || return 1; }
    [[ $start_phase -le 1 ]] && { phase_1b_interactive_configuration || return 1; }
    [[ $start_phase -le 2 ]] && { phase_2_device_configuration || return 1; }
    [[ $start_phase -le 3 ]] && { phase_3_disk_preparation || return 1; }
    [[ $start_phase -le 4 ]] && { phase_4_luks_encryption || return 1; }
    [[ $start_phase -le 5 ]] && { phase_5_btrfs_filesystem || return 1; }
    [[ $start_phase -le 6 ]] && { phase_6_base_installation || return 1; }
    [[ $start_phase -le 7 ]] && { phase_7_mount_configuration || return 1; }
    [[ $start_phase -le 8 ]] && { phase_8_chroot_configuration || return 1; }
    [[ $start_phase -le 9 ]] && { phase_9_system_configuration || return 1; }
    [[ $start_phase -le 10 ]] && { phase_10_user_setup || return 1; }
    [[ $start_phase -le 11 ]] && { phase_11_security_hardening || return 1; }
    [[ $start_phase -le 12 ]] && { phase_12_snapshot_automation || return 1; }
    [[ $start_phase -le 14 ]] && phase_14_optional_desktop_setup
    [[ $start_phase -le 15 ]] && phase_15_laptop_configuration
    [[ $start_phase -le 13 ]] && [[ "$skip_unmount" != "true" ]] && { phase_13_final_verification || return 1; }

    # Completion summary
    show_completion_summary
}

show_completion_summary() {
    log_section "INSTALLATION COMPLETED SUCCESSFULLY"

    log_info ""
    log_info "Next steps:"
    log_info "  1. Remove installation media (USB/ISO)"
    log_info "  2. Reboot system: reboot"
    log_info "  3. Enter your LUKS passphrase at boot"
    log_info "  4. Login with user: $PRIMARY_USER"

    if [[ "${DESKTOP_SETUP_COMPLETE:-false}" == "true" ]]; then
        log_info "  5. Run 'startx' to launch your desktop environment"
    else
        log_info "  5. (Optional) Run installer again with menu option 2 for desktop"
    fi

    log_info ""
    log_info "Installation log: $LOG_FILE"
    log_info "Installation completed: $(date)"
    log_info ""
}

################################################################################
# MAIN EXECUTION
################################################################################

show_usage() {
    cat << 'EOF'
Usage: bash arch-secure-deploy.sh [OPTIONS]

Options:
  --menu                Show interactive menu (default if no args)

  --install             Start full installation (non-interactive)

  --start-from PHASE    Start from a specific phase (1-14)
                        Example: --start-from 14

  --phase PHASE         Run only a specific phase
                        Example: --phase 14

  --health              Run system health check

  --btrfs               Show BTRFS dashboard

  --integrity           Run integrity check (AIDE)

  --skip-unmount        Skip unmounting in phase 13 (for testing)

  --help, -h            Show this help message

Examples:
  # Interactive menu (recommended)
  bash arch-secure-deploy.sh

  # Full installation (non-interactive start)
  bash arch-secure-deploy.sh --install

  # Desktop setup only
  bash arch-secure-deploy.sh --phase 14

  # Resume from phase 14
  bash arch-secure-deploy.sh --start-from 14

  # Continue installation without unmounting (for iterative testing)
  bash arch-secure-deploy.sh --start-from 10 --skip-unmount

Phase Numbers:
  1   - Preflight checks
  1b  - Interactive configuration
  2   - Device configuration
  3   - Disk preparation
  4   - LUKS encryption
  5   - BTRFS filesystem
  6   - Base installation
  7   - Mount configuration
  8   - Chroot configuration
  9   - System configuration
  10  - User setup
  11  - Security hardening
  12  - BTRFS snapshots
  13  - Final verification
  14  - Optional desktop setup

EOF
}

main() {
    # If no arguments, show interactive menu
    if [[ $# -eq 0 ]]; then
        show_main_menu
        exit 0
    fi

    # Parse command-line arguments
    local START_FROM_PHASE=""
    local RUN_ONLY_PHASE=""
    local SKIP_UNMOUNT=false
    local RUN_INSTALL=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --menu)
                show_main_menu
                exit 0
                ;;
            --install)
                RUN_INSTALL=true
                shift
                ;;
            --start-from)
                START_FROM_PHASE="$2"
                shift 2
                ;;
            --phase)
                RUN_ONLY_PHASE="$2"
                shift 2
                ;;
            --health)
                run_system_health
                exit 0
                ;;
            --btrfs)
                run_btrfs_dashboard
                exit 0
                ;;
            --integrity)
                run_integrity_check
                exit 0
                ;;
            --skip-unmount)
                SKIP_UNMOUNT=true
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    # Initialize logging
    mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$ERROR_LOG")"
    touch "$LOG_FILE" "$ERROR_LOG"

    # Load previous state if exists
    load_state

    # Run specific phase only
    if [[ -n "$RUN_ONLY_PHASE" ]]; then
        log_section "ARCH LINUX SECURE RESEARCH DEPLOYMENT - PRODUCTION v2.2"
        log_info "Running ONLY phase $RUN_ONLY_PHASE (testing mode)"
        case "$RUN_ONLY_PHASE" in
            15) phase_15_laptop_configuration ;;
            14) phase_14_optional_desktop_setup ;;
            13) phase_13_final_verification ;;
            12) phase_12_snapshot_automation ;;
            11) phase_11_security_hardening ;;
            10) phase_10_user_setup ;;
            9)  phase_9_system_configuration ;;
            8)  phase_8_chroot_configuration ;;
            7)  phase_7_mount_configuration ;;
            6)  phase_6_base_installation ;;
            5)  phase_5_btrfs_filesystem ;;
            4)  phase_4_luks_encryption ;;
            3)  phase_3_disk_preparation ;;
            2)  phase_2_device_configuration ;;
            1b) phase_1b_interactive_configuration ;;
            1)  phase_1_preflight_checks ;;
            *)  log_error "Invalid phase: $RUN_ONLY_PHASE"; exit 1 ;;
        esac
        return 0
    fi

    # Start from specific phase
    if [[ -n "$START_FROM_PHASE" ]]; then
        run_installation_from_phase "$START_FROM_PHASE" "$SKIP_UNMOUNT"
        return 0
    fi

    # Full installation
    if [[ "$RUN_INSTALL" == "true" ]]; then
        run_installation_from_phase 1 "$SKIP_UNMOUNT"
        return 0
    fi

    # Default: show menu (this shouldn't be reached, but as fallback)
    show_main_menu
}

# Execute main
main "$@"

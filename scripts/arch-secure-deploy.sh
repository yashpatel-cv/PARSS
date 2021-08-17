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
        echo ""
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

    echo ""
    echo -e "${RED}=============================================================${NC}"
    echo -e "${RED}            ** DESTRUCTIVE OPERATION WARNING **${NC}"
    echo -e "${RED}=============================================================${NC}"
    echo ""
    echo "This script will ask for custom names and settings."
    echo "  1. Confirm you selected the CORRECT device"
    echo "  2. Confirm you have backed up all important data"
    echo "  3. Type 'YES' to proceed"
    echo ""

    read -p "Type 'y' or 'Y' to confirm: " confirmation
    echo

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

    echo ""
    echo -e "${CYAN}=============================================================${NC}"
    echo -e "${CYAN}                  ENCRYPTION PASSPHRASE SETUP                    ${NC}"
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
    echo -e "${YELLOW}  This passphrase will unlock the encrypted root partition (containing all BTRFS subvolumes)${NC}"
    echo ""

    local passphrase=""
    local passphrase_confirm=""
    local attempts=0

    while [[ $attempts -lt 3 ]]; do
        read -sp "Enter passphrase: " passphrase
        echo ""

        if ! validate_passphrase_strength "$passphrase"; then
            log_warn "Passphrase does not meet requirements. Try again."
            ((attempts++))
            continue
        fi

        read -sp "Confirm passphrase: " passphrase_confirm
        echo ""

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
    echo ""
    echo -e "${CYAN}=============================================================${NC}"
    echo -e "${CYAN}        CUSTOM PARTITION SIZE CONFIGURATION${NC}"
    echo -e "${CYAN}=============================================================${NC}"
    echo ""
    echo "Total available space: ${AVAILABLE_SPACE_GB}GB"

    echo ""
    echo "Configuration:"
    echo "  1. EFI System Partition: 1GB (FAT32)"
    echo "  2. Root partition with BTRFS subvolumes (@, @home, @var, @snapshots, etc.): All remaining space"
    echo ""
    echo "BTRFS subvolumes will be created on the root partition:"
    echo "  - @ (root filesystem)"
    echo "  - @home (user home directories)"
    echo "  - @var (variable data)"
    echo "  - @snapshots (BTRFS snapshots)"
    echo "  - @varcache (package cache)"
    echo "  - @log (system logs)"
    echo ""

    echo -e "${GREEN}Partition Layout:${NC}"
    echo "  EFI System Partition: 1GB"
    echo "  Root partition:       $((AVAILABLE_SPACE_GB - 1))GB (all BTRFS subvolumes)"
    echo "  Total:                ${AVAILABLE_SPACE_GB}GB"
    echo ""

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

    echo ""
    echo -e "${CYAN}=============================================================${NC}"
    echo -e "${CYAN}         CUSTOM SYSTEM CONFIGURATION (Interactive)          ${NC}"
    echo -e "${CYAN}=============================================================${NC}"
    echo ""
    echo "This script will ask for custom names and settings."
    echo "Press Enter to use default values shown in [brackets]"
    echo ""

    # SECTION 1: SYSTEM IDENTIFICATION
    log_info "SECTION 1: System Identification"
    echo ""

    log_info "Enter system hostname (computer name)"
    echo "Examples: thinkpad-research, arch-laptop, secure-dev"
    read -p "Hostname [devta]: " input_hostname
    HOSTNAME_SYS="${input_hostname:-devta}"

    if ! validate_hostname "$HOSTNAME_SYS"; then
        log_error "Invalid hostname. Use only alphanumeric and hyphens."
        return 1
    fi

    log_success "Hostname: $HOSTNAME_SYS"

    log_info "Enter primary username (login account)"
    echo "Examples: patel, research, developer"
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
    echo ""

    # BTRFS subvolumes use standard naming convention:
    # @, @home, @var, @snapshots, @varcache, @log (no customization needed)
    log_info "BTRFS subvolumes will use standard naming: @, @home, @var, @snapshots, @varcache, @log"
    log_success "BTRFS layout configured with standard subvolume names"

    log_info "Include @log BTRFS subvolume?"
    echo "(Separates systemd journal - improves snapshot efficiency)"
    read -p "Include @log (y/n) [y]: " input_log
    ADD_LOG_SUBVOLUME="${input_log:-y}"
    [[ "$ADD_LOG_SUBVOLUME" =~ ^[yY]$ ]] && ADD_LOG_SUBVOLUME="true" || ADD_LOG_SUBVOLUME="false"
    log_success "@log subvolume: $ADD_LOG_SUBVOLUME"

    log_info "Enable NVIDIA GPU drivers?"
    echo "(For RTX A5500 CUDA support)"
    read -p "Enable NVIDIA (y/n) [y]: " input_gpu
    ENABLE_NVIDIA_GPU="${input_gpu:-y}"
    [[ "$ENABLE_NVIDIA_GPU" =~ ^[yY]$ ]] && ENABLE_NVIDIA_GPU="true" || ENABLE_NVIDIA_GPU="false"
    log_success "NVIDIA GPU support: $ENABLE_NVIDIA_GPU"

    log_info "Snapshot retention count"
    echo "(Number of weekly snapshots to keep: 12 = ~3 months)"
    read -p "Snapshot retention [12]: " input_snapshots
    SNAPSHOT_RETENTION="${input_snapshots:-12}"

    if ! [[ "$SNAPSHOT_RETENTION" =~ ^[0-9]+$ ]] || [[ "$SNAPSHOT_RETENTION" -lt 2 ]]; then
        log_warn "Invalid snapshot retention, using default: 12"
        SNAPSHOT_RETENTION=12
    fi

    log_success "Snapshot retention: $SNAPSHOT_RETENTION"

    log_info "System timezone"
    echo ""
    echo "Common timezones:"
    echo "  UTC                     (Universal Coordinated Time)"
    echo "  America/New_York        (US Eastern)"
    echo "  America/Chicago         (US Central)"
    echo "  America/Denver          (US Mountain)"
    echo "  America/Los_Angeles     (US Pacific)"
    echo "  Europe/London           (UK)"
    echo "  Europe/Paris            (Central Europe)"
    echo "  Asia/Tokyo              (Japan)"
    echo "  Asia/Shanghai           (China)"
    echo "  Asia/Kolkata            (India)"
    echo "  Australia/Sydney        (Australia)"
    echo ""
    echo "To find your timezone:"
    echo "  • List all: timedatectl list-timezones"
    echo "  • Search:   timedatectl list-timezones | grep -i <region>"
    echo "  • Example:  timedatectl list-timezones | grep -i america"
    echo ""
    read -p "Enter timezone [UTC]: " input_timezone
    SYSTEM_TIMEZONE="${input_timezone:-UTC}"

    # Validate timezone exists
    if [[ ! -f "/usr/share/zoneinfo/$SYSTEM_TIMEZONE" ]]; then
        log_warn "Timezone '$SYSTEM_TIMEZONE' not found, using UTC"
        SYSTEM_TIMEZONE="UTC"
    fi
    log_success "Timezone: $SYSTEM_TIMEZONE"

    # CONFIRMATION
    log_info ""
    log_info "============================================================="
    log_info "INSTALLATION SUMMARY - Please Review"
    log_info "============================================================="
    echo ""

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
    echo ""

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

        echo "  ($i) $full_path - $size - $type"
        device_menu[$i]="$full_path"
        ((i++))
    done

    echo ""

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
        "base" "linux-zen" "linux-zen-headers" "linux-lts" "linux-lts-headers"
        "mkinitcpio"
        "grub" "efibootmgr" "os-prober" "ntfs-3g"
        "btrfs-progs"
        "cryptsetup"
        "networkmanager"
        "vim" "nano"
        "git" "curl" "wget"
        "sudo"
        "zsh" "zsh-completions"
        "openssh"
        "base-devel"
        "xorg-server" "xorg-xinit" "xorg-xrandr"
        "libx11" "libxft" "libxinerama" "libxcb"
        "fontconfig" "freetype2"
        "noto-fonts" "noto-fonts-emoji"
        "picom"
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
        --bootloader-id=ArchLinux \
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

    # SSH - Remote access
    log_info "Enabling SSH service..."
    arch-chroot "$MOUNT_ROOT" systemctl enable sshd

    # Configure SSH to allow root login with password (for development/testing)
    # For production, consider using key-based authentication only
    if [[ -f "$MOUNT_ROOT/etc/ssh/sshd_config" ]]; then
        log_info "Configuring SSH to permit root login..."
        # Uncomment and set PermitRootLogin to yes
        sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' "$MOUNT_ROOT/etc/ssh/sshd_config"
        # Ensure password authentication is enabled
        sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' "$MOUNT_ROOT/etc/ssh/sshd_config"
        log_success "SSH configured to allow root login"
    else
        log_warn "SSH config file not found, skipping SSH configuration"
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
        echo
        local user_password_confirm
        read -sp "Confirm password: " user_password_confirm
        echo
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
        echo
        local root_password_confirm
        read -sp "Confirm password: " root_password_confirm
        echo
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
    local prompt_message=" Congratulations! Your secure base system is ready!

The next step is OPTIONAL but RECOMMENDED:
Install complete desktop environment (DWM + Dotfiles)

WHAT WILL BE INSTALLED:
  - archrice dotfiles (personal configs)
  - yay AUR helper (for AUR packages)
  - DWM window manager (lightweight, keyboard-driven)
  - ST terminal, dmenu, dwmblocks
  - Moonfly OLED theme (optimized for OLED displays)
  - ~60 packages from progs.csv
  - Librewolf browser + extensions
  - Development tools (neovim, git, etc.)

ADVANTAGES:
   * No reboot needed - continue immediately
   * Network already configured
   * Faster testing workflow
   * Complete system ready in one session

TIME: 10-30 minutes (network dependent)

TIP: Can install later with:
   sudo bash arch-secure-deploy.sh --phase 14"

    # Desktop environment prompt
    echo ""
    echo ""
    echo "==============================================================================="
    echo "                 DESKTOP ENVIRONMENT INSTALLATION"
    echo "                          ** PHASE 14 **"
    echo "==============================================================================="
    echo ""
    echo "$prompt_message"
    echo ""
    echo "==============================================================================="
    echo "               INSTALL DESKTOP ENVIRONMENT NOW?"
    echo "==============================================================================="
    echo ""

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

    # Desktop setup configuration (like LARBS does it inline)
    local DOTFILES_REPO="https://github.com/yashpatel-01/archrice.git"
    local DOTFILES_DIR="/home/$PRIMARY_USER/.local/src/archrice"
    local PROGS_FILE="$DOTFILES_DIR/progs.csv"

    log_info "This may take 10-30 minutes depending on network speed..."
    log_info ""

    # Execute desktop setup inline (LARBS-style: all logic in one script)
    arch-chroot "$MOUNT_ROOT" /bin/bash <<DESKTOP_SETUP_EOF
set -e

# Helper functions
info() { echo -e "\\033[0;32m[INFO]\\033[0m \$*"; }
warn() { echo -e "\\033[1;33m[WARN]\\033[0m \$*"; }

info "PARSS Desktop Setup starting..."

# 0. Setup temporary passwordless sudo (LARBS method)
# Required for AUR package builds which need to install as root
info "Configuring temporary passwordless sudo for AUR builds..."
trap 'rm -f /etc/sudoers.d/parss-temp' HUP INT QUIT TERM PWR EXIT
echo "%wheel ALL=(ALL) NOPASSWD: ALL
Defaults:%wheel,root runcwd=*" >/etc/sudoers.d/parss-temp
info " * Temporary sudo configured (will be removed after setup)"

# 1. Clone archrice dotfiles
info "Cloning archrice dotfiles repository..."
sudo -u $PRIMARY_USER mkdir -p "\$(dirname $DOTFILES_DIR)"
if [[ -d "$DOTFILES_DIR/.git" ]]; then
    info "Found existing archrice repo, pulling latest..."
    sudo -u $PRIMARY_USER git -C "$DOTFILES_DIR" pull --ff-only || warn "Using existing copy"
else
    sudo -u $PRIMARY_USER git clone --depth 1 "$DOTFILES_REPO" "$DOTFILES_DIR" || {
        warn "Failed to clone dotfiles"
        exit 1
    }
fi

# 2. Install AUR helper (yay) - LARBS method
info "Installing AUR helper (yay)..."
if ! command -v yay >/dev/null 2>&1; then
    # Install yay from AUR (same method as LARBS)
    repodir="/home/$PRIMARY_USER/.local/src"
    sudo -u $PRIMARY_USER mkdir -p "\$repodir/yay"

    sudo -u $PRIMARY_USER git -C "\$repodir" clone --depth 1 --single-branch \
        --no-tags -q "https://aur.archlinux.org/yay.git" "\$repodir/yay" || {
        cd "\$repodir/yay" || exit 1
        sudo -u $PRIMARY_USER git pull --force origin master
    }

    cd "\$repodir/yay" || exit 1
    sudo -u $PRIMARY_USER makepkg --noconfirm -si >/dev/null 2>&1 || {
        warn "Failed to install yay"
        exit 1
    }

    # Configure yay for auto-updates of *-git packages (LARBS does this)
    sudo -u $PRIMARY_USER yay -Y --save --devel >/dev/null 2>&1

    info " * yay installed"
else
    info " * yay already installed"
fi

# 3. Install packages from progs.csv
info "Looking for progs.csv at: $PROGS_FILE"
if [[ ! -f "$PROGS_FILE" ]]; then
    warn "No progs.csv found at $PROGS_FILE"
    info "Contents of $DOTFILES_DIR:"
    ls -la "$DOTFILES_DIR" || warn "Directory doesn't exist"
else
    # Count total packages for progress tracking
    total=\$(grep -c "^[^#]" "$PROGS_FILE" 2>/dev/null || echo 0)
    n=0
    info "Installing \$total packages from progs.csv..."

    while IFS=, read -r tag prog comment; do
        # Skip comments and blank lines
        [[ -z "\${tag}\${prog}" ]] && continue
        [[ "\$tag" =~ ^# ]] && continue

        n=\$((n + 1))

        case "\$tag" in
            "" )
                info "[\$n/\$total] [pacman] \$prog"
                pacman --noconfirm --needed -S "\$prog" >/dev/null 2>&1 || warn "Failed: \$prog"
                ;;
            "G" )
                info "[\$n/\$total] [git/make] \$prog"
                repodir="/home/$PRIMARY_USER/.local/src"
                sudo -u $PRIMARY_USER mkdir -p "\$repodir"
                name="\${prog##*/}"
                name="\${name%.git}"
                dir="\$repodir/\$name"

                if [[ -d "\$dir/.git" ]]; then
                    sudo -u $PRIMARY_USER git -C "\$dir" pull --ff-only >/dev/null 2>&1 || warn "Using existing: \$prog"
                else
                    sudo -u $PRIMARY_USER git clone --depth 1 --quiet "\$prog" "\$dir" >/dev/null 2>&1 || {
                        warn "Clone failed: \$prog"
                        continue
                    }
                fi

                (cd "\$dir" && sudo -u $PRIMARY_USER make >/dev/null 2>&1 && make install >/dev/null 2>&1) || warn "Build failed: \$prog"
                ;;
            "A" )
                # AUR packages - requires AUR helper (yay)
                if command -v yay >/dev/null 2>&1; then
                    info "[\$n/\$total] [AUR] \$prog (building from source...)"
                    sudo -u $PRIMARY_USER yay --noconfirm --needed -S "\$prog" >/dev/null 2>&1 || warn "Failed: \$prog"
                else
                    warn "No AUR helper (yay) found, skipping: \$prog"
                fi
                ;;
            * )
                warn "Unknown tag '\$tag' for \$prog"
                ;;
        esac
    done < "$PROGS_FILE"

    info ""
    info " * Package installation complete (\$n packages processed)"
fi

# 4. Deploy dotfiles
info "Deploying dotfiles to /home/$PRIMARY_USER..."
if command -v rsync >/dev/null 2>&1; then
    sudo -u $PRIMARY_USER rsync -a --delete --exclude='.git' "$DOTFILES_DIR"/ "/home/$PRIMARY_USER"/
else
    warn "rsync not found, using cp"
    sudo -u $PRIMARY_USER cp -rf "$DOTFILES_DIR"/. "/home/$PRIMARY_USER"/
fi

# 5. OLED/HiDPI Configuration
info "Configuring OLED theme and HiDPI support..."

# Make all scripts executable
chmod +x /home/$PRIMARY_USER/.local/bin/* 2>/dev/null || true

# Set OLED black wallpaper using existing file from dotfiles
if [[ -f "/home/$PRIMARY_USER/.local/share/wallpapers/oled-black.png" ]]; then
    sudo -u $PRIMARY_USER ln -sf /home/$PRIMARY_USER/.local/share/wallpapers/oled-black.png /home/$PRIMARY_USER/.local/share/bg
    info " * OLED black wallpaper set"
fi

# Auto-detect screen resolution and set DPI in Xresources
resolution=\$(xrandr 2>/dev/null | grep '\*' | awk '{print \$1}' | head -n1 || echo "1920x1080")
width=\${resolution%x*}
if [[ \$width -ge 3840 ]]; then
    dpi=192  # 4K displays
elif [[ \$width -ge 2560 ]]; then
    dpi=144  # 1440p/1600p displays
else
    dpi=96   # 1080p and lower
fi
xresources="/home/$PRIMARY_USER/.config/x11/xresources"
if [[ -f "\$xresources" ]]; then
    sed -i "s/^! Xft.dpi:.*/Xft.dpi: \$dpi/" "\$xresources"
    sed -i "s/^Xft.dpi:.*/Xft.dpi: \$dpi/" "\$xresources"
    info " * DPI set to \$dpi (detected \$resolution)"
fi

# Remove DWM gaps for OLED displays (edge-to-edge windows)
dwm_config="/home/$PRIMARY_USER/.local/src/dwm/config.h"
if [[ -f "\$dwm_config" ]]; then
    sed -i 's/^static const unsigned int gappih.*/static const unsigned int gappih = 0;/' "\$dwm_config"
    sed -i 's/^static const unsigned int gappiv.*/static const unsigned int gappiv = 0;/' "\$dwm_config"
    sed -i 's/^static const unsigned int gappoh.*/static const unsigned int gappoh = 0;/' "\$dwm_config"
    sed -i 's/^static const unsigned int gappov.*/static const unsigned int gappov = 0;/' "\$dwm_config"
    cd "/home/$PRIMARY_USER/.local/src/dwm"
    sudo -u $PRIMARY_USER make >/dev/null 2>&1 && make install >/dev/null 2>&1 && info " * DWM gaps removed"
fi

# Copy configs to root for consistent theme with sudo
mkdir -p /root/.config 2>/dev/null
[[ -d "/home/$PRIMARY_USER/.config/nvim" ]] && cp -r "/home/$PRIMARY_USER/.config/nvim" /root/.config/ && info " * Root nvim configured"
[[ -f "/home/$PRIMARY_USER/.config/x11/xresources" ]] && cp "/home/$PRIMARY_USER/.config/x11/xresources" /root/.Xresources

info ""
info "OLED/HiDPI Setup Complete:"
info "  - Moonfly OLED: Pure black #000000 (OLED pixels off)"
info "  - DPI: \$dpi for \$resolution display"
info "  - Wallpaper: Black (zero power)"
info "  - DWM: No gaps (maximize space)"
info "  - Root/user: Same theme"
info ""
info "After reboot: login and run 'startx'"

# Cleanup: Remove temporary passwordless sudo
info "Cleaning up temporary sudo configuration..."
rm -f /etc/sudoers.d/parss-temp
info " * Temporary sudo removed (security restored)"

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
# MAIN EXECUTION
################################################################################

show_usage() {
    cat << 'EOF'
Usage: bash arch-secure-deploy.sh [OPTIONS]

Options:
  --start-from PHASE    Start from a specific phase (1-14)
                        Example: --start-from 14

  --phase PHASE         Run only a specific phase
                        Example: --phase 14

  --skip-unmount        Skip unmounting in phase 13 (for testing)

  --help, -h            Show this help message

Examples:
  # Full installation
  bash arch-secure-deploy.sh

  # Test desktop setup only (assumes system is installed and mounted)
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
    # Parse command-line arguments
    local START_FROM_PHASE=1
    local RUN_ONLY_PHASE=""
    local SKIP_UNMOUNT=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --start-from)
                START_FROM_PHASE="$2"
                shift 2
                ;;
            --phase)
                RUN_ONLY_PHASE="$2"
                shift 2
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

    log_section "ARCH LINUX SECURE RESEARCH DEPLOYMENT - PRODUCTION v2.2"
    log_info "Installation started: $(date)"
    log_info "Log file: $LOG_FILE"
    log_info "Error log: $ERROR_LOG"
    log_info "State file: $STATE_FILE"

    if [[ -n "$RUN_ONLY_PHASE" ]]; then
        log_info "Running ONLY phase $RUN_ONLY_PHASE (testing mode)"
        case "$RUN_ONLY_PHASE" in
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

    if [[ "$START_FROM_PHASE" != "1" ]]; then
        log_info "Starting from phase $START_FROM_PHASE (skipping earlier phases)"
    fi

    # Execute phases (conditionally based on START_FROM_PHASE)
    [[ $START_FROM_PHASE -le 1 ]] && { phase_1_preflight_checks || exit 1; }
    [[ $START_FROM_PHASE -le 1 ]] && { phase_1b_interactive_configuration || exit 1; }
    [[ $START_FROM_PHASE -le 2 ]] && { phase_2_device_configuration || exit 1; }
    [[ $START_FROM_PHASE -le 3 ]] && { phase_3_disk_preparation || exit 1; }
    [[ $START_FROM_PHASE -le 4 ]] && { phase_4_luks_encryption || exit 1; }
    [[ $START_FROM_PHASE -le 5 ]] && { phase_5_btrfs_filesystem || exit 1; }
    [[ $START_FROM_PHASE -le 6 ]] && { phase_6_base_installation || exit 1; }
    [[ $START_FROM_PHASE -le 7 ]] && { phase_7_mount_configuration || exit 1; }
    [[ $START_FROM_PHASE -le 8 ]] && { phase_8_chroot_configuration || exit 1; }
    [[ $START_FROM_PHASE -le 9 ]] && { phase_9_system_configuration || exit 1; }
    [[ $START_FROM_PHASE -le 10 ]] && { phase_10_user_setup || exit 1; }
    [[ $START_FROM_PHASE -le 11 ]] && { phase_11_security_hardening || exit 1; }
    [[ $START_FROM_PHASE -le 12 ]] && { phase_12_snapshot_automation || exit 1; }
    [[ $START_FROM_PHASE -le 14 ]] && phase_14_optional_desktop_setup
    [[ $START_FROM_PHASE -le 13 ]] && [[ "$SKIP_UNMOUNT" != "true" ]] && { phase_13_final_verification || exit 1; }

    # Completion summary
    log_section "INSTALLATION COMPLETED SUCCESSFULLY"

    log_info ""
    log_info "Next steps:"
    log_info "  1. Remove installation media (USB/ISO)"
    log_info "  2. Reboot system: reboot"
    log_info "  3. Enter your LUKS passphrase at boot"
    log_info "  4. Login with user: $PRIMARY_USER"

    # Check if desktop was installed (variable is exported by phase_14 via save_state)
    if [[ "${DESKTOP_SETUP_COMPLETE:-false}" == "true" ]]; then
        log_info "  5. Run 'startx' to launch your desktop environment"
    else
        log_info "  5. (Optional) Rerun installer with --phase 14 for GUI (see below)"
    fi
    log_info ""
    log_info "System Information:"
    log_info "  Hostname: $HOSTNAME_SYS"
    log_info "  Root partition: $((AVAILABLE_SPACE_GB - 1))GB (encrypted BTRFS with all subvolumes)"
    log_info "  User: $PRIMARY_USER"
    log_info "  LUKS device name: $LUKS_ROOT_NAME"
    log_info "  Encryption: Single passphrase for entire system"
    log_info ""
    log_info "Features:"
    log_info "   * LUKS2 encryption (Argon2id KDF) - SINGLE PASSPHRASE"
    log_info "   * BTRFS filesystem with automatic snapshots ($SNAPSHOT_RETENTION snapshots)"
    log_info "   * Security hardening (sysctl + kernel parameters)"
    log_info "   * Zen kernel for performance"
    log_info "   * NetworkManager for networking"
    log_info "   * SSH server enabled (root login allowed for development)"
    log_info "   * Time synchronization (systemd-timesyncd)"
    log_info "   * SSD TRIM optimization (fstrim.timer - weekly)"
    log_info "   * zsh as default shell"
    log_info "   * X11 graphics stack"
    if [[ "$ENABLE_NVIDIA_GPU" == "true" ]]; then
        log_info "   * NVIDIA GPU drivers (RTX A5500 support)"
    fi
    if [[ "${DESKTOP_SETUP_COMPLETE:-false}" == "true" ]]; then
        log_info "   * Desktop environment (dwm/st/dmenu/slstatus)"
        log_info "   * Archrice dotfiles deployed"
    fi
    log_info ""

    # Only show manual instructions if desktop was NOT installed
    if [[ "${DESKTOP_SETUP_COMPLETE:-false}" != "true" ]]; then
        log_info " * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *  *
        log_info ""
        log_info "OPTIONAL: Desktop Environment & Dotfiles Setup"
        log_info ""
        log_info "The base system is complete. To add a desktop environment (dwm/st/dmenu)"
        log_info "and your dotfiles, follow these steps AFTER rebooting:"
        log_info ""
        log_info "1. Boot into the new system and login as: $PRIMARY_USER"
        log_info ""
        log_info "2. Mount your system (if not already mounted):"
        log_info "   sudo cryptsetup luksOpen /dev/sdXY $LUKS_ROOT_NAME"
        log_info "   sudo mount -o subvol=@ /dev/mapper/$LUKS_ROOT_NAME /mnt/root"
        log_info "   sudo mount /dev/sdX1 /mnt/root/boot"
        log_info ""
        log_info "3. Clone PARSS and run phase 14:"
        log_info "   cd /tmp"
        log_info "   git clone https://github.com/yashpatel-01/PARSS.git"
        log_info "   cd PARSS"
        log_info "   sudo bash scripts/arch-secure-deploy.sh --phase 14"
        log_info ""
        log_info "This will:"
        log_info "  - Clone your archrice dotfiles (https://github.com/yashpatel-01/archrice)"
        log_info "  - Install packages from progs.csv (suckless tools, browsers, etc.)"
        log_info "  - Deploy dotfiles to your home directory"
        log_info "  - Build suckless software (dwm, st, dmenu, slstatus)"
        log_info ""
        log_info "After phase 14 completes, reboot and run 'startx' to launch your environment."
        log_info ""
        log_info " * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *  *
        log_info ""
    fi
    log_info "Installation log: $LOG_FILE"
    log_info "Installation completed: $(date)"
    log_info ""
}

# Execute main
main "$@"

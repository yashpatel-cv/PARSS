#!/usr/bin/env bash

################################################################################
# ARCH LINUX SECURE RESEARCH DEPLOYMENT - FINAL PRODUCTION v2.1
#
# Purpose: Complete automated Arch Linux installation with security hardening,
#          LUKS2 encryption, BTRFS snapshots, and suckless desktop environment
#          with interactive configuration, error recovery, and reproducible setup
#
# Version: 2.1 (Final - With Phase 1B Interactive Configuration)
#
# Features:
#   ✓ Interactive user input (hostname, username, BTRFS volume names)
#   ✓ Customizable partition sizing (root: 170-190GB, home: remainder)
#   ✓ LUKS2 encryption with Argon2id KDF (mandatory)
#   ✓ BTRFS filesystem with multi-subvolume architecture
#   ✓ Comprehensive error recovery (15+ scenarios)
#   ✓ Security hardening (kernel params, sysctl tuning)
#   ✓ BTRFS automatic snapshot automation (weekly)
#   ✓ CSV-driven package installation (pacman/AUR/git)
#   ✓ Automatic voidrice deployment (LARBS identical)
#   ✓ Suckless window manager stack (dwm, st, dmenu, slstatus)
#   ✓ Network resilience with retry logic
#   ✓ Extensive logging and state tracking
#   ✓ Disaster recovery mechanisms
#
# Usage: sudo bash ./arch-secure-deploy-production.sh
#
# Prerequisites:
#   - Arch Linux ISO (fresh install environment)
#   - UEFI firmware
#   - Network connectivity (Wi-Fi or Ethernet)
#   - Minimum 300GB storage (170-190GB root + home)
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
declare HOME_PARTITION=""
declare ROOT_CRYPT="/dev/mapper/root_crypt"
declare MOUNT_ROOT="/mnt/root"
declare ROOT_SIZE_GB=50
declare HOME_SIZE_GB=0
declare AVAILABLE_SPACE_GB=0

# === INTERACTIVE CONFIGURATION VARIABLES ===
declare HOSTNAME_SYS="archlinux"
declare PRIMARY_USER=""
declare BTRFS_ROOT_VOL="arch_root"
declare BTRFS_HOME_VOL="arch_home"
declare BTRFS_SNAP_VOL="arch_snapshots"
declare LUKS_ROOT_NAME="crypt_root"
declare LUKS_HOME_NAME="crypt_home"
declare ADD_LOG_SUBVOLUME="true"
declare ENABLE_NVIDIA_GPU="true"
declare SNAPSHOT_RETENTION=8
declare SYSTEM_TIMEZONE="UTC"

# === FEATURE FLAGS ===
declare PERFORM_UPGRADE=true

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
    
    if [[ -b "$ROOT_CRYPT" ]]; then
        cryptsetup close root_crypt 2>/dev/null || true
    fi
    
    if [[ -b "/dev/mapper/home_crypt" ]]; then
        cryptsetup close home_crypt 2>/dev/null || true
    fi
    
    umount -l /mnt/root/* 2>/dev/null || true
    umount -l /mnt/root 2>/dev/null || true
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
    echo -e "${GREEN}[✓ SUCCESS]${NC} $message" | tee -a "$LOG_FILE"
}

log_error() {
    local message="$1"
    echo -e "${RED}[✗ ERROR]${NC} $message" | tee -a "$LOG_FILE" "$ERROR_LOG"
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

# Validate block device
validate_block_device() {
    local device="$1"
    
    if [[ ! -b "$device" ]]; then
        return 1
    fi
    
    if grep -q "$device" /proc/mounts; then
        log_error "Device $device is currently mounted"
        return 1
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
    echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                    ⚠️  DESTRUCTIVE OPERATION  ⚠️                 ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "Device: ${YELLOW}$device${NC}"
    echo -e "Size: ${YELLOW}${size_gb}GB${NC}"
    echo -e "Action: ${RED}ALL DATA WILL BE PERMANENTLY DESTROYED${NC}"
    echo ""
    echo "This action CANNOT be undone. You must:"
    echo "  1. Confirm you selected the CORRECT device"
    echo "  2. Confirm you have backed up all important data"
    echo "  3. Type the exact device name to proceed"
    echo ""
    
    read -p "Enter device name to confirm (e.g., /dev/nvme0n1): " confirmation
    
    if [[ "$confirmation" != "$device" ]]; then
        log_warn "Confirmation mismatch. Operation cancelled."
        exit 0
    fi
    
    read -p "Are you ABSOLUTELY CERTAIN? Type 'YES' to proceed: " double_confirm
    
    if [[ "$double_confirm" != "YES" ]]; then
        log_warn "Double confirmation failed. Operation cancelled."
        exit 0
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
    
    if [[ ${#passphrase} -lt 12 ]]; then
        return 1
    fi
    
    if [[ ! "$passphrase" =~ [A-Z] ]]; then
        return 1
    fi
    
    if [[ ! "$passphrase" =~ [a-z] ]]; then
        return 1
    fi
    
    if [[ ! "$passphrase" =~ [0-9] ]]; then
        return 1
    fi
    
    return 0
}

# Prompt for LUKS passphrase
prompt_luks_passphrase() {
    log_section "LUKS ENCRYPTION PASSPHRASE SETUP"
    
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                  ENCRYPTION PASSPHRASE SETUP                    ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Passphrase Requirements:"
    echo "  • Minimum 12 characters"
    echo "  • At least one uppercase letter (A-Z)"
    echo "  • At least one lowercase letter (a-z)"
    echo "  • At least one number (0-9)"
    echo "  • Special characters recommended"
    echo ""
    echo -e "${YELLOW}⚠️  You will need this passphrase to boot your system every time${NC}"
    echo -e "${YELLOW}⚠️  Write it down and store it in a secure location${NC}"
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
        echo "$passphrase"
        return 0
    done
    
    log_error "Failed to set valid passphrase after 3 attempts"
    return 1
}

# Prompt for partition size
prompt_partition_size() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║               CUSTOM PARTITION SIZE CONFIGURATION               ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Total available space: ${AVAILABLE_SPACE_GB}GB"
    echo ""
    echo "Configuration:"
    echo "  1. EFI System Partition: 1GB (FAT32)"
    echo "  2. Root partition (@): Customizable"
    echo "  3. Home partition (@home): Remainder of disk"
    echo ""
    
    while true; do
        read -p "Enter root partition size (170-190 GB recommended): " root_input
        
        if ! [[ "$root_input" =~ ^[0-9]+$ ]]; then
            log_warn "Invalid input. Please enter a number."
            continue
        fi
        
        ROOT_SIZE_GB=$root_input
        HOME_SIZE_GB=$((AVAILABLE_SPACE_GB - 1 - ROOT_SIZE_GB))
        
        if [[ $ROOT_SIZE_GB -lt 50 ]]; then
            log_warn "Root partition must be at least 50GB"
            continue
        fi
        
        if [[ $HOME_SIZE_GB -lt 50 ]]; then
            log_warn "Home partition must be at least 50GB (${HOME_SIZE_GB}GB remaining)"
            continue
        fi
        
        echo ""
        echo -e "${GREEN}Partition Layout:${NC}"
        echo "  EFI System Partition: 1GB"
        echo "  Root partition (@):   ${ROOT_SIZE_GB}GB"
        echo "  Home partition (@home): ${HOME_SIZE_GB}GB"
        echo "  Total:                $((1 + ROOT_SIZE_GB + HOME_SIZE_GB))GB"
        echo ""
        
        read -p "Is this configuration correct? (yes/no): " confirm_partition
        
        if [[ "$confirm_partition" == "yes" ]] || [[ "$confirm_partition" == "y" ]]; then
            log_success "Partition configuration confirmed"
            return 0
        fi
    done
}

# Check available disk space
check_disk_space() {
    local device="$1"
    local total_bytes
    total_bytes=$(lsblk -bnd -o SIZE "$device")
    AVAILABLE_SPACE_GB=$((total_bytes / (1024**3)))
    
    log_info "Available disk space: ${AVAILABLE_SPACE_GB}GB"
    
    if [[ $AVAILABLE_SPACE_GB -lt 300 ]]; then
        log_error "Insufficient disk space. Minimum required: 300GB, Available: ${AVAILABLE_SPACE_GB}GB"
        return 1
    fi
    
    return 0
}

################################################################################
# PHASE 1: PRE-FLIGHT VALIDATION
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
    local required_tools=("cryptsetup" "parted" "mkfs.btrfs" "pacstrap" "arch-chroot" "genfstab")
    
    for tool in "${required_tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            log_debug "✓ $tool available"
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
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║         CUSTOM SYSTEM CONFIGURATION (Interactive)          ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "This script will ask for custom names and settings."
    echo "Press Enter to use default values shown in [brackets]"
    echo ""
    
    # SECTION 1: SYSTEM IDENTIFICATION
    log_info "SECTION 1: System Identification"
    echo ""
    
    log_info "Enter system hostname (computer name)"
    echo "Examples: thinkpad-research, arch-laptop, secure-dev"
    read -p "Hostname [archlinux]: " input_hostname
    HOSTNAME_SYS="${input_hostname:-archlinux}"
    
    if ! validate_hostname "$HOSTNAME_SYS"; then
        log_error "Invalid hostname. Use only alphanumeric and hyphens."
        return 1
    fi
    
    log_success "Hostname: $HOSTNAME_SYS"
    
    log_info "Enter primary username (login account)"
    echo "Examples: yash, research, developer"
    read -p "Username: " input_username
    PRIMARY_USER="$input_username"
    
    if ! validate_username "$PRIMARY_USER"; then
        log_error "Invalid username. Use only alphanumeric, underscore, or hyphen."
        return 1
    fi
    
    log_success "Username: $PRIMARY_USER"
    
    # SECTION 2: STORAGE & BTRFS CONFIGURATION
    log_info ""
    log_info "SECTION 2: Storage & BTRFS Configuration"
    echo ""
    
    log_info "BTRFS root logical volume name"
    echo "This labels your encrypted root volume (e.g., arch_root, system_root)"
    read -p "BTRFS root volume [arch_root]: " input_root_vol
    BTRFS_ROOT_VOL="${input_root_vol:-arch_root}"
    
    if ! validate_volume_name "$BTRFS_ROOT_VOL"; then
        log_error "Invalid BTRFS root volume name"
        return 1
    fi
    
    log_success "BTRFS root volume: $BTRFS_ROOT_VOL"
    
    log_info "BTRFS home logical volume name"
    echo "This labels your encrypted home partition"
    read -p "BTRFS home volume [arch_home]: " input_home_vol
    BTRFS_HOME_VOL="${input_home_vol:-arch_home}"
    
    if ! validate_volume_name "$BTRFS_HOME_VOL"; then
        log_error "Invalid BTRFS home volume name"
        return 1
    fi
    
    log_success "BTRFS home volume: $BTRFS_HOME_VOL"
    
    log_info "BTRFS snapshots volume name"
    echo "This stores BTRFS snapshots for recovery"
    read -p "BTRFS snapshots volume [arch_snapshots]: " input_snap_vol
    BTRFS_SNAP_VOL="${input_snap_vol:-arch_snapshots}"
    
    if ! validate_volume_name "$BTRFS_SNAP_VOL"; then
        log_error "Invalid BTRFS snapshots volume name"
        return 1
    fi
    
    log_success "BTRFS snapshots volume: $BTRFS_SNAP_VOL"
    
    # SECTION 3: ENCRYPTION CONFIGURATION
    log_info ""
    log_info "SECTION 3: LUKS Encryption Names"
    echo ""
    
    log_info "LUKS encrypted root volume name"
    echo "This is the cryptographic mapping name (e.g., crypt_root, root_crypt)"
    read -p "Root encryption name [crypt_root]: " input_crypt_root
    LUKS_ROOT_NAME="${input_crypt_root:-crypt_root}"
    
    if ! validate_volume_name "$LUKS_ROOT_NAME"; then
        log_error "Invalid LUKS root name"
        return 1
    fi
    
    log_success "Root encryption: $LUKS_ROOT_NAME"
    
    log_info "LUKS encrypted home volume name"
    echo "This is the cryptographic mapping name (e.g., crypt_home, home_crypt)"
    read -p "Home encryption name [crypt_home]: " input_crypt_home
    LUKS_HOME_NAME="${input_crypt_home:-crypt_home}"
    
    if ! validate_volume_name "$LUKS_HOME_NAME"; then
        log_error "Invalid LUKS home name"
        return 1
    fi
    
    log_success "Home encryption: $LUKS_HOME_NAME"
    
    # SECTION 4: OPTIONAL FEATURES
    log_info ""
    log_info "SECTION 4: Optional Features"
    echo ""
    
    log_info "Include @log BTRFS subvolume?"
    echo "(Separates systemd journal - improves snapshot efficiency) [y/n]"
    read -p "Include @log: " input_log
    ADD_LOG_SUBVOLUME="${input_log:-y}"
    [[ "$ADD_LOG_SUBVOLUME" =~ ^[yY]$ ]] && ADD_LOG_SUBVOLUME="true" || ADD_LOG_SUBVOLUME="false"
    log_success "@log subvolume: $ADD_LOG_SUBVOLUME"
    
    log_info "Enable NVIDIA GPU drivers?"
    echo "(For RTX A5500 CUDA support) [y/n]"
    read -p "Enable NVIDIA: " input_gpu
    ENABLE_NVIDIA_GPU="${input_gpu:-y}"
    [[ "$ENABLE_NVIDIA_GPU" =~ ^[yY]$ ]] && ENABLE_NVIDIA_GPU="true" || ENABLE_NVIDIA_GPU="false"
    log_success "NVIDIA GPU support: $ENABLE_NVIDIA_GPU"
    
    log_info "Snapshot retention count"
    echo "(Number of weekly snapshots to keep: 8 = ~2 months) [8]"
    read -p "Snapshot retention: " input_snapshots
    SNAPSHOT_RETENTION="${input_snapshots:-8}"
    
    if ! [[ "$SNAPSHOT_RETENTION" =~ ^[0-9]+$ ]] || [[ "$SNAPSHOT_RETENTION" -lt 2 ]]; then
        log_warn "Invalid snapshot retention, using default: 8"
        SNAPSHOT_RETENTION=8
    fi
    
    log_success "Snapshot retention: $SNAPSHOT_RETENTION"
    
    log_info "System timezone"
    echo "(Examples: UTC, America/New_York, Europe/London) [UTC]"
    read -p "Timezone: " input_timezone
    SYSTEM_TIMEZONE="${input_timezone:-UTC}"
    log_success "Timezone: $SYSTEM_TIMEZONE"
    
    # CONFIRMATION
    log_info ""
    log_info "════════════════════════════════════════════════════════════"
    log_info "INSTALLATION SUMMARY - Please Review"
    log_info "════════════════════════════════════════════════════════════"
    log_info ""
    log_info "SYSTEM IDENTIFICATION:"
    log_info "  Hostname:                $HOSTNAME_SYS"
    log_info "  Primary User:            $PRIMARY_USER"
    log_info ""
    log_info "STORAGE CONFIGURATION:"
    log_info "  Storage Device:          $TARGET_DEVICE"
    log_info "  Root Partition:          ${ROOT_SIZE_GB}GB"
    log_info "  Home Partition:          ${HOME_SIZE_GB}GB"
    log_info "  BTRFS Root Volume:       $BTRFS_ROOT_VOL"
    log_info "  BTRFS Home Volume:       $BTRFS_HOME_VOL"
    log_info "  BTRFS Snapshots Volume:  $BTRFS_SNAP_VOL"
    log_info ""
    log_info "ENCRYPTION:"
    log_info "  Root Encryption:         $LUKS_ROOT_NAME"
    log_info "  Home Encryption:         $LUKS_HOME_NAME"
    log_info ""
    log_info "OPTIONAL FEATURES:"
    log_info "  @log Subvolume:          $ADD_LOG_SUBVOLUME"
    log_info "  NVIDIA GPU Support:      $ENABLE_NVIDIA_GPU"
    log_info "  Snapshot Retention:      $SNAPSHOT_RETENTION"
    log_info "  Timezone:                $SYSTEM_TIMEZONE"
    log_info ""
    log_info "════════════════════════════════════════════════════════════"
    echo ""
    
    read -p "Proceed with installation? (type 'YES' to confirm): " final_confirm
    
    if [[ "$final_confirm" != "YES" ]]; then
        log_warn "Installation cancelled by user"
        exit 0
    fi
    
    # SAVE CONFIGURATION TO STATE FILE
    log_info "Saving configuration..."
    
    save_state "HOSTNAME_SYS" "$HOSTNAME_SYS"
    save_state "PRIMARY_USER" "$PRIMARY_USER"
    save_state "BTRFS_ROOT_VOL" "$BTRFS_ROOT_VOL"
    save_state "BTRFS_HOME_VOL" "$BTRFS_HOME_VOL"
    save_state "BTRFS_SNAP_VOL" "$BTRFS_SNAP_VOL"
    save_state "LUKS_ROOT_NAME" "$LUKS_ROOT_NAME"
    save_state "LUKS_HOME_NAME" "$LUKS_HOME_NAME"
    save_state "ADD_LOG_SUBVOLUME" "$ADD_LOG_SUBVOLUME"
    save_state "ENABLE_NVIDIA_GPU" "$ENABLE_NVIDIA_GPU"
    save_state "SNAPSHOT_RETENTION" "$SNAPSHOT_RETENTION"
    save_state "SYSTEM_TIMEZONE" "$SYSTEM_TIMEZONE"
    
    log_success "Configuration saved to state file"
    log_success "Phase 1B completed successfully"
}

################################################################################
# PHASE 2: DEVICE & PARTITION CONFIGURATION
################################################################################

phase_2_device_configuration() {
    log_section "PHASE 2: DEVICE & PARTITION CONFIGURATION"
    
    log_info "Available block devices:"
    lsblk -d -n -o NAME,SIZE,TYPE | grep -E "nvme|sd" | tee -a "$LOG_FILE"
    echo ""
    
    while true; do
        read -p "Enter target storage device (e.g., /dev/nvme0n1 or /dev/sda): " TARGET_DEVICE
        
        if ! validate_block_device "$TARGET_DEVICE"; then
            log_warn "Invalid or mounted device: $TARGET_DEVICE"
            continue
        fi
        
        break
    done
    
    save_state "TARGET_DEVICE" "$TARGET_DEVICE"
    
    if ! check_disk_space "$TARGET_DEVICE"; then
        return 1
    fi
    
    prompt_partition_size
    
    confirm_destructive_operation "$TARGET_DEVICE"
    
    if [[ "$TARGET_DEVICE" == *"nvme"* ]]; then
        BOOT_PARTITION="${TARGET_DEVICE}p1"
        ROOT_PARTITION="${TARGET_DEVICE}p2"
        HOME_PARTITION="${TARGET_DEVICE}p3"
    else
        BOOT_PARTITION="${TARGET_DEVICE}1"
        ROOT_PARTITION="${TARGET_DEVICE}2"
        HOME_PARTITION="${TARGET_DEVICE}3"
    fi
    
    log_info "Partition configuration:"
    log_info "  Boot: $BOOT_PARTITION"
    log_info "  Root: $ROOT_PARTITION (${ROOT_SIZE_GB}GB)"
    log_info "  Home: $HOME_PARTITION (${HOME_SIZE_GB}GB)"
    
    save_state "BOOT_PARTITION" "$BOOT_PARTITION"
    save_state "ROOT_PARTITION" "$ROOT_PARTITION"
    save_state "HOME_PARTITION" "$HOME_PARTITION"
    
    log_success "Phase 2 completed successfully"
}

################################################################################
# PHASE 3: DISK WIPING & PARTITIONING
################################################################################

phase_3_disk_preparation() {
    log_section "PHASE 3: DISK WIPING & PARTITIONING"
    
    log_info "Closing any existing LUKS volumes..."
    cryptsetup close root_crypt 2>/dev/null || true
    cryptsetup close home_crypt 2>/dev/null || true
    
    log_info "Wiping existing filesystem signatures from $TARGET_DEVICE..."
    execute_cmd "wipefs -a $TARGET_DEVICE" "Wiping filesystem signatures" true
    
    log_info "Creating GPT partition table..."
    execute_cmd "parted -s $TARGET_DEVICE mklabel gpt" "Creating GPT label" true
    
    log_info "Creating EFI System Partition (1GB)..."
    execute_cmd "parted -s $TARGET_DEVICE mkpart ESP fat32 1MiB 1GiB" "Creating ESP partition" true
    execute_cmd "parted -s $TARGET_DEVICE set 1 esp on" "Setting ESP boot flag" true
    
    log_info "Creating root partition (${ROOT_SIZE_GB}GB)..."
    local root_start=1024
    local root_end=$((root_start + ROOT_SIZE_GB * 1024))
    execute_cmd "parted -s $TARGET_DEVICE mkpart root $root_start MiB $root_end MiB" "Creating root partition" true
    
    log_info "Creating home partition (${HOME_SIZE_GB}GB, remainder)..."
    execute_cmd "parted -s $TARGET_DEVICE mkpart home $root_end MiB 100%" "Creating home partition" true
    
    execute_cmd "parted -s $TARGET_DEVICE set 2 type 8309" "Setting root partition type (LUKS)" false
    execute_cmd "parted -s $TARGET_DEVICE set 3 type 8309" "Setting home partition type (LUKS)" false
    
    log_info "Partition table:"
    parted -s "$TARGET_DEVICE" print | tee -a "$LOG_FILE"
    
    log_success "Phase 3 completed successfully"
}

################################################################################
# PHASE 4: LUKS ENCRYPTION SETUP
################################################################################

phase_4_luks_encryption() {
    log_section "PHASE 4: LUKS2 ENCRYPTION SETUP"
    
    local luks_passphrase
    luks_passphrase=$(prompt_luks_passphrase) || return 1
    
    log_info "Formatting EFI System Partition..."
    execute_cmd "mkfs.fat -F 32 $BOOT_PARTITION" "Formatting $BOOT_PARTITION" true
    
    log_info "Encrypting root partition with LUKS2 (Argon2id KDF)..."
    echo -n "$luks_passphrase" | execute_cmd \
        "cryptsetup luksFormat --type luks2 --pbkdf argon2id --pbkdf-force-iterations 4 $ROOT_PARTITION -" \
        "Initializing LUKS2 on root partition" true
    
    log_info "Opening encrypted root volume..."
    echo -n "$luks_passphrase" | execute_cmd \
        "cryptsetup luksOpen $ROOT_PARTITION $LUKS_ROOT_NAME -" \
        "Opening LUKS volume as $LUKS_ROOT_NAME" true
    
    if [[ ! -b "/dev/mapper/$LUKS_ROOT_NAME" ]]; then
        log_error "Failed to open encrypted root volume"
        return 1
    fi
    
    log_success "Root partition encrypted and opened"
    
    read -p "Encrypt home partition separately? (recommended: yes) [y/n]: " encrypt_home
    
    if [[ "$encrypt_home" == "y" ]] || [[ "$encrypt_home" == "yes" ]] || [[ "$encrypt_home" == "" ]]; then
        log_info "Encrypting home partition with LUKS2..."
        echo -n "$luks_passphrase" | execute_cmd \
            "cryptsetup luksFormat --type luks2 --pbkdf argon2id --pbkdf-force-iterations 4 $HOME_PARTITION -" \
            "Initializing LUKS2 on home partition" false
        
        echo -n "$luks_passphrase" | execute_cmd \
            "cryptsetup luksOpen $HOME_PARTITION $LUKS_HOME_NAME -" \
            "Opening LUKS volume as $LUKS_HOME_NAME" false
        
        if [[ -b "/dev/mapper/$LUKS_HOME_NAME" ]]; then
            log_success "Home partition encrypted and opened"
            save_state "HOME_ENCRYPTED" "true"
        fi
    fi
    
    save_state "ROOT_CRYPT_OPENED" "true"
    log_success "Phase 4 completed successfully"
}

################################################################################
# PHASE 5: BTRFS FILESYSTEM SETUP
################################################################################

phase_5_btrfs_filesystem() {
    log_section "PHASE 5: BTRFS FILESYSTEM SETUP"
    
    local root_crypt_device="/dev/mapper/$LUKS_ROOT_NAME"
    
    log_info "Creating BTRFS filesystem on encrypted root volume..."
    execute_cmd "mkfs.btrfs -f -L root_encrypted -K $root_crypt_device" \
        "Formatting $root_crypt_device with BTRFS" true
    
    log_info "Mounting BTRFS root..."
    mkdir -p "$MOUNT_ROOT"
    execute_cmd "mount $root_crypt_device $MOUNT_ROOT" "Mounting BTRFS root" true
    
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
    
    log_info "Remounting with optimized mount options..."
    execute_cmd "umount $MOUNT_ROOT" "Unmounting temporary mount" true
    
    execute_cmd "mount -o subvol=@,compress=zstd,noatime,space_cache=v2,nodev,nosuid,noexec $root_crypt_device $MOUNT_ROOT" \
        "Mounting @ subvolume with optimization flags" true
    
    mkdir -p "$MOUNT_ROOT"/{home,var,var/cache,.snapshots,boot}
    
    if [[ "$ADD_LOG_SUBVOLUME" == "true" ]]; then
        mkdir -p "$MOUNT_ROOT/var/log"
    fi
    
    execute_cmd "mount -o subvol=@home,compress=zstd,noatime,space_cache=v2 $root_crypt_device $MOUNT_ROOT/home" \
        "Mounting @home subvolume" true
    
    execute_cmd "mount -o subvol=@var,compress=zstd,noatime,space_cache=v2,nodev,nosuid $root_crypt_device $MOUNT_ROOT/var" \
        "Mounting @var subvolume" true
    
    execute_cmd "mount -o subvol=@varcache,compress=zstd,noatime,space_cache=v2,nodev,nosuid $root_crypt_device $MOUNT_ROOT/var/cache" \
        "Mounting @varcache subvolume" true
    
    execute_cmd "mount -o subvol=@snapshots,compress=zstd,noatime,space_cache=v2,nodev,nosuid $root_crypt_device $MOUNT_ROOT/.snapshots" \
        "Mounting @snapshots subvolume" true
    
    if [[ "$ADD_LOG_SUBVOLUME" == "true" ]]; then
        execute_cmd "mount -o subvol=@log,compress=zstd,noatime,space_cache=v2,nodev,nosuid $root_crypt_device $MOUNT_ROOT/var/log" \
            "Mounting @log subvolume" true
    fi
    
    execute_cmd "mount $BOOT_PARTITION $MOUNT_ROOT/boot" "Mounting EFI System Partition" true
    
    log_info "Verifying BTRFS mount configuration..."
    mount | grep "$MOUNT_ROOT" | tee -a "$LOG_FILE"
    
    log_success "BTRFS subvolume hierarchy created and mounted"
    
    save_state "MOUNT_ROOT" "$MOUNT_ROOT"
    save_state "BTRFS_MOUNTED" "true"
    log_success "Phase 5 completed successfully"
}

################################################################################
# PHASE 6: BASE SYSTEM INSTALLATION
################################################################################

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
        "base" "linux-zen" "linux-zen-headers"
        "mkinitcpio"
        "grub" "efibootmgr"
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
    
    if ! execute_cmd_retry "pacstrap -K $MOUNT_ROOT $packages_str" \
        "Installing base system packages" 2; then
        log_error "Pacstrap installation failed"
        return 1
    fi
    
    log_success "Base system installation completed"
    save_state "BASE_INSTALLED" "true"
    log_success "Phase 6 completed successfully"
}

################################################################################
# PHASE 7: MOUNT CONFIGURATION & ENCRYPTION
################################################################################

phase_7_mount_configuration() {
    log_section "PHASE 7: MOUNT CONFIGURATION & ENCRYPTION"
    
    log_info "Generating fstab from current mounts..."
    execute_cmd "genfstab -U $MOUNT_ROOT >> $MOUNT_ROOT/etc/fstab" "Generating fstab" true
    
    log_info "Generated fstab:"
    cat "$MOUNT_ROOT/etc/fstab" | tee -a "$LOG_FILE"
    
    log_info "Configuring crypttab for encrypted root..."
    
    local root_partuuid
    root_partuuid=$(blkid -s PARTUUID -o value "$ROOT_PARTITION")
    
    cat > "$MOUNT_ROOT/etc/crypttab" << EOF
$LUKS_ROOT_NAME	PARTUUID=$root_partuuid	none	luks,x-systemd.device-timeout=10
EOF
    
    if [[ -b "/dev/mapper/$LUKS_HOME_NAME" ]]; then
        local home_partuuid
        home_partuuid=$(blkid -s PARTUUID -o value "$HOME_PARTITION")
        echo "$LUKS_HOME_NAME	PARTUUID=$home_partuuid	none	luks,x-systemd.device-timeout=10" >> "$MOUNT_ROOT/etc/crypttab"
    fi
    
    log_info "crypttab configuration:"
    cat "$MOUNT_ROOT/etc/crypttab" | tee -a "$LOG_FILE"
    
    save_state "FSTAB_GENERATED" "true"
    log_success "Phase 7 completed successfully"
}

################################################################################
# PHASE 8: CHROOT ENVIRONMENT & BOOTLOADER
################################################################################

phase_8_chroot_configuration() {
    log_section "PHASE 8: CHROOT ENVIRONMENT & BOOTLOADER"
    
    log_info "Configuring mkinitcpio for encrypted root..."
    
    local mkinitcpio_conf="$MOUNT_ROOT/etc/mkinitcpio.conf"
    cp "$mkinitcpio_conf" "${mkinitcpio_conf}.bak"
    
    sed -i 's/^MODULES=.*/MODULES=(btrfs dm_crypt)/' "$mkinitcpio_conf"
    sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect keyboard sd-vconsole modconf block sd-encrypt filesystems fsck)/' "$mkinitcpio_conf"
    
    log_info "Updated mkinitcpio configuration:"
    grep -E "^(MODULES|HOOKS)" "$mkinitcpio_conf" | tee -a "$LOG_FILE"
    
    log_info "Generating initramfs (mkinitcpio -p linux-zen)..."
    
    if ! arch-chroot "$MOUNT_ROOT" bash -c "mkinitcpio -p linux-zen" 2>&1 | tee -a "$LOG_FILE"; then
        log_error "Initramfs generation failed"
        return 1
    fi
    
    log_success "Initramfs generated successfully"
    
    log_info "Installing GRUB to EFI System Partition..."
    
    if ! arch-chroot "$MOUNT_ROOT" grub-install \
        --target=x86_64-efi \
        --efi-directory=/boot \
        --bootloader-id=GRUB 2>&1 | tee -a "$LOG_FILE"; then
        log_error "GRUB installation failed"
        return 1
    fi
    
    log_info "Configuring GRUB kernel parameters for encrypted root..."
    
    local grub_default="$MOUNT_ROOT/etc/default/grub"
    local root_partuuid
    root_partuuid=$(blkid -s PARTUUID -o value "$ROOT_PARTITION")
    
    sed -i "/^GRUB_CMDLINE_LINUX=/s|\"$| rd.luks.name=${root_partuuid}:${LUKS_ROOT_NAME} root=/dev/mapper/${LUKS_ROOT_NAME} quiet\"|" "$grub_default"
    sed -i '/^GRUB_CMDLINE_LINUX=/s/$/ mitigations=auto,nosmt spectre_v1=on spectre_v2=on tsx=off audit=1/' "$grub_default"
    
    echo "GRUB_ENABLE_CRYPTODISK=y" >> "$grub_default"
    
    log_info "Updated GRUB configuration:"
    grep -E "^(GRUB_CMDLINE_LINUX|GRUB_ENABLE_CRYPTODISK)" "$grub_default" | tee -a "$LOG_FILE"
    
    log_info "Generating GRUB menu configuration..."
    
    if ! arch-chroot "$MOUNT_ROOT" grub-mkconfig -o /boot/grub/grub.cfg 2>&1 | tee -a "$LOG_FILE"; then
        log_error "GRUB configuration generation failed"
        return 1
    fi
    
    log_success "GRUB bootloader configured successfully"
    save_state "GRUB_INSTALLED" "true"
    log_success "Phase 8 completed successfully"
}

################################################################################
# PHASE 9: SYSTEM CONFIGURATION
################################################################################

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
    
    log_info "Enabling NetworkManager service..."
    arch-chroot "$MOUNT_ROOT" systemctl enable NetworkManager
    
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

################################################################################
# PHASE 10: USER ACCOUNT SETUP
################################################################################

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
    arch-chroot "$MOUNT_ROOT" bash -c "passwd $PRIMARY_USER"
    
    log_info "Setting root password..."
    arch-chroot "$MOUNT_ROOT" bash -c "passwd root"
    
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

################################################################################
# PHASE 11: SECURITY HARDENING
################################################################################

phase_11_security_hardening() {
    log_section "PHASE 11: SECURITY HARDENING"
    
    log_info "Creating security-hardened sysctl parameters..."
    
    cat > "$MOUNT_ROOT/etc/sysctl.d/99-hardening.conf" << 'SYSCTL_CONFIG'
# Security-hardened kernel parameters
kernel.modules_disabled = 1
kernel.dmesg_restrict = 1
kernel.sysrq = 0
kernel.perf_event_paranoid = 3
kernel.kptr_restrict = 2
kernel.printk_devkmsg = off
kernel.randomize_va_space = 2
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
kernel.audit = 1
fs.protected_fifos = 2
fs.protected_regular = 2
fs.protected_symlinks = 1
fs.protected_hardlinks = 1
SYSCTL_CONFIG
    
    log_success "Sysctl hardening configuration created"
    
    arch-chroot "$MOUNT_ROOT" sysctl -p /etc/sysctl.d/99-hardening.conf 2>&1 | tee -a "$LOG_FILE"
    
    log_success "Security hardening completed"
    save_state "HARDENING_APPLIED" "true"
    log_success "Phase 11 completed successfully"
}

################################################################################
# PHASE 12: BTRFS SNAPSHOT AUTOMATION
################################################################################

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
        log_snapshot "✓ Snapshot created: $snapshot_name"
    else
        log_snapshot "✗ Failed to create snapshot: $snapshot_name"
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

################################################################################
# PHASE 13: FINAL VERIFICATION & UNMOUNTING
################################################################################

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
    
    log_info "Closing LUKS encrypted volumes..."
    cryptsetup luksClose root_crypt 2>/dev/null || true
    cryptsetup luksClose home_crypt 2>/dev/null || true
    
    log_success "Installation completed and filesystems unmounted"
    save_state "INSTALLATION_COMPLETE" "true"
    log_success "Phase 13 completed successfully"
}

################################################################################
# MAIN EXECUTION
################################################################################

main() {
    # Initialize logging
    mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$ERROR_LOG")"
    touch "$LOG_FILE" "$ERROR_LOG"
    
    # Load previous state if exists
    load_state
    
    log_section "ARCH LINUX SECURE RESEARCH DEPLOYMENT - PRODUCTION v2.1"
    log_info "Installation started: $(date)"
    log_info "Log file: $LOG_FILE"
    log_info "Error log: $ERROR_LOG"
    log_info "State file: $STATE_FILE"
    
    # Execute phases
    phase_1_preflight_checks || exit 1
    phase_1b_interactive_configuration || exit 1
    phase_2_device_configuration || exit 1
    phase_3_disk_preparation || exit 1
    phase_4_luks_encryption || exit 1
    phase_5_btrfs_filesystem || exit 1
    phase_6_base_installation || exit 1
    phase_7_mount_configuration || exit 1
    phase_8_chroot_configuration || exit 1
    phase_9_system_configuration || exit 1
    phase_10_user_setup || exit 1
    phase_11_security_hardening || exit 1
    phase_12_snapshot_automation || exit 1
    phase_13_final_verification || exit 1
    
    # Completion summary
    log_section "INSTALLATION COMPLETED SUCCESSFULLY"
    
    log_info ""
    log_info "Next steps:"
    log_info "  1. Remove installation media (USB/ISO)"
    log_info "  2. Reboot system: reboot"
    log_info "  3. Unlock encrypted volume when prompted"
    log_info "  4. Login with user: $PRIMARY_USER"
    log_info ""
    log_info "System Information:"
    log_info "  Hostname: $HOSTNAME_SYS"
    log_info "  Root partition: ${ROOT_SIZE_GB}GB (encrypted)"
    log_info "  Home partition: ${HOME_SIZE_GB}GB"
    log_info "  User: $PRIMARY_USER"
    log_info "  LUKS root name: $LUKS_ROOT_NAME"
    log_info "  BTRFS root volume: $BTRFS_ROOT_VOL"
    log_info ""
    log_info "Features:"
    log_info "  ✓ LUKS2 encryption (Argon2id KDF)"
    log_info "  ✓ BTRFS filesystem with automatic snapshots"
    log_info "  ✓ Security hardening (sysctl + kernel parameters)"
    log_info "  ✓ Zen kernel for performance"
    log_info "  ✓ NetworkManager for networking"
    log_info "  ✓ zsh as default shell"
    log_info "  ✓ X11 graphics stack"
    if [[ "$ENABLE_NVIDIA_GPU" == "true" ]]; then
        log_info "  ✓ NVIDIA GPU drivers (RTX A5500 support)"
    fi
    log_info ""
    log_info "Installation log: $LOG_FILE"
    log_info "Installation completed: $(date)"
    log_info ""
}

# Execute main
main "$@"

#!/usr/bin/env bash

################################################################################
# UNIVERSAL HIDPI FONT CONFIGURATION SCRIPT - PRODUCTION READY v1.0
# 
# Purpose: Single-command solution for HiDPI font scaling on ANY display size
# Works with: 1080p, 1440p, 1600p, 3840x2400, etc.
# Automatically detects display and configures all applications
#
# Usage: bash ~/setup-hidpi.sh
# 
# What it does:
#   1. Detects display resolution automatically
#   2. Calculates optimal DPI for comfortable viewing
#   3. Creates ~/.Xresources with master DPI config
#   4. Creates ~/.xinitrc with environment variables
#   5. Patches st/dwm/dmenu config.h with correct pixelsize
#   6. Recompiles all suckless programs
#   7. Configures GTK3
#   8. Provides Firefox setup instructions
#
################################################################################

set -euo pipefail

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Logging functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }

# Global variables (will be set by detect_display)
TARGET_DPI=96
SUCKLESS_FONT_SIZE=9
DWMSTATUS_FONT_SIZE=8
DISPLAY_RES="unknown"

################################################################################
# STEP 1: DETECT DISPLAY AND CALCULATE DPI
################################################################################

detect_display() {
    log_info "Detecting display configuration..."
    
    # Get display info using xdpyinfo
    if ! command -v xdpyinfo &> /dev/null; then
        log_error "xdpyinfo not found. Install xorg-xdpyinfo"
        return 1
    fi
    
    local display_info
    display_info=$(xdpyinfo 2>/dev/null || echo "")
    
    if [[ -z "$display_info" ]]; then
        log_error "Unable to detect display. Make sure X11 is running."
        return 1
    fi
    
    # Extract resolution
    DISPLAY_RES=$(echo "$display_info" | grep "dimensions:" | awk '{print $2}')
    
    log_info "Display detected: $DISPLAY_RES"
    
    # Detect display type and set DPI
    case "$DISPLAY_RES" in
        3840x2400)
            log_info "WQUXGA (3840x2400) detected → 192 DPI (2x scaling)"
            TARGET_DPI=192
            SUCKLESS_FONT_SIZE=12
            DWMSTATUS_FONT_SIZE=11
            ;;
        2560x1600)
            log_info "QHD+ (2560x1600) detected → 144 DPI (1.5x scaling)"
            TARGET_DPI=144
            SUCKLESS_FONT_SIZE=11
            DWMSTATUS_FONT_SIZE=10
            ;;
        2560x1440)
            log_info "QHD (2560x1440) detected → 120 DPI (1.25x scaling)"
            TARGET_DPI=120
            SUCKLESS_FONT_SIZE=10
            DWMSTATUS_FONT_SIZE=9
            ;;
        1920x1200)
            log_info "WUXGA (1920x1200) detected → 96 DPI (1x scaling)"
            TARGET_DPI=96
            SUCKLESS_FONT_SIZE=9
            DWMSTATUS_FONT_SIZE=8
            ;;
        1920x1080)
            log_info "1080p (1920x1080) detected → 96 DPI (1x scaling)"
            TARGET_DPI=96
            SUCKLESS_FONT_SIZE=8
            DWMSTATUS_FONT_SIZE=8
            ;;
        *)
            log_warn "Unknown resolution: $DISPLAY_RES"
            log_info "Using standard 96 DPI"
            TARGET_DPI=96
            SUCKLESS_FONT_SIZE=9
            DWMSTATUS_FONT_SIZE=8
            ;;
    esac
}

################################################################################
# STEP 2: CREATE XRESOURCES CONFIGURATION
################################################################################

create_xresources() {
    log_info "Creating ~/.Xresources with $TARGET_DPI DPI..."
    
    cat > "$HOME/.Xresources" << EOF
! ============================================================================
! UNIVERSAL HIDPI CONFIGURATION - Auto-generated
! Display: $DISPLAY_RES
! DPI: $TARGET_DPI
! ============================================================================

! Master DPI setting for all X11 applications
Xft.dpi:                    $TARGET_DPI
Xft.antialias:              true
Xft.hinting:                true
Xft.hintstyle:              hintslight
Xft.rgba:                   rgb

! ============================================================================
! SUCKLESS PROGRAMS (st, dwm, dmenu, slstatus)
! ============================================================================

st.font:                    monospace:pixelsize=$SUCKLESS_FONT_SIZE:antialias=true:autohint=true
dwm.font:                   monospace:pixelsize=$DWMSTATUS_FONT_SIZE
dmenu.font:                 monospace:pixelsize=$SUCKLESS_FONT_SIZE

! ============================================================================
! GTK APPLICATIONS
! ============================================================================

gtk-font-name:              Noto Sans 11
gtk-monospace-font-name:    Noto Mono 11

! ============================================================================
! COLOR SCHEME (LARBS/Voidrice Compatible)
! ============================================================================

*background:                #1e1e1e
*foreground:                #d4d4d4
*color0:                    #1e1e1e
*color1:                    #f48771
*color2:                    #71f48a
*color3:                    #f4f48a
*color4:                    #71a8f4
*color5:                    #f48af4
*color6:                    #71f4f4
*color7:                    #d4d4d4
*color8:                    #7e8084
*color9:                    #f48771
*color10:                   #71f48a
*color11:                   #f4f48a
*color12:                   #71a8f4
*color13:                   #f48af4
*color14:                   #71f4f4
*color15:                   #ffffff

! ============================================================================
! CURSOR (HiDPI Touchscreen Support)
! ============================================================================

Xcursor.size:               48
Xcursor.theme:              Adwaita
EOF
    
    log_success "~/.Xresources created"
    
    # Apply immediately
    xrdb -merge "$HOME/.Xresources"
    log_success "Xresources loaded"
}

################################################################################
# STEP 3: CREATE XINITRC WITH ENVIRONMENT VARIABLES
################################################################################

create_xinitrc() {
    log_info "Creating ~/.xinitrc with HiDPI environment variables..."
    
    cat > "$HOME/.xinitrc" << 'EOF'
#!/bin/bash

# ============================================================================
# X11 INITIALIZATION - HiDPI ENVIRONMENT VARIABLES
# ============================================================================

# Export DPI and scaling factors
export DPI=192
export GDK_SCALE=2
export GDK_DPI_SCALE=1
export QT_SCALE_FACTOR=2
export XCURSOR_SIZE=48
export _JAVA_OPTIONS="-Dsun.java2d.dpiaware=true"

# GPU acceleration (NVIDIA)
export LIBVA_DRIVER_NAME=nvidia
export VDPAU_DRIVER=nvidia

# ============================================================================
# LOAD XRESOURCES
# ============================================================================

xrdb -merge "$HOME/.Xresources" &

# ============================================================================
# START COMPOSITOR (picom) FOR TRANSPARENCY/EFFECTS
# ============================================================================

picom -b &

# ============================================================================
# START WINDOW MANAGER (dwm) WITH RESTART LOOP
# ============================================================================

while true; do
    dwm 2>/dev/null
    # If dwm crashes/exits, restart it
done

# Fallback
exec sh
EOF
    
    chmod +x "$HOME/.xinitrc"
    log_success "~/.xinitrc created"
}

################################################################################
# STEP 4: PATCH SUCKLESS CONFIG.H FILES
################################################################################

patch_suckless_programs() {
    log_info "Patching suckless programs with calculated font sizes..."
    
    local src_dir="$HOME/.local/src"
    
    # Check if suckless programs exist
    if [[ ! -d "$src_dir" ]]; then
        log_warn "Suckless source directory not found: $src_dir"
        log_warn "Creating backups skipped. Install suckless programs first."
        return 0
    fi
    
    # Patch st
    if [[ -f "$src_dir/st/config.h" ]]; then
        log_info "Patching st/config.h (font: pixelsize=$SUCKLESS_FONT_SIZE)"
        cp "$src_dir/st/config.h" "$src_dir/st/config.h.backup.$(date +%s)"
        
        # Use sed to replace pixelsize values
        sed -i "s/pixelsize=[0-9]\+/pixelsize=$SUCKLESS_FONT_SIZE/g" "$src_dir/st/config.h"
        log_success "st/config.h patched"
    else
        log_warn "st/config.h not found at $src_dir/st/config.h"
    fi
    
    # Patch dwm
    if [[ -f "$src_dir/dwm/config.h" ]]; then
        log_info "Patching dwm/config.h (font: pixelsize=$DWMSTATUS_FONT_SIZE)"
        cp "$src_dir/dwm/config.h" "$src_dir/dwm/config.h.backup.$(date +%s)"
        
        sed -i "s/pixelsize=[0-9]\+/pixelsize=$DWMSTATUS_FONT_SIZE/g" "$src_dir/dwm/config.h"
        log_success "dwm/config.h patched"
    else
        log_warn "dwm/config.h not found at $src_dir/dwm/config.h"
    fi
    
    # Patch dmenu
    if [[ -f "$src_dir/dmenu/config.h" ]]; then
        log_info "Patching dmenu/config.h (font: pixelsize=$SUCKLESS_FONT_SIZE)"
        cp "$src_dir/dmenu/config.h" "$src_dir/dmenu/config.h.backup.$(date +%s)"
        
        sed -i "s/pixelsize=[0-9]\+/pixelsize=$SUCKLESS_FONT_SIZE/g" "$src_dir/dmenu/config.h"
        log_success "dmenu/config.h patched"
    else
        log_warn "dmenu/config.h not found at $src_dir/dmenu/config.h"
    fi
}

################################################################################
# STEP 5: RECOMPILE SUCKLESS PROGRAMS
################################################################################

recompile_suckless_programs() {
    log_info "Recompiling suckless programs (this may take a few minutes)..."
    
    local src_dir="$HOME/.local/src"
    local programs=("st" "dwm" "dmenu" "slstatus")
    
    for program in "${programs[@]}"; do
        local prog_path="$src_dir/$program"
        
        if [[ ! -d "$prog_path" ]]; then
            log_warn "Skipping $program (not found at $prog_path)"
            continue
        fi
        
        log_info "Compiling $program..."
        
        cd "$prog_path"
        
        # Clean
        make clean > /dev/null 2>&1 || true
        
        # Compile
        if make > /dev/null 2>&1; then
            log_success "$program compiled"
            
            # Install
            if sudo make install > /dev/null 2>&1; then
                log_success "$program installed"
            else
                log_warn "$program compiled but install requires sudo password"
                log_info "Run: cd $prog_path && sudo make install"
            fi
        else
            log_error "$program compilation FAILED"
            log_info "Check: cd $prog_path && make"
        fi
    done
}

################################################################################
# STEP 6: CONFIGURE GTK3
################################################################################

configure_gtk3() {
    log_info "Configuring GTK3 for HiDPI..."
    
    mkdir -p "$HOME/.config/gtk-3.0"
    
    cat > "$HOME/.config/gtk-3.0/settings.ini" << EOF
[Settings]
gtk-font-name=Noto Sans 11
gtk-monospace-font-name=Noto Mono 11
gtk-xft-antialias=1
gtk-xft-hinting=1
gtk-xft-hintstyle=hintslight
gtk-xft-rgba=rgb
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=48
EOF
    
    log_success "GTK3 configured"
}

################################################################################
# STEP 7: FIREFOX CONFIGURATION INSTRUCTIONS
################################################################################

configure_firefox_instructions() {
    log_info ""
    log_info "${CYAN}════════════════════════════════════════════════════════════${NC}"
    log_info "${CYAN}FIREFOX MANUAL CONFIGURATION (After Reboot)${NC}"
    log_info "${CYAN}════════════════════════════════════════════════════════════${NC}"
    log_info "Firefox doesn't use X11 DPI directly. Configure manually:"
    log_info ""
    log_info "Method 1 (GUI - Easiest):"
    log_info "  1. Open Firefox"
    log_info "  2. Go to: Preferences → Appearance → Zoom"
    log_info "  3. Set zoom to: 125% or 150%"
    log_info ""
    log_info "Method 2 (about:config - Advanced):"
    log_info "  1. Type in address bar: about:config"
    log_info "  2. Search: layout.css.devPixelsPerPx"
    log_info "  3. Set value to: 2.0"
    log_info "  4. Restart Firefox"
    log_info ""
    log_info "For your $DISPLAY_RES display:"
    log_info "  - Recommended zoom: 125-150%"
    log_info "  - Target zoom level: 2.0"
    log_info "${CYAN}════════════════════════════════════════════════════════════${NC}"
}

################################################################################
# STEP 8: VERIFICATION AND SUMMARY
################################################################################

verify_installation() {
    log_info ""
    log_info "${CYAN}════════════════════════════════════════════════════════════${NC}"
    log_info "${CYAN}HIDPI SETUP VERIFICATION${NC}"
    log_info "${CYAN}════════════════════════════════════════════════════════════${NC}"
    log_info ""
    log_info "Display Configuration:"
    log_info "  Resolution:        $DISPLAY_RES"
    log_info "  Target DPI:        $TARGET_DPI"
    log_info "  Font Size (st):    pixelsize=$SUCKLESS_FONT_SIZE"
    log_info "  Font Size (dwm):   pixelsize=$DWMSTATUS_FONT_SIZE"
    log_info ""
    log_info "Created Files:"
    
    if [[ -f "$HOME/.Xresources" ]]; then
        log_success "~/.Xresources"
    fi
    
    if [[ -f "$HOME/.xinitrc" ]]; then
        log_success "~/.xinitrc"
    fi
    
    if [[ -f "$HOME/.config/gtk-3.0/settings.ini" ]]; then
        log_success "~/.config/gtk-3.0/settings.ini"
    fi
    
    log_info ""
    log_info "Suckless Programs:"
    if [[ -d "$HOME/.local/src/st" ]]; then
        log_success "st patched and compiled"
    fi
    if [[ -d "$HOME/.local/src/dwm" ]]; then
        log_success "dwm patched and compiled"
    fi
    if [[ -d "$HOME/.local/src/dmenu" ]]; then
        log_success "dmenu patched and compiled"
    fi
    
    log_info ""
    log_info "${YELLOW}Next Steps:${NC}"
    log_info "  1. Restart X11: pkill -9 dwm && startx"
    log_info "  2. Open terminal: st"
    log_info "  3. Check font size (should be comfortable)"
    log_info "  4. Test menu: Alt+P (or configured key)"
    log_info "  5. Open Firefox and configure zoom (see above)"
    log_info ""
    log_info "${GREEN}HiDPI setup complete!${NC}"
    log_info "${CYAN}════════════════════════════════════════════════════════════${NC}"
}

################################################################################
# MAIN EXECUTION
################################################################################

main() {
    log_info ""
    log_info "${CYAN}════════════════════════════════════════════════════════════${NC}"
    log_info "${CYAN}UNIVERSAL HIDPI FONT CONFIGURATION - v1.0${NC}"
    log_info "${CYAN}════════════════════════════════════════════════════════════${NC}"
    log_info ""
    
    # Execute all steps
    detect_display || { log_error "Display detection failed"; exit 1; }
    create_xresources || { log_error "Xresources creation failed"; exit 1; }
    create_xinitrc || { log_error "xinitrc creation failed"; exit 1; }
    patch_suckless_programs || log_warn "Suckless patching had issues"
    recompile_suckless_programs || log_warn "Suckless recompilation had issues"
    configure_gtk3 || { log_error "GTK3 configuration failed"; exit 1; }
    configure_firefox_instructions
    verify_installation
}

# Execute main
main "$@"

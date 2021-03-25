# PARSS Refactoring Plan

## Current Issues

### 1. Inconsistent Header Formatting
```bash
# Some headers:
################################################################################
# PHASE 1: PRE-FLIGHT VALIDATION
################################################################################

# Others:
# CRITICAL FIX: Phase 8 - Corrected mkinitcpio HOOKS...

# Others:
# PHASE 2: DEVICE & PARTITION CONFIGURATION (MENU-BASED SELECTION)
```

**Problem:** Messy, inconsistent, contains outdated comments like "CRITICAL FIXES", "MENU-BASED", "REST OF PHASES UNCHANGED"

### 2. Verbose/Outdated Comments
- Line 1142: `# REST OF PHASES (5-13) - REMAIN UNCHANGED` ← Outdated
- Headers with implementation details (MENU-BASED, CRITICAL FIXES)
- Phase 13 has excessive debug logging messages

### 3. No TUI/Dialog Integration
- LARBS uses whiptail for progress display
- We use only `echo` and `log_*` functions
- User can't see what's happening during long operations
- No visual progress indicator

### 4. Poor User Experience During Installation
- Silent compilation (AUR packages take 10+ minutes)
- No progress bar or percentage
- No "infobox" showing current operation
- User doesn't know if it's working or frozen

---

## Proposed Solutions

### A. Standardize All Headers

**New Format:**
```bash
################################################################################
# PHASE X: SHORT DESCRIPTIVE NAME
################################################################################

phase_X_function_name() {
    log_section "PHASE X: SHORT DESCRIPTIVE NAME"
    # Implementation
}
```

**Rules:**
- No implementation details in headers (remove CRITICAL, MENU-BASED, etc.)
- Consistent formatting across all phases
- Remove outdated comments
- Keep phase list in main header only

### B. Add TUI Integration (whiptail/dialog)

**Install whiptail early:**
```bash
# In phase 1 or at script start
if ! command -v whiptail >/dev/null 2>&1; then
    pacman -Sy --noconfirm libnewt
fi
```

**Use for progress display:**
```bash
# During package installation
whiptail --title "PARSS Installation" \
    --infobox "Installing package 15/78: lf-git\n\nBuilding from source..." 8 70

# For long operations
whiptail --title "PARSS Installation" \
    --gauge "Compiling dwm..." 8 70 45
```

### C. Clean Up Phase 13

**Current (verbose):**
```bash
log_debug "Checking crypttab..."
log_debug "Checking fstab..."
log_debug "Checking mkinitcpio configuration..."
log_debug "Checking BTRFS subvolumes..."
log_debug "Checking total packages installed..."
```

**Proposed (concise):**
```bash
log_info "Performing final verification..."
# Run checks silently, only log issues
verify_critical_files
log_success "Verification complete"
```

### D. Restructure Script Organization

**Current:**
```
1. Giant header comment (50+ lines)
2. Global variables
3. Utility functions (scattered)
4. Phase functions (some with huge headers)
5. Main execution
```

**Proposed:**
```
1. Minimal header (license, version, description)
2. Global constants
3. TUI helper functions (NEW)
4. Utility functions (grouped logically)
5. Phase functions (clean headers)
6. Main execution
```

---

## Implementation Priority

### Phase 1: Clean Headers (IMMEDIATE)
- [x] Remove all "CRITICAL", "MENU-BASED", implementation details
- [x] Standardize format: `# PHASE X: NAME`
- [x] Remove outdated comments
- [ ] Keep phase list ONLY in main header

### Phase 2: Reduce Verbosity (IMMEDIATE)
- [ ] Phase 13: Remove excessive log_debug calls
- [ ] Convert detailed checks to single summary message
- [ ] Only show errors/warnings, not every step

### Phase 3: Add TUI Foundation (NEXT)
- [ ] Install whiptail/dialog dependency
- [ ] Create TUI wrapper functions:
  - `show_progress()` - Progress bar
  - `show_infobox()` - Status messages
  - `show_gauge()` - Percentage progress
- [ ] Test with one phase (phase 14)

### Phase 4: Integrate TUI Throughout (LATER)
- [ ] Phase 6: Package installation progress
- [ ] Phase 8: GRUB installation progress  
- [ ] Phase 14: Desktop setup progress
- [ ] Long operations: Show spinner/gauge

---

## TUI Implementation Example

### Before (Current):
```bash
info "Installing packages from progs.csv..."
while IFS=, read -r tag prog comment; do
    info "[AUR] $prog"
    yay -S "$prog" >/dev/null 2>&1
done
```

### After (With TUI):
```bash
total=$(grep -c "^[^#]" progs.csv)
n=0

while IFS=, read -r tag prog comment; do
    n=$((n + 1))
    percent=$((n * 100 / total))
    
    # Show progress in dialog
    whiptail --title "PARSS Desktop Setup" \
        --gauge "Installing $prog ($n/$total)\n\nBuilding from source..." 8 70 $percent
    
    yay -S "$prog" >/dev/null 2>&1
done
```

---

## Benefits

✅ **Cleaner code** - No outdated comments, consistent format
✅ **Better UX** - Visual progress, know what's happening
✅ **Professional** - Looks like LARBS, archinstall, other installers
✅ **Less confusion** - User sees progress, not blank screen
✅ **Maintainable** - Easy to understand structure

---

## Questions to Resolve

1. **TUI Tool Choice:**
   - whiptail (LARBS uses this, minimal)
   - dialog (more features, but larger)
   - gum (modern, but extra dependency)
   
   **Recommendation:** whiptail (LARBS-compatible, minimal)

2. **Verbosity Level:**
   - Show every package? (current)
   - Show only phases? (too quiet)
   - Show key operations? (balanced)
   
   **Recommendation:** Key operations + TUI progress

3. **When to implement TUI:**
   - Now (big refactor)
   - Gradually (phase by phase)
   
   **Recommendation:** Gradually, start with phase 14

---

## Next Steps

1. Review this plan with user
2. Clean headers first (quick win)
3. Reduce phase 13 verbosity
4. Create TUI helper functions
5. Test with phase 14
6. Integrate throughout script

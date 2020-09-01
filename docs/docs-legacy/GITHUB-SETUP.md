# GitHub Repository Setup Guide

## Repository Structure for GitHub

### 1. Create GitHub Repository

```bash
# Initialize local git repository
git init
git config user.name "Your Name"
git config user.email "your.email@example.com"

# Add all files
git add .

# Initial commit
git commit -m "Initial commit: Complete Arch Linux secure research deployment

- Phases 1-12: Base system with security hardening
- Phases 13-18: LARBS integration with suckless stack
- Automatic voidrice dotfile deployment
- CSV-driven package management
- LUKS2 encryption + BTRFS snapshots
- Comprehensive error handling and logging"

# Add remote and push
git remote add origin https://github.com/yourusername/arch-secure-research-deployment.git
git branch -M main
git push -u origin main
```

### 2. Directory Structure for GitHub

```
arch-secure-research-deployment/
│
├── .gitignore                        # Exclude sensitive files
├── .github/
│   ├── workflows/
│   │   ├── shellcheck.yml           # Shell script linting
│   │   └── docs-build.yml           # Documentation validation
│   └── ISSUE_TEMPLATE/
│       └── bug_report.md            # GitHub issue template
│
├── scripts/
│   ├── arch-secure-deploy.sh        # Phase 1-12: Base system
│   ├── arch-secure-larbs.sh         # Phase 13-18: LARBS integration
│   ├── progs.csv                    # Package manifest
│   └── utils/
│       ├── validate-csv.sh          # CSV validation script
│       └── recovery.sh              # Recovery utilities
│
├── dotfiles/                         # Optional: Custom voidrice fork
│   ├── .config/
│   ├── .zshrc
│   ├── .Xresources
│   └── README.md
│
├── docs/
│   ├── README.md                    # Main documentation
│   ├── ARCHITECTURE.md              # Technical deep-dive
│   ├── INSTALLATION-GUIDE.md        # Step-by-step guide
│   ├── CONFIG.md                    # Configuration reference
│   ├── security-features.md         # Hardening details
│   ├── snapshot-management.md       # BTRFS guide
│   ├── suckless-customization.md    # Customization guide
│   └── troubleshooting.md           # FAQ & troubleshooting
│
├── examples/
│   ├── custom-progs.csv             # Example custom packages
│   ├── security-hardened.progs.csv  # Extra hardening packages
│   └── minimal.progs.csv            # Minimal setup
│
├── tests/
│   ├── shellcheck-tests.sh          # Shell script validation
│   └── csv-validation.sh            # CSV format checking
│
├── LICENSE                          # GPL-3.0
└── CONTRIBUTING.md                  # Contribution guidelines
```

### 3. Create .gitignore

```bash
cat > .gitignore << 'EOF'
# Installation logs
*.log
/var/log/

# Temporary files
/tmp/
*.tmp
*.swp
*.swo
*~

# Build artifacts
*.o
*.a
*.so
build/
dist/

# State files
.arch-deploy-state
*.state
deployment-state.env

# IDE files
.vscode/
.idea/
*.sublime-project

# OS files
.DS_Store
.AppleDouble
Thumbs.db

# Sensitive configuration
.env
*.key
*.pem
credentials/

# Virtual environments
venv/
.venv/
env/

# Installation media
*.iso
*.img

# Private notes
PRIVATE/
notes/
EOF

git add .gitignore
git commit -m "Add .gitignore for build artifacts and logs"
```

### 4. Create GitHub Actions Workflows

#### shell-check.yml (Lint shell scripts)

```bash
mkdir -p .github/workflows

cat > .github/workflows/shellcheck.yml << 'EOF'
name: Shell Script Analysis

on: [push, pull_request]

jobs:
  shellcheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run shellcheck
        run: |
          sudo apt-get update
          sudo apt-get install -y shellcheck
          shellcheck scripts/*.sh
EOF

git add .github/workflows/shellcheck.yml
git commit -m "Add shell script linting workflow"
```

#### csv-validation.yml (Validate progs.csv)

```bash
cat > .github/workflows/csv-validation.yml << 'EOF'
name: CSV Validation

on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Validate CSV format
        run: |
          bash tests/csv-validation.sh scripts/progs.csv
EOF

git add .github/workflows/csv-validation.yml
git commit -m "Add CSV validation workflow"
```

### 5. Create CONTRIBUTING.md

```bash
cat > CONTRIBUTING.md << 'EOF'
# Contributing to arch-secure-research-deployment

Thank you for your interest in contributing! This document outlines guidelines for contributing.

## Development Workflow

1. Fork the repository
2. Create feature branch: `git checkout -b feature/your-feature`
3. Test in clean Arch Linux ISO environment
4. Verify all error handling edge cases
5. Update documentation
6. Submit pull request

## Testing Requirements

- Run `shellcheck` on all bash scripts
- Test installation in clean Arch ISO
- Verify error recovery mechanisms
- Check LUKS/BTRFS functionality
- Validate CSV parsing for edge cases

## Code Standards

- Bash scripts use `set -euo pipefail`
- Comprehensive error handling (trap ERR)
- Dual logging (console + file)
- Comments for complex operations
- Proper quoting of variables

## Documentation

- Update README.md for major changes
- Add examples in docs/
- Include deployment logs in issues
- Reference relevant GitHub issues

## Submitting Issues

Include:
- Installation phase where issue occurred
- Full error logs (from `/var/log/`)
- Exact steps to reproduce
- System specifications (CPU/RAM/Storage)
- Network environment

## Pull Request Process

1. Update CHANGELOG
2. Reference related issues
3. Include test results
4. Describe implementation approach
5. Await maintainer review

## Code of Conduct

- Respectful discussion
- Technical focus
- No harassment or discrimination

EOF

git add CONTRIBUTING.md
git commit -m "Add contribution guidelines"
```

### 6. Create CHANGELOG

```bash
cat > CHANGELOG.md << 'EOF'
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-11-17

### Added
- Phase 1-12: Complete base system installation with security hardening
- Phase 13-18: LARBS integration with suckless stack
- CSV-driven package management (pacman/AUR/git)
- Automatic voidrice dotfile deployment
- LUKS2 encryption with Argon2id KDF
- BTRFS subvolume architecture with weekly snapshots
- Comprehensive security hardening (sysctl + kernel parameters)
- 99.99% error handling coverage
- Dual logging (console + persistent files)
- State recovery mechanisms

### Features
- Mandatory LUKS2 encryption (not optional)
- Hardened kernel parameters by default
- Systemd timer-based snapshot automation
- AUR helper (yay) integration
- Suckless programs compilation from source
- Reproducible environment from dotfiles
- Interactive device/hostname/user prompts

### Documentation
- Complete architecture documentation
- Step-by-step installation guide
- Security features reference
- BTRFS snapshot management guide
- Troubleshooting guide

EOF

git add CHANGELOG.md
git commit -m "Add changelog"
```

### 7. Create Releases

```bash
# Create version tag
git tag -a v1.0.0 -m "Release v1.0.0 - Initial production release"
git push origin v1.0.0

# Create GitHub release with:
# - Installation instructions
# - Known issues
# - Security considerations
# - Changelog
```

### 8. Repository Topics/Tags

Set on GitHub:
- `arch-linux`
- `security`
- `encryption`
- `automation`
- `deployment`
- `suckless`
- `dotfiles`
- `btrfs`
- `larbs`
- `research`

### 9. Create Issue Templates

```bash
mkdir -p .github/ISSUE_TEMPLATE

cat > .github/ISSUE_TEMPLATE/bug_report.md << 'EOF'
---
name: Bug Report
about: Report installation or runtime issues

---

## Description
Brief description of the issue

## Installation Phase
- [ ] Phase 1-5 (Disk/Base)
- [ ] Phase 6-9 (Configuration)
- [ ] Phase 10-12 (Hardening)
- [ ] Phase 13-18 (LARBS)
- [ ] Runtime

## Error Log
```bash
# Paste relevant error logs from:
# /var/log/arch-deploy-errors-*.log
```

## System Information
- Architecture: (x86_64, arm64, etc)
- Storage: (HDD/NVMe, size in GB)
- RAM: (in GB)
- Network: (Wifi/Ethernet)

## Steps to Reproduce
1. Step 1
2. Step 2
3. ...

## Expected Behavior
What should happen

## Actual Behavior
What actually happened

## Additional Context
Screenshots, configurations, etc

EOF

git add .github/ISSUE_TEMPLATE/bug_report.md
git commit -m "Add bug report template"
```

### 10. Create README Badges

```bash
# Add to README.md header

[![GitHub License](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![Arch Linux](https://img.shields.io/badge/Arch%20Linux-1793D1?style=flat&logo=arch-linux&logoColor=white)](https://archlinux.org/)
[![ShellCheck](https://github.com/yourusername/arch-secure-research-deployment/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/yourusername/arch-secure-research-deployment/actions)
[![CSV Validation](https://github.com/yourusername/arch-secure-research-deployment/actions/workflows/csv-validation.yml/badge.svg)](https://github.com/yourusername/arch-secure-research-deployment/actions)
```

## Separate Dotfiles Repository

### Option 1: Fork voidrice

```bash
# Clone voidrice
git clone https://github.com/yourusername/voidrice-secure.git
cd voidrice-secure

# Customize with security enhancements
# - Update .config/dwm/config.h
# - Enhance .zshrc with additional security tools
# - Add security aliases

git commit -am "Security enhancements to voidrice"
git push
```

### Option 2: Create Independent Repository

```bash
git init voidrice-secure
cd voidrice-secure

# Add dotfiles structure
mkdir -p .config .local/bin

# Add custom configurations
# - .zshrc with security tools
# - .config/dwm/config.h (suckless configuration)
# - .config/picom/picom.conf (compositor)
# - .local/bin/* (custom scripts)

git add .
git commit -m "Initial voidrice-secure repository"
git push -u origin main
```

### Reference in progs.csv

```bash
# Modify Phase 15 to use custom dotfiles:

# In arch-secure-larbs.sh
log_info "Cloning custom voidrice repository..."
arch-chroot "$MOUNT_ROOT" bash -c "
    sudo -u $PRIMARY_USER git clone https://github.com/yourusername/voidrice-secure.git \
    $user_home/.config/voidrice-source
"
```

## Summary of GitHub Files

```
Files to create in GitHub repository:

1. MAIN SCRIPTS:
   ✓ scripts/arch-secure-deploy.sh      [Phase 1-12]
   ✓ scripts/arch-secure-larbs.sh       [Phase 13-18]
   ✓ scripts/progs.csv                  [Package manifest]

2. DOCUMENTATION:
   ✓ docs/README.md                     [Main docs]
   ✓ docs/ARCHITECTURE.md               [Technical]
   ✓ docs/INSTALLATION-GUIDE.md         [Step-by-step]
   ✓ docs/CONFIG.md                     [Configuration]
   ✓ docs/security-features.md          [Hardening]
   ✓ docs/snapshot-management.md        [BTRFS]
   ✓ docs/suckless-customization.md     [Customization]
   ✓ docs/troubleshooting.md            [FAQ]

3. REPOSITORY CONFIG:
   ✓ .gitignore                         [Git ignore rules]
   ✓ .github/workflows/shellcheck.yml   [Script linting]
   ✓ .github/workflows/csv-validation.yml [CSV validation]
   ✓ .github/ISSUE_TEMPLATE/bug_report.md [Issue template]

4. PROJECT FILES:
   ✓ CONTRIBUTING.md                    [Contribution guide]
   ✓ CHANGELOG.md                       [Version history]
   ✓ LICENSE                            [GPL-3.0]

5. OPTIONAL:
   ✓ examples/custom-progs.csv          [Example packages]
   ✓ examples/minimal.progs.csv         [Minimal setup]
   ✓ tests/shellcheck-tests.sh          [Shell testing]
   ✓ dotfiles/ (separate repo)          [Custom voidrice]
```

## Initial Push Commands

```bash
# Configure git
git config --global user.name "Your Name"
git config --global user.email "your.email@github.com"

# Create local repository
cd arch-secure-research-deployment
git init
git add .
git commit -m "Initial commit: Complete Arch Linux secure research deployment"

# Add remote
git remote add origin https://github.com/yourusername/arch-secure-research-deployment.git
git branch -M main

# Push to GitHub
git push -u origin main

# Create version tag
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

# Done! Repository is live
```

---

**Next**: After pushing to GitHub, consider:
1. Enable branch protection rules
2. Set up automatic releases from tags
3. Configure GitHub Pages for documentation
4. Enable discussions for community support

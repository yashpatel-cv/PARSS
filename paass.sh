!#bin/sh
# Patel's Arch Auto Setup Script (PAASS)
# by Yash Patel <yash@patel.host>
# License: MIT

# Purpose of this script is to get Arch installation done ASAP

### VARIABLES ###

# Current Script Name
PAASS="Patel's Arch Auto Setup Script" 


### FUNCTIONS ###

# Static command for installing every package from Arch repository
install() { pacman --noconfirm --needed -S "$1" >/dev/null 2>&1 ; }

# Handling each error thrown in later commands
error() { printf "%s\n" "$1" >&2; exit 1; }

getstarted() { \
	dialog  --backtitle "$PAASS" \
		--title "Welcome to PAASS!" \
		--msgbox "Welcome to $PAASS!\\n\\nThis script will automatically install a fully-featured Arch desktop, which I use as myself for both work and daily purposes." 10 60
}




### THE ACTUAL SCRIPT ###

### This is how everything happens in an intuitive format and order

# Make sure user has root previliges on Arch and if so Install dialog.
pacman --noconfirm --needed -Sy dialog || error "Please make sure that you are running PAASS as root user, are on Arch-based (Preferred Pure Arch) distro, and have an internet connection?" 

# Welcome the User and Get started
getstarted || error "User exited."


clear

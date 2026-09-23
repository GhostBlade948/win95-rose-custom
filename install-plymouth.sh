#!/bin/sh
# Install the Windows 95 boot splash, or put the previous one back. Needs root.
#
#   install-plymouth.sh [SPLASH.png]   install, optionally with a splash image
#   install-plymouth.sh --reset        restore the previous theme
#   install-plymouth.sh --preview      show the splash now, without rebooting
#
# The theme is registered with update-alternatives, which is how Debian and
# Ubuntu pick the default, and then baked into the initramfs, since the splash
# runs long before the root filesystem is mounted.
set -eu

THEME=win95-rose-custom
SRCDIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SRC="$SRCDIR/Plymouth/$THEME"
DEST=/usr/share/plymouth/themes/$THEME
LINK=/usr/share/plymouth/themes/default.plymouth
PREVIOUS=/usr/share/plymouth/themes/mint-logo/mint-logo.plymouth

mode=install
case "${1:-}" in
--reset)   mode=reset ;;
--preview) mode=preview ;;
esac

# ------------------------------------------------------------------- preview
# Deliberately before the root check: the preview only talks to plymouthd.
if [ "$mode" = preview ]; then
	if [ ! -d "$DEST" ]; then
		echo "$THEME is not installed yet; run this without --preview first."
		exit 1
	fi
	echo "Showing the splash for 10 seconds. It draws on the console, so switch"
	echo "to a text console (Ctrl+Alt+F3) to see it, then come back (Ctrl+Alt+F7)."
	plymouthd --tty=/dev/tty3 || :
	plymouth --show-splash || :
	i=0
	while [ $i -lt 10 ]; do
		plymouth --update=test >/dev/null 2>&1 || :
		sleep 1
		i=$((i + 1))
	done
	plymouth --quit || :
	exit 0
fi

if [ "$(id -u)" -ne 0 ]; then
	echo "This needs root: run it with sudo or pkexec."
	exit 1
fi

# --------------------------------------------------------------------- reset
if [ "$mode" = reset ]; then
	if [ -f "$PREVIOUS" ]; then
		update-alternatives --set default.plymouth "$PREVIOUS"
		echo "Set the boot splash back to mint-logo."
	fi
	update-alternatives --remove default.plymouth "$DEST/$THEME.plymouth" 2>/dev/null || :
	rm -rf "$DEST"
	update-initramfs -u
	echo "Removed. The old splash is back at the next boot."
	exit 0
fi

# ------------------------------------------------------------------- install
if [ ! -d "$SRC" ]; then
	echo "$SRC not found."
	exit 1
fi

rm -rf "$DEST"
mkdir -p "$DEST"
cp -a "$SRC"/. "$DEST"/

# A splash image given on the command line wins over one sitting in the theme.
if [ -n "${1:-}" ] && [ "$1" != --reset ] && [ "$1" != --preview ]; then
	if [ ! -f "$1" ]; then
		echo "$1 not found."
		exit 1
	fi
	cp "$1" "$DEST/splash.png"
	echo "Using $1 as the splash image."
fi

if [ ! -f "$DEST/splash.png" ]; then
	echo "No splash.png: the splash will be the sky gradient and the progress"
	echo "bar only. Put one at $SRC/splash.png, or pass one as an argument."
fi

chmod 0755 "$DEST"
find "$DEST" ! -type d -exec chmod 0644 {} +

# update-alternatives owns default.plymouth on Debian and Ubuntu; writing the
# symlink by hand would be undone the next time anything else touched it.
update-alternatives --install "$LINK" default.plymouth "$DEST/$THEME.plymouth" 150
update-alternatives --set default.plymouth "$DEST/$THEME.plymouth"

# The splash runs from the initramfs, so the theme has to be copied into it.
update-initramfs -u

echo "Installed. Reboot to see it."
echo "Check it first with: sh $SRCDIR/install-plymouth.sh --preview"

#!/bin/sh
# Turn the shell into an MS-DOS one: the Windows 95 startup banner, the
# C:\> prompt, and fastfetch if it is installed.
#
#   shell-setup.sh                 add it to ~/.bashrc
#   shell-setup.sh --no-fastfetch  the same, without running fastfetch
#   shell-setup.sh --reset         take it back out
#
# Extras/DOSrc is copied to ~/.config/win95-rose-custom so the line in .bashrc
# does not break if this repository is moved or deleted.
set -eu

THEME=win95-rose-custom
SRCDIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CONFDIR="$HOME/.config/$THEME"
BASHRC="$HOME/.bashrc"
FFSRC="$SRCDIR/Extras/fastfetch/config.jsonc"
FFCONF="$HOME/.config/fastfetch/config.jsonc"
BEGIN="# >>> $THEME >>>"
END="# <<< $THEME <<<"

reset=no
fastfetch=yes
for arg in "$@"; do
	case "$arg" in
	--reset) reset=yes ;;
	--no-fastfetch) fastfetch=no ;;
	*) echo "Unknown option: $arg"; exit 1 ;;
	esac
done

if [ ! -f "$BASHRC" ]; then
	echo "$BASHRC not found; nothing to do."
	exit 0
fi

# Drop any block we added before, so this is repeatable and --reset is just
# this step on its own.
if grep -qF "$BEGIN" "$BASHRC"; then
	tmp=$(mktemp)
	awk -v b="$BEGIN" -v e="$END" '
		index($0, b) { skip = 1 }
		!skip { print }
		index($0, e) { skip = 0 }
	' "$BASHRC" > "$tmp"
	cat "$tmp" > "$BASHRC"
	rm -f "$tmp"
	[ "$reset" = yes ] && echo "Removed the $THEME block from $BASHRC"
fi

if [ "$reset" = yes ]; then
	rm -f "$CONFDIR/DOSrc"
	rmdir "$CONFDIR" 2>/dev/null || :
	# Only our own fastfetch config is removed; one you wrote is left alone.
	if [ -f "$FFCONF" ] && grep -q "$THEME" "$FFCONF"; then
		rm -f "$FFCONF"
		if [ -f "$FFCONF.bak" ]; then
			mv "$FFCONF.bak" "$FFCONF"
			echo "Restored your previous fastfetch config."
		else
			rmdir "$(dirname "$FFCONF")" 2>/dev/null || :
		fi
	fi
	echo "Open a new terminal to get your old prompt back."
	exit 0
fi

if [ ! -f "$SRCDIR/Extras/DOSrc" ]; then
	echo "$SRCDIR/Extras/DOSrc not found; nothing to install."
	exit 1
fi

mkdir -p "$CONFDIR"
cp "$SRCDIR/Extras/DOSrc" "$CONFDIR/DOSrc"

# fastfetch reads this wherever it is run from, so `fastfetch` typed by hand
# shows the Windows 95 flag too, not just the line added to .bashrc below.
if [ "$fastfetch" = yes ] && [ -f "$FFSRC" ]; then
	mkdir -p "$(dirname "$FFCONF")"
	if [ -f "$FFCONF" ] && ! grep -q "$THEME" "$FFCONF"; then
		mv "$FFCONF" "$FFCONF.bak"
		echo "Moved your existing fastfetch config to $FFCONF.bak"
	fi
	cp "$FFSRC" "$FFCONF"
fi

# The block is guarded on an interactive shell: DOSrc prints a banner and sets
# PS1, and output from a non-interactive shell breaks scp and rsync.
{
	echo "$BEGIN"
	echo "case \$- in *i*)"
	echo "	. \"\$HOME/.config/$THEME/DOSrc\""
	if [ "$fastfetch" = yes ]; then
		echo "	command -v fastfetch >/dev/null 2>&1 && fastfetch"
	fi
	echo "esac"
	echo "$END"
} >> "$BASHRC"

echo "Added the MS-DOS prompt to $BASHRC"
[ "$fastfetch" = yes ] && command -v fastfetch >/dev/null 2>&1 ||
	echo "fastfetch is not installed; run install-deps.sh for it."
echo "Open a new terminal to see it."

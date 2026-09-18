#!/bin/sh
# Make the login screen and root applications (pkexec, Timeshift) use the
# theme's cursor. They do not read your session settings: X falls back to
# icons/default, and the greeter reads its own config file. Needs root.
#
#   system-cursor.sh [--reset] [DESTDIR]
set -eu

CURSOR=Chicago95_Cursor_White
SIZE=24

reset=no
if [ "${1:-}" = --reset ]; then reset=yes; shift; fi
DESTDIR=${1:-}

default_theme="$DESTDIR/usr/share/icons/default/index.theme"
greeter_conf="$DESTDIR/etc/lightdm/slick-greeter.conf"

# ---------------------------------------------------- X fallback cursor theme
if [ "$reset" = yes ]; then
	if [ -f "$default_theme.bak" ]; then
		mv "$default_theme.bak" "$default_theme"
		echo "Restored $default_theme"
	elif [ -f "$default_theme" ] && grep -q "$CURSOR" "$default_theme"; then
		# No original to restore: the file was ours.
		rm -f "$default_theme"
		echo "Removed $default_theme"
	fi
else
	mkdir -p "$(dirname "$default_theme")"
	# A file already naming our cursor is one an earlier install wrote, not the
	# original; backing it up would make --reset put our cursor back.
	if [ -f "$default_theme" ] && [ ! -f "$default_theme.bak" ] &&
	   ! grep -q "$CURSOR" "$default_theme"; then
		cp -p "$default_theme" "$default_theme.bak"
		echo "Saved the previous $default_theme as $default_theme.bak"
	fi
	cat > "$default_theme" <<EOF
[Icon Theme]
Name=Default
Comment=Default cursor theme
Inherits=$CURSOR
EOF
	echo "Set the system cursor default to $CURSOR"
fi

# ----------------------------------------------------------- slick-greeter
# Only touch the greeter Linux Mint actually uses.
if [ ! -x "$DESTDIR/usr/sbin/slick-greeter" ] && [ ! -f "$DESTDIR/usr/share/xgreeters/slick-greeter.desktop" ]; then
	echo "slick-greeter not installed; left the greeter config alone."
	exit 0
fi

if [ "$reset" = yes ]; then
	if [ -f "$greeter_conf.bak" ]; then
		mv "$greeter_conf.bak" "$greeter_conf"
		echo "Restored $greeter_conf"
	elif [ -f "$greeter_conf" ]; then
		# The file was ours; drop just the keys we added.
		tmp=$(mktemp)
		grep -v '^cursor-theme-\(name\|size\)=' "$greeter_conf" > "$tmp"
		# Nothing but the section header left? Remove the file.
		if [ "$(grep -vc '^\[Greeter\]$\|^[[:space:]]*$' "$tmp")" -eq 0 ]; then
			rm -f "$greeter_conf" "$tmp"
		else
			cat "$tmp" > "$greeter_conf"; rm -f "$tmp"
		fi
		echo "Removed the cursor setting from the greeter config."
	fi
	exit 0
fi

mkdir -p "$(dirname "$greeter_conf")"
if [ ! -f "$greeter_conf" ]; then
	printf '[Greeter]\ncursor-theme-name=%s\ncursor-theme-size=%s\n' "$CURSOR" "$SIZE" > "$greeter_conf"
else
	# As above: if the file already has our cursor, an earlier install created or
	# edited it, and the original (if there was one) is already in the .bak.
	if [ ! -f "$greeter_conf.bak" ] && ! grep -q "^cursor-theme-name=$CURSOR\$" "$greeter_conf"; then
		cp -p "$greeter_conf" "$greeter_conf.bak"
	fi
	tmp=$(mktemp)
	if grep -q '^\[Greeter\]' "$greeter_conf"; then
		awk -v t="$CURSOR" -v s="$SIZE" '
			/^[[:space:]]*cursor-theme-(name|size)[[:space:]]*=/ { next }
			{ print }
			/^\[Greeter\]/ { print "cursor-theme-name=" t; print "cursor-theme-size=" s }
		' "$greeter_conf" > "$tmp"
	else
		{ cat "$greeter_conf"; printf '\n[Greeter]\ncursor-theme-name=%s\ncursor-theme-size=%s\n' "$CURSOR" "$SIZE"; } > "$tmp"
	fi
	cat "$tmp" > "$greeter_conf"; rm -f "$tmp"
fi
chmod 0644 "$greeter_conf"
echo "Set the login screen cursor to $CURSOR"

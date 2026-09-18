#!/bin/sh
# Switch the current user's Cinnamon desktop to win95-rose-custom, or back.
# Called by the Makefile; can also be run by hand.
#
#   apply-settings.sh THEME_DIR WALLPAPER   apply the theme and wallpaper
#   apply-settings.sh --reset               restore the Cinnamon defaults
set -eu

THEME=win95-rose-custom
CSS="$HOME/.config/gtk-4.0/gtk.css"
CURSOR=Chicago95_Cursor_White
USERCURSOR="$HOME/.icons/default/index.theme"

# gsettings needs the session bus; under sudo it is not in the environment.
if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] && [ -S "/run/user/$(id -u)/bus" ]; then
	DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
	export DBUS_SESSION_BUS_ADDRESS
fi

if ! command -v gsettings >/dev/null 2>&1 ||
   ! gsettings list-schemas | grep -qx org.cinnamon.theme; then
	echo "Cinnamon settings not found; choose the theme by hand in System Settings."
	exit 0
fi

if [ "${1:-}" = --reset ]; then
	gsettings reset org.cinnamon.theme name
	gsettings reset org.cinnamon.desktop.interface gtk-theme
	gsettings reset org.cinnamon.desktop.interface icon-theme
	gsettings reset org.cinnamon.desktop.interface cursor-theme
	gsettings reset org.cinnamon.desktop.wm.preferences theme
	case "$(gsettings get org.cinnamon.desktop.background picture-uri)" in
	*"$THEME"*)
		gsettings reset org.cinnamon.desktop.background picture-uri
		gsettings reset org.cinnamon.desktop.background picture-options ;;
	esac
	if [ -f "$USERCURSOR" ] && grep -q "$CURSOR" "$USERCURSOR"; then
		rm -f "$USERCURSOR"
		[ -f "$USERCURSOR.bak" ] && mv "$USERCURSOR.bak" "$USERCURSOR"
	fi
	if [ -f "$CSS" ] && grep -q "$THEME" "$CSS"; then
		rm -f "$CSS"
		[ -f "$CSS.bak" ] && mv "$CSS.bak" "$CSS"
	fi
	echo "Restored the default Cinnamon theme."
	exit 0
fi

theme_dir=$1
wallpaper=$2

gsettings set org.cinnamon.theme name "$THEME"
gsettings set org.cinnamon.desktop.interface gtk-theme "$THEME"
gsettings set org.cinnamon.desktop.wm.preferences theme "$THEME"
gsettings set org.cinnamon.desktop.interface icon-theme Chicago95
gsettings set org.cinnamon.desktop.interface cursor-theme Chicago95_Cursor_White

if [ -f "$wallpaper" ]; then
	gsettings set org.cinnamon.desktop.background picture-uri "file://$wallpaper"
	gsettings set org.cinnamon.desktop.background picture-options zoom
fi

# Applications that ask X for the cursor rather than reading the theme setting.
mkdir -p "$(dirname "$USERCURSOR")"
if [ -f "$USERCURSOR" ] && ! grep -q "$CURSOR" "$USERCURSOR"; then
	cp -p "$USERCURSOR" "$USERCURSOR.bak"
fi
cat > "$USERCURSOR" <<CURSOREOF
[Icon Theme]
Name=Default
Comment=Default cursor theme
Inherits=$CURSOR
CURSOREOF

# libadwaita applications ignore the theme setting but load this file.
mkdir -p "$(dirname "$CSS")"
if [ -f "$CSS" ] && ! grep -q "$THEME" "$CSS"; then
	mv "$CSS" "$CSS.bak"
	echo "Moved your existing $CSS to $CSS.bak"
fi
cat > "$CSS" <<EOF
/* $THEME: libadwaita applications ignore the theme setting but do
   load this file. Delete it if you switch to an unrelated theme. */
@import url("file://$theme_dir/gtk-4.0/gtk.css");
EOF

echo "Applied $THEME. Restart open applications to restyle them."

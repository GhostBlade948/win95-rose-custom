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

# The menu applet: the Start button. Its icon and text are applet settings
# rather than theme properties, so they live in the applet's own config file.
MENUDIR="$HOME/.config/cinnamon/spices/menu@cinnamon.org"
MENUICON=start-here
MENULABEL=Start
MENUICONSIZE=22

# Set or restore the menu applet's icon and label. The original values are kept
# next to the config as .bak, and only those keys are put back on a reset, so
# anything else changed in the applet's settings meanwhile is left alone.
menu_button() {
	[ -d "$MENUDIR" ] || return 0
	if ! command -v python3 >/dev/null 2>&1; then
		echo "python3 not found; set the menu icon and text by hand in the applet settings."
		return 0
	fi
	python3 - "$1" "$MENUDIR" "$MENUICON" "$MENULABEL" "$MENUICONSIZE" <<'PYEOF'
import glob, json, os, shutil, sys

mode, confdir, icon, label, size = sys.argv[1:6]
wanted = {"menu-custom": True, "menu-icon": icon,
          "menu-label": label, "menu-icon-size": int(size)}
changed = False

for path in sorted(glob.glob(os.path.join(confdir, "*.json"))):
    with open(path) as fh:
        conf = json.load(fh)
    # Not a menu applet instance we recognise; leave it untouched.
    if not all(key in conf for key in wanted):
        continue
    bak = path + ".bak"

    if mode == "reset":
        if not os.path.exists(bak):
            continue
        with open(bak) as fh:
            old = json.load(fh)
        for key in wanted:
            if key in old and "value" in old[key]:
                conf[key]["value"] = old[key]["value"]
    else:
        if not os.path.exists(bak):
            shutil.copy2(path, bak)
        for key, value in wanted.items():
            conf[key]["value"] = value

    with open(path, "w") as fh:
        json.dump(conf, fh, indent=4)
    if mode == "reset":
        os.remove(bak)
    changed = True

if changed:
    print("Restored the menu button." if mode == "reset"
          else "Set the menu button to the %s icon with the text %r." % (icon, label))
PYEOF
}

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
	menu_button reset
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

menu_button apply

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

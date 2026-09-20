#!/bin/sh
# Give Wine and Proton windows the theme's colours.
#
#   wine-colors.sh          apply to every prefix found
#   wine-colors.sh --list   show the prefixes, change nothing
#   wine-colors.sh --reset  restore the originals
#
# Wine draws its own titlebars, buttons and menus rather than asking the window
# manager or GTK, so neither the desktop theme nor the metacity frame reaches a
# game running under it. The colours come from Control Panel\Colors in each
# prefix's registry instead, which is what this edits.
#
# Close Steam and any Wine programs first: a running prefix holds the registry
# in memory and writes it back out on exit, discarding anything changed here.
set -eu

THEME=win95-rose-custom
ACTIVE_TITLE="163 69 69"

mode=apply
case "${1:-}" in
--list)  mode=list ;;
--reset) mode=reset ;;
"")      ;;
*) echo "Unknown option: $1"; exit 1 ;;
esac

# ------------------------------------------------------------------ prefixes
# A plain Wine prefix, plus every Steam library's per-game Proton prefixes.
find_prefixes() {
	[ -f "$HOME/.wine/user.reg" ] && echo "$HOME/.wine"

	for steam in "$HOME/.steam/steam" "$HOME/.steam/debian-installation" \
	             "$HOME/.local/share/Steam"; do
		vdf="$steam/steamapps/libraryfolders.vdf"
		[ -f "$vdf" ] || continue
		# Every library in the file, plus the one holding the file itself.
		{ echo "$steam"; sed -n 's/.*"path"[^"]*"\(.*\)"/\1/p' "$vdf"; } |
		while read -r lib; do
			[ -d "$lib/steamapps/compatdata" ] || continue
			for pfx in "$lib"/steamapps/compatdata/*/pfx; do
				# Resolved, because ~/.steam/steam is usually a symlink to the
				# same directory the vdf already named.
				[ -f "$pfx/user.reg" ] && realpath "$pfx"
			done
		done
	done | sort -u
}

prefixes=$(find_prefixes)

if [ -z "$prefixes" ]; then
	echo "No Wine or Proton prefixes found."
	exit 0
fi

if [ "$mode" = list ]; then
	echo "$prefixes" | while read -r p; do
		state=original
		grep -q "\"ActiveTitle\"=\"$ACTIVE_TITLE\"" "$p/user.reg" 2>/dev/null &&
			state="already $THEME"
		printf '%s  [%s]\n' "$p" "$state"
	done
	exit 0
fi

# It is a live wineserver that holds a prefix's registry in memory and writes it
# back out on exit; the Steam client on its own does not, so it is not in the
# way. Close the game, not the store.
if pgrep -x wineserver >/dev/null 2>&1; then
	echo "A Wine program is running, and it will write its own registry back out"
	echo "when it exits, undoing this. Close the game first."
	exit 1
fi

# -------------------------------------------------------------------- restore
if [ "$mode" = reset ]; then
	echo "$prefixes" | while read -r p; do
		if [ -f "$p/user.reg.bak" ]; then
			mv "$p/user.reg.bak" "$p/user.reg"
			echo "Restored $p/user.reg"
		fi
	done
	exit 0
fi

# ---------------------------------------------------------------------- apply
echo "$prefixes" | while read -r p; do
	python3 - "$p/user.reg" "$THEME" <<'PYEOF'
import os, shutil, sys

path, theme = sys.argv[1], sys.argv[2]

# A Windows 95 scheme with the theme's rose in place of the original navy.
# Wine writes these as "R G B" decimal strings.
COLOURS = {
    "ActiveTitle":           "163 69 69",     # #a34545
    "GradientActiveTitle":   "163 69 69",     # flat, as Windows 95 was
    "TitleText":             "235 152 168",   # #eb98a8
    "InactiveTitle":         "153 124 124",   # #997c7c
    "GradientInactiveTitle": "153 124 124",
    "InactiveTitleText":     "38 35 35",      # #262323
    "ActiveBorder":          "192 192 192",
    "InactiveBorder":        "192 192 192",
    "AppWorkSpace":          "128 128 128",
    "Background":            "0 0 0",
    "ButtonFace":            "192 192 192",
    "ButtonAlternateFace":   "192 192 192",
    "ButtonDkShadow":        "0 0 0",
    "ButtonHilight":         "255 255 255",
    "ButtonLight":           "223 223 223",
    "ButtonShadow":          "128 128 128",
    "ButtonText":            "0 0 0",
    "GrayText":              "128 128 128",
    "Hilight":               "163 69 69",
    "HilightText":           "255 255 255",
    "HotTrackingColor":      "163 69 69",
    "InfoText":              "0 0 0",
    "InfoWindow":            "255 255 225",
    "Menu":                  "192 192 192",
    "MenuBar":               "192 192 192",
    "MenuHilight":           "163 69 69",
    "MenuText":              "0 0 0",
    "Scrollbar":             "192 192 192",
    "Window":                "255 255 255",
    "WindowFrame":           "0 0 0",
    "WindowText":            "0 0 0",
}

with open(path, encoding="utf-8", errors="surrogateescape") as fh:
    lines = fh.read().split("\n")

# Wine keeps a second copy of the scheme under ThemeManager; both are set so
# the two do not disagree.
in_colours = False
changed = 0
out = []

for line in lines:
    if line.startswith("["):
        in_colours = line.split("]")[0].endswith("Control Panel\\\\Colors")
    if in_colours and line.startswith('"'):
        key = line.split('"')[1]
        if key in COLOURS:
            new = '"%s"="%s"' % (key, COLOURS[key])
            if new != line:
                line = new
                changed += 1
    out.append(line)

if not changed:
    print("  %s: already set" % os.path.dirname(path))
    sys.exit(0)

bak = path + ".bak"
if not os.path.exists(bak):
    shutil.copy2(path, bak)

# Written alongside and moved into place, so an interrupted run cannot leave a
# prefix with a half-written registry.
tmp = path + ".tmp"
with open(tmp, "w", encoding="utf-8", errors="surrogateescape") as fh:
    fh.write("\n".join(out))
shutil.copymode(path, tmp)
os.replace(tmp, path)
print("  %s: %d colours set" % (os.path.dirname(path), changed))
PYEOF
done

echo "Done. Start the game again to see it."

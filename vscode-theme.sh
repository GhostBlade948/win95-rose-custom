#!/bin/sh
# Install the VS Code colour theme and point VS Code at it, or undo that.
# Called by the Makefile; can also be run by hand.
#
#   vscode-theme.sh            install the theme and select it
#   vscode-theme.sh --reset    remove it and put the old settings back
#
# VS Code is Electron and ignores the GTK theme, so the window chrome is set
# through its own settings instead. "window.titleBarStyle": "native" hands the
# titlebar and menus back to GTK, which is where the rose colours come from.
set -eu

THEME=win95-rose-custom
SRCDIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
EXTSRC="$SRCDIR/VSCode/$THEME"
EXTDIR="$HOME/.vscode/extensions/$THEME"
SETTINGS="$HOME/.config/Code/User/settings.json"

reset=no
[ "${1:-}" = --reset ] && reset=yes

if [ "$reset" = no ] && [ ! -d "$EXTSRC" ]; then
	echo "$EXTSRC not found; skipping the VS Code theme."
	exit 0
fi

# ------------------------------------------------------------------ extension
if [ "$reset" = yes ]; then
	rm -rf "$EXTDIR"
else
	mkdir -p "$(dirname "$EXTDIR")"
	rm -rf "$EXTDIR"
	cp -a "$EXTSRC" "$EXTDIR"
fi

# -------------------------------------------------------------------- settings
# VS Code rewrites this file itself, so only the two keys are touched and the
# rest is left byte for byte as it was wherever possible.
if [ ! -f "$SETTINGS" ]; then
	if [ "$reset" = yes ]; then
		echo "Removed the VS Code theme."
		exit 0
	fi
	mkdir -p "$(dirname "$SETTINGS")"
	printf '{\n}\n' > "$SETTINGS"
fi

if ! command -v python3 >/dev/null 2>&1; then
	echo "python3 not found; select the $THEME theme by hand in VS Code."
	exit 0
fi

python3 - "$reset" "$SETTINGS" "$THEME" <<'PYEOF'
import json, os, shutil, sys

reset, path, theme = sys.argv[1], sys.argv[2], sys.argv[3]
wanted = {
    "workbench.colorTheme": theme,
    "window.titleBarStyle": "native",
    # With a native titlebar the menus default to GTK ones, which neither the
    # colour theme nor the stylesheet can reach, so they keep their rounded
    # corners. Drawing them in VS Code puts them back under the theme.
    "window.menuStyle": "custom",
}

# The stylesheet is copied into the extension directory with everything else,
# so it is pointed at there rather than at wherever this repository sits.
# The stylesheet is applied by vscode-patch.sh, not through a setting: VS Code's
# Content-Security-Policy allows inline styles but not file:// stylesheets, so it
# has to be inlined into workbench.html rather than linked.
bak = path + ".bak"

try:
    with open(path) as fh:
        conf = json.load(fh)
except ValueError:
    # settings.json allows comments and trailing commas; json does not. Rather
    # than risk mangling the file, leave it alone and say so.
    print("Could not parse %s (comments or trailing commas?);" % path)
    print("set %r and \"window.titleBarStyle\": \"native\" by hand." % theme)
    sys.exit(0)

if reset == "yes":
    old = {}
    if os.path.exists(bak):
        try:
            with open(bak) as fh:
                old = json.load(fh)
        except ValueError:
            old = {}
    for key in wanted:
        # Put back what was there before, or drop the key if we added it.
        if key in old:
            conf[key] = old[key]
        else:
            conf.pop(key, None)
else:
    if not os.path.exists(bak):
        shutil.copy2(path, bak)
    conf.update(wanted)

with open(path, "w") as fh:
    json.dump(conf, fh, indent=4)
    fh.write("\n")

if reset == "yes":
    if os.path.exists(bak):
        os.remove(bak)
    print("Removed the VS Code theme and restored the previous settings.")
else:
    print("Installed the %s VS Code theme and selected it." % theme)
    print("Restart VS Code, or run 'Developer: Reload Window', to see it.")
PYEOF

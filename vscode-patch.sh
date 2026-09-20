#!/bin/sh
# Inline the theme's stylesheet into VS Code's workbench.html, or take it out.
# Needs root, because the file belongs to the VS Code package.
#
#   vscode-patch.sh [DIR]           add the stylesheet
#   vscode-patch.sh --reset [DIR]   remove it and restore the original
#
# VS Code compiles its corner radii in as design tokens with no setting behind
# them, so a colour theme cannot reach them. The stylesheet is inlined rather
# than linked because workbench.html's Content-Security-Policy allows
# "style-src 'unsafe-inline'" but not file:// stylesheets.
#
# The file is edited in place rather than made writable by the user: leaving
# VS Code's startup HTML writable would let anything running as you change what
# VS Code loads at launch.
#
# VS Code checks this file against a list of SHA-256 hashes in product.json and
# reports itself as corrupt when it no longer matches, so the hash there is
# updated to match the patched file. That silences the warning at the cost of
# the only automatic signal that this particular file has changed; it is not a
# security boundary either way, since writing workbench.html already needs the
# root access that editing product.json needs. Pass --keep-checksum to leave
# product.json alone and dismiss the warning in VS Code instead.
#
# Both files are replaced by a VS Code update, so this has to be run again.
set -eu

THEME=win95-rose-custom
SRCDIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CSS="$SRCDIR/VSCode/$THEME/$THEME.css"
MARK="$THEME"

reset=no
checksum=yes
while :; do
	case "${1:-}" in
	--reset) reset=yes; shift ;;
	--keep-checksum) checksum=no; shift ;;
	*) break ;;
	esac
done

# Where VS Code keeps workbench.html, unless a directory was given.
if [ -n "${1:-}" ]; then
	HTML=$1
else
	HTML=/usr/share/code/resources/app/out/vs/code/electron-browser/workbench/workbench.html
fi

if [ ! -f "$HTML" ]; then
	echo "$HTML not found; is VS Code installed there?"
	exit 1
fi

if [ ! -w "$HTML" ]; then
	echo "Cannot write $HTML; run this with sudo or pkexec."
	exit 1
fi

# product.json sits five directories above workbench.html, at the root of the
# application. A second argument overrides it, which is what the tests use.
KEY=vs/code/electron-browser/workbench/workbench.html
if [ -n "${2:-}" ]; then
	PRODUCT=$2
else
	up=$(dirname "$HTML")/../../../../..
	PRODUCT=""
	[ -d "$up" ] && PRODUCT=$(CDPATH= cd -- "$up" && pwd)/product.json
fi

# ------------------------------------------------------------------ uninstall
if [ "$reset" = yes ]; then
	if [ -f "$HTML.bak" ]; then
		mv "$HTML.bak" "$HTML"
		echo "Restored $HTML"
	else
		echo "No $HTML.bak to restore; leaving it alone."
	fi
	if [ -n "$PRODUCT" ] && [ -f "$PRODUCT.bak" ]; then
		mv "$PRODUCT.bak" "$PRODUCT"
		echo "Restored $PRODUCT"
	fi
	exit 0
fi

if [ ! -f "$CSS" ]; then
	echo "$CSS not found; nothing to inline."
	exit 1
fi

# The original is kept once. A file already carrying our marker is one we
# patched, so it is not backed up over the real original.
if [ ! -f "$HTML.bak" ] && ! grep -q "$MARK" "$HTML"; then
	cp -p "$HTML" "$HTML.bak"
	echo "Saved the original as $HTML.bak"
fi

# Patch from the pristine copy so re-running replaces the block instead of
# stacking another one on top of it.
SOURCE="$HTML"
[ -f "$HTML.bak" ] && SOURCE="$HTML.bak"

python3 - "$SOURCE" "$HTML" "$CSS" "$MARK" <<'PYEOF'
import sys

source, target, cssfile, mark = sys.argv[1:5]

with open(source) as fh:
    html = fh.read()
with open(cssfile) as fh:
    css = fh.read()

block = '\t\t<!-- %s -->\n\t\t<style id="%s">\n%s\t\t</style>\n' % (mark, mark, css)

if "</head>" not in html:
    sys.exit("No </head> in %s; refusing to guess where to put the styles." % source)

html = html.replace("</head>", block + "\t</head>", 1)

with open(target, "w") as fh:
    fh.write(html)
PYEOF

echo "Inlined $THEME styles into $HTML"

# ------------------------------------------------------------------- checksum
if [ "$checksum" = no ] || [ -z "$PRODUCT" ] || [ ! -f "$PRODUCT" ]; then
	echo "Restart VS Code. It will warn that it is corrupt; that is this patch."
	exit 0
fi

if [ ! -w "$PRODUCT" ]; then
	echo "Cannot write $PRODUCT; the corrupt warning will stay."
	exit 0
fi

python3 - "$PRODUCT" "$HTML" "$KEY" <<'PYEOF'
import base64, hashlib, json, os, shutil, sys

product, html, key = sys.argv[1:4]

with open(product) as fh:
    data = json.load(fh)

checksums = data.get("checksums")
if not checksums or key not in checksums:
    # Nothing to correct; VS Code is not checking this file on this build.
    sys.exit(0)

digest = hashlib.sha256(open(html, "rb").read()).digest()
new = base64.b64encode(digest).decode().rstrip("=")

if checksums[key] == new:
    sys.exit(0)

# Keep the original once, so --reset restores the real hashes rather than ours.
bak = product + ".bak"
if not os.path.exists(bak):
    shutil.copy2(product, bak)
    print("Saved the original as %s" % bak)

checksums[key] = new
# Written to a temporary file first: a half-written product.json stops VS Code
# from starting at all.
tmp = product + ".tmp"
with open(tmp, "w") as fh:
    json.dump(data, fh, indent="\t")
    fh.write("\n")
json.load(open(tmp))
shutil.copymode(product, tmp)
os.replace(tmp, product)
print("Updated the workbench.html checksum in product.json")
PYEOF

echo "Restart VS Code."

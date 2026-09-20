#!/bin/sh
# Install everything the theme needs before `make install`, plus fastfetch.
#
#   sh install-deps.sh          install what is missing
#   sh install-deps.sh --list   show what would be installed, change nothing
#
# Safe to run more than once: anything already present is left alone.
#
# Debian and Ubuntu only. On anything else it says so and stops rather than
# guessing at a package manager.
set -eu

# make and python3 are used by the Makefile and the install scripts; the other
# two provide gtk-update-icon-cache and fc-cache, which refresh the icon and
# font caches after installing.
PKGS="make python3 fontconfig libgtk-3-bin"

# fastfetch entered Ubuntu in 24.10, so on anything older it is installed from
# the project's own release instead of the distribution.
FASTFETCH_REPO=fastfetch-cli/fastfetch

list_only=no
[ "${1:-}" = --list ] && list_only=yes

if ! command -v apt-get >/dev/null 2>&1; then
	echo "This script only knows apt. Install these by hand: $PKGS fastfetch"
	exit 1
fi

# Run the installing parts through sudo unless we are already root.
SUDO=
if [ "$(id -u)" -ne 0 ]; then
	if command -v sudo >/dev/null 2>&1; then
		SUDO=sudo
	else
		echo "Not root and no sudo; re-run this as root."
		exit 1
	fi
fi

# ------------------------------------------------------------ what is missing
missing=
for p in $PKGS; do
	if ! dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q "^install ok installed$"; then
		missing="$missing $p"
	fi
done

need_fastfetch=no
command -v fastfetch >/dev/null 2>&1 || need_fastfetch=yes

if [ "$list_only" = yes ]; then
	echo "packages to install:${missing:- (none)}"
	echo "fastfetch:           $([ "$need_fastfetch" = yes ] && echo "yes" || echo "already installed")"
	exit 0
fi

if [ -z "$missing" ] && [ "$need_fastfetch" = no ]; then
	echo "Everything is already installed."
	exit 0
fi

# -------------------------------------------------------------------- packages
if [ -n "$missing" ]; then
	echo "Installing:$missing"
	$SUDO apt-get update
	# shellcheck disable=SC2086
	$SUDO apt-get install -y $missing
fi

# ------------------------------------------------------------------- fastfetch
[ "$need_fastfetch" = no ] && exit 0

if apt-cache show fastfetch >/dev/null 2>&1; then
	echo "Installing fastfetch from the distribution."
	$SUDO apt-get install -y fastfetch
	exit 0
fi

echo "fastfetch is not in this release's repositories; using the project's own"
echo "release from https://github.com/$FASTFETCH_REPO/releases"

for c in curl python3; do
	command -v $c >/dev/null 2>&1 || { echo "$c is needed to download it."; exit 1; }
done

case "$(uname -m)" in
x86_64)  arch=amd64 ;;
aarch64) arch=aarch64 ;;
*) echo "No prebuilt package for $(uname -m); install fastfetch by hand."; exit 1 ;;
esac

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

url=$(curl -fsSL "https://api.github.com/repos/$FASTFETCH_REPO/releases/latest" |
	python3 -c "
import json, sys
want = 'fastfetch-linux-$arch.deb'
for asset in json.load(sys.stdin)['assets']:
    if asset['name'] == want:
        print(asset['browser_download_url'])
        break
")

if [ -z "$url" ]; then
	echo "Could not find a .deb for $arch in the latest release."
	exit 1
fi

echo "Downloading $url"
curl -fsSL -o "$tmp/fastfetch.deb" "$url"

# apt install of a local file pulls in whatever the package depends on, which
# plain dpkg -i would not.
$SUDO apt-get install -y "$tmp/fastfetch.deb"

echo "Installed $(fastfetch --version 2>/dev/null || echo fastfetch)"

#!/bin/sh
# Use the Windows 95 sounds for Cinnamon's login and logout.
#
#   login-sound.sh              copy the sounds in and select them (needs root)
#   login-sound.sh --autostart  also play the login sound as a startup app
#   login-sound.sh --no-select  copy them without changing any setting
#   login-sound.sh --reset      remove all of it and put Mint's sounds back
#   login-sound.sh --show       print what is set now, change nothing
#
# Cinnamon's own login sound does not reliably play: the call is made while the
# session is still coming up and fails silently. Setting the file above is
# still worth doing, since that is what the Sound settings show, but --autostart
# is what actually makes a noise. It plays once per boot, so logging out and
# back in on a running machine stays silent.
#
# The sounds are copied to /usr/share/mint-artwork/sounds, next to Mint's own
# login.oga and logout.ogg, which is where Cinnamon's sound picker opens. They
# are given their own names rather than replacing Mint's files, which belong to
# the mint-artwork package and would be restored by its next update.
#
# Then "Starting Cinnamon" and "Leaving Cinnamon" in System Settings > Sound >
# Sounds are pointed at them, so there is nothing to pick by hand.
#
# The sounds come from the Chicago95 sound theme, which the install targets put
# in place; nothing here installs it.
set -eu

SCHEMA=org.cinnamon.sounds
DEST=/usr/share/mint-artwork/sounds

# source name under the Chicago95 sound theme : name written into $DEST
LOGIN_SRC=Chicago95/stereo/desktop-login.wav
LOGIN_DST=win95-login.wav
LOGOUT_SRC=Chicago95/stereo/desktop-logout.wav
LOGOUT_DST=win95-logout.wav

have_gsettings=no
if command -v gsettings >/dev/null 2>&1 && gsettings list-schemas | grep -qx "$SCHEMA"; then
	have_gsettings=yes
fi

# Only the copying needs root; the settings are per-user.
SUDO=
if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
	SUDO=sudo
fi

# Settings belong to the person who ran this, not to root. Under sudo or pkexec
# the script itself is root, so the writes are handed back to the real user
# along with their session bus, or gsettings would quietly configure root's
# desktop instead of theirs.
DESKTOP_USER=""
if [ "$(id -u)" -eq 0 ]; then
	DESKTOP_USER=${SUDO_USER:-}
	if [ -z "$DESKTOP_USER" ] && [ -n "${PKEXEC_UID:-}" ]; then
		DESKTOP_USER=$(getent passwd "$PKEXEC_UID" | cut -d: -f1)
	fi
fi

gset() {
	if [ -z "$DESKTOP_USER" ]; then
		gsettings "$@"
		return $?
	fi
	uid=$(id -u "$DESKTOP_USER")
	sudo -u "$DESKTOP_USER" \
		DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
		gsettings "$@"
}

# Under sudo or pkexec $HOME is root's, which would put the startup app in
# /root where no session would ever read it.
USERHOME=$HOME
if [ -n "$DESKTOP_USER" ]; then
	USERHOME=$(getent passwd "$DESKTOP_USER" | cut -d: -f6)
fi
AUTOSTART="$USERHOME/.config/autostart/win95-login-sound.desktop"
PLAYER="$USERHOME/.config/win95-rose-custom/login-sound-player.sh"

find_sound() {
	for d in "$HOME/.local/share/sounds" /usr/share/sounds; do
		if [ -f "$d/$1" ]; then
			echo "$d/$1"
			return 0
		fi
	done
	return 1
}

case "${1:-}" in
--show)
	if [ "$have_gsettings" = no ]; then
		echo "Cinnamon settings not found."
		exit 0
	fi
	echo "Starting Cinnamon: $(gset get $SCHEMA login-file)  (on=$(gset get $SCHEMA login-enabled))"
	echo "Leaving Cinnamon:  $(gset get $SCHEMA logout-file)  (on=$(gset get $SCHEMA logout-enabled))"
	echo "in $DEST:"
	for f in "$LOGIN_DST" "$LOGOUT_DST"; do
		[ -f "$DEST/$f" ] && echo "  $f" || echo "  $f  (not installed)"
	done
	[ -f "$AUTOSTART" ] && echo "startup app:       $AUTOSTART" \
	                    || echo "startup app:       not set up"
	exit 0 ;;
--autostart)
	sound="$DEST/$LOGIN_DST"
	if [ ! -f "$sound" ]; then
		sound=$(find_sound "$LOGIN_SRC") || {
			echo "No login sound found. Run this without --autostart first."
			exit 1
		}
	fi
	command -v paplay >/dev/null 2>&1 || {
		echo "paplay not found; install pulseaudio-utils."
		exit 1
	}

	mkdir -p "$(dirname "$PLAYER")" "$(dirname "$AUTOSTART")"
	cat > "$PLAYER" <<EOF
#!/bin/sh
# Play the login sound once per boot, as soon as the audio server accepts it.
#
# Written by login-sound.sh --autostart. Edit SOUND below to change the file.
SOUND="$sound"
STATE="$USERHOME/.cache/win95-rose-custom/last-boot"
EOF
	cat >> "$PLAYER" <<'EOF'

# The kernel's boot id changes on every boot and nothing else. A marker under
# /run would be simpler but is wiped when the user's last session ends, so a
# logout would look like a reboot.
BOOT_ID=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null || echo unknown)
if [ -f "$STATE" ] && [ "$(cat "$STATE" 2>/dev/null)" = "$BOOT_ID" ]; then
	exit 0
fi

# Wait for the audio server rather than sleeping a fixed time: PipeWire is
# socket-activated and usually up already, so this normally costs nothing.
i=0
while [ $i -lt 200 ]; do
	if pactl info >/dev/null 2>&1 && [ -n "$(pactl list short sinks 2>/dev/null)" ]; then
		break
	fi
	sleep 0.05
	i=$((i + 1))
done

# Recorded before playing: a second session starting meanwhile should find the
# boot already marked and stay quiet.
mkdir -p "$(dirname "$STATE")"
printf '%s\n' "$BOOT_ID" > "$STATE"

exec paplay "$SOUND"
EOF
	chmod 0755 "$PLAYER"

	# No X-GNOME-Autostart-Phase here, deliberately. Moving it earlier than the
	# default Application phase does make the sound arrive sooner, but it runs
	# before the desktop is laid out and the background fails to load.
	cat > "$AUTOSTART" <<EOF
[Desktop Entry]
Type=Application
Name=Windows 95 startup sound
Comment=Plays the startup sound once per boot, after the desktop appears
Exec=$PLAYER
Icon=multimedia-volume-control
X-GNOME-Autostart-enabled=true
EOF
	echo "Wrote $PLAYER"
	echo "Wrote $AUTOSTART"
	echo "It plays $sound once per boot."
	echo "Visible in Startup Applications as \"Windows 95 startup sound\"."
	exit 0 ;;
--reset)
	if [ -f "$AUTOSTART" ] || [ -f "$PLAYER" ]; then
		rm -f "$AUTOSTART" "$PLAYER" "$USERHOME/.cache/win95-rose-custom/last-boot"
		rmdir "$USERHOME/.cache/win95-rose-custom" 2>/dev/null || :
		echo "Removed the startup app and its player."
	fi
	if [ "$have_gsettings" = yes ]; then
		# Only where ours are still selected: a sound you chose yourself stays.
		for pair in "login-file $LOGIN_DST" "logout-file $LOGOUT_DST"; do
			key=${pair% *}
			name=${pair#* }
			case "$(gset get $SCHEMA "$key")" in
			*"$name"*)
				gset reset "$SCHEMA" "$key"
				echo "$key back to $(gset get $SCHEMA "$key")" ;;
			esac
		done
	fi
	if [ -f "$DEST/$LOGIN_DST" ] || [ -f "$DEST/$LOGOUT_DST" ]; then
		$SUDO rm -f "$DEST/$LOGIN_DST" "$DEST/$LOGOUT_DST"
		echo "Removed the Windows 95 sounds from $DEST"
	fi
	exit 0 ;;
"" | --no-select) ;;
*)
	echo "Unknown option: $1"
	exit 1 ;;
esac

if [ ! -d "$DEST" ]; then
	echo "$DEST does not exist; is mint-artwork installed?"
	exit 1
fi

login_file=$(find_sound "$LOGIN_SRC") || {
	echo "$LOGIN_SRC not found under ~/.local/share/sounds or /usr/share/sounds."
	echo "Install the theme first: make install_user, or sudo make install."
	exit 1
}
logout_file=$(find_sound "$LOGOUT_SRC") || logout_file=""

$SUDO install -m 0644 "$login_file" "$DEST/$LOGIN_DST"
echo "Copied $login_file -> $DEST/$LOGIN_DST"

if [ -n "$logout_file" ]; then
	$SUDO install -m 0644 "$logout_file" "$DEST/$LOGOUT_DST"
	echo "Copied $logout_file -> $DEST/$LOGOUT_DST"
else
	echo "No $LOGOUT_SRC found; skipped the logout sound."
fi

if [ "$have_gsettings" = yes ] && [ "${1:-}" != --no-select ]; then
	gset set "$SCHEMA" login-file "$DEST/$LOGIN_DST"
	echo "Starting Cinnamon set to $LOGIN_DST"
	if [ -n "$logout_file" ]; then
		gset set "$SCHEMA" logout-file "$DEST/$LOGOUT_DST"
		echo "Leaving Cinnamon set to $LOGOUT_DST"
	fi
else
	echo
	echo "Not selected. Pick them in System Settings > Sound > Sounds,"
	echo "browsing $DEST."
fi

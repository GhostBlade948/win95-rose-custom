# Makefile for win95-rose-custom
# License: CC-BY-SA 4.0
# Derived from the Chicago95 Makefile by bgstack15.

APPNAME    = win95-rose-custom
THEMENAME  = win95-rose-custom
SRCDIR     = $(CURDIR)
prefix     = /usr
SHAREDIR   = $(DESTDIR)$(prefix)/share
THEMESDIR  = $(SHAREDIR)/themes
ICONSDIR   = $(SHAREDIR)/icons
FONTDIR    = $(SHAREDIR)/fonts
SOUNDSDIR  = $(SHAREDIR)/sounds
BKGDSDIR   = $(SHAREDIR)/backgrounds/$(APPNAME)
DOCDIR     = $(SHAREDIR)/doc/$(APPNAME)

# user-level install targets
USERTHEMES = $(HOME)/.themes
USERICONS  = $(HOME)/.icons
USERFONTS  = $(HOME)/.fonts
USERSOUNDS = $(HOME)/.local/share/sounds
USERBKGDS  = $(HOME)/.local/share/backgrounds

WALLPAPER  = $(APPNAME).png
APPLY      = sh $(SRCDIR)/apply-settings.sh
VSCODE     = sh $(SRCDIR)/vscode-theme.sh
DEPS       = sh $(SRCDIR)/install-deps.sh
SHELLRC    = sh $(SRCDIR)/shell-setup.sh
WINE       = sh $(SRCDIR)/wine-colors.sh
PLYMOUTH   = sh $(SRCDIR)/install-plymouth.sh
LOGINSOUND = sh $(SRCDIR)/login-sound.sh

.PHONY: all install install_user uninstall uninstall_user install_system_cursor \
	apply_sudo_user install_vscode uninstall_vscode patch_vscode unpatch_vscode \
	deps install_shell uninstall_shell install_wine_colors uninstall_wine_colors \
	install_plymouth uninstall_plymouth preview_plymouth \
	install_login_sound uninstall_login_sound list

all:
	@echo "targets: install (system, needs root), install_user, uninstall, uninstall_user"

# ---------------------------------------------------------------- system-wide

install: install_theme install_icons install_cursors install_fonts install_sounds install_backgrounds install_doc install_system_cursor apply_sudo_user

install_theme:
	install -dm0755 $(THEMESDIR)
	cp -pr $(SRCDIR)/Theme/$(THEMENAME) $(THEMESDIR)
	find $(THEMESDIR)/$(THEMENAME) ! -type d -exec chmod 0644 {} + || :
	find $(THEMESDIR)/$(THEMENAME) -type d -exec chmod 0755 {} + || :

install_icons:
	install -dm0755 $(ICONSDIR)
	cp -pr $(SRCDIR)/Icons/* $(ICONSDIR)/
	find $(ICONSDIR)/Chicago95* ! -type d ! -type l -exec chmod 0644 {} +

install_cursors:
	install -dm0755 $(ICONSDIR)
	cp -pr $(SRCDIR)/Cursors/* $(ICONSDIR)/

install_fonts:
	install -dm0755 $(FONTDIR)/truetype
	install -m0644 -t $(FONTDIR)/truetype $(SRCDIR)/Fonts/vga_font/*ttf

install_sounds:
	install -dm0755 $(SOUNDSDIR)/Chicago95/stereo
	install -m0644 -t $(SOUNDSDIR)/Chicago95/stereo $(SRCDIR)/sounds/Chicago95/stereo/*
	install -m0644 -t $(SOUNDSDIR)/Chicago95 $(SRCDIR)/sounds/Chicago95/index.theme

install_backgrounds:
	install -dm0755 $(BKGDSDIR)/patterns $(BKGDSDIR)/wallpapers
	install -m0644 -t $(BKGDSDIR)/patterns $(SRCDIR)/Extras/Backgrounds/Patterns/*
	install -m0644 -t $(BKGDSDIR)/wallpapers $(SRCDIR)/Extras/Backgrounds/Wallpaper/*
	install -m0644 $(SRCDIR)/wallpaper.png $(BKGDSDIR)/wallpapers/$(WALLPAPER)

install_doc:
	install -dm0755 $(DOCDIR)
	install -m0644 -t $(DOCDIR) $(SRCDIR)/README.md $(SRCDIR)/INSTALL.md $(SRCDIR)/CREDITS

# The login screen and root applications (pkexec, Timeshift) ignore your session
# settings, so the cursor is set for them separately. Needs the cursors in
# $(ICONSDIR), which install_cursors puts there.
install_system_cursor: install_cursors
	sh $(SRCDIR)/system-cursor.sh "$(DESTDIR)"

# Apply the theme for the user who ran sudo. Skipped when packaging (DESTDIR set).
apply_sudo_user:
ifeq ($(DESTDIR),)
	@if [ -n "$$SUDO_USER" ] && [ "$$SUDO_USER" != root ]; then \
		sudo -H -u "$$SUDO_USER" $(APPLY) $(THEMESDIR)/$(THEMENAME) $(BKGDSDIR)/wallpapers/$(WALLPAPER); \
		sudo -H -u "$$SUDO_USER" $(VSCODE); \
	else \
		echo "Installed. Run 'sh apply-settings.sh $(THEMESDIR)/$(THEMENAME) $(BKGDSDIR)/wallpapers/$(WALLPAPER)' as your own user to switch to it."; \
	fi
endif

uninstall:
	-sh $(SRCDIR)/system-cursor.sh --reset "$(DESTDIR)"
	rm -rf $(THEMESDIR)/$(THEMENAME) \
		$(ICONSDIR)/Chicago95 $(ICONSDIR)/Chicago95-tux $(ICONSDIR)/Chicago95-puffy \
		$(ICONSDIR)/Chicago95_Cursor_Black $(ICONSDIR)/Chicago95_Cursor_White \
		$(ICONSDIR)/Chicago95_Emerald \
		$(ICONSDIR)/Chicago95_Standard_Cursors $(ICONSDIR)/Chicago95_Standard_Cursors_Black \
		$(ICONSDIR)/Chicago95_Animated_Hourglass_Cursors \
		$(ICONSDIR)/Chicago95_Animated_Hourglass_Cursors_HiDPI \
		$(FONTDIR)/truetype/LessPerfectDOSVGA.ttf $(FONTDIR)/truetype/MorePerfectDOSVGA.ttf \
		$(SOUNDSDIR)/Chicago95 $(BKGDSDIR) $(DOCDIR)

# ------------------------------------------------------------------ this user

install_user:
	mkdir -p $(USERTHEMES) $(USERICONS) $(USERFONTS) $(USERSOUNDS) $(USERBKGDS)
	rm -rf $(USERTHEMES)/$(THEMENAME)
	cp -a $(SRCDIR)/Theme/$(THEMENAME) $(USERTHEMES)/
	cp -a $(SRCDIR)/Icons/* $(SRCDIR)/Cursors/* $(USERICONS)/
	cp -a $(SRCDIR)/Fonts/vga_font/*ttf $(USERFONTS)/
	cp -a $(SRCDIR)/sounds/Chicago95 $(USERSOUNDS)/
	cp $(SRCDIR)/wallpaper.png $(USERBKGDS)/$(WALLPAPER)
	-gtk-update-icon-cache -f -t $(USERICONS)/Chicago95
	-fc-cache -f $(USERFONTS)
	@$(APPLY) $(USERTHEMES)/$(THEMENAME) $(USERBKGDS)/$(WALLPAPER)
	@$(VSCODE)

# VS Code keeps its extensions and settings under $(HOME) whichever way the
# rest of the theme was installed, so these targets never need root.
install_vscode:
	@$(VSCODE)

uninstall_vscode:
	-@$(VSCODE) --reset

# Everything the theme needs from the distribution, plus fastfetch. Uses sudo
# itself where it needs to, so it is not run by the install targets.
deps:
	@$(DEPS)

# The MS-DOS prompt, the Windows 95 startup banner and fastfetch, added to
# ~/.bashrc. Not part of either install target: it edits a file you own and
# probably have your own things in.
install_shell:
	@$(SHELLRC)

uninstall_shell:
	-@$(SHELLRC) --reset

# The Windows 95 login and logout sounds. Kept out of the install targets: the
# copying needs root, and replacing the sounds a desktop makes is a bigger
# change than a theme should apply without being asked.
install_login_sound:
	$(LOGINSOUND)

uninstall_login_sound:
	-$(LOGINSOUND) --reset

# The boot splash. Kept out of the install targets: it needs root, rebuilds the
# initramfs, only shows up after a reboot, and wants a splash.png that this
# repository does not ship.
install_plymouth:
	$(PLYMOUTH)

uninstall_plymouth:
	-$(PLYMOUTH) --reset

preview_plymouth:
	@$(PLYMOUTH) --preview

# Wine draws its own titlebars and widgets, so games under Proton keep Wine's
# default blue whatever the desktop theme is. This sets the colours in each
# prefix's registry instead. Close Steam first.
install_wine_colors:
	@$(WINE)

uninstall_wine_colors:
	-@$(WINE) --reset

# Squaring off VS Code's rounded corners means editing its own workbench.html,
# which belongs to root and is not part of either install target. VS Code will
# call itself corrupt afterwards, and an update undoes it.
patch_vscode:
	sh $(SRCDIR)/vscode-patch.sh

unpatch_vscode:
	-sh $(SRCDIR)/vscode-patch.sh --reset

uninstall_user:
	-@$(APPLY) --reset
	-@$(VSCODE) --reset
	rm -rf $(USERBKGDS)/$(WALLPAPER) \
		$(USERTHEMES)/$(THEMENAME) \
		$(USERICONS)/Chicago95 $(USERICONS)/Chicago95-tux $(USERICONS)/Chicago95-puffy \
		$(USERICONS)/Chicago95_Cursor_Black $(USERICONS)/Chicago95_Cursor_White \
		$(USERICONS)/Chicago95_Emerald \
		$(USERICONS)/Chicago95_Standard_Cursors $(USERICONS)/Chicago95_Standard_Cursors_Black \
		$(USERICONS)/Chicago95_Animated_Hourglass_Cursors \
		$(USERICONS)/Chicago95_Animated_Hourglass_Cursors_HiDPI \
		$(USERFONTS)/LessPerfectDOSVGA.ttf $(USERFONTS)/MorePerfectDOSVGA.ttf \
		$(USERSOUNDS)/Chicago95

list:
	@echo "Theme:       Theme/$(THEMENAME)  (gtk-2.0, gtk-3.0, gtk-4.0, cinnamon, metacity-1)"
	@echo "Icons:       Icons/  Cursors/"
	@echo "Fonts:       Fonts/vga_font"
	@echo "Sounds:      sounds/Chicago95"
	@echo "Extras:      Extras/  (backgrounds, DOS prompt, fastfetch, recolour script, fontconfig)"

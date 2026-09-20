# Installing win95-rose-custom

A Windows 95 desktop theme for **Cinnamon**, with dusty rose titlebars in place
of the original navy. This guide covers installing it, the parts that are not
installed automatically, and how to undo everything.

If you only want the short version: run `sudo make install`, log out and back
in, and skip to [After installing](#after-installing).

## Before you start

| | |
| --- | --- |
| Desktop | Cinnamon. The theme was built and tested on Cinnamon 6.6 (Linux Mint 22). |
| Needed | `make`, `python3` (both are already on a Mint install) |
| Optional | `gtk-update-icon-cache` and `fc-cache`, used to refresh caches |

On Debian or Ubuntu you can let the repository sort that out, along with
fastfetch for the terminal:

    make deps

It installs only what is missing and can be run again safely. `sh
install-deps.sh --list` shows what it would do without changing anything.
fastfetch is taken from your distribution where it exists; it only entered
Ubuntu in 24.10, so on anything older the `.deb` from the project's own
[releases](https://github.com/fastfetch-cli/fastfetch/releases) is used instead.

This is not a general Chicago95 install. The repository is trimmed to Cinnamon,
so there is nothing here for XFCE, LXDE or the Whisker menu. On any other
desktop the files will install but nothing will switch over.

## Installing

Two ways, and they install the same theme. Pick one.

### For your user only

    make install_user

Everything goes under your home directory — `~/.themes`, `~/.icons`, `~/.fonts`,
`~/.local/share/sounds` and `~/.local/share/backgrounds`. No root, nothing
outside your account touched.

### System-wide

    sudo make install

Everything goes under `/usr/share`, so every account on the machine can select
the theme. This also sets the cursor for the login screen and for programs
started with administrator rights, which the user install cannot do — see
[The login screen and root applications](#the-login-screen-and-root-applications).

Either way the install then switches your desktop over for you: the Cinnamon
theme, window borders, Chicago95 icons, the white cursor, the wallpaper, the
Start button and the VS Code theme. The sound theme is installed but left
switched off.

### What gets installed where

| Target | Installs |
| --- | --- |
| `install_theme` | the GTK2, GTK3, GTK4, Cinnamon and window border theme |
| `install_icons` | the `Chicago95` icon theme and its `-tux` and `-puffy` variants |
| `install_cursors` | the cursor themes, including the animated hourglass |
| `install_fonts` | the Perfect DOS VGA fonts |
| `install_sounds` | the Windows 95 sound theme (not enabled) |
| `install_backgrounds` | the wallpaper and the Windows 95 pattern tiles |
| `install_system_cursor` | the login screen and root application cursor (root only) |
| `install_vscode` | the VS Code colour theme |

Run `make list` for a summary of what is in the repository.

## After installing

Log out and back in. If only part of the theme took effect, restart Cinnamon
with **Ctrl+Alt+Esc**, which is quicker than a full logout.

**Restart your applications.** A running application keeps the theme it started
with, so anything already open will look unthemed until you restart it.

**Cinnamon caches stylesheets.** If you edit the theme after installing it,
Cinnamon will keep showing the old version until you restart it with
**Ctrl+Alt+Esc**.

To re-apply the desktop settings without reinstalling the files:

    sh apply-settings.sh ~/.themes/win95-rose-custom ~/.local/share/backgrounds/win95-rose-custom.png

## The Start button

The install sets the Cinnamon menu applet to the `start-here` icon — the Windows
flag — with the text **Start** beside it, at 22px to match the other applets.
The label is bold, as it was in Windows 95.

These are applet settings, not theme properties, so they live in
`~/.config/cinnamon/spices/menu@cinnamon.org/*.json`. The previous settings are
saved next to that file as `.bak`, and only those keys are put back when you
uninstall, so anything else you changed in the applet's settings is kept.

To change the icon or the wording, either right-click the panel and choose
*Configure*, or edit `MENUICON`, `MENULABEL` and `MENUICONSIZE` at the top of
`apply-settings.sh` before installing.

## The login screen and root applications

The login screen, and programs started with administrator rights such as
Timeshift, GParted and the update manager, do not read your session settings.
They keep the default arrow pointer unless the cursor is set for them
separately. `sudo make install` does this. To do only that part:

    sudo make install_system_cursor

It puts the cursor themes in `/usr/share/icons`, points
`/usr/share/icons/default` at `Chicago95_Cursor_White`, and writes
`cursor-theme-name` into `/etc/lightdm/slick-greeter.conf`. Originals are kept
beside each file as `.bak`. The login screen changes at the next reboot; root
applications change as soon as they are restarted.

Only the cursor is set. Mint's own greeter settings are left alone.

### The login screen shows your desktop wallpaper

This catches people out: after installing, the login screen may show the
Windows 95 wallpaper even though nothing here themed it. That is not this theme.
Cinnamon copies your desktop wallpaper into AccountsService, and Mint's greeter
shows each user's wallpaper by default.

To stop it, tell the greeter not to draw user backgrounds:

    sudo sh -c 'printf "draw-user-backgrounds=false\n" >> /etc/lightdm/slick-greeter.conf'

Make sure that line ends up under the `[Greeter]` section. The login screen then
uses Mint's default background. Resetting the AccountsService entry instead does
not last, because Cinnamon writes your wallpaper back to it.

The `Lightdm/` directory holds a full Windows 95 login screen theme. Nothing
installs it, and it needs `lightdm-webkit2-greeter`, which Mint does not use by
default.

## VS Code

VS Code ignores the GTK theme, so it is themed through its own settings. Both
install targets do this; on its own:

    make install_vscode

This copies the colour theme to `~/.vscode/extensions`, selects it, and sets
`"window.titleBarStyle": "native"` so that GTK draws the titlebar — which is
where the rose colour and the Windows 95 window buttons come from.

It also sets `"window.menuStyle": "custom"`. A native titlebar otherwise brings
native GTK menus with it, and those are drawn outside VS Code, so neither the
colour theme nor the stylesheet reaches them: the File and Terminal menus keep
their rounded corners and their own colours. Drawing them in VS Code instead
puts them back under the theme.

**`window.titleBarStyle` only takes effect on a full restart of VS Code.**
Reloading the window is not enough. Until you restart, VS Code keeps drawing its
own titlebar and window buttons, which look nothing like the rest of the theme.

Only `workbench.colorTheme`, `window.titleBarStyle` and `window.menuStyle` are
written to your settings. The previous file is kept as `settings.json.bak`. A
settings file containing comments or trailing commas is left alone with a
message, since those are not valid JSON.

### Squaring off VS Code's rounded corners (optional)

VS Code rounds its own corners and no colour theme can change that: the radii
are compiled in as design tokens with no setting behind them. If it bothers you:

    sudo make patch_vscode      # apply
    sudo make unpatch_vscode    # restore the original files

This inlines `VSCode/win95-rose-custom/win95-rose-custom.css` into VS Code's
`workbench.html` and corrects that file's checksum in `product.json`, so VS Code
does not report itself as corrupt at the next launch. Both originals are kept as
`.bak` beside them.

Know what you are getting into:

- **A VS Code update replaces both files**, so the corners come back and you
  re-run `sudo make patch_vscode`. Running it again is safe; it patches from the
  pristine backup rather than stacking another copy.
- **Correcting the checksum costs you the only automatic signal that
  `workbench.html` has changed.** It is not a security boundary either way, since
  writing that file already needs the same root access as editing `product.json`.
  Pass `--keep-checksum` to `vscode-patch.sh` to leave `product.json` alone and
  dismiss VS Code's warning by hand instead.
- **The patch is not tracked in this repository** — only the stylesheet is. The
  edit lives in the VS Code installation, so it is per machine.

## Optional extras

None of these are installed automatically.

### Qt applications

Qt applications are not themed. Two options:

- `Extras/Chicago95_qt.conf` is a colour scheme for `qt5ct`. Install `qt5ct`,
  then point it at the file under *Appearance → Colors → Custom*.
- Or set `QT_QPA_PLATFORMTHEME=gtk2` in your environment, which renders Qt5
  applications through the GTK2 theme.

### The Windows 95 sounds

Installed but not switched on, since replacing every system sound is a bigger
change than a theme should make silently. To enable:

    gsettings set org.cinnamon.desktop.sound theme-name Chicago95

`Extras/Microsoft Windows 95 Startup Sound.ogg` is the startup sound, if you
want to add it to your startup applications.

### An MS-DOS shell prompt

    make install_shell      # add it
    make uninstall_shell    # take it back out

This gives a new terminal the Windows 95 startup banner:

    Microsoft(R) Windows 95
       (C)Copyright Microsoft Corp 1981-1996.

a `C:\path\like\this>` prompt, and a fastfetch summary if fastfetch is
installed. Use `sh shell-setup.sh --no-fastfetch` for the prompt and banner
without it.

fastfetch is set to the Windows 95 flag, recoloured to the theme's palette: a
silver frame with the four quadrants in rose, pink, mauve and grey, and the
field names in the titlebar's `#eb98a8`. `Extras/fastfetch/config.jsonc` is
copied to `~/.config/fastfetch/config.jsonc`, so running `fastfetch` by hand
shows the flag too, not only the line in `.bashrc`. The logo is one of
fastfetch's own — `fastfetch --list-logos` shows the rest — so there is no art
file to ship. A fastfetch config you already had is kept as `config.jsonc.bak`
and put back by `make uninstall_shell`.

`Extras/DOSrc` is copied to `~/.config/win95-rose-custom/` and sourced from
there, so moving this repository later does not break your shell. The block
added to `~/.bashrc` is fenced with `# >>> win95-rose-custom >>>` markers, runs
only in interactive shells — output from a non-interactive one breaks `scp` and
`rsync` — and is replaced rather than repeated if you run the target again.

The prompt's drive letters follow the filesystems `df` reports, starting at
`C:`, since `A:` and `B:` were the floppy drives.

`Extras/ZSHDOSrc` is the same for zsh, and `Extras/Chicago95.zsh-theme` is an
oh-my-zsh theme — copy it to `~/.oh-my-zsh/themes/` and set
`ZSH_THEME="Chicago95"` in `~/.zshrc`. Neither is wired up by `install_shell`,
which only touches `~/.bashrc`.

### The DOS terminal font

The install puts `LessPerfectDOSVGA` and `MorePerfectDOSVGA` on the system.
Select either in your terminal's profile settings. They are bitmap-style fonts
and look sharpest at multiples of 16px.

### MS Sans Serif

`Extras/99-ms-sans-serif.conf` and `99-ms-sans-serif-bold.conf` are fontconfig
snippets that map MS Sans Serif onto Helvetica. Copy them to
`~/.config/fontconfig/conf.d/` and run `fc-cache -f`. You need a Helvetica font
installed for this to change anything.

### GTK3 overrides

`Extras/override/` holds `gtk.css` snippets for GTK 3.22 and 3.24, for
per-version fixes. Copy the one matching your GTK version to
`~/.config/gtk-3.0/gtk.css` if you hit a widget that looks wrong.

### GTK4 and libadwaita applications

Ordinary GTK4 applications follow the theme setting. libadwaita applications
ignore it and always load Adwaita, but they do read a per-user stylesheet, so
the install writes `~/.config/gtk-4.0/gtk.css` importing the theme from there.
If you already had that file it is kept as `gtk.css.bak`.

Delete that file if you later switch to an unrelated theme, or it will keep
styling those applications.

## Changing the colours

The titlebar and highlight colours live in four places, which must agree:

- `Theme/win95-rose-custom/gtk-3.0/gtk.css`
- `Theme/win95-rose-custom/gtk-4.0/gtk-colours.css`
- `Theme/win95-rose-custom/metacity-1/metacity-theme-1.xml`
- `VSCode/win95-rose-custom/themes/win95-rose-custom-color-theme.json`

The values are `#a34545` (active titlebar), `#eb98a8` (its text), `#997c7c`
(inactive titlebar) and `#262323` (its text).

Current Cinnamon draws titlebars from the GTK stylesheet rather than the
metacity file, which is kept so the theme still appears in the *Window borders*
list.

`Extras/recolor.py` remaps the whole palette at once, writing out a recoloured
copy of the theme rather than editing this one in place.

## Uninstalling

    make uninstall_user      # if you installed with make install_user
    sudo make uninstall      # if you installed with sudo make install

`uninstall_user` removes the files, puts the Cinnamon defaults back, restores the
menu applet and removes the VS Code theme. It changes the wallpaper back only if
it is still this theme's.

`sudo make uninstall` removes the system-wide files and restores the cursor
configuration, but it does not reset your own session settings. Run
`sh apply-settings.sh --reset` as yourself for that.

If you patched VS Code, undo that separately with `sudo make unpatch_vscode`.

## If something looks wrong

**Part of the desktop is still unthemed.** Restart Cinnamon with
**Ctrl+Alt+Esc**, then restart the applications that still look wrong.

**An edit to the theme has no effect.** Cinnamon caches the stylesheet, and the
system-wide copy under `/usr/share/themes` is what is in use — editing the
repository does nothing until you reinstall. Run the install again, then restart
Cinnamon.

**The theme is missing from System Settings.** It needs to be in `~/.themes` or
`/usr/share/themes`. Check that the install actually ran, and that you are
looking under both *Themes* and *Window borders*.

**GTK4 applications have no scrollbar arrows.** GTK4 removed scrollbar stepper
buttons, so those applications cannot have the little arrows that GTK2 and GTK3
applications do. Nothing to fix.

**VS Code still looks wrong after installing.** Restart it fully rather than
reloading the window; `window.titleBarStyle` is only read at launch.

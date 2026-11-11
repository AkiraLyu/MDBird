# Installation

MDBird loads through Thunderbird's `userChrome.css` and `userContent.css`. The MDBird Search add-on provides global search in the sidebar. The installer puts the files in your Thunderbird profile directory.

## Profile directory

In Thunderbird, open **Help > Troubleshooting Information** and find **Profile Directory** or **Profile Folder**. Click the button beside it to open the profile. This directory contains `prefs.js`. The installer creates `user.js` and the `chrome` directory as needed.

The following profile root directories are common on Linux.

```text
~/.thunderbird
~/.mozilla-thunderbird
~/snap/thunderbird/common/.thunderbird
~/.var/app/org.mozilla.Thunderbird/.thunderbird
```

The profile root is `~/Library/Thunderbird` on macOS and `%APPDATA%\Thunderbird` on Windows.

## Automatic installation

Run the installer from the repository root.

```bash
./install.sh
```

The installer looks for `profiles.ini` and selects the default profile in this order.

1. The directory specified by the `THUNDERBIRD_PROFILE_ROOT` environment variable.
2. Common profile root directories on Linux and macOS.
3. The `Default` value in the `[Install...]` section of `profiles.ini`.
4. The sole profile, if only one exists.

If the installer finds multiple profiles and cannot determine the default, it shows a numbered list and asks you to choose one. If Thunderbird is running, the installer reminds you to restart it.

Use `--profile` to specify a profile directory.

```bash
./install.sh --profile ~/.thunderbird/xxxxxxxx.default-release
```

Use `--accent` to choose a palette.

```bash
./install.sh --accent blue
./install.sh --accent violet
./install.sh --accent mint
```

If you omit `--accent`, the installer uses the palette already configured in the profile.

The installer performs these steps.

- Copies `userChrome.css`, `userContent.css`, and `theme/` to `<profile>/chrome/mdbird`.
- Packages MDBird Search as `<profile>/extensions/mdbird-search@mdbird.local.xpi`.
- Rewrites the managed `@import` block at the top of `<profile>/chrome/userChrome.css` and `userContent.css` so each stylesheet imports MDBird once.
- Adds the `toolkit.legacyUserProfileCustomizations.stylesheets` preference to `<profile>/user.js`.
- Clears `<profile>/startupCache` so Thunderbird reloads all theme files on its next launch.
- Copies existing files to `chrome/.mdbird-backup-<timestamp>` before replacing the theme directory.
- Preserves local changes in `chrome/mdbird/theme/customization.css`.

If `userChrome.css` or `userContent.css` already exists, the installer preserves its contents and inserts the managed block at the top. The block goes first because `@import` must appear before other rules.

After installation, quit Thunderbird completely and restart it. On first installation, open the MDBird Search installation prompt from the application menu in the upper-right corner and select **Enable**. If you dismiss the prompt, you can enable MDBird Search in the Add-ons Manager. The add-on uses Thunderbird's Experiment API to access the main window and mail index.

## Manual installation

### Linux and macOS

Replace `<profile>` with the path to your profile directory and run the following commands.

```bash
mkdir -p "<profile>/chrome/mdbird"
cp -R userChrome.css userContent.css theme "<profile>/chrome/mdbird/"
```

Create or edit `<profile>/chrome/userChrome.css` and add this line at the top.

```css
@import url("mdbird/userChrome.css");
```

Create or edit `<profile>/chrome/userContent.css` and add this line at the top.

```css
@import url("mdbird/userContent.css");
```

Keep any existing rules below the `@import` statements. Thunderbird ignores imports that appear after ordinary style rules.

Create or edit `<profile>/user.js` and add this preference.

```js
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
```

You can also open **Settings > General > Config Editor**, search for `toolkit.legacyUserProfileCustomizations.stylesheets`, and set it to `true`. On each launch, Thunderbird applies the value from `user.js` over the corresponding value in `prefs.js`.

### Windows

The profile directory on Windows is usually at the following path.

```text
%APPDATA%\Thunderbird\Profiles\xxxxxxxx.default-release
```

Create `chrome\mdbird` inside the profile directory and copy the same files as on Linux. Place `userChrome.css` and `userContent.css` in the `chrome` directory and the theme files in `chrome\mdbird`. Enable the custom stylesheets preference using the same steps as on Linux.

### Direct installation in `chrome`

You can also copy `userChrome.css`, `userContent.css`, and `theme/` from the repository directly into `<profile>/chrome/`. The `@import url("theme/...")` paths resolve relative to each entry stylesheet, so this layout works as well. The automatic installer uses the `chrome/mdbird` layout to make it easier to preserve and uninstall the theme.

### Search add-on

Create a ZIP archive from the files in `search-addon/`, including the `_locales/` directory, and change the file extension to `.xpi`. Place `manifest.json` at the root of the archive. In Thunderbird's Add-ons Manager, choose **Install Add-on From File…** from the gear menu. Select the XPI and confirm the installation. [Installing a Thunderbird add-on from a file](https://support.mozilla.org/en-US/kb/installing-addon-thunderbird)

## Verification

After restarting Thunderbird, check the following areas.

- Selected folders have a pill-shaped highlight. The message list and message pane appear as rounded cards.
- The top toolbar hides the global search box by default. At window widths of 900 CSS pixels or more, the tab bar shares a row with the unified toolbar. Open Quick Filter from the message list header.
- Click the magnifying glass in the Spaces Toolbar on the left or use the global search shortcut. Type a keyword and press Enter to view matching messages in a new tab. If the popup says indexing is disabled, select **Turn on search across all email accounts** in **Settings > General**.
- The application menu, message context menu, and attachment menu in the compose window use tonal surfaces.
- Selection colors in Settings, Account Settings, Address Book, and the Add-ons Manager match the active palette.

The screenshots use the vertical three-pane layout and Cards View. To match them, choose **View > Layout > Vertical View**, then select **Cards View** from the message list display options.

If Thunderbird still shows its default appearance, check the following.

1. Thunderbird is running with the profile where you installed MDBird.
2. `toolkit.legacyUserProfileCustomizations.stylesheets` is set to `true`.
3. The `@import` statement in `chrome/userChrome.css` is at the top of the file.
4. Thunderbird was fully quit and restarted.
5. Thunderbird is running in normal mode. Troubleshoot Mode disables custom stylesheets.

## Updates

Run the installer again from the repository directory.

```bash
./install.sh
```

The installer backs up the previous theme directory, replaces the theme files, rewrites the managed import blocks, and clears the startup cache. It preserves the following items.

- Existing rules in `userChrome.css` and `userContent.css`.
- Local overrides in `chrome/mdbird/theme/customization.css`.
- The last selected palette and custom palette files in `theme/palettes/` when you omit `--accent`.

To reset all theme-level overrides, delete `chrome/mdbird/theme/customization.css` and reinstall.

## Uninstallation

```bash
./install.sh --uninstall
```

The uninstaller performs these steps.

- Removes the `chrome/mdbird` directory.
- Removes the MDBird Search XPI from the profile's `extensions/` directory.
- Removes the managed blocks from `chrome/userChrome.css` and `chrome/userContent.css`.
- Clears `<profile>/startupCache` so Thunderbird discards cached theme styles on its next launch.
- Preserves other rules in the stylesheet files and the custom stylesheet preference in `user.js`.
- Preserves the `chrome/.mdbird-backup-*` directories.

Restart Thunderbird after uninstalling. To remove the remaining MDBird settings and backups, delete the corresponding preference line in `user.js` and the backup directories.

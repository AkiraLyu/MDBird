# Installation

MDBird loads through Thunderbird's `userChrome.css` and `userContent.css` stylesheets and pairs with the bundled MDBird Search add-on for sidebar global search. On Linux and macOS, `./install.sh` handles profile discovery, backups, stylesheet wiring, add-on packaging, and cache cleanup automatically; on Windows, copy the files into your profile directory manually.

## Locating your profile directory

Open **Help > Troubleshooting Information** in Thunderbird and look up **Profile Directory** (or **Profile Folder**), which contains `prefs.js`. Common default profile roots by platform are:

| Platform | Profile root |
| --- | --- |
| Linux (native) | `~/.thunderbird` or `~/.mozilla-thunderbird` |
| Linux (Snap) | `~/snap/thunderbird/common/.thunderbird` |
| Linux (Flatpak) | `~/.var/app/org.mozilla.Thunderbird/.thunderbird` |
| macOS | `~/Library/Thunderbird` |
| Windows | `%APPDATA%\Thunderbird\Profiles` |

## Automatic installation (Linux and macOS)

Quit Thunderbird completely, then run the installer from the repository root:

```bash
./install.sh
```

When `--profile` is omitted, the script checks `THUNDERBIRD_PROFILE_ROOT` first, then scans the standard Linux and macOS profile roots for `profiles.ini`, choosing the default entry under `[Install...]` or the sole profile if only one exists. If multiple profiles exist without a single default, it prompts you interactively to pick one. You can pass `--profile` to target a directory directly, `--accent` (`blue`, `violet`, or `mint`) to select a palette, and `--yes` to avoid prompts:

```bash
./install.sh --profile ~/.thunderbird/xxxxxxxx.default-release --accent mint
```

During installation, the script backs up any pre-existing `userChrome.css`, `userContent.css`, `chrome/mdbird/`, and MDBird Search XPI into `chrome/.mdbird-backup-<timestamp>`, installs the theme into `<profile>/chrome/mdbird`, prepends a single managed `@import` block to `<profile>/chrome/userChrome.css` and `userContent.css` while preserving any custom rules below it, writes `user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);` into `<profile>/user.js`, packages `search-addon/` to `<profile>/extensions/mdbird-search@mdbird.local.xpi`, and deletes `<profile>/startupCache` so Thunderbird compiles the fresh stylesheets on next launch.

Restart Thunderbird after the script finishes. On the first launch, open the application menu in the upper-right corner and select **Enable** on the MDBird Search installation notice (or enable **MDBird Search** directly inside the Add-ons Manager).

## Manual installation

Manual installation works identically on Linux, macOS, and Windows. Replace `<profile>` with the path to your Thunderbird profile folder.

1. Copy `userChrome.css`, `userContent.css`, and `theme/` from this repository into `<profile>/chrome/mdbird/`. (Copying them directly into `<profile>/chrome/` also works because internal `@import url("theme/...")` paths resolve relative to each entry file, though keeping a `mdbird/` subdirectory makes updates and removal cleaner.)
2. Add the matching import line to the very top of `<profile>/chrome/userChrome.css` and `<profile>/chrome/userContent.css`, before any other CSS rules so Gecko honors the `@import` statements:

   ```css
   /* <profile>/chrome/userChrome.css */
   @import url("mdbird/userChrome.css");
   ```

   ```css
   /* <profile>/chrome/userContent.css */
   @import url("mdbird/userContent.css");
   ```

3. Enable custom stylesheets either by adding the line below to `<profile>/user.js` or by toggling `toolkit.legacyUserProfileCustomizations.stylesheets` to `true` in **Settings > General > Config Editor**:

   ```js
   user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
   ```

4. To install the sidebar search add-on manually, compress the contents of `search-addon/` (with `manifest.json` at the root of the ZIP archive, alongside `schema.json`, `search.js`, `search.css`, and `_locales/`), rename the archive to `mdbird-search.xpi`, and install it from **Add-ons and Themes > Gear menu > Install Add-on From File…**.
5. Quit Thunderbird completely and restart it.

## Verification and troubleshooting

After restarting, confirm that the three-pane workspace displays rounded content cards over a tinted canvas, the **New Message** button stands out in the primary container color and morphs smoothly on hover and press, the tab bar shares the top row with the unified toolbar on windows 900px or wider, the magnifying glass in the Spaces Toolbar opens the search popup, and menus, Calendar, Tasks, Address Book, Settings, and Compose share the active palette. To match the repository screenshots, select **View > Layout > Vertical View** and enable **Cards View** in the message list display options. If global search reports that indexing is disabled, turn on **Enable Global Search and Indexer** in **Settings > General**.

If Thunderbird still renders its default appearance after a restart, verify these five conditions:

1. Thunderbird launched with the same profile directory where you installed MDBird.
2. `toolkit.legacyUserProfileCustomizations.stylesheets` is `true` in Config Editor.
3. The `@import` line is placed above all ordinary CSS rules in `chrome/userChrome.css` and `chrome/userContent.css`.
4. Thunderbird was fully terminated rather than minimized to the tray before restarting.
5. Thunderbird is not running in Troubleshoot Mode, which disables user stylesheets and add-ons.

## Updating and uninstalling

To update MDBird after pulling new changes, quit Thunderbird and run `./install.sh` again. The script backs up the previous installation, refreshes the theme files and search XPI, rewrites the managed import blocks, clears `startupCache`, and preserves your custom rules in `userChrome.css` and `userContent.css`, local overrides in `chrome/mdbird/theme/customization.css`, and your previously selected or custom palette whenever `--accent` is omitted. To reset local overrides to defaults, remove `chrome/mdbird/theme/customization.css` before reinstalling.

To uninstall MDBird, run:

```bash
./install.sh --uninstall
```

Uninstalling removes `chrome/mdbird/`, the MDBird Search XPI, the managed `@import` blocks, and `startupCache`, while leaving unrelated stylesheet rules, backup folders (`chrome/.mdbird-backup-*`), and `user.js` preferences intact. Restart Thunderbird to return to the stock theme, and delete the `user.js` preference entry or backup directories manually if you no longer need them.

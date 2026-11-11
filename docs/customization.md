# Customization

Choose a palette with the installer or edit the local overrides file in your profile directory. After saving your changes, quit Thunderbird completely and restart it.

## Palettes

```bash
./install.sh --accent violet
```

| Name | Color |
| --- | --- |
| `blue` | Google Blue (default) |
| `violet` | Material 3 violet |
| `mint` | Mint green |

To create a custom palette, copy `chrome/mdbird/theme/palettes/blue.css` to `custom.css` in the same directory. Keep the `@-moz-document` scope and the existing color roles. Change the light and dark values you want to customize. Selections, primary actions, and error states each have their own foreground and background colors. When you change a background, check that its foreground color remains readable.

Import the custom palette in `chrome/mdbird/theme/palette.css`.

```css
@import url("palettes/custom.css");
```

When you run the installer again without `--accent`, it keeps the current palette import and any custom palette files.

## Window appearance

The installer preserves `chrome/mdbird/theme/customization.css`. Use this file to adjust corner radii, spacing, and fonts in windows and mail panes styled by `userChrome.css`.

```css
:root {
  --mdbird-pane-radius: 20px;
  --mdbird-pane-gap: 10px;
  --mdbird-row-radius: 12px;
  --mdbird-nav-radius: 16px;
  --mdbird-font: "Inter", "Noto Sans", system-ui, sans-serif;
}
```

| Variable | Purpose |
| --- | --- |
| `--mdbird-pane-radius` | Corner radius of content cards |
| `--mdbird-pane-gap` | Spacing between mail panes |
| `--mdbird-row-radius` | Corner radius of message cards |
| `--mdbird-nav-radius` | Corner radius of folder and navigation items |
| `--mdbird-font` | Interface font stack |
| `--mdbird-selected-container` | Selection background |
| `--mdbird-on-selected-container` | Selection text color |

## Built-in tabs

In your profile's `chrome/userContent.css`, add content-page overrides after the MDBird import. Scope the rules to the relevant built-in URL. Use `about:preferences` to target Settings.

```css
@import url("mdbird/userContent.css");

@-moz-document url-prefix("about:preferences") {
  :root {
    --mdbird-pane-radius: 20px;
  }
}
```

Thunderbird's dark mode setting for reading messages controls the appearance of HTML messages. Its display and composition settings control the fonts used to read and compose messages.

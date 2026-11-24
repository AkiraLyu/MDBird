# Customization

MDBird supports switching between built-in color palettes, authoring custom palettes, and overriding layout tokens without modifying the core theme stylesheets. After editing any stylesheet in your profile directory, quit Thunderbird completely and restart it so Gecko reloads `userChrome.css` and `userContent.css`.

## Color palettes

Switch among the bundled palettes by passing `--accent` to the installer:

```bash
./install.sh --accent violet
```

| Accent | Description |
| --- | --- |
| `blue` | Google Blue with a cool neutral surface ramp (default) |
| `violet` | Material 3 baseline violet |
| `mint` | Teal-mint primary with cool green-tinted surfaces |

To define a custom palette, copy `chrome/mdbird/theme/palettes/blue.css` inside your profile directory to `custom.css` in the same folder, keep the `@-moz-document` wrapper and all `--md-sys-color-*` role names intact, and update each `light-dark(<light>, <dark>)` pair. Every container role pairs with a matching `--md-sys-color-on-*` foreground role, so verify readable contrast in both light and dark modes whenever you adjust primary, secondary, tertiary, error, or surface colors. Point `chrome/mdbird/theme/palette.css` to your file:

```css
@import url("palettes/custom.css");
```

Re-running `./install.sh` without `--accent` preserves both your current `theme/palette.css` import and any custom files in `theme/palettes/`.

## Window layout and typography

The installer preserves `chrome/mdbird/theme/customization.css` across updates. Add `:root` overrides there to adjust card geometry, pane spacing, typography, or selection colors across chrome windows and mail panes:

```css
:root {
  --mdbird-pane-radius: 20px;
  --mdbird-pane-gap: 10px;
  --mdbird-row-radius: 12px;
  --mdbird-nav-radius: 16px;
  --mdbird-font: "Google Sans Flex", "Inter", "Noto Sans", system-ui, sans-serif;
}
```

| Token | Default | Effect |
| --- | --- | --- |
| `--mdbird-pane-radius` | `24px` (`18px` at ≤ 800px) | Corner radius of major workspace cards |
| `--mdbird-pane-gap` | `8px` (`5px` at ≤ 800px) | Outer margin around panes and splitter spacing between them |
| `--mdbird-row-radius` | `14px` | Corner radius of message cards and list rows |
| `--mdbird-nav-radius` | `var(--md-sys-shape-corner-full)` | Corner radius of folder tree, category, and sidebar items |
| `--mdbird-shape-pill` | `max(24px, 1.5em)` | Bounded pill radius used by spring-morphing buttons and chips |
| `--mdbird-font` | `"Google Sans Flex", "Google Sans", ...` | UI font stack across windows, menus, and built-in pages |
| `--mdbird-selected-container` | `var(--md-sys-color-secondary-container)` | Fill color for selected tabs, folders, and list items |
| `--mdbird-on-selected-container` | `var(--md-sys-color-on-secondary-container)` | Text and icon color on selected containers |

## Built-in content tabs

Because `theme/customization.css` is imported only by `userChrome.css`, overrides for built-in content pages such as Settings, Account Settings, Address Book, or Add-ons belong in `<profile>/chrome/userContent.css` below the managed MDBird import block. Scope those rules to the target `about:` document so they never leak into rendered email messages:

```css
@import url("mdbird/userContent.css");

@-moz-document url-prefix("about:preferences") {
  :root {
    --mdbird-pane-radius: 20px;
  }
}
```

HTML email rendering remains governed by Thunderbird's own display, font, composition, and dark reading settings rather than MDBird's UI tokens.

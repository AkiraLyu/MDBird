# Design

MDBird adapts Material Design 3 Expressive (M3E) principles to Thunderbird's desktop workspace, taking layout cues from Gmail while keeping Thunderbird's native commands, layouts, and accessibility behaviors intact. Rather than redrawing application widgets from scratch, the theme maps M3E color, shape, elevation, typography, and spring motion tokens onto Thunderbird's Bolt variables, Gecko toolkit tokens, and document-scoped component rules.

## Stylesheet architecture

Thunderbird renders its interface across separate chrome and content documents, so MDBird splits styling between two profile entry points that share a common foundation:

| Path | Role |
| --- | --- |
| `userChrome.css` | Entry point for main windows, standalone message and compose windows, and privileged mail panes |
| `userContent.css` | Entry point for built-in content tabs, plain-text email bodies, and the compose editor iframe |
| `theme/palette.css` | Selects one active palette (`blue`, `violet`, `mint`, or a user palette) for both entry points |
| `theme/tokens.css` | Defines shared M3E surface aliases, corner scale, dual-layer shadows, state layers, spring curves, and type sizes |
| `theme/interface.css` | Maps tokens to Thunderbird Bolt and Gecko variables and styles shared controls, menus, dialogs, and built-in pages |
| `theme/components/` | Styles the top bar, navigation rail and folder tree, message list, message reader, compose window, spaces, and XUL menus |
| `theme/pages/` | Styles Settings, Account Settings, Address Book, Account Central, global search, Add-ons, Import, Downloads, management dialogs, and error pages |
| `theme/message-content.css` | Applies margins and quote colors to plain-text MIME wrappers and matches the compose editor background |
| `search-addon/` | MailExtension Experiment that adds the sidebar search button, search popup, and global search shortcut wiring |

Both `userChrome.css` and `userContent.css` import `theme/interface.css`, which restricts its rules with `@-moz-document` to Thunderbird's built-in `chrome://` packages and internal `about:` pages so web content and sender-formatted HTML messages remain untouched. Plain-text messages are matched only when Thunderbird's `.moz-text-plain` or `.moz-text-flowed` wrapper is present without a sibling `.moz-text-html` part, and the compose editor is targeted solely through its dedicated `about:blank?compose` URL without altering body font or text color attributes that outgoing drafts serialize.

## Color, shape, and motion system

Every shipped palette in `theme/palettes/` defines a complete light and dark Material 3 color scheme using CSS `light-dark()`, including primary, secondary, tertiary, error, inverse, outline, scrim, and six surface container steps (`surface-container-lowest` through `surface-container-highest`). Content cards rest on `surface-container-lowest` in light mode and `surface` in dark mode over a `surface-container-low` workspace canvas, creating crisp figure-ground separation in both schemes. Primary creation actions—New Message, New Event, New Task, and New Contact—use `primary-container` Extended FABs, while active navigation destinations, tabs, and selected rows use `secondary-container` so primary actions retain clear hierarchy even in dark mode. Under `forced-colors: active`, all palette tokens, shadows, and container borders fall back to standard system color keywords so high-contrast modes remain legible.

MDBird implements the M3E corner scale across `4px`, `8px`, `12px`, `16px`, `20px` (`large-increased`), `28px` (`extra-large`), and `999px` (`full`), paired with a bounded pill token (`--mdbird-shape-pill: max(24px, 1.5em)`) for controls that animate `border-radius`. Using a bounded pill radius prevents CSS spring overshoot from crossing zero into sharp corners during shrink transitions and keeps the visual morph distributed evenly across the transition duration. Motion separates spatial shape morphing (`350ms cubic-bezier(0.42, 1.67, 0.21, 0.9)`) from non-overshooting color and elevation transitions (`150ms cubic-bezier(0.31, 0.94, 0.34, 1)`), and all animations are gated behind `@media (prefers-reduced-motion: no-preference)`.

## Components and layout boundaries

Extended FABs transition from `16px` rounded rectangles to pills on hover or keyboard focus and compress to `12px` on press; standard and primary buttons morph from pills to `8px`–`12px` on press; connected button groups (calendar view switching, calendar navigation, and application menu density and font-size controls) pair outer pill edges with `8px` inner corners and expand the selected segment to a full pill; and split buttons in the message header and compose toolbar separate the primary action and dropdown trigger with a `2px` gap and `4px` inner corners. Focus outlines on virtualized message and contact lists activate through `:has(:focus-visible)` so keyboard navigation stays unmistakable while pointer clicks leave selected cards borderless.

Layout customizations defer to Thunderbird whenever native geometry must remain authoritative. Virtualized row heights in `#threadTree` and Address Book `#cards` stay under Thunderbird's control, while card styling applies inside `.card-container`. On windows 900 CSS pixels wide or wider, `#titlebar` arranges `#tabs-toolbar` beside `unified-toolbar` and gives `#toolbar-menubar` its own full-width row when enabled; narrower windows and the unified toolbar customization view revert to Thunderbird's native layout. In the compose window, the formatting bar sits as an elevated floating pill above the bottom action bar while `#compose-toolbox` preserves its layout box whenever toolbar customization is active, and in the message reader `#messageHeader` caps its height at `50vh` with unified scrolling so long subjects and wrapped recipient lists never push the message body off screen.

XUL `menupopup` and `panel` elements apply M3E surface, elevation, and rounded item styling while letting Thunderbird manage subviews, keyboard navigation, and checkmarks; on Linux environments without GTK client-side decoration transparency, popup corner radii revert to `0px` to avoid opaque corner artifacts. HTML popups in built-in pages such as the Add-ons Manager inherit matching surface and item tokens through `panel-list` and `panel-item`.

## Global search integration

Because MDBird hides the unified toolbar search field to keep the top row compact, `search-addon/` registers a MailExtension Experiment that appends a search button to the Spaces Toolbar, anchors a themed `<panel>` search view to it, and intercepts Thunderbird's built-in global search command (`glodaSearchCmd`) and keyboard shortcut (`key_quickSearchFocus`). Submitting a query invokes `GlodaMsgSearcher` (and `GlodaIMSearcher` when chat is enabled) and opens results in either faceted or list view according to `gloda.show_as_list_by_default`. Disabling or uninstalling the add-on tears down the injected button, popup, stylesheet, and event listeners cleanly.

## CSS cascade and specificity

User stylesheets sit in the CSS user origin, where normal declarations lose to Thunderbird's author-origin rules. MDBird therefore marks component overrides with `!important` where required, while leaving layout and customization tokens in `theme/tokens.css` at normal priority so local overrides in `theme/customization.css` or profile entry stylesheets take effect without fighting specificity.

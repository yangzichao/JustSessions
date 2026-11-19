# UI style

The app's views draw with the values in `Sources/JustSessions/Views/Theme/`. They do not set their own colors, font sizes, corner radii, shadows, or animation timings. This keeps the same kind of control looking the same everywhere, and it lets a theme change reach every view.

The contract tests in `Tests/JustSessionsTests/Contracts/UIStyle/` read the view source and fail `make test` when a view breaks a rule below. Each failure lists the file and line and names the token to use.

## Where the rules apply

The rules cover every Swift file under `Sources/JustSessions/Views/`, with two exceptions:

- `Theme/` itself, where the tokens are defined.
- Miniature drawings: the theme thumbnails in `Settings/Appearance/App/Sketch/` and the app mark in `Branding/`. They scale the window down and do not follow the spec.

The transcript's conversation text follows the reading text size, so it sets its size from a variable. The terminal is drawn by SwiftTerm and follows **Settings → Appearance → Terminal**.

## Colors

Use `ThemePalette` for every foreground, fill, stroke, background, and tint:

| Use | Token |
| --- | --- |
| Window, sidebar, and raised surfaces | `contentSurface`, `sidebarSurface`, `raisedSurface` |
| Primary text and filled controls | `ink`, with `inkForeground` on top of it |
| Secondary and tertiary text | `secondaryText`, `tertiaryText` |
| Hover, pressed, track, and hairline | `hoverFill`, `pressedFill`, `trackFill`, `hairline` |
| Status | `live`, `warning`, `unseenTurn`, `warningText`, `errorText` |
| A CLI's hue | `ConversationProvider.tintColor` |

The system's `.primary` and named colors ignore the chosen theme. Its `.secondary` and `.tertiary` text falls below 4.5 contrast on the light themes. `ThemePalette`'s text colors are readable on every surface they sit on.

`.foreground` and `.tint` are allowed. They take the color the enclosing view already set.

Enforced by `UIColorContractTests`.

## Typography

Set text in `ThemeFont`:

| Token | Size | Use |
| --- | --- | --- |
| `title` | 17 semibold | Sheet, Settings page, selected session, and reading window titles |
| `heading` | 13 semibold | Section headings and card titles |
| `body` | 13 | Text to read and Settings row labels |
| `callout` | 12 | Sidebar rows, tabs, buttons, and supporting copy under a title or field |
| `fieldLabel` | 11 medium | A field's label and a row title on a Settings page |
| `detail` | 11 | A row's second line, counts, and paths |
| `caption` | 10 | The smallest copy, such as a message count |

Add `.weight(_:)` for emphasis, `.monospacedDigit()` for counts that change, and `.monospaced()` for code and paths.

Draw a standalone SF Symbol with `ThemeFont.glyph(_:weight:)` at a `ThemeGlyphSize`:

| Size | Points | Use |
| --- | --- | --- |
| `statusDot` | 7 | A running or ended CLI's dot |
| `statusMark` | 8 | An unseen turn's dot and the pin |
| `small` | 9 | Disclosure chevrons, a tab's close button |
| `control` | 10 | Icon buttons in headings and toolbars, a checkbox's check, a CLI icon in a row |
| `titleBar` | 14 | The sidebar toggle |
| `badge` | 15 | The CLI icon in the selected session's badge |
| `emptyState` | 24 | The icon above an empty list's message |

A symbol inline with text uses the text's font.

The sizes above are at the default interface size. **Settings → Appearance → Interface size** (`InterfaceSizeStore`, 90% to 150%) scales every token, and a view drawing with one redraws when it changes, since SwiftUI follows the `@Observable` store a body reads; read tokens in a body, not into a stored property, or the text keeps its old size. A number that holds text or a symbol, such as a row's height, an icon button's frame, or a sheet's width, goes through `InterfaceScale.points(_:)` so it grows with its text; spacing and margins stay as they are. The tab bar keeps its height, level with the window's buttons. Each window's root gives text that names no font `ThemeFont.body`, and the system's controls `InterfaceScale.controlSize`.

Enforced by `UITypographyContractTests`. The test rejects `.system(size: <number>)` and the system text styles (`.headline`, `.caption`, and the rest).

## Corner radii

Draw rounded shapes with `RoundedRectangle(_ radius: ThemeCornerRadius)`. It always uses continuous corners, as macOS controls do.

| Radius | Points | Use |
| --- | --- | --- |
| `checkbox` | 3 | A checkbox |
| `small` | 4 | Keycaps, inline code chips, small heading buttons, a segment inside a track |
| `control` | 6 | Text and search fields, sidebar rows, segmented tracks, tab group labels, compact buttons |
| `card` | 8 | Buttons, tables, framed lists, the terminal preview |
| `panel` | 10 | Code blocks, images, your messages in a transcript, Settings cards, the track holding a split across projects' two tabs |

A shape nested inside another uses the next smaller radius, so the corners stay concentric. A handle or bar with fully rounded ends is a `Capsule()`, and a round icon button is a `Circle()`.

Enforced by `UICornerRadiusContractTests`. The test rejects a number assigned to any `cornerRadius` argument or constant.

## Buttons and controls

Each button takes one of the theme's styles:

| Kind | Style |
| --- | --- |
| A view's one primary action | `ThemeProminentButtonStyle`, filled with ink |
| A primary action that starts a CLI (Resume, Start session) | `ProviderProminentButtonStyle`, filled with that CLI's hue. Like the ink button, it has no gradient or shadow. |
| Every other text button, including Cancel | `QuietBorderedButtonStyle`. Use `role: .destructive` to show the label in `errorText`. |
| Icon buttons and row actions | `ThemePlainButtonStyle`. Use `cornerRadius: nil` for a round button. |
| A text link | `ThemePlainButtonStyle(verticalPadding: 2)` |
| A label that already draws its own hover and selection | `ThemePressButtonStyle` |

Use `ThemedCheckboxToggleStyle` for checkboxes, `ThemedTextFieldStyle` for text fields, `ThemeSegmentedPicker` in place of a segmented `Picker`, and `ThemeDivider()` for lines between views. A custom search field may use `.textFieldStyle(.plain)` inside the themed surface it draws. `Divider()` is allowed only inside menus, pickers, and commands, where macOS draws the separator.

A `DisclosureGroup` takes its title as `ThemeDisclosureTitleButton`, so a click on the title opens it as a click on the chevron does.

Enforced by `UIControlStyleContractTests`. The test rejects the system button, toggle, and text field styles, `.pickerStyle(.segmented)`, `Divider()` outside menu code, and a `DisclosureGroup` without `ThemeDisclosureTitleButton`.

## Sheets

Lay out every sheet with `ThemeSheetLayout`. It owns the following:

- The title in `ThemeFont.title`, with an optional accessory such as a help button.
- An optional intro line in `callout` and `secondaryText`.
- The content, then the footer.
- The 20pt margin and 16pt spacing between sections.
- The content surface.
- A quiet default button style for everything inside the sheet.

Pick `ThemeSheetMetrics.compactWidth` (480) for a sheet with one field or a short list, and `regularWidth` (520) for a sheet with several sections.

The footer puts progress first, then a `Spacer`, then Cancel and the default action. The default action names `ThemeProminentButtonStyle`, or `ProviderProminentButtonStyle` when it starts a CLI, on the lines just before its `.keyboardShortcut(.defaultAction)`.

Settings is the exception. Its sheet switches pages under a tab picker, the pages share one size, and each lays out with `SettingsTabPage`.

Enforced by `UISheetContractTests`.

## Shadows and motion

Surfaces are flat. Only something that floats casts a shadow, through `.themeShadow(_:)`:

- `.floating` for a tab's hover card, a dragged row, or a terminal's find bar.
- `.raisedSegment` for the selected segment in a track.

Animate with `ThemeMotion`:

- `disclosure` (0.12s ease-out) for a chevron turning.
- `slide` (0.15s ease-out) for tabs, groups, and pinned rows moving into place.

Enforced by `UIShadowAndMotionContractTests`. The test rejects `.shadow(` and literal animation durations.

## Spacing

Spacing is **not** enforced yet. Views set about 270 spacing and padding values locally. Prefer these values:

- 2, 4, and 6 inside a control.
- 8 and 12 between controls in a row or group.
- 16 between sections.
- 20 and 24 for window and sheet margins.

Sheet margins and section spacing come from `ThemeSheetMetrics`. Settings pages take theirs from `SettingsTabPage`.

## Adding to the spec

If a view needs a value the tokens do not have, add a case to the token in `Theme/`, named for the kind of element it is for. Then use the new case from the view. Do not exempt the view in the test. A value should be added to the theme only when it describes a kind of UI element, not a one-off.

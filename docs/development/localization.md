# Interface localization

`Localization/Localizable.xcstrings` is the translation source. Edit it with Xcode's String Catalog editor or as JSON. The English source strings are extracted by the Swift compiler; keys, interpolations, and plural variations use Apple's localization formats. Never edit the generated `.strings` or `.stringsdict` files in `Sources/JustSessions/Resources/Localization/`.

## Add a language

1. Add the language to the String Catalog and translate its entries. Mark product names or symbols that should remain unchanged with `shouldTranslate: false`.
2. Run `make localization`. This extracts current Swift UI strings, synchronizes the catalog, validates translations, and compiles the resources.
3. Run `make localization-check` and `make test`, then build with `make` and inspect the language in General settings.
4. Commit the catalog and generated resources together.

No Swift enum, picker options, language-specific conditionals, or packaging lists need updating. The picker discovers localizations from the resource bundle and displays each language in its native name, including its region or script where applicable. The app bundle's declared localizations are generated from the packaged resources.

## Add UI copy

Use SwiftUI's localized initializers, such as `Text("New session")` and `Button("Save")`. For a label passed between views, use `LocalizedStringKey` rather than `String`. For native AppKit panels, use `AppLocalization.string("Export")`; its argument is a compiler-extractable `String.LocalizationValue`. For an explicit stable key or custom table, use `AppLocalization.string(resource:)` with a `LocalizedStringResource`; it preserves the key, default value, table, and bundle. Use interpolations in complete sentences instead of assembling translated words or adding English plural suffixes.

Keep session titles, paths, transcript text, CLI names, and other user data verbatim. Never treat an arbitrary user string as a translation key. Native CLI output and operating-system-owned dialogs keep their own language.

For count labels, configure plural variations in the catalog, including English. The generated `.stringsdict` applies each language's grammar; a label such as `Resume \(count) sessions` can render “Resume 1 session” without any language-specific Swift branches.

Run `make localization` after changing UI copy. Newly extracted strings must be translated before compilation passes. `make localization-check`, also run by `make verify`, detects uncatalogued or stale UI strings, missing translations, incompatible format arguments, and generated resources that do not match the catalog. Catalog compilation uses `xcstringstool`, including its support for plural rules and substitutions.

## Runtime behavior

Follow System is the default and is stored by removing the override. Matching uses the ordered system language preferences, Foundation's region/script matching, and the English development language as fallback. Language identifiers are canonicalized because SwiftPM lowercases localization directory names. Invalid preferences or a removed translation are cleared and recover to Follow System. System locale change notifications refresh existing views when they follow the system.

Workspace, Settings, Help, and independent reading windows receive the same locale through `appLanguage`. Updating that environment preserves view identity; it does not recreate terminals or conversation stores. Native panels resolve the saved choice through the same resource bundle.

Tests cover persistence, system language matching, fallback, interpolated user values, existing-view lifetime, and a temporary Japanese resource bundle that adds a language without any application-code changes.

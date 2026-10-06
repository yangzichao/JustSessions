# Accessibility

JustSessions aims to make finding, reading, and resuming CLI sessions usable by people with different access needs. Accessibility improvements and reports are welcome for the native macOS app, its documentation, and the product website.

## Supported environment and available controls

The distributed app supports macOS 14 or later on Apple Silicon. Its interface uses SwiftUI and AppKit, and its embedded terminal uses SwiftTerm. The app provides:

- Adjustable conversation reading text size and reading width.
- Terminal font, size, and color settings, and light, dark, or system appearance.
- Keyboard shortcuts for common actions, documented in the [session management guide](docs/guides/session-management.md#tab-keyboard-shortcuts) and **Settings → Help**.
- English and Chinese interface translations.

The [website](https://yangzichao.github.io/JustSessions/) and documentation can also be read without installing the app.

## Limitations and verification

Complete VoiceOver coverage, full keyboard access, and every theme's contrast have not been verified across all supported macOS versions. This statement does not claim conformance with a particular accessibility standard.

Embedded terminal behavior also depends on SwiftTerm and the CLI running inside it. CLI output, its colors, and its interactive controls can differ from the native app's controls. Custom themes and imported terminal color schemes may need adjustment for your contrast needs.

## Report an accessibility barrier

Use the [accessibility issue form](https://github.com/yangzichao/JustSessions/issues/new?template=accessibility_report.yml), or email [zichaoyangphys@gmail.com](mailto:zichaoyangphys@gmail.com) if GitHub is difficult to use.

Include the affected screen or website page, app and macOS versions or browser, any assistive technology and settings you use, steps to reproduce, and what you expected to happen. Screenshots or recordings are optional; remove private conversation content and identifying information before sharing them.

We will use reports to reproduce barriers and prioritize improvements. Contributors should include relevant keyboard, focus, text size, contrast, and assistive technology checks when changing a user interface. See [contributing](CONTRIBUTING.md) for the development and verification process.

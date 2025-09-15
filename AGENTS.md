# Repository Guidelines

## Project Structure & Module Organization
- App code: `Stitch/` (Swift, SwiftUI). Extension: `StitchQuickLookExtension/`.
- Tests: `StitchTests/` (XCTest). Mirror the source layout; use `*Tests.swift`.
- Docs and assets: `Guides/`, `README_Assets/`, `public/`.
- CI helpers: `ci_scripts/` (e.g., `ci_pre_xcodebuild.sh` writes `secrets.json`).
- Xcode project: `Stitch.xcodeproj`, test plan: `Stitch.xctestplan`.

## Build, Test, and Development Commands
- Open in Xcode: open `Stitch.xcodeproj`, select the `Stitch` scheme, run.
- CLI build (Debug macOS): `xcodebuild -scheme Stitch -configuration Debug build`.
- Run tests (macOS): `xcodebuild -scheme Stitch -destination 'platform=macOS' test`.
- Run tests (iOS sim): `xcodebuild -scheme Stitch -destination 'platform=iOS Simulator,name=iPhone 15' test`.
- Lint Swift: `swiftlint` (install via Homebrew). Config lives in `.swiftlint.yml`.

## Coding Style & Naming Conventions
- Swift style enforced by SwiftLint. Key rules: `line_length: 120`, `vertical_whitespace: 2`; several complexity rules are disabled to favor iteration.
- Use 4-space indentation; Unix line endings; UTF-8.
- Names: Types `UpperCamelCase`, methods/properties `lowerCamelCase`, constants `lowerCamelCase`.
- SwiftUI: prefer explicit `.position` vs `.offset` consistently when laying out views.

## Testing Guidelines
- Framework: XCTest. Derive from `XCTestCase`; test methods start with `test`.
- File naming: `FeatureNameTests.swift`; keep focused, deterministic tests.
- Location: add new tests under `StitchTests/` mirroring source folders.
- Run locally with Xcode or `xcodebuild ... test` (examples above).

## Commit & Pull Request Guidelines
- Commits: present tense, concise, describe intent. Include PR reference like `(#123)` when applicable.
  - Examples: `Fix crash on empty graph`, `Handle .overlay views in parser (#1630)`.
- PRs: clear description, what/why, linked issues, steps to test, screenshots or clips for UI changes.
- Keep changes scoped; update docs (`Guides/`, `README.md`) and tests when behavior changes.

## Security & Configuration Tips
- Do not commit secrets. In CI, `ci_scripts/ci_pre_xcodebuild.sh` writes `secrets.json` from environment variables.
- For local development, you may create a local `secrets.json`; never push real keys.
- Update bundle IDs and Development Team for both `Stitch` and `StitchQuickLookExtension` targets; enable CloudKit per README.


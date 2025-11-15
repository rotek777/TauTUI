# TauTUI

TauTUI is an idiomatic Swift 6 port of [@mariozechner/pi-tui](https://github.com/badlogic/pi-mono/tree/main/packages/tui), Mario Zechner’s TypeScript terminal UI framework. It delivers the same feature set—differential rendering with synchronized output, bracketed paste handling, slash/file autocomplete, Markdown/Text components, SelectLists, spinners, editor, and VirtualTerminal harness—expressed with Swift concurrency, value types, and strong typing.

## Features
- **Differential renderer** with CSI 2026 synchronized output and resize-aware fallbacks.
- **Terminal plumbing**: raw-mode `ProcessTerminal`, key/modifier normalization, optional `VirtualTerminal` for tests.
- **Rich editor + autocomplete**: slash-command + filesystem completion, Tab-forced suggestions, paste markers, modifier-aware shortcuts.
- **Components**: Markdown (with RGB background/foreground), Text, Input, SelectList, Loader, Spacer, plus utilities like `VisibleWidth`.
- **Examples & tools**: `ChatDemo` mirrors `test/chat-simple.ts`, and `KeyTester` is the Swift rewrite of pi-tui’s key logger.
- **Tests**: SwiftPM test suite ports the Node specs (markdown rendering, autocomplete, editor behaviors, renderer snapshots).

## Quick Start

Add TauTUI as a dependency and build an app:

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    dependencies: [
        .package(url: "https://github.com/yourname/TauTUI.git", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "Demo",
            dependencies: [
                .product(name: "TauTUI", package: "TauTUI"),
            ]
        )
    ]
)
```

```swift
import TauTUI

let terminal = ProcessTerminal()
let tui = TUI(terminal: terminal)
let text = Text(text: "Welcome to TauTUI!")
let editor = Editor()
editor.onSubmit = { value in
    tui.addChild(MarkdownComponent(text: value))
    tui.requestRender()
}
tui.addChild(text)
tui.addChild(editor)
tui.setFocus(editor)
try tui.start()
RunLoop.main.run()
```

## Examples
- `swift run ChatDemo` — Chat-like UI with slash commands, autocomplete, loader, and Markdown components.
- `swift run KeyTester` — Interactive logger that prints raw input, modifiers, and codes for debugging terminal keybindings.

## Platform Support
- ✅ macOS 13+ (Swift 6)
- ✅ Linux (glibc)
- ❌ Windows consoles (not supported)

## Credits
Huge thanks to Mario Zechner and the pi-tui contributors—the architecture, rendering strategy, and component APIs originate from their work. See `docs/spec.md` for the full migration plan and roadmap.

import Testing
@testable import TauTUI

@Suite("TTY replayer")
struct TTYReplayerTests {
    @Test
    func replaysEditorScript() async throws {
        let script = TTYScript(
            columns: 40,
            rows: 10,
            events: [
                TTYEvent(type: .key, data: "H", modifiers: nil, columns: nil, rows: nil, ms: nil),
                TTYEvent(type: .key, data: "i", modifiers: nil, columns: nil, rows: nil, ms: nil),
                TTYEvent(type: .key, data: "enter", modifiers: nil, columns: nil, rows: nil, ms: nil),
                TTYEvent(type: .paste, data: "there", modifiers: nil, columns: nil, rows: nil, ms: nil),
            ])

        let result = try await MainActor.run {
            try replayTTY(script: script) { vt in
                let tui = TUI(terminal: vt)
                let editor = Editor()
                tui.addChild(editor)
                tui.setFocus(editor)
                return tui
            }
        }

        let log = result.outputLog.joined(separator: "")
        #expect(log.contains("Hi"))
        #expect(log.contains("there"))
    }
}

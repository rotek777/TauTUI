import Foundation
import Testing
@testable import TauTUI

private struct TestCommand: SlashCommand {
    let name: String
    let description: String? = nil
    func argumentCompletions(prefix: String) -> [AutocompleteItem] { [] }
}

@Suite("Editor")
struct EditorTests {
    @Test
    func typingAndSubmitResetsState() async throws {
        let editor = Editor()
        var submitted: String?
        editor.onSubmit = { submitted = $0 }
        editor.handle(input: .raw("hello"))
        editor.handle(input: .key(.enter))
        #expect(submitted == "hello")
        #expect(editor.getText().isEmpty)
    }

    @Test
    func newlineCreatesSecondLine() async throws {
        let editor = Editor()
        editor.handle(input: .raw("hello"))
        editor.handle(input: .raw("\nworld"))
        #expect(editor.getText() == "hello\nworld")
    }

    @Test
    func backspaceMergesLines() async throws {
        let editor = Editor()
        editor.setText("hello\nworld")
        editor.handle(input: .key(.home))
        editor.handle(input: .key(.backspace))
        #expect(editor.getText() == "helloworld")
    }

    @Test
    func largePasteMarkerReplacedOnSubmit() async throws {
        let editor = Editor()
        var submitted: String?
        editor.onSubmit = { submitted = $0 }
        let pasted = (0..<20).map { "line \($0)" }.joined(separator: "\n")
        editor.handle(input: .paste(pasted))
        #expect(editor.getText().contains("[paste #1"))
        editor.handle(input: .key(.enter))
        #expect(submitted == pasted)
    }

    @Test
    func ctrlUAndCtrlKDeleteSegments() async throws {
        let editor = Editor()
        editor.setText("hello world")
        editor.handle(input: .key(.home))
        editor.handle(input: .key(.character("k"), modifiers: [.control]))
        #expect(editor.getText().isEmpty)

        editor.setText("hello world")
        editor.handle(input: .key(.end))
        editor.handle(input: .key(.character("u"), modifiers: [.control]))
        #expect(editor.getText().isEmpty)
    }

    @Test
    func ctrlWDeletesWordBackwards() async throws {
        let editor = Editor()
        editor.setText("hello world")
        editor.handle(input: .key(.end))
        editor.handle(input: .key(.character("w"), modifiers: [.control]))
        #expect(editor.getText() == "hello ")
    }

    @Test
    func ctrlAMovesToStartAndCtrlEMovesToEnd() async throws {
        let editor = Editor()
        editor.setText("hello world")
        editor.handle(input: .key(.character("a"), modifiers: [.control]))
        editor.handle(input: .key(.character("x")))
        #expect(editor.getText().hasPrefix("x"))

        editor.handle(input: .key(.character("e"), modifiers: [.control]))
        editor.handle(input: .key(.character("!")))
        #expect(editor.getText().hasSuffix("!"))
    }

    @Test
    func optionBackspaceDeletesWord() async throws {
        let editor = Editor()
        editor.setText("hello world")
        editor.handle(input: .key(.end))
        editor.handle(input: .key(.backspace, modifiers: [.option]))
        #expect(editor.getText() == "hello ")
    }

    @Test
    func optionDeleteForwardDeletesWord() async throws {
        let editor = Editor()
        editor.setText("hello world")
        editor.handle(input: .key(.home))
        editor.handle(input: .key(.delete, modifiers: [.option]))
        #expect(editor.getText() == " world")
    }

    @Test
    func optionEnterAddsNewlineNotSubmit() async throws {
        let editor = Editor()
        editor.setText("hello")
        editor.handle(input: .key(.enter, modifiers: [.option]))
        #expect(editor.getText() == "hello\n")
    }

    @Test
    func vscodeShiftEnterSequenceAddsNewline() async throws {
        let editor = Editor()
        editor.handle(input: .raw("\\\r"))
        #expect(editor.getText() == "\n")
    }

    @Test
    func tabForcesFileAutocomplete() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }
        FileManager.default.createFile(atPath: temp.appendingPathComponent("hello.txt").path, contents: Data())

        let provider = CombinedAutocompleteProvider(basePath: temp.path)
        let editor = Editor()
        editor.setAutocompleteProvider(provider)

        editor.handle(input: .raw("hel"))
        editor.handle(input: .key(.tab)) // show suggestions
        editor.handle(input: .key(.tab)) // accept first item

        #expect(editor.getText().contains("hello.txt"))
    }

    @Test
    func slashCommandsTabComplete() throws {
        let provider = CombinedAutocompleteProvider(commands: [TestCommand(name: "clear")])
        let editor = Editor()
        editor.setAutocompleteProvider(provider)

        editor.handle(input: .raw("/cl"))
        editor.handle(input: .key(.tab))
        editor.handle(input: .key(.tab))

        #expect(editor.getText().hasPrefix("/clear "))
    }

    @Test
    func pasteFiltersControlCharacters() throws {
        let editor = Editor()
        editor.handle(input: .paste("\tcolumn\u{0007}\nline"))
        let text = editor.getText()
        #expect(text.contains("    column"))
        #expect(!text.contains("\u{0007}"))
    }

    @Test
    func arrowLeftAndRightMoveCursor() throws {
        let editor = Editor()
        editor.setText("hi")
        editor.handle(input: .key(.arrowLeft))
        editor.handle(input: .raw("X"))
        #expect(editor.getText() == "hXi")
        editor.handle(input: .key(.arrowRight))
        editor.handle(input: .raw("!"))
        #expect(editor.getText() == "hXi!")
    }

    @Test
    func arrowUpAndDownNavigateLines() throws {
        let editor = Editor()
        editor.setText("foo\nbar")
        editor.handle(input: .key(.arrowUp))
        editor.handle(input: .raw("*"))
        #expect(editor.getText().starts(with: "foo*"))
        editor.handle(input: .key(.arrowDown))
        editor.handle(input: .raw("!"))
        #expect(editor.getText().hasSuffix("bar!"))
    }

    @Test
    func homeAndEndKeysMoveToLineBounds() throws {
        let editor = Editor()
        editor.setText("hello")
        editor.handle(input: .key(.home))
        editor.handle(input: .raw("X"))
        #expect(editor.getText() == "Xhello")
        editor.handle(input: .key(.end))
        editor.handle(input: .raw("!"))
        #expect(editor.getText() == "Xhello!")
    }

    @Test
    func deleteKeyRemovesForwardCharacters() throws {
        let editor = Editor()
        editor.setText("hello")
        editor.handle(input: .key(.home))
        editor.handle(input: .key(.delete))
        #expect(editor.getText() == "ello")
    }

    @Test
    func deleteKeyMergesNextLine() throws {
        let editor = Editor()
        editor.setText("foo\nbar")
        editor.handle(input: .key(.home))
        editor.handle(input: .key(.arrowUp))
        editor.handle(input: .key(.end))
        editor.handle(input: .key(.delete))
        #expect(editor.getText() == "foobar")
    }
}

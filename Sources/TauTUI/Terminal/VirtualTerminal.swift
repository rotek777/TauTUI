import Foundation

/// Lightweight terminal implementation for unit tests. It does not attempt to
/// emulate cursor movement; instead it records every write so tests can inspect
/// ANSI sequences and payloads emitted by the renderer.
public final class VirtualTerminal: Terminal {
    public private(set) var columns: Int
    public private(set) var rows: Int
    public private(set) var outputLog: [String] = []

    private var scrollback: [String] = []
    private var pendingLine: String = ""
    private let scrollbackLimit = 4000

    private var inputHandler: ((TerminalInput) -> Void)?
    private var resizeHandler: (() -> Void)?
    private var isRunning = false

    public init(columns: Int = 80, rows: Int = 24) {
        self.columns = max(1, columns)
        self.rows = max(1, rows)
    }

    public func start(
        onInput: @escaping (TerminalInput) -> Void,
        onResize: @escaping () -> Void) throws
    {
        guard !self.isRunning else { throw TerminalError.alreadyRunning }
        self.isRunning = true
        self.inputHandler = onInput
        self.resizeHandler = onResize
    }

    public func stop() {
        self.isRunning = false
        self.inputHandler = nil
        self.resizeHandler = nil
    }

    public func write(_ data: String) {
        self.outputLog.append(data)
        self.captureOutput(data)
    }

    public func moveBy(lines: Int) {
        // For completeness we record cursor movement.
        guard lines != 0 else { return }
        let sequence = lines > 0 ? "\u{001B}[\(lines)B" : "\u{001B}[\(-lines)A"
        self.outputLog.append(sequence)
    }

    public func hideCursor() {
        self.outputLog.append("\u{001B}[?25l")
    }

    public func showCursor() {
        self.outputLog.append("\u{001B}[?25h")
    }

    public func clearLine() {
        self.outputLog.append("\u{001B}[K")
    }

    public func clearFromCursor() {
        self.outputLog.append("\u{001B}[J")
    }

    public func clearScreen() {
        self.outputLog.append("\u{001B}[2J\u{001B}[H")
    }

    public func flush() {}

    public func flushAndGetViewport() -> [String] {
        self.flush()
        return self.getViewport()
    }

    public func getViewport() -> [String] {
        var lines = self.scrollback
        if !self.pendingLine.isEmpty {
            lines.append(self.pendingLine)
        }
        let tail = lines.suffix(self.rows)
        let paddingNeeded = max(0, self.rows - tail.count)
        return Array(repeating: "", count: paddingNeeded) + tail
    }

    public func getScrollBuffer() -> [String] {
        var lines = self.scrollback
        if !self.pendingLine.isEmpty {
            lines.append(self.pendingLine)
        }
        return lines
    }

    public func clear() {
        self.scrollback.removeAll()
        self.pendingLine.removeAll(keepingCapacity: false)
    }

    public func reset() {
        self.clear()
        self.outputLog.removeAll(keepingCapacity: false)
    }

    public func getCursorPosition() -> (x: Int, y: Int) {
        let currentLine = min(self.columns - 1, max(self.pendingLine.count, 0))
        let totalLines = self.scrollback.count + (self.pendingLine.isEmpty ? 0 : 1)
        let y = min(self.rows - 1, max(totalLines - 1, 0))
        return (max(currentLine, 0), max(y, 0))
    }

    /// Simulate user input for tests.
    public func sendInput(_ input: TerminalInput) {
        self.inputHandler?(input)
    }

    /// Change the viewport size and trigger resize callback.
    public func resize(columns: Int, rows: Int) {
        self.columns = max(1, columns)
        self.rows = max(1, rows)
        self.resizeHandler?()
    }

    /// Current rendered lines including pending line (scrollback wide).
    public func snapshotLines() -> [String] {
        var lines = self.scrollback
        if !self.pendingLine.isEmpty {
            lines.append(self.pendingLine)
        }
        return lines
    }

    private func captureOutput(_ data: String) {
        var normalized = data
        if normalized.contains(ANSI.clearScrollbackAndScreen) {
            self.resetBuffers()
            normalized = normalized.replacingOccurrences(of: ANSI.clearScrollbackAndScreen, with: "")
        }
        if normalized.contains(ANSI.clearScreen) {
            self.resetBuffers()
            normalized = normalized.replacingOccurrences(of: ANSI.clearScreen, with: "")
        }
        normalized = normalized
            .replacingOccurrences(of: ANSI.syncStart, with: "")
            .replacingOccurrences(of: ANSI.syncEnd, with: "")
        let withoutCarriage = normalized
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        for char in withoutCarriage {
            if char == "\n" {
                self.flushPendingLine()
            } else {
                self.pendingLine.append(char)
            }
        }
    }

    private func flushPendingLine() {
        self.scrollback.append(self.pendingLine)
        self.pendingLine.removeAll(keepingCapacity: false)
        if self.scrollback.count > self.scrollbackLimit {
            self.scrollback.removeFirst(self.scrollback.count - self.scrollbackLimit)
        }
    }

    private func resetBuffers() {
        self.scrollback.removeAll(keepingCapacity: false)
        self.pendingLine.removeAll(keepingCapacity: false)
    }
}

import SwiftUI
import SwiftTerm

/// SwiftUI wrapper around SwiftTerm's UIKit `TerminalView`, wired to a
/// ``TerminalSession``. Renders remote stdout and forwards keystrokes + resizes.
public struct SSHTerminalView: UIViewRepresentable {
    private let session: TerminalSession

    public init(session: TerminalSession) { self.session = session }

    public func makeUIView(context: Context) -> TerminalView {
        let tv = TerminalView(frame: .zero)
        tv.terminalDelegate = context.coordinator
        context.coordinator.bind(tv: tv)
        return tv
    }

    public func updateUIView(_ uiView: TerminalView, context: Context) {
        let dims = uiView.getTerminal().getDims()
        session.resize(cols: dims.cols, rows: dims.rows)
    }

    public func makeCoordinator() -> Coordinator { Coordinator(session: session) }

    @MainActor
    public final class Coordinator: NSObject, TerminalViewDelegate {
        private let session: TerminalSession
        private weak var tv: TerminalView?
        private var started = false

        init(session: TerminalSession) { self.session = session }

        func bind(tv: TerminalView) {
            self.tv = tv
            session.onStdout = { [weak tv] bytes in tv?.feed(byteArray: bytes[...]) }
            guard !started else { return }
            started = true
            let dims = tv.getTerminal().getDims()
            session.start(cols: dims.cols, rows: dims.rows)
        }

        public func send(source: TerminalView, data: ArraySlice<UInt8>) {
            session.write(Array(data))
        }
        public func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
            session.resize(cols: newCols, rows: newRows)
        }
        public func setTerminalTitle(source: TerminalView, title: String) {}
        public func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
        public func scrolled(source: TerminalView, position: Double) {}
        public func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {}
        public func bell(source: TerminalView) {}
        public func clipboardCopy(source: TerminalView, content: Data) {}
        public func clipboardRead(source: TerminalView) -> Data? { nil }
        public func iTermContent(source: TerminalView, content: ArraySlice<UInt8>) {}
        public func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}
    }
}

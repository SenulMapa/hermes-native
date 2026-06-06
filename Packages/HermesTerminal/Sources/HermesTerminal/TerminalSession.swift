import Foundation

/// Drives one interactive SSH PTY session (Apple swift-nio-ssh under the hood),
/// bridging bytes to/from a SwiftTerm view. UI feeds happen on the main thread.
@MainActor
@Observable
public final class TerminalSession {
    public enum State: Equatable {
        case idle, connecting, connected, failed(String), closed
    }

    public private(set) var state: State = .idle
    /// Set by the terminal view: receives raw stdout/stderr bytes to render.
    public var onStdout: (([UInt8]) -> Void)?

    private let host: SSHHost
    private let password: String
    private let connection = SSHConnection()
    private var cols = 80
    private var rows = 25

    public init(host: SSHHost, password: String) {
        self.host = host
        self.password = password
    }

    public func start(cols: Int, rows: Int) {
        guard state == .idle else { return }
        self.cols = max(cols, 1)
        self.rows = max(rows, 1)
        state = .connecting
        Task { await run() }
    }

    private func run() async {
        do {
            try await connection.connect(
                host: host.host, port: host.port,
                username: host.username, password: password,
                cols: cols, rows: rows,
                serverAuth: TOFUHostKeyValidator(host: host.host),
                onData: { bytes in
                    // NIO thread → main, FIFO-preserving for stable rendering.
                    DispatchQueue.main.async { [weak self] in self?.onStdout?(bytes) }
                },
                onError: { error in
                    DispatchQueue.main.async { [weak self] in
                        self?.state = .failed(String(describing: error))
                    }
                }
            )
            state = .connected
        } catch {
            state = .failed(String(describing: error))
        }
    }

    /// Send user keystrokes to the remote shell.
    public func write(_ bytes: [UInt8]) {
        connection.write(bytes)
    }

    /// Propagate a local size change to the remote PTY (SIGWINCH).
    public func resize(cols: Int, rows: Int) {
        guard cols > 0, rows > 0, (cols != self.cols || rows != self.rows) else { return }
        self.cols = cols
        self.rows = rows
        connection.resize(cols: cols, rows: rows)
    }

    public func stop() {
        connection.close()
        state = .closed
    }
}

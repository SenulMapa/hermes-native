import Foundation
import NIOCore
import NIOSSH
import Citadel

/// Drives one interactive SSH PTY session via Citadel, bridging bytes to/from a
/// SwiftTerm view. UI feeds happen on the main actor.
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
    private var client: SSHClient?
    private var stdin: TTYStdinWriter?
    private var runTask: Task<Void, Never>?
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
        runTask = Task { await run() }
    }

    private func run() async {
        do {
            let client = try await SSHClient.connect(
                host: host.host,
                port: host.port,
                authenticationMethod: .passwordBased(username: host.username, password: password),
                hostKeyValidator: .acceptAnything(),
                reconnect: .never
            )
            self.client = client
            state = .connected

            let pty = SSHChannelRequestEvent.PseudoTerminalRequest(
                wantReply: true,
                term: "xterm-256color",
                terminalCharacterWidth: cols,
                terminalRowHeight: rows,
                terminalPixelWidth: 0,
                terminalPixelHeight: 0,
                terminalModes: SSHTerminalModes([:])
            )

            try await client.withPTY(pty) { [weak self] inbound, outbound in
                await MainActor.run { self?.stdin = outbound }
                for try await chunk in inbound {
                    let buffer: ByteBuffer
                    switch chunk {
                    case .stdout(let b): buffer = b
                    case .stderr(let b): buffer = b
                    }
                    let bytes = Array(buffer.readableBytesView)
                    await MainActor.run { self?.onStdout?(bytes) }
                }
            }
            state = .closed
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Send user keystrokes to the remote shell.
    public func write(_ bytes: [UInt8]) {
        guard let stdin else { return }
        let buf = ByteBuffer(bytes: bytes)
        Task { try? await stdin.write(buf) }
    }

    /// Propagate a local size change to the remote PTY (SIGWINCH).
    public func resize(cols: Int, rows: Int) {
        guard cols > 0, rows > 0, (cols != self.cols || rows != self.rows) else { return }
        self.cols = cols
        self.rows = rows
        guard let stdin else { return }
        Task { try? await stdin.changeSize(cols: cols, rows: rows, pixelWidth: 0, pixelHeight: 0) }
    }

    public func stop() {
        runTask?.cancel()
        runTask = nil
        let c = client
        client = nil
        stdin = nil
        Task { try? await c?.close() }
        state = .closed
    }
}

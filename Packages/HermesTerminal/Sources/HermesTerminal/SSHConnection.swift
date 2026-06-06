import Foundation
import NIOCore
import NIOPosix
import NIOSSH

enum SSHClientError: Error, CustomStringConvertible {
    case passwordAuthUnavailable
    var description: String {
        switch self {
        case .passwordAuthUnavailable: return "Server does not offer password authentication."
        }
    }
}

/// Offers password authentication to the server.
final class PasswordAuthDelegate: NIOSSHClientUserAuthenticationDelegate {
    private let username: String
    private let password: String
    init(username: String, password: String) { self.username = username; self.password = password }

    func nextAuthenticationType(
        availableMethods: NIOSSHAvailableUserAuthenticationMethods,
        nextChallengePromise: EventLoopPromise<NIOSSHUserAuthenticationOffer?>
    ) {
        guard availableMethods.contains(.password) else {
            nextChallengePromise.fail(SSHClientError.passwordAuthUnavailable)
            return
        }
        nextChallengePromise.succeed(
            NIOSSHUserAuthenticationOffer(username: username, serviceName: "",
                                          offer: .password(.init(password: password)))
        )
    }
}

/// Propagates connection-level errors out of the NIO pipeline.
final class SSHErrorHandler: ChannelInboundHandler {
    typealias InboundIn = Any
    private let onError: (Error) -> Void
    init(onError: @escaping (Error) -> Void) { self.onError = onError }
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        onError(error)
        context.close(promise: nil)
    }
}

/// Child-channel handler for an interactive shell: requests a PTY + shell on
/// activation, unwraps stdout/stderr to bytes, and wraps stdin bytes back into
/// SSH channel data.
final class PTYChannelHandler: ChannelDuplexHandler {
    typealias InboundIn = SSHChannelData
    typealias InboundOut = ByteBuffer
    typealias OutboundIn = ByteBuffer
    typealias OutboundOut = SSHChannelData

    private let cols: Int
    private let rows: Int
    private let onData: ([UInt8]) -> Void
    init(cols: Int, rows: Int, onData: @escaping ([UInt8]) -> Void) {
        self.cols = cols; self.rows = rows; self.onData = onData
    }

    func channelActive(context: ChannelHandlerContext) {
        let pty = SSHChannelRequestEvent.PseudoTerminalRequest(
            wantReply: true, term: "xterm-256color",
            terminalCharacterWidth: cols, terminalRowHeight: rows,
            terminalPixelWidth: 0, terminalPixelHeight: 0,
            terminalModes: SSHTerminalModes([:])
        )
        context.triggerUserOutboundEvent(pty, promise: nil)
        context.triggerUserOutboundEvent(SSHChannelRequestEvent.ShellRequest(wantReply: true), promise: nil)
        context.fireChannelActive()
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let channelData = unwrapInboundIn(data)
        guard case .byteBuffer(var buffer) = channelData.data else { return }
        if let bytes = buffer.readBytes(length: buffer.readableBytes), !bytes.isEmpty {
            onData(bytes)
        }
    }

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let buffer = unwrapOutboundIn(data)
        let channelData = SSHChannelData(type: .channel, data: .byteBuffer(buffer))
        context.write(wrapOutboundOut(channelData), promise: promise)
    }
}

/// Owns the NIO event loop + SSH channels for one interactive session.
final class SSHConnection: @unchecked Sendable {
    private let group: MultiThreadedEventLoopGroup
    private var channel: Channel?
    private var childChannel: Channel?

    init() { group = MultiThreadedEventLoopGroup(numberOfThreads: 1) }

    func connect(
        host: String, port: Int, username: String, password: String,
        cols: Int, rows: Int,
        serverAuth: NIOSSHClientServerAuthenticationDelegate,
        onData: @escaping ([UInt8]) -> Void,
        onError: @escaping (Error) -> Void
    ) async throws {
        let config = SSHClientConfiguration(
            userAuthDelegate: PasswordAuthDelegate(username: username, password: password),
            serverAuthDelegate: serverAuth
        )
        let bootstrap = ClientBootstrap(group: group)
            .channelInitializer { channel in
                channel.pipeline.addHandlers([
                    NIOSSHHandler(role: .client(config), allocator: channel.allocator,
                                  inboundChildChannelInitializer: nil),
                    SSHErrorHandler(onError: onError),
                ])
            }
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)

        let channel = try await bootstrap.connect(host: host, port: port).get()
        self.channel = channel

        let sshHandler = try await channel.pipeline.handler(type: NIOSSHHandler.self).get()
        let childPromise = channel.eventLoop.makePromise(of: Channel.self)
        sshHandler.createChannel(childPromise, channelType: .session) { childChannel, _ in
            childChannel.setOption(ChannelOptions.allowRemoteHalfClosure, value: true).flatMap {
                childChannel.pipeline.addHandler(PTYChannelHandler(cols: cols, rows: rows, onData: onData))
            }
        }
        self.childChannel = try await childPromise.futureResult.get()
    }

    func write(_ bytes: [UInt8]) {
        guard let child = childChannel else { return }
        var buffer = child.allocator.buffer(capacity: bytes.count)
        buffer.writeBytes(bytes)
        child.writeAndFlush(buffer, promise: nil)
    }

    func resize(cols: Int, rows: Int) {
        guard let child = childChannel else { return }
        let event = SSHChannelRequestEvent.WindowChangeRequest(
            terminalCharacterWidth: cols, terminalRowHeight: rows,
            terminalPixelWidth: 0, terminalPixelHeight: 0
        )
        child.triggerUserOutboundEvent(event, promise: nil)
    }

    func close() {
        childChannel?.close(promise: nil)
        channel?.close(promise: nil)
        try? group.syncShutdownGracefully()
    }
}

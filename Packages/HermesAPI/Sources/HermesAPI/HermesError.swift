import Foundation

/// Typed errors surfaced by ``HermesAPIClient``. Every failure path maps to one
/// of these so the UI can render a human reason — never a silent failure.
public enum HermesError: Error, Equatable, Sendable {
    /// No server URL configured yet.
    case notConfigured
    /// The configured base URL is not a valid URL.
    case invalidBaseURL(String)
    /// Transport-level failure (DNS, TLS, timeout, offline).
    case network(String)
    /// Server replied with a non-2xx status.
    case http(status: Int)
    /// Response body could not be decoded into the expected shape.
    case decoding(String)
    /// Authenticated endpoint hit without (or with an invalid) credential.
    case unauthorized

    public var userMessage: String {
        switch self {
        case .notConfigured:
            return "No Hermes server configured."
        case .invalidBaseURL(let s):
            return "That doesn't look like a valid server address: \(s)"
        case .network(let s):
            return "Couldn't reach Hermes: \(s)"
        case .http(let status):
            return "Hermes responded with an error (HTTP \(status))."
        case .decoding:
            return "Hermes sent a response the app couldn't understand."
        case .unauthorized:
            return "Not signed in — add or refresh your Hermes session token."
        }
    }
}

import Foundation

/// Narrow decode-only escape hatch used by creator tooling when the host
/// sandbox denies AVFoundation sample decoding. Runtime leaves it unset.
protocol ContentPackVideoDecodeFallback: Sendable {
    var backendID: String { get }

    func decodeVideo(
        at url: URL,
        declarationID: String
    ) throws
}

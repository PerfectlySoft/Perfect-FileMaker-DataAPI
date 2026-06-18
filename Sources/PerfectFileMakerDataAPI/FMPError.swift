/// Errors thrown by the FileMaker Data API client.
public enum FMPError: Error, Sendable {
    /// A FileMaker server-level error with its numeric code and description.
    case serverError(Int, String)
    /// HTTP-level authentication failure (401/403).
    case authenticationFailed
    /// The response could not be parsed or a URL could not be constructed.
    case invalidResponse
}

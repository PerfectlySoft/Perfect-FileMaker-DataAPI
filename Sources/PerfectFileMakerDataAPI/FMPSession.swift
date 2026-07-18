import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Manages the Data API bearer token for a single database connection.
/// Tokens are obtained lazily on first use and cached until invalidated.
actor FMPSession {
    private var token: String?

    func currentToken() -> String? { token }

    func invalidate() { token = nil }

    func getToken(host: String, port: Int, database: String,
                  username: String, password: String,
                  urlSession: URLSession) async throws -> String {
        if let token { return token }
        let newToken = try await Self.login(
            host: host, port: port, database: database,
            username: username, password: password,
            urlSession: urlSession
        )
        self.token = newToken
        return newToken
    }

    private static func login(host: String, port: Int, database: String,
                               username: String, password: String,
                               urlSession: URLSession) async throws -> String {
        let scheme = port == 443 ? "https" : "http"
        let db = database.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? database
        guard let url = URL(string: "\(scheme)://\(host):\(port)/fmi/data/v1/databases/\(db)/sessions") else {
            throw FMPError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let credentials = Data("\(username):\(password)".utf8).base64EncodedString()
        request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [:] as [String: String])

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw FMPError.authenticationFailed
        }
        struct LoginResponse: Decodable {
            struct Inner: Decodable { let token: String }
            let response: Inner
        }
        return try JSONDecoder().decode(LoginResponse.self, from: data).response.token
    }
}

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A connection to a FileMaker Server using the FileMaker Data API (v1).
///
/// All methods are async and thread-safe. The bearer token is obtained lazily
/// on first use and cached; a new token is fetched automatically after logout
/// or authentication failure.
///
/// ```swift
/// let server = FileMakerServer(host: "fm.example.com", database: "Contacts",
///                               username: "api-user", password: "secret")
/// let results = try await server.find(
///     layout: "ContactList",
///     query: FMPQuery().adding(findRequest: FMPFindRequest(fields: ["City": "Denver"]))
/// )
/// ```
public struct FileMakerServer: Sendable {
    public let host: String
    public let port: Int
    public let database: String
    let username: String
    let password: String
    let session: FMPSession
    let urlSession: URLSession

    /// - Parameters:
    ///   - host: FileMaker Server hostname or IP address.
    ///   - port: Port number. Defaults to 443 (HTTPS).
    ///   - database: The hosted database to connect to.
    ///   - username: Data API account username.
    ///   - password: Data API account password.
    ///   - urlSession: Custom URLSession for certificate pinning or testing. Defaults to `.shared`.
    public init(host: String, port: Int = 443, database: String,
                username: String, password: String,
                urlSession: URLSession = .shared) {
        self.host = host
        self.port = port
        self.database = database
        self.username = username
        self.password = password
        self.session = FMPSession()
        self.urlSession = urlSession
    }

    // MARK: - Databases & Layouts

    /// Returns the names of all databases available to these credentials.
    public func databaseNames() async throws -> [String] {
        let scheme = port == 443 ? "https" : "http"
        guard let url = URL(string: "\(scheme)://\(host):\(port)/fmi/data/v1/databases") else {
            throw FMPError.invalidResponse
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        let creds = Data("\(username):\(password)".utf8).base64EncodedString()
        req.setValue("Basic \(creds)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await urlSession.data(for: req)
        struct Response: Decodable {
            struct Inner: Decodable {
                struct DB: Decodable { let name: String }
                let databases: [DB]
            }
            let response: Inner
        }
        return try JSONDecoder().decode(Response.self, from: data).response.databases.map { $0.name }
    }

    /// Returns the names of all layouts in the database.
    /// Flattens FM folder entries — folders themselves are not usable as layout names.
    public func layoutNames() async throws -> [String] {
        let data = try await request(method: "GET", path: "/layouts")
        struct LayoutEntry: Decodable {
            let name: String
            let isFolder: Bool?
            let folderLayoutNames: [LayoutEntry]?
        }
        struct Inner: Decodable { let layouts: [LayoutEntry] }
        struct Response: Decodable { let response: Inner }
        let top = try JSONDecoder().decode(Response.self, from: data).response.layouts
        func flatten(_ entries: [LayoutEntry]) -> [String] {
            entries.flatMap { e -> [String] in
                if e.isFolder == true { return flatten(e.folderLayoutNames ?? []) }
                if e.name == "-" { return [] }  // FM separator menu item
                return [e.name]
            }
        }
        return flatten(top)
    }

    /// Returns field and portal metadata for the named layout.
    public func layoutInfo(layout: String) async throws -> FMPLayoutInfo {
        let data = try await request(method: "GET", path: "/layouts/\(encoded(layout))")
        struct FieldMeta: Decodable {
            let name: String
            let result: String
        }
        struct Inner: Decodable {
            let fieldMetaData: [FieldMeta]
            let portalMetaData: [String: [FieldMeta]]?  // absent when layout has no portals
        }
        struct Response: Decodable { let response: Inner }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        let fields = decoded.response.fieldMetaData.map {
            FMPFieldDefinition(name: $0.name, type: FMPFieldType($0.result))
        }
        let portals = (decoded.response.portalMetaData ?? [:]).map { name, portalFields in
            FMPPortalInfo(name: name, fields: portalFields.map {
                FMPFieldDefinition(name: $0.name, type: FMPFieldType($0.result))
            })
        }
        return FMPLayoutInfo(name: layout, fields: fields, portals: portals)
    }

    // MARK: - Records

    /// Returns a single record by its internal FileMaker record ID.
    public func getRecord(layout: String, recordId: String) async throws -> FMPRecord {
        let data = try await request(method: "GET", path: "/layouts/\(encoded(layout))/records/\(recordId)")
        struct Inner: Decodable { let data: [FMPRecord] }
        struct Response: Decodable { let response: Inner }
        guard let record = try JSONDecoder().decode(Response.self, from: data).response.data.first else {
            throw FMPError.serverError(404, "Record not found")
        }
        return record
    }

    /// Returns a page of records from a layout.
    /// - Parameters:
    ///   - offset: 1-based record offset into the found set.
    ///   - limit: Maximum number of records to return (1–100 000).
    public func getRecords(layout: String, offset: Int = 1, limit: Int = 100) async throws -> FMPResultSet {
        do {
            let data = try await request(method: "GET",
                path: "/layouts/\(encoded(layout))/records?_offset=\(offset)&_limit=\(limit)")
            return try decodeResultSet(data: data)
        } catch FMPError.serverError(101, _) {
            return .empty  // empty table — not an error
        }
    }

    /// Creates a new record and returns the new record's FileMaker record ID.
    /// - Parameter fieldData: Field names and their string values.
    public func createRecord(layout: String, fieldData: [String: String]) async throws -> String {
        let body: [String: Any] = ["fieldData": fieldData]
        let data = try await request(method: "POST", path: "/layouts/\(encoded(layout))/records", body: body)
        struct Inner: Decodable { let recordId: String }
        struct Response: Decodable { let response: Inner }
        return try JSONDecoder().decode(Response.self, from: data).response.recordId
    }

    /// Updates fields on an existing record.
    /// - Parameter modId: Optional modification ID for conflict detection.
    public func editRecord(layout: String, recordId: String,
                           fieldData: [String: String], modId: String? = nil) async throws {
        var body: [String: Any] = ["fieldData": fieldData]
        if let modId { body["modId"] = modId }
        _ = try await request(method: "PATCH",
            path: "/layouts/\(encoded(layout))/records/\(recordId)", body: body)
    }

    /// Deletes the record with the given FileMaker record ID.
    public func deleteRecord(layout: String, recordId: String) async throws {
        _ = try await request(method: "DELETE",
            path: "/layouts/\(encoded(layout))/records/\(recordId)")
    }

    // MARK: - Find

    /// Performs a compound find and returns matching records.
    /// Returns an empty result set when no records match (FileMaker error 401)
    /// rather than throwing.
    public func find(layout: String, query: FMPQuery) async throws -> FMPResultSet {
        do {
            let data = try await request(method: "POST",
                path: "/layouts/\(encoded(layout))/_find", body: query.jsonBody)
            return try decodeResultSet(data: data)
        } catch FMPError.serverError(401, _) {
            return .empty
        }
    }

    // MARK: - Scripts

    /// Executes a FileMaker script and returns its result parameter (if any).
    public func executeScript(layout: String, script: String, param: String? = nil) async throws -> String? {
        var path = "/layouts/\(encoded(layout))/script/\(encoded(script))"
        if let param {
            path += "?script.param=\(param.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? param)"
        }
        let data = try await request(method: "GET", path: path)
        struct Inner: Decodable { let scriptResult: String? }
        struct Response: Decodable { let response: Inner }
        return (try? JSONDecoder().decode(Response.self, from: data))?.response.scriptResult
    }

    // MARK: - Session

    /// Closes the current session on the server and clears the cached token.
    public func logout() async throws {
        guard let token = await session.currentToken() else { return }
        let scheme = port == 443 ? "https" : "http"
        let db = encoded(database)
        guard let url = URL(string: "\(scheme)://\(host):\(port)/fmi/data/v1/databases/\(db)/sessions/\(token)") else {
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        _ = try? await urlSession.data(for: req)
        await session.invalidate()
    }

    // MARK: - Private helpers

    var baseURL: String {
        let scheme = port == 443 ? "https" : "http"
        return "\(scheme)://\(host):\(port)/fmi/data/v1/databases/\(encoded(database))"
    }

    func encoded(_ segment: String) -> String {
        segment.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? segment
    }

    func token() async throws -> String {
        try await session.getToken(host: host, port: port, database: database,
                                   username: username, password: password,
                                   urlSession: urlSession)
    }

    func request(method: String, path: String, body: [String: Any]? = nil) async throws -> Data {
        guard let url = URL(string: baseURL + path) else {
            throw FMPError.invalidResponse
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(try await token())", forHTTPHeaderField: "Authorization")
        if let body {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await urlSession.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw FMPError.invalidResponse
        }
        if http.statusCode == 401 || http.statusCode == 403 {
            await session.invalidate()
            throw FMPError.authenticationFailed
        }
        // Inspect the FileMaker error code embedded in every response.
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let messages = json["messages"] as? [[String: Any]],
           let first = messages.first,
           let codeStr = first["code"] as? String,
           let code = Int(codeStr), code != 0 {
            let message = first["message"] as? String ?? "Unknown error"
            throw FMPError.serverError(code, message)
        }
        return data
    }

    func decodeResultSet(data: Data) throws -> FMPResultSet {
        struct Inner: Decodable {
            let data: [FMPRecord]
            let dataInfo: FMPDataInfo
        }
        struct Response: Decodable { let response: Inner }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return FMPResultSet(dataInfo: decoded.response.dataInfo, records: decoded.response.data)
    }
}

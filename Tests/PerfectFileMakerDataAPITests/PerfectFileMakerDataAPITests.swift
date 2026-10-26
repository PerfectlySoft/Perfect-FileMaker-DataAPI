import Testing
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import PerfectFileMakerDataAPI

// MARK: - FMPQuery

@Suite("FMPQuery") struct FMPQueryTests {

    @Test func emptyQueryBodyHasOffsetAndLimit() {
        let q = FMPQuery()
        let body = q.jsonBody
        #expect(body["offset"] as? Int == 1)
        #expect(body["limit"] as? Int == 100)
        #expect(body["query"] == nil)
        #expect(body["sort"] == nil)
    }

    @Test func fluentBuildersReturnNewValues() {
        let q = FMPQuery()
            .adding(findRequest: FMPFindRequest(fields: ["City": "Denver"]))
            .sorting(by: [FMPSortField(name: "LastName", order: .descending)])
            .withOffset(21)
            .withLimit(20)

        #expect(q.findRequests.count == 1)
        #expect(q.sort.count == 1)
        #expect(q.offset == 21)
        #expect(q.limit == 20)
    }

    @Test func findRequestBodyEncoding() {
        let q = FMPQuery().adding(findRequest: FMPFindRequest(fields: ["Status": "Active"]))
        let body = q.jsonBody
        let queryArr = body["query"] as? [[String: Any]]
        #expect(queryArr?.count == 1)
        #expect(queryArr?.first?["Status"] as? String == "Active")
    }

    @Test func omitFlagIncludedInBody() {
        let q = FMPQuery().adding(findRequest: FMPFindRequest(fields: ["Status": "Inactive"], omit: true))
        let body = q.jsonBody
        let queryArr = body["query"] as? [[String: Any]]
        #expect(queryArr?.first?["omit"] as? String == "true")
    }

    @Test func sortFieldBodyEncoding() {
        let q = FMPQuery().sorting(by: [FMPSortField(name: "Name", order: .ascending)])
        let sortArr = q.jsonBody["sort"] as? [[String: String]]
        #expect(sortArr?.first?["fieldName"] == "Name")
        #expect(sortArr?.first?["sortOrder"] == "ascend")
    }
}

// MARK: - FMPFieldValue

@Suite("FMPFieldValue") struct FMPFieldValueTests {

    @Test func decodeString() throws {
        let json = #""Hello""#.data(using: .utf8)!
        let v = try JSONDecoder().decode(FMPFieldValue.self, from: json)
        #expect(v.description == "Hello")
    }

    @Test func decodeNumber() throws {
        let json = "42.5".data(using: .utf8)!
        let v = try JSONDecoder().decode(FMPFieldValue.self, from: json)
        #expect(v.doubleValue == 42.5)
    }

    @Test func decodeIntegerNumber() throws {
        let json = "7".data(using: .utf8)!
        let v = try JSONDecoder().decode(FMPFieldValue.self, from: json)
        #expect(v.description == "7")
        #expect(v.intValue == 7)
    }

    @Test func decodeEmptyString() throws {
        let json = #""""#.data(using: .utf8)!
        let v = try JSONDecoder().decode(FMPFieldValue.self, from: json)
        #expect(v.description == "")
    }

    @Test func decodeNull() throws {
        let json = "null".data(using: .utf8)!
        let v = try JSONDecoder().decode(FMPFieldValue.self, from: json)
        #expect(v.description == "")
    }
}

// MARK: - FMPPortalRecord

@Suite("FMPPortalRecord") struct FMPPortalRecordTests {

    @Test func decodesRecordIdModIdAndFields() throws {
        let json = """
        {
            "Orders::Product": "Widget",
            "Orders::Quantity": 5,
            "recordId": "99",
            "modId": "2"
        }
        """.data(using: .utf8)!
        let r = try JSONDecoder().decode(FMPPortalRecord.self, from: json)
        #expect(r.recordId == "99")
        #expect(r.modId == "2")
        #expect(r.fields["Orders::Product"]?.description == "Widget")
        #expect(r.fields["Orders::Quantity"]?.intValue == 5)
    }
}

// MARK: - FMPRecord.decode

@Suite("FMPRecord.decode") struct FMPRecordDecodeTests {

    private func makeRecord(fieldData: [String: Any]) throws -> FMPRecord {
        let json = try JSONSerialization.data(withJSONObject: [
            "recordId": "1", "modId": "0",
            "fieldData": fieldData,
            "portalData": [String: [String]]()
        ])
        return try JSONDecoder().decode(FMPRecord.self, from: json)
    }

    @Test func decodesStringFieldsViaCodingKeys() throws {
        struct Task: Decodable {
            let task: String
            let status: String
            let dueDate: String?
            enum CodingKeys: String, CodingKey {
                case task = "Task"; case status = "Status"; case dueDate = "Due Date"
            }
        }
        let record = try makeRecord(fieldData: [
            "Task": "Buy groceries",
            "Status": "In Progress",
            "Due Date": "06/20/2026",
        ])
        let task = try record.decode(Task.self)
        #expect(task.task == "Buy groceries")
        #expect(task.status == "In Progress")
        #expect(task.dueDate == "06/20/2026")
    }

    @Test func decodesNumericFields() throws {
        struct LineItem: Decodable {
            let quantity: Int
            let price: Double
            enum CodingKeys: String, CodingKey {
                case quantity = "Quantity"; case price = "Unit Price"
            }
        }
        let record = try makeRecord(fieldData: ["Quantity": 3, "Unit Price": 14.99])
        let item = try record.decode(LineItem.self)
        #expect(item.quantity == 3)
        #expect(item.price == 14.99)
    }

    @Test func emptyFMFieldDecodesAsNilOptional() throws {
        struct Item: Decodable {
            let name: String
            let note: String?
            enum CodingKeys: String, CodingKey {
                case name = "Name"; case note = "Note"
            }
        }
        let record = try makeRecord(fieldData: ["Name": "Widget", "Note": ""])
        let item = try record.decode(Item.self)
        #expect(item.name == "Widget")
        #expect(item.note == nil)
    }
}

// MARK: - FMPFieldType

@Suite("FMPFieldType") struct FMPFieldTypeTests {

    @Test func knownTypesMap() {
        #expect(FMPFieldType("text")      == .text)
        #expect(FMPFieldType("number")    == .number)
        #expect(FMPFieldType("date")      == .date)
        #expect(FMPFieldType("time")      == .time)
        #expect(FMPFieldType("timestamp") == .timestamp)
        #expect(FMPFieldType("container") == .container)
    }

    @Test func unknownTypeMapsFallback() {
        #expect(FMPFieldType("calculation") == .unknown)
    }
}

// MARK: - Transport

/// Records each request's URL and answers with HTTP 500, so a call fails right after its first request.
final class RecordingURLProtocol: URLProtocol {
    nonisolated(unsafe) private static var urls: [URL] = []
    private static let lock = NSLock()

    static func reset() { lock.withLock { urls = [] } }
    static func recorded() -> [URL] { lock.withLock { urls } }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if let url = request.url {
            Self.lock.withLock { Self.urls.append(url) }
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Suite("Transport", .serialized) struct TransportTests {

    @Test(arguments: [443, 8443, 80])
    func everyRequestUsesHTTPS(port: Int) async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [RecordingURLProtocol.self]
        let server = FileMakerServer(host: "fm.example.com", port: port, database: "My DB",
                                     username: "u", password: "p",
                                     urlSession: URLSession(configuration: config))
        RecordingURLProtocol.reset()

        #expect(server.baseURL.hasPrefix("https://fm.example.com:\(port)/"))
        _ = try? await server.databaseNames()        // no session needed
        _ = try? await server.getRecords(layout: "L") // logs in first

        let urls = RecordingURLProtocol.recorded()
        #expect(urls.count == 2)
        #expect(urls.allSatisfy { $0.scheme == "https" && $0.port == port })
        #expect(urls.last?.path == "/fmi/data/v1/databases/My DB/sessions")
    }
}

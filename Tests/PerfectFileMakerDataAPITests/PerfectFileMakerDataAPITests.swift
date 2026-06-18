import Testing
import Foundation
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

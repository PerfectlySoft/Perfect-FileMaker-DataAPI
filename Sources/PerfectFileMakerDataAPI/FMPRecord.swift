import Foundation

// Internal key helper for containers with arbitrary string keys.
struct AnyCodingKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    init(_ value: String) { self.stringValue = value }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}

/// A field value returned from the FileMaker Data API.
/// Numeric fields arrive as JSON numbers; all others arrive as strings.
public enum FMPFieldValue: Sendable, CustomStringConvertible {
    case string(String)
    case number(Double)
    case empty

    public var description: String {
        switch self {
        case .string(let s): return s
        case .number(let n): return n.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(n)) : String(n)
        case .empty: return ""
        }
    }

    public var doubleValue: Double? {
        switch self {
        case .number(let n): return n
        case .string(let s): return Double(s)
        case .empty: return nil
        }
    }

    public var intValue: Int? { doubleValue.map { Int($0) } }
}

extension FMPFieldValue: Decodable {
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            self = .empty
        } else if let n = try? c.decode(Double.self) {
            self = .number(n)
        } else if let s = try? c.decode(String.self) {
            self = s.isEmpty ? .empty : .string(s)
        } else {
            self = .empty
        }
    }
}

/// A record belonging to a portal (related set). Field keys are in the form `"PortalName::FieldName"`.
public struct FMPPortalRecord: Sendable {
    public let recordId: String
    public let modId: String
    /// Portal field values keyed as `"PortalName::FieldName"`.
    public let fields: [String: FMPFieldValue]
}

extension FMPPortalRecord: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        recordId = (try? container.decode(String.self, forKey: AnyCodingKey("recordId"))) ?? ""
        modId    = (try? container.decode(String.self, forKey: AnyCodingKey("modId")))    ?? ""
        var fields = [String: FMPFieldValue]()
        for key in container.allKeys where key.stringValue != "recordId" && key.stringValue != "modId" {
            fields[key.stringValue] = try container.decode(FMPFieldValue.self, forKey: key)
        }
        self.fields = fields
    }
}

/// An individual result record.
public struct FMPRecord: Sendable {
    public let recordId: String
    public let modId: String
    /// Top-level field values keyed by field name.
    public let fieldData: [String: FMPFieldValue]
    /// Portal records keyed by portal name.
    public let portalData: [String: [FMPPortalRecord]]
}

extension FMPRecord: Decodable {
    enum CodingKeys: String, CodingKey { case recordId, modId, fieldData, portalData }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        recordId   = try c.decode(String.self, forKey: .recordId)
        modId      = try c.decode(String.self, forKey: .modId)
        fieldData  = try c.decode([String: FMPFieldValue].self, forKey: .fieldData)
        portalData = (try? c.decode([String: [FMPPortalRecord]].self, forKey: .portalData)) ?? [:]
    }
}

/// Metadata about the scope and size of a query result.
public struct FMPDataInfo: Codable, Sendable {
    public let database: String
    public let layout: String
    public let table: String
    public let totalRecordCount: Int
    public let foundCount: Int
    public let returnedCount: Int
}

// MARK: - Encodable conformances

extension FMPFieldValue: Encodable {
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .number(let n): try c.encode(n)
        case .empty:         try c.encodeNil()
        }
    }
}

extension FMPPortalRecord: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: AnyCodingKey.self)
        try container.encode(recordId, forKey: AnyCodingKey("recordId"))
        try container.encode(modId,    forKey: AnyCodingKey("modId"))
        for (key, value) in fields {
            try container.encode(value, forKey: AnyCodingKey(key))
        }
    }
}

extension FMPRecord: Encodable {
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(recordId,  forKey: .recordId)
        try c.encode(modId,     forKey: .modId)
        try c.encode(fieldData, forKey: .fieldData)
        if !portalData.isEmpty {
            try c.encode(portalData, forKey: .portalData)
        }
    }
}

// MARK: - Custom type decoding

extension FMPRecord {
    /// Decodes the record's fieldData into a custom `Decodable` type.
    ///
    /// Define a struct with `CodingKeys` whose raw values match the FileMaker field names.
    /// Optional properties map to empty/null FM fields; numeric FM fields decode into
    /// `Double`, `Int`, or `String` — `JSONDecoder` handles the coercion.
    ///
    /// ```swift
    /// struct Task: Decodable {
    ///     var task: String
    ///     var status: String
    ///     var dueDate: String?
    ///     enum CodingKeys: String, CodingKey {
    ///         case task = "Task"; case status = "Status"; case dueDate = "Due Date"
    ///     }
    /// }
    /// let task = try record.decode(Task.self)
    /// ```
    public func decode<T: Decodable>(_ type: T.Type) throws -> T {
        let dict: [String: Any] = fieldData.mapValues { value -> Any in
            switch value {
            case .string(let s): return s
            case .number(let n): return n
            case .empty:         return NSNull()
            }
        }
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(T.self, from: data)
    }
}

/// The result of a find or list records operation.
public struct FMPResultSet: Sendable, Encodable {
    public let dataInfo: FMPDataInfo
    public let records: [FMPRecord]

    public static let empty = FMPResultSet(
        dataInfo: FMPDataInfo(database: "", layout: "", table: "",
                              totalRecordCount: 0, foundCount: 0, returnedCount: 0),
        records: []
    )
}

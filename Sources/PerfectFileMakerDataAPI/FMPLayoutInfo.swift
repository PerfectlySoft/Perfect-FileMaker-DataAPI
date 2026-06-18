/// The result type of a FileMaker field as reported by the Data API layout metadata endpoint.
public enum FMPFieldType: Sendable, Equatable {
    case text, number, date, time, timestamp, container, unknown

    init(_ string: String) {
        switch string.lowercased() {
        case "text":      self = .text
        case "number":    self = .number
        case "date":      self = .date
        case "time":      self = .time
        case "timestamp": self = .timestamp
        case "container": self = .container
        default:          self = .unknown
        }
    }
}

/// A FileMaker field name and its result type.
public struct FMPFieldDefinition: Sendable {
    public let name: String
    public let type: FMPFieldType

    init(name: String, type: FMPFieldType) {
        self.name = name
        self.type = type
    }
}

/// A portal's name and the fields it exposes.
public struct FMPPortalInfo: Sendable {
    public let name: String
    public let fields: [FMPFieldDefinition]
}

/// Metadata describing a layout — its fields and any portals it contains.
public struct FMPLayoutInfo: Sendable {
    public let name: String
    public let fields: [FMPFieldDefinition]
    public let portals: [FMPPortalInfo]
}

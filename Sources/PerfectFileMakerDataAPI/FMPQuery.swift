/// Sort order for query results.
public enum FMPSortOrder: String, Sendable {
    case ascending = "ascend"
    case descending = "descend"
    case custom
}

/// A single sort directive.
public struct FMPSortField: Sendable {
    public let name: String
    public let order: FMPSortOrder

    public init(name: String, order: FMPSortOrder = .ascending) {
        self.name = name
        self.order = order
    }
}

/// One criteria set within a compound find. Multiple requests are OR'd together;
/// setting `omit: true` excludes matching records.
public struct FMPFindRequest: Sendable {
    public let fields: [String: String]
    public let omit: Bool

    public init(fields: [String: String], omit: Bool = false) {
        self.fields = fields
        self.omit = omit
    }
}

/// Optional FileMaker script execution tied to a query.
public struct FMPScripts: Sendable {
    public let prerequest: String?
    public let prerequestParam: String?
    public let presort: String?
    public let presortParam: String?
    public let after: String?
    public let afterParam: String?

    public init(after: String? = nil, afterParam: String? = nil,
                prerequest: String? = nil, prerequestParam: String? = nil,
                presort: String? = nil, presortParam: String? = nil) {
        self.after = after
        self.afterParam = afterParam
        self.prerequest = prerequest
        self.prerequestParam = prerequestParam
        self.presort = presort
        self.presortParam = presortParam
    }
}

/// A Data API find query. Build using the fluent modifier methods.
///
/// ```swift
/// let query = FMPQuery()
///     .adding(findRequest: FMPFindRequest(fields: ["Status": "Active"]))
///     .sorting(by: [FMPSortField(name: "LastName")])
///     .withLimit(50)
/// ```
public struct FMPQuery: Sendable {
    public let findRequests: [FMPFindRequest]
    public let sort: [FMPSortField]
    public let offset: Int
    public let limit: Int
    public let scripts: FMPScripts?

    public init(findRequests: [FMPFindRequest] = [],
                sort: [FMPSortField] = [],
                offset: Int = 1,
                limit: Int = 100,
                scripts: FMPScripts? = nil) {
        self.findRequests = findRequests
        self.sort = sort
        self.offset = offset
        self.limit = limit
        self.scripts = scripts
    }

    public func adding(findRequest: FMPFindRequest) -> FMPQuery {
        FMPQuery(findRequests: findRequests + [findRequest], sort: sort,
                 offset: offset, limit: limit, scripts: scripts)
    }

    public func sorting(by fields: [FMPSortField]) -> FMPQuery {
        FMPQuery(findRequests: findRequests, sort: fields,
                 offset: offset, limit: limit, scripts: scripts)
    }

    public func withOffset(_ offset: Int) -> FMPQuery {
        FMPQuery(findRequests: findRequests, sort: sort,
                 offset: offset, limit: limit, scripts: scripts)
    }

    public func withLimit(_ limit: Int) -> FMPQuery {
        FMPQuery(findRequests: findRequests, sort: sort,
                 offset: offset, limit: limit, scripts: scripts)
    }

    public func withScripts(_ scripts: FMPScripts) -> FMPQuery {
        FMPQuery(findRequests: findRequests, sort: sort,
                 offset: offset, limit: limit, scripts: scripts)
    }

    var jsonBody: [String: Any] {
        var body: [String: Any] = ["offset": offset, "limit": limit]
        if !findRequests.isEmpty {
            body["query"] = findRequests.map { req -> [String: Any] in
                var dict: [String: Any] = req.fields
                if req.omit { dict["omit"] = "true" }
                return dict
            }
        }
        if !sort.isEmpty {
            body["sort"] = sort.map { ["fieldName": $0.name, "sortOrder": $0.order.rawValue] }
        }
        if let s = scripts {
            if let name = s.prerequest {
                body["script.prerequest"] = name
                if let p = s.prerequestParam { body["script.prerequest.param"] = p }
            }
            if let name = s.presort {
                body["script.presort"] = name
                if let p = s.presortParam { body["script.presort.param"] = p }
            }
            if let name = s.after {
                body["script"] = name
                if let p = s.afterParam { body["script.param"] = p }
            }
        }
        return body
    }
}

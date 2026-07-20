# Perfect-FileMaker-DataAPI

A modern, dependency-free Swift client for FileMaker's Data API — the REST/JSON
web service (`/fmi/data/v1`) exposed by FileMaker Server. Built with Swift 6
concurrency: every network call is `async throws`, the public entry point
(`FileMakerServer`) is `Sendable`, and session/token state lives in an
`FMPSession` actor rather than behind manual locking.

## Status: staged for future integration

This package is real, working code, not a stub. It is currently exercised
only through **FMTestApp**, a standalone local test harness — it is **not
yet wired into Perfect-Lasso's own `Package.swift`**. It is the planned
successor/complement to the classic XML CWP client
([`Perfect-FileMaker`](../Perfect-FileMaker)) that Perfect-Lasso uses today:
that package speaks FileMaker's older XML Custom Web Publishing protocol,
while this one speaks FileMaker's newer HTTP/JSON Data API. Integration into
Perfect-Lasso is planned future work, not abandoned or superseded code.

## Requirements

- Swift tools version **6.2**
- **macOS 26** or later (the only platform declared in `Package.swift`; no
  iOS/watchOS/tvOS platform entries). Sources are also guarded with
  `#if canImport(FoundationNetworking)` for Linux source-compatibility, but
  Linux is not yet declared as a supported platform.
- Zero external package dependencies — built entirely on `Foundation`
  (`FoundationNetworking` on Linux).

## Installation

Add it as a local Swift Package Manager dependency:

```swift
.package(path: "../Perfect-FileMaker-DataAPI")
```

and add `"PerfectFileMakerDataAPI"` to your target's dependencies.

## What it does

`Sources/PerfectFileMakerDataAPI/` (6 files, ~700 lines):

- **`FileMakerServer`** — the main `Sendable` entry point: database and
  layout listing, record CRUD (`getRecord`, `getRecords`, `createRecord`,
  `editRecord`, `deleteRecord`), compound find (`find(layout:query:)`),
  script execution (`executeScript`), and `logout()`.
- **`FMPSession`** — an actor that lazily fetches and caches the bearer
  token, and automatically invalidates and re-authenticates on a 401/403.
- **`FMPQuery`** / `FMPFindRequest` — builds compound find requests, sorts,
  and script parameters.
- **`FMPRecord`** — the record model, including a generic
  `decode<T: Decodable>(_:)` helper for mapping a record's field data
  straight into your own `Decodable` types.
- **`FMPLayoutInfo`** — field and portal metadata returned by layout
  introspection.
- **`FMPError`** — a dedicated error type for Data API failures.

It also has FileMaker-specific quirks already handled correctly: FileMaker's
"no records match" (401) and "empty table" (101) response codes are turned
into an empty result set instead of being thrown as errors, and FileMaker's
nested layout-folder structure is flattened when listing layouts.

## Usage

```swift
import PerfectFileMakerDataAPI

let server = FileMakerServer(
    host: "fm.example.com",
    database: "Contacts",
    username: "api-user",
    password: "secret"
)

let results = try await server.find(
    layout: "ContactList",
    query: FMPQuery().adding(findRequest: FMPFindRequest(fields: ["City": "Denver"]))
)

for record in results.records {
    let contact = try record.decode(Contact.self)
    print(contact)
}
```

The bearer token is fetched and cached automatically on first use — there is
no separate login call to make.

## Testing

`Tests/PerfectFileMakerDataAPITests/` covers the client's request/response
handling. Run with:

```
swift test
```

## License

No LICENSE file is currently present in this repository.

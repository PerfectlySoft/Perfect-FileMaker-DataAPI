# Perfect FileMaker Data API

<p align="center">
    <img src="https://img.shields.io/badge/Swift-6.2%2B-orange.svg?style=flat" alt="Swift 6.2+">
    <img src="https://img.shields.io/badge/Platforms-macOS%2012%2B%20%7C%20Linux-lightgray.svg?style=flat" alt="Platforms macOS 12+ | Linux">
    <a href="LICENSE" target="_blank">
        <img src="https://img.shields.io/badge/License-Apache%202.0-lightgrey.svg?style=flat" alt="License Apache 2.0">
    </a>
</p>

A dependency-free Swift client for the FileMaker Data API, the REST/JSON web service
(`/fmi/data/v1`) that FileMaker Server exposes. Every network call is `async throws`, the entry
point (`FileMakerServer`) is `Sendable`, and the bearer token lives in an actor rather than behind
manual locking.

This is a new package, not a port. For FileMaker's older XML Custom Web Publishing protocol, use
[Perfect-FileMaker](https://github.com/PerfectlySoft/Perfect-FileMaker); for FileMaker Server's
Admin API, use [Perfect-FileMaker-AdminAPI](https://github.com/PerfectlySoft/Perfect-FileMaker-AdminAPI).
The three packages are independent of each other.

## Requirements

- Swift 6.2 or later (`swift-tools-version: 6.2`, Swift 6 language mode).
- macOS 12 or later, or Linux (`FoundationNetworking`). CI covers Swift 6.2 and 6.4 on Ubuntu
  24.04 and Xcode 26.0.1 and 26.6 on macOS, in debug and release, with warnings as errors.
- No package dependencies.

## Using in your project

```swift
.package(url: "https://github.com/PerfectlySoft/Perfect-FileMaker-DataAPI.git", from: "1.0.0"),
```

```swift
.product(name: "PerfectFileMakerDataAPI", package: "Perfect-FileMaker-DataAPI"),
```

## Usage

```swift
import PerfectFileMakerDataAPI

struct Contact: Decodable {
    let name: String
    let city: String
}

let server = FileMakerServer(
    host: "fm.example.com",
    database: "Contacts",
    username: "api-user",
    password: "secret"
)

let results = try await server.find(
    layout: "ContactList",
    query: FMPQuery().adding(findRequest: FMPFindRequest(fields: ["city": "Denver"]))
)

for record in results.records {
    let contact = try record.decode(Contact.self)
    print(contact.name)
}
```

There is no separate login call. The token is fetched on first use, cached, and refreshed
automatically after a 401 or 403.

## What's here

- **`FileMakerServer`**: database and layout listing, layout metadata, record CRUD (`getRecord`,
  `getRecords`, `createRecord`, `editRecord`, `deleteRecord`), compound find
  (`find(layout:query:)`), script execution (`executeScript`), and `logout()`.
- **`FMPQuery`**, **`FMPFindRequest`**, **`FMPSortField`**, **`FMPScripts`**: compound find
  requests (including omit requests), sort order, paging, and pre-request, pre-sort and
  after-find scripts.
- **`FMPRecord`** and **`FMPResultSet`**: records with typed field values and portal rows, plus
  `decode(_:)` to map a record's field data onto your own `Decodable` type.
- **`FMPLayoutInfo`**: field and portal metadata from layout introspection.
- **`FMPError`**: Data API failures.

Two FileMaker quirks are handled for you. A find that matches nothing (FileMaker error 401) and an
empty table (error 101) come back as an empty result set instead of a thrown error. Layout
listings flatten FileMaker's nested layout folders.

## Testing

```sh
swift test
```

The tests cover request building and response decoding and don't need a FileMaker Server.

## License

Apache 2.0. See [LICENSE](LICENSE).

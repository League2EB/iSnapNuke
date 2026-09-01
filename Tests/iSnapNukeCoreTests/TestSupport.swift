import Foundation
@testable import iSnapNukeCore

struct FixtureRunner: CommandRunning {
    let responses: [String: CommandResult]

    static let standard = FixtureRunner(
        responses: [
            key(["info", "-plist", "/"]): .success(plist(named: "system-info")),
            key(["info", "-plist", "/System/Volumes/Data"]): .success(plist(named: "data-info")),
            key(["apfs", "listSnapshots", "disk3s5", "-plist"]): .success(plist(named: "system-snapshots")),
            key(["apfs", "listSnapshots", "disk3s1", "-plist"]): .success(plist(named: "data-snapshots")),
        ]
    )

    func run(executable _: URL, arguments: [String]) async throws -> CommandResult {
        guard let result = responses[Self.key(arguments)] else {
            throw TestRunnerError.missingResponse(arguments)
        }
        return result
    }

    static func key(_ arguments: [String]) -> String {
        arguments.joined(separator: "\u{1F}")
    }
}

enum TestRunnerError: Error {
    case missingResponse([String])
}

extension CommandResult {
    static func success(_ data: Data) -> CommandResult {
        CommandResult(status: 0, standardOutput: data, standardError: Data())
    }
}

func plist(named name: String) -> Data {
    let url = Bundle.module.url(forResource: name, withExtension: "plist")!
    return try! Data(contentsOf: url)
}

struct FixtureSizeProvider: SnapshotPrivateSizeProviding {
    let sizesByVolume: [String: [UUID: Int64]]

    static let empty = FixtureSizeProvider(sizesByVolume: [:])

    static let standard = FixtureSizeProvider(
        sizesByVolume: [
            "disk3s1": [
                UUID(uuidString: "0FA116AA-913B-4A65-95B0-D5769B5C8097")!: 5_191_966_720,
                UUID(uuidString: "E35DF2CA-16E1-448A-AD02-059C0DB240C2")!: 1_073_819_648,
            ],
        ]
    )

    func privateSizes(for volume: APFSVolume) throws -> [UUID: Int64] {
        sizesByVolume[volume.deviceIdentifier] ?? [:]
    }
}

func fixtureScanner(
    runner: any CommandRunning,
    sizeProvider: any SnapshotPrivateSizeProviding = FixtureSizeProvider.standard
) -> DiskUtilityScanner {
    DiskUtilityScanner(runner: runner, sizeProvider: sizeProvider)
}

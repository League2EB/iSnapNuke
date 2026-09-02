import Foundation

public enum AppVersionError: Error, Equatable, Sendable {
    case invalidSemanticVersion(String)
    case invalidBuild(String)
    case missingBundleVersion
}

public struct SemanticVersion: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(major: Int, minor: Int, patch: Int) throws {
        guard major >= 0, minor >= 0, patch >= 0 else {
            throw AppVersionError.invalidSemanticVersion("\(major).\(minor).\(patch)")
        }
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public init(_ value: String) throws {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard
            parts.count == 3,
            let major = Int(parts[0]),
            let minor = Int(parts[1]),
            let patch = Int(parts[2]),
            parts.allSatisfy(Self.isValidNumericPart),
            major >= 0,
            minor >= 0,
            patch >= 0
        else {
            throw AppVersionError.invalidSemanticVersion(value)
        }

        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public var description: String {
        "\(major).\(minor).\(patch)"
    }

    private static func isValidNumericPart(_ part: Substring) -> Bool {
        guard !part.isEmpty, part.allSatisfy(\.isNumber) else {
            return false
        }
        return part == "0" || !part.hasPrefix("0")
    }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        do {
            try self.init(value)
        } catch {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid semantic version: \(value)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

public struct AppVersion: Equatable, Comparable, Sendable, CustomStringConvertible {
    public let marketingVersion: SemanticVersion
    public let build: Int

    public init(marketingVersion: SemanticVersion, build: Int) throws {
        guard build > 0 else {
            throw AppVersionError.invalidBuild(String(build))
        }
        self.marketingVersion = marketingVersion
        self.build = build
    }

    public init(marketingVersion: String, build: String) throws {
        guard let buildNumber = Int(build), buildNumber > 0 else {
            throw AppVersionError.invalidBuild(build)
        }
        try self.init(marketingVersion: SemanticVersion(marketingVersion), build: buildNumber)
    }

    public init(bundle: Bundle) throws {
        guard
            let marketingVersion = bundle.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
            ) as? String,
            let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        else {
            throw AppVersionError.missingBundleVersion
        }
        try self.init(marketingVersion: marketingVersion, build: build)
    }

    public var description: String {
        "\(marketingVersion) (\(build))"
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        if lhs.build != rhs.build { return lhs.build < rhs.build }
        return lhs.marketingVersion < rhs.marketingVersion
    }
}

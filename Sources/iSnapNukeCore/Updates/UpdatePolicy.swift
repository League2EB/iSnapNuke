import CryptoKit
import Foundation

public enum UpdatePolicyError: Error, Equatable, Sendable {
    case unsupportedSchema(Int)
    case invalidBuildRange
    case invalidVersionRange
    case invalidPublishedDate
    case invalidPublicKey
    case invalidSignatureEncoding
    case signatureMismatch
    case policyRollback
}

public struct UpdatePolicy: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let latestVersion: SemanticVersion
    public let latestBuild: Int
    public let minimumSupportedVersion: SemanticVersion
    public let minimumSupportedBuild: Int
    public let releaseNotes: [String: String]
    public let publishedAt: Date

    public init(
        schemaVersion: Int = 1,
        latestVersion: SemanticVersion,
        latestBuild: Int,
        minimumSupportedVersion: SemanticVersion,
        minimumSupportedBuild: Int,
        releaseNotes: [String: String],
        publishedAt: Date
    ) {
        self.schemaVersion = schemaVersion
        self.latestVersion = latestVersion
        self.latestBuild = latestBuild
        self.minimumSupportedVersion = minimumSupportedVersion
        self.minimumSupportedBuild = minimumSupportedBuild
        self.releaseNotes = releaseNotes
        self.publishedAt = publishedAt
    }

    public func validate() throws {
        guard schemaVersion == 1 else {
            throw UpdatePolicyError.unsupportedSchema(schemaVersion)
        }
        guard
            latestBuild > 0,
            minimumSupportedBuild > 0,
            minimumSupportedBuild <= latestBuild
        else {
            throw UpdatePolicyError.invalidBuildRange
        }
        guard minimumSupportedVersion <= latestVersion else {
            throw UpdatePolicyError.invalidVersionRange
        }
        guard publishedAt.timeIntervalSince1970 > 0 else {
            throw UpdatePolicyError.invalidPublishedDate
        }
    }

    public func decision(for currentVersion: AppVersion) -> UpdateDecision {
        if currentVersion.build < minimumSupportedBuild {
            return .required(self)
        }
        if currentVersion.build < latestBuild {
            return .optional(self)
        }
        return .upToDate
    }

    public func releaseNote(language: String) -> String? {
        releaseNotes[language] ?? releaseNotes["en"]
    }
}

public enum UpdateDecision: Equatable, Sendable {
    case upToDate
    case optional(UpdatePolicy)
    case required(UpdatePolicy)
}

public struct SignedUpdatePolicyEnvelope: Codable, Equatable, Sendable {
    public let policy: UpdatePolicy
    public let signature: String

    public init(policy: UpdatePolicy, signature: String) {
        self.policy = policy
        self.signature = signature
    }

    public static func signingData(for policy: UpdatePolicy) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(policy)
    }
}

public protocol UpdatePolicyVerifying: Sendable {
    func verifiedPolicy(from document: Data) throws -> UpdatePolicy
}

public struct Ed25519UpdatePolicyVerifier: UpdatePolicyVerifying {
    private let publicKey: Curve25519.Signing.PublicKey

    public init(publicKeyBase64: String) throws {
        guard
            let rawKey = Data(base64Encoded: publicKeyBase64),
            let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: rawKey)
        else {
            throw UpdatePolicyError.invalidPublicKey
        }
        self.publicKey = publicKey
    }

    public func verifiedPolicy(from document: Data) throws -> UpdatePolicy {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(SignedUpdatePolicyEnvelope.self, from: document)

        guard let signature = Data(base64Encoded: envelope.signature) else {
            throw UpdatePolicyError.invalidSignatureEncoding
        }

        let signingData = try SignedUpdatePolicyEnvelope.signingData(for: envelope.policy)
        guard publicKey.isValidSignature(signature, for: signingData) else {
            throw UpdatePolicyError.signatureMismatch
        }

        try envelope.policy.validate()
        return envelope.policy
    }
}

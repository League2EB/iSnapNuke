import CryptoKit
import Foundation
@testable import iSnapNukeCore

actor InMemoryUpdatePolicyCache: UpdatePolicyCaching {
    var cachedDocument: CachedUpdatePolicyDocument?
    var saveError: Error?

    init(cachedDocument: CachedUpdatePolicyDocument? = nil) {
        self.cachedDocument = cachedDocument
    }

    func load() throws -> CachedUpdatePolicyDocument? {
        cachedDocument
    }

    func save(_ cachedDocument: CachedUpdatePolicyDocument) throws {
        if let saveError {
            throw saveError
        }
        self.cachedDocument = cachedDocument
    }
}

actor StubUpdatePolicyFetcher: UpdatePolicyFetching {
    var result: Result<UpdatePolicyFetchResult, Error>
    private(set) var requestedETags: [String?] = []

    init(result: Result<UpdatePolicyFetchResult, Error>) {
        self.result = result
    }

    func fetch(ifNoneMatch eTag: String?) throws -> UpdatePolicyFetchResult {
        requestedETags.append(eTag)
        return try result.get()
    }

    func allRequestedETags() -> [String?] {
        requestedETags
    }
}

actor StubUpdatePolicyEvaluator: UpdatePolicyEvaluating {
    var cached: UpdatePolicyEvaluation
    var refreshed: UpdatePolicyEvaluation

    init(cached: UpdatePolicyEvaluation, refreshed: UpdatePolicyEvaluation) {
        self.cached = cached
        self.refreshed = refreshed
    }

    func cachedEvaluation(for _: AppVersion) -> UpdatePolicyEvaluation {
        cached
    }

    func refreshEvaluation(for _: AppVersion) -> UpdatePolicyEvaluation {
        refreshed
    }
}

@MainActor
final class RecordingUpdateInstaller: UpdateInstalling {
    private(set) var checkCount = 0

    func checkForUpdates() {
        checkCount += 1
    }
}

@MainActor
final class InMemoryUpdateDeferralStore: UpdateDeferralStoring {
    var deferredBuild: Int?
}

func makeUpdatePolicy(
    latestVersion: String = "1.1.0",
    latestBuild: Int = 2,
    minimumVersion: String = "1.0.0",
    minimumBuild: Int = 1,
    publishedAt: Date = Date(timeIntervalSince1970: 1_700_000_000)
) -> UpdatePolicy {
    UpdatePolicy(
        latestVersion: try! SemanticVersion(latestVersion),
        latestBuild: latestBuild,
        minimumSupportedVersion: try! SemanticVersion(minimumVersion),
        minimumSupportedBuild: minimumBuild,
        releaseNotes: [
            "en": "Update notes",
            "zh-Hant": "更新說明",
        ],
        publishedAt: publishedAt
    )
}

func makeSignedPolicyDocument(
    policy: UpdatePolicy,
    privateKey: Curve25519.Signing.PrivateKey
) throws -> Data {
    let signature = try privateKey.signature(
        for: SignedUpdatePolicyEnvelope.signingData(for: policy)
    ).base64EncodedString()
    let envelope = SignedUpdatePolicyEnvelope(policy: policy, signature: signature)
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(envelope)
}

func makeUpdateVersion(_ marketingVersion: String = "1.0.0", build: Int = 1) -> AppVersion {
    try! AppVersion(marketingVersion: try! SemanticVersion(marketingVersion), build: build)
}

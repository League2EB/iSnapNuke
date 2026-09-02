import CryptoKit
import XCTest
@testable import iSnapNukeCore

final class UpdatePolicyServiceTests: XCTestCase {
    func testFileCacheRoundTripsPolicyDocumentAndETag() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directory.appendingPathComponent("policy-cache.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        let expected = CachedUpdatePolicyDocument(
            document: Data("signed document".utf8),
            eTag: "\"etag\"",
            fetchedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let cache = FileUpdatePolicyCache(fileURL: fileURL)

        try await cache.save(expected)

        let actual = try await cache.load()
        XCTAssertEqual(actual, expected)
    }

    func testNetworkPolicyIsSavedAndEvaluated() async throws {
        let privateKey = Curve25519.Signing.PrivateKey()
        let policy = makeUpdatePolicy(latestBuild: 2, minimumBuild: 1)
        let document = try makeSignedPolicyDocument(policy: policy, privateKey: privateKey)
        let fetcher = StubUpdatePolicyFetcher(
            result: .success(.modified(document: document, eTag: "\"v2\""))
        )
        let cache = InMemoryUpdatePolicyCache()
        let service = UpdatePolicyService(
            fetcher: fetcher,
            cache: cache,
            verifier: try Ed25519UpdatePolicyVerifier(
                publicKeyBase64: privateKey.publicKey.rawRepresentation.base64EncodedString()
            )
        )

        let evaluation = await service.refreshEvaluation(for: makeUpdateVersion(build: 1))

        XCTAssertEqual(evaluation.source, .network)
        XCTAssertEqual(evaluation.decision, .optional(policy))
        let cached = try await cache.load()
        XCTAssertEqual(cached?.document, document)
        XCTAssertEqual(cached?.eTag, "\"v2\"")
    }

    func testOfflineUsesValidCachedRequiredPolicy() async throws {
        let privateKey = Curve25519.Signing.PrivateKey()
        let policy = makeUpdatePolicy(latestBuild: 3, minimumBuild: 2)
        let document = try makeSignedPolicyDocument(policy: policy, privateKey: privateKey)
        let cache = InMemoryUpdatePolicyCache(
            cachedDocument: CachedUpdatePolicyDocument(
                document: document,
                eTag: "\"v3\"",
                fetchedAt: .now
            )
        )
        let service = UpdatePolicyService(
            fetcher: StubUpdatePolicyFetcher(
                result: .failure(URLError(.notConnectedToInternet))
            ),
            cache: cache,
            verifier: try Ed25519UpdatePolicyVerifier(
                publicKeyBase64: privateKey.publicKey.rawRepresentation.base64EncodedString()
            )
        )

        let evaluation = await service.refreshEvaluation(for: makeUpdateVersion(build: 1))

        XCTAssertEqual(evaluation.source, .cache)
        XCTAssertEqual(evaluation.decision, .required(policy))
        XCTAssertEqual(evaluation.failure, .unavailable)
    }

    func testFirstLaunchOfflineFailsOpen() async throws {
        let privateKey = Curve25519.Signing.PrivateKey()
        let service = UpdatePolicyService(
            fetcher: StubUpdatePolicyFetcher(
                result: .failure(URLError(.notConnectedToInternet))
            ),
            cache: InMemoryUpdatePolicyCache(),
            verifier: try Ed25519UpdatePolicyVerifier(
                publicKeyBase64: privateKey.publicKey.rawRepresentation.base64EncodedString()
            )
        )

        let evaluation = await service.refreshEvaluation(for: makeUpdateVersion())

        XCTAssertNil(evaluation.decision)
        XCTAssertEqual(evaluation.source, .none)
        XCTAssertEqual(evaluation.failure, .unavailable)
    }

    func testNotModifiedUsesCachedPolicyAndETag() async throws {
        let privateKey = Curve25519.Signing.PrivateKey()
        let policy = makeUpdatePolicy(latestBuild: 3, minimumBuild: 1)
        let cache = InMemoryUpdatePolicyCache(
            cachedDocument: CachedUpdatePolicyDocument(
                document: try makeSignedPolicyDocument(policy: policy, privateKey: privateKey),
                eTag: "\"cached\"",
                fetchedAt: .now
            )
        )
        let fetcher = StubUpdatePolicyFetcher(result: .success(.notModified(eTag: "\"cached\"")))
        let service = UpdatePolicyService(
            fetcher: fetcher,
            cache: cache,
            verifier: try Ed25519UpdatePolicyVerifier(
                publicKeyBase64: privateKey.publicKey.rawRepresentation.base64EncodedString()
            )
        )

        let evaluation = await service.refreshEvaluation(for: makeUpdateVersion())

        XCTAssertEqual(evaluation.source, .cache)
        XCTAssertEqual(evaluation.decision, .optional(policy))
        let requestedETags = await fetcher.allRequestedETags()
        XCTAssertEqual(requestedETags, ["\"cached\""])
    }

    func testRejectsNewPolicyThatLowersCachedRequiredBuild() async throws {
        let privateKey = Curve25519.Signing.PrivateKey()
        let cachedPolicy = makeUpdatePolicy(
            latestVersion: "1.2.0",
            latestBuild: 3,
            minimumVersion: "1.1.0",
            minimumBuild: 2,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let incomingPolicy = makeUpdatePolicy(
            latestBuild: 4,
            minimumBuild: 1,
            publishedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let cache = InMemoryUpdatePolicyCache(
            cachedDocument: CachedUpdatePolicyDocument(
                document: try makeSignedPolicyDocument(
                    policy: cachedPolicy,
                    privateKey: privateKey
                ),
                eTag: "\"cached\"",
                fetchedAt: .now
            )
        )
        let service = UpdatePolicyService(
            fetcher: StubUpdatePolicyFetcher(
                result: .success(
                    .modified(
                        document: try makeSignedPolicyDocument(
                            policy: incomingPolicy,
                            privateKey: privateKey
                        ),
                        eTag: "\"new\""
                    )
                )
            ),
            cache: cache,
            verifier: try Ed25519UpdatePolicyVerifier(
                publicKeyBase64: privateKey.publicKey.rawRepresentation.base64EncodedString()
            )
        )

        let evaluation = await service.refreshEvaluation(for: makeUpdateVersion(build: 1))

        XCTAssertEqual(evaluation.source, .cache)
        XCTAssertEqual(evaluation.decision, .required(cachedPolicy))
        XCTAssertEqual(evaluation.failure, .invalidPolicy)
    }
}

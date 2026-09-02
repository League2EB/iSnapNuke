import CryptoKit
import XCTest
@testable import iSnapNukeCore

final class UpdatePolicyTests: XCTestCase {
    func testPolicyDecidesUpToDateOptionalAndRequiredByBuild() {
        let policy = makeUpdatePolicy(latestBuild: 3, minimumBuild: 2)

        XCTAssertEqual(policy.decision(for: makeUpdateVersion(build: 3)), .upToDate)
        XCTAssertEqual(policy.decision(for: makeUpdateVersion(build: 2)), .optional(policy))
        XCTAssertEqual(policy.decision(for: makeUpdateVersion(build: 1)), .required(policy))
    }

    func testPolicyRejectsInvalidBuildAndVersionRanges() {
        XCTAssertThrowsError(
            try makeUpdatePolicy(latestBuild: 2, minimumBuild: 3).validate()
        )
        XCTAssertThrowsError(
            try makeUpdatePolicy(
                latestVersion: "1.0.0",
                minimumVersion: "1.1.0"
            ).validate()
        )
    }

    func testVerifierAcceptsSignedPolicy() throws {
        let privateKey = Curve25519.Signing.PrivateKey()
        let policy = makeUpdatePolicy()
        let document = try makeSignedPolicyDocument(policy: policy, privateKey: privateKey)
        let verifier = try Ed25519UpdatePolicyVerifier(
            publicKeyBase64: privateKey.publicKey.rawRepresentation.base64EncodedString()
        )

        XCTAssertEqual(try verifier.verifiedPolicy(from: document), policy)
    }

    func testVerifierRejectsAChangedPolicy() throws {
        let privateKey = Curve25519.Signing.PrivateKey()
        let policy = makeUpdatePolicy()
        var document = try makeSignedPolicyDocument(policy: policy, privateKey: privateKey)
        document[document.startIndex] ^= 1
        let verifier = try Ed25519UpdatePolicyVerifier(
            publicKeyBase64: privateKey.publicKey.rawRepresentation.base64EncodedString()
        )

        XCTAssertThrowsError(try verifier.verifiedPolicy(from: document))
    }

    func testVerifierRejectsSignatureFromAnotherKey() throws {
        let signingKey = Curve25519.Signing.PrivateKey()
        let verificationKey = Curve25519.Signing.PrivateKey()
        let document = try makeSignedPolicyDocument(
            policy: makeUpdatePolicy(),
            privateKey: signingKey
        )
        let verifier = try Ed25519UpdatePolicyVerifier(
            publicKeyBase64: verificationKey.publicKey.rawRepresentation.base64EncodedString()
        )

        XCTAssertThrowsError(
            try verifier.verifiedPolicy(from: document),
            "A signature must be bound to the pinned public key."
        )
    }
}

import CryptoKit
import Darwin
import Foundation
import iSnapNukeCore

enum ReleaseToolError: LocalizedError {
    case usage
    case missingOption(String)
    case fileAlreadyExists(URL)
    case invalidPrivateKey

    var errorDescription: String? {
        switch self {
        case .usage:
            """
            Usage:
              iSnapNukeReleaseTool generate-policy-key --private-key <path>
              iSnapNukeReleaseTool print-policy-public-key --private-key <path>
              iSnapNukeReleaseTool sign-policy --policy <path> --private-key <path> --output <path>
              iSnapNukeReleaseTool verify-policy --policy <path> --public-key <base64>
            """
        case let .missingOption(option):
            "Missing required option \(option)."
        case let .fileAlreadyExists(url):
            "Refusing to overwrite existing file: \(url.path)"
        case .invalidPrivateKey:
            "The private key is not a valid Ed25519 signing key."
        }
    }
}

struct CommandLineOptions {
    let command: String
    let values: [String: String]

    init(arguments: [String]) throws {
        guard let command = arguments.first else {
            throw ReleaseToolError.usage
        }

        var values: [String: String] = [:]
        var index = 1
        while index < arguments.count {
            let option = arguments[index]
            guard option.hasPrefix("--"), index + 1 < arguments.count else {
                throw ReleaseToolError.usage
            }
            values[option] = arguments[index + 1]
            index += 2
        }

        self.command = command
        self.values = values
    }

    func required(_ name: String) throws -> String {
        guard let value = values[name], !value.isEmpty else {
            throw ReleaseToolError.missingOption(name)
        }
        return value
    }
}

@main
struct iSnapNukeReleaseTool {
    static func main() {
        do {
            let options = try CommandLineOptions(
                arguments: Array(CommandLine.arguments.dropFirst())
            )

            switch options.command {
            case "generate-policy-key":
                try generatePolicyKey(options)
            case "print-policy-public-key":
                try printPolicyPublicKey(options)
            case "sign-policy":
                try signPolicy(options)
            case "verify-policy":
                try verifyPolicy(options)
            default:
                throw ReleaseToolError.usage
            }
        } catch {
            FileHandle.standardError.write(
                Data("error: \(error.localizedDescription)\n".utf8)
            )
            exit(EXIT_FAILURE)
        }
    }

    private static func generatePolicyKey(_ options: CommandLineOptions) throws {
        let privateKeyURL = URL(fileURLWithPath: try options.required("--private-key"))
        guard !FileManager.default.fileExists(atPath: privateKeyURL.path) else {
            throw ReleaseToolError.fileAlreadyExists(privateKeyURL)
        }

        let privateKey = Curve25519.Signing.PrivateKey()
        try FileManager.default.createDirectory(
            at: privateKeyURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try privateKey.rawRepresentation.write(to: privateKeyURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: privateKeyURL.path
        )

        print("Policy public key (base64): \(privateKey.publicKey.rawRepresentation.base64EncodedString())")
        print("Private key saved at: \(privateKeyURL.path)")
        print("Keep the private key outside this repository.")
    }

    private static func printPolicyPublicKey(_ options: CommandLineOptions) throws {
        let privateKey = try privateKey(from: options)
        print(privateKey.publicKey.rawRepresentation.base64EncodedString())
    }

    private static func signPolicy(_ options: CommandLineOptions) throws {
        let policyURL = URL(fileURLWithPath: try options.required("--policy"))
        let outputURL = URL(fileURLWithPath: try options.required("--output"))
        let privateKey = try privateKey(from: options)
        let policy = try decodePolicy(from: policyURL)
        try policy.validate()

        let signature = try privateKey.signature(
            for: SignedUpdatePolicyEnvelope.signingData(for: policy)
        ).base64EncodedString()
        let envelope = SignedUpdatePolicyEnvelope(policy: policy, signature: signature)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(envelope)
        try data.write(to: outputURL, options: .atomic)
        print("Signed policy written to: \(outputURL.path)")
    }

    private static func verifyPolicy(_ options: CommandLineOptions) throws {
        let policyURL = URL(fileURLWithPath: try options.required("--policy"))
        let publicKey = try options.required("--public-key")
        let verifier = try Ed25519UpdatePolicyVerifier(publicKeyBase64: publicKey)
        let policy = try verifier.verifiedPolicy(from: Data(contentsOf: policyURL))
        print(
            "Valid policy: latest \(policy.latestVersion) (\(policy.latestBuild)), " +
                "minimum \(policy.minimumSupportedVersion) (\(policy.minimumSupportedBuild))"
        )
    }

    private static func privateKey(from options: CommandLineOptions) throws
        -> Curve25519.Signing.PrivateKey
    {
        let url = URL(fileURLWithPath: try options.required("--private-key"))
        let data = try Data(contentsOf: url)
        guard let privateKey = try? Curve25519.Signing.PrivateKey(rawRepresentation: data) else {
            throw ReleaseToolError.invalidPrivateKey
        }
        return privateKey
    }

    private static func decodePolicy(from url: URL) throws -> UpdatePolicy {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(UpdatePolicy.self, from: Data(contentsOf: url))
    }
}

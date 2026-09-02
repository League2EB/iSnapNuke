import Foundation

public enum UpdatePolicyFetchResult: Equatable, Sendable {
    case modified(document: Data, eTag: String?)
    case notModified(eTag: String?)
}

public enum UpdatePolicyClientError: Error, Equatable, Sendable {
    case invalidResponse
    case unexpectedStatus(Int)
}

public protocol UpdatePolicyFetching: Sendable {
    func fetch(ifNoneMatch eTag: String?) async throws -> UpdatePolicyFetchResult
}

public struct URLSessionUpdatePolicyClient: UpdatePolicyFetching {
    private let url: URL
    private let session: URLSession
    private let timeout: TimeInterval

    public init(
        url: URL,
        session: URLSession = .shared,
        timeout: TimeInterval = 5
    ) {
        self.url = url
        self.session = session
        self.timeout = timeout
    }

    public func fetch(ifNoneMatch eTag: String?) async throws -> UpdatePolicyFetchResult {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("iSnapNuke-Update-Checker", forHTTPHeaderField: "User-Agent")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        if let eTag {
            request.setValue(eTag, forHTTPHeaderField: "If-None-Match")
        }

        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw UpdatePolicyClientError.invalidResponse
        }

        let responseETag = response.value(forHTTPHeaderField: "ETag")
        switch response.statusCode {
        case 200:
            return .modified(document: data, eTag: responseETag)
        case 304:
            return .notModified(eTag: responseETag ?? eTag)
        default:
            throw UpdatePolicyClientError.unexpectedStatus(response.statusCode)
        }
    }
}

public struct CachedUpdatePolicyDocument: Codable, Equatable, Sendable {
    public let document: Data
    public let eTag: String?
    public let fetchedAt: Date

    public init(document: Data, eTag: String?, fetchedAt: Date) {
        self.document = document
        self.eTag = eTag
        self.fetchedAt = fetchedAt
    }
}

public protocol UpdatePolicyCaching: Sendable {
    func load() async throws -> CachedUpdatePolicyDocument?
    func save(_ cachedDocument: CachedUpdatePolicyDocument) async throws
}

public actor FileUpdatePolicyCache: UpdatePolicyCaching {
    private let fileURL: URL
    private let fileManager: FileManager

    public init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    public static func defaultFileURL(
        bundleIdentifier: String = "com.xuanci.isnapnuke"
    ) -> URL {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return applicationSupport
            .appendingPathComponent(bundleIdentifier, isDirectory: true)
            .appendingPathComponent("update-policy-cache.json")
    }

    public func load() throws -> CachedUpdatePolicyDocument? {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CachedUpdatePolicyDocument.self, from: data)
    }

    public func save(_ cachedDocument: CachedUpdatePolicyDocument) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(cachedDocument)
        try data.write(to: fileURL, options: .atomic)
    }
}

public enum UpdatePolicySource: Equatable, Sendable {
    case network
    case cache
    case none
}

public enum UpdateRefreshFailure: Equatable, Sendable {
    case unavailable
    case invalidPolicy
    case cacheFailure
}

public struct UpdatePolicyEvaluation: Equatable, Sendable {
    public let decision: UpdateDecision?
    public let source: UpdatePolicySource
    public let failure: UpdateRefreshFailure?

    public init(
        decision: UpdateDecision?,
        source: UpdatePolicySource,
        failure: UpdateRefreshFailure? = nil
    ) {
        self.decision = decision
        self.source = source
        self.failure = failure
    }
}

public protocol UpdatePolicyEvaluating: Sendable {
    func cachedEvaluation(for currentVersion: AppVersion) async -> UpdatePolicyEvaluation
    func refreshEvaluation(for currentVersion: AppVersion) async -> UpdatePolicyEvaluation
}

public actor UpdatePolicyService: UpdatePolicyEvaluating {
    private let fetcher: any UpdatePolicyFetching
    private let cache: any UpdatePolicyCaching
    private let verifier: any UpdatePolicyVerifying

    public init(
        fetcher: any UpdatePolicyFetching,
        cache: any UpdatePolicyCaching,
        verifier: any UpdatePolicyVerifying
    ) {
        self.fetcher = fetcher
        self.cache = cache
        self.verifier = verifier
    }

    public func cachedEvaluation(for currentVersion: AppVersion) async -> UpdatePolicyEvaluation {
        do {
            guard let cached = try await loadVerifiedCache() else {
                return UpdatePolicyEvaluation(decision: nil, source: .none)
            }
            return UpdatePolicyEvaluation(
                decision: cached.policy.decision(for: currentVersion),
                source: .cache
            )
        } catch {
            return UpdatePolicyEvaluation(
                decision: nil,
                source: .none,
                failure: classify(error)
            )
        }
    }

    public func refreshEvaluation(for currentVersion: AppVersion) async -> UpdatePolicyEvaluation {
        let cached = try? await loadVerifiedCache()

        do {
            let result = try await fetcher.fetch(ifNoneMatch: cached?.document.eTag)
            switch result {
            case let .notModified(eTag):
                guard let cached else {
                    return UpdatePolicyEvaluation(
                        decision: nil,
                        source: .none,
                        failure: .invalidPolicy
                    )
                }

                if eTag != cached.document.eTag {
                    try? await cache.save(
                        CachedUpdatePolicyDocument(
                            document: cached.document.document,
                            eTag: eTag,
                            fetchedAt: .now
                        )
                    )
                }

                return UpdatePolicyEvaluation(
                    decision: cached.policy.decision(for: currentVersion),
                    source: .cache
                )

            case let .modified(document, eTag):
                let policy = try verifier.verifiedPolicy(from: document)
                try policy.validate()
                if let cached {
                    try ensureNoRollback(from: cached.policy, to: policy)
                }

                let cachedDocument = CachedUpdatePolicyDocument(
                    document: document,
                    eTag: eTag,
                    fetchedAt: .now
                )

                do {
                    try await cache.save(cachedDocument)
                    return UpdatePolicyEvaluation(
                        decision: policy.decision(for: currentVersion),
                        source: .network
                    )
                } catch {
                    return UpdatePolicyEvaluation(
                        decision: policy.decision(for: currentVersion),
                        source: .network,
                        failure: .cacheFailure
                    )
                }
            }
        } catch {
            if let cached {
                return UpdatePolicyEvaluation(
                    decision: cached.policy.decision(for: currentVersion),
                    source: .cache,
                    failure: classify(error)
                )
            }
            return UpdatePolicyEvaluation(
                decision: nil,
                source: .none,
                failure: classify(error)
            )
        }
    }

    private func loadVerifiedCache() async throws
        -> (document: CachedUpdatePolicyDocument, policy: UpdatePolicy)?
    {
        guard let cachedDocument = try await cache.load() else {
            return nil
        }
        let policy = try verifier.verifiedPolicy(from: cachedDocument.document)
        try policy.validate()
        return (cachedDocument, policy)
    }

    private func ensureNoRollback(from cached: UpdatePolicy, to incoming: UpdatePolicy) throws {
        guard
            incoming.latestBuild >= cached.latestBuild,
            incoming.minimumSupportedBuild >= cached.minimumSupportedBuild,
            incoming.publishedAt >= cached.publishedAt
        else {
            throw UpdatePolicyError.policyRollback
        }
    }

    private func classify(_ error: Error) -> UpdateRefreshFailure {
        if error is URLError || error is UpdatePolicyClientError {
            return .unavailable
        }
        if error is UpdatePolicyError || error is DecodingError {
            return .invalidPolicy
        }
        return .cacheFailure
    }
}

public struct DisabledUpdatePolicyEvaluator: UpdatePolicyEvaluating {
    public init() {}

    public func cachedEvaluation(for _: AppVersion) async -> UpdatePolicyEvaluation {
        UpdatePolicyEvaluation(decision: nil, source: .none)
    }

    public func refreshEvaluation(for _: AppVersion) async -> UpdatePolicyEvaluation {
        UpdatePolicyEvaluation(
            decision: nil,
            source: .none,
            failure: .unavailable
        )
    }
}

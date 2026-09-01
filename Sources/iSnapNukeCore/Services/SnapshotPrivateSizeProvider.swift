import Darwin
import Foundation

@_silgen_name("fs_snapshot_list")
private func fsSnapshotList(
    _ directoryFileDescriptor: Int32,
    _ attributes: UnsafeMutablePointer<attrlist>,
    _ buffer: UnsafeMutableRawPointer?,
    _ bufferSize: Int,
    _ flags: UInt32
) -> Int32

public protocol SnapshotPrivateSizeProviding: Sendable {
    func privateSizes(for volume: APFSVolume) throws -> [UUID: Int64]
}

public enum SnapshotPrivateSizeError: Error, Equatable {
    case openFailed(Int32)
    case listFailed(Int32)
    case malformedRecord
}

public struct SnapshotPrivateSizeProvider: SnapshotPrivateSizeProviding {
    private static let pageSize = 64 * 1024

    public init() {}

    public func privateSizes(for volume: APFSVolume) throws -> [UUID: Int64] {
        let descriptor = open(volume.mountPoint, O_RDONLY | O_CLOEXEC)
        guard descriptor >= 0 else {
            throw SnapshotPrivateSizeError.openFailed(errno)
        }
        defer { close(descriptor) }

        var sizes: [UUID: Int64] = [:]
        var page = [UInt8](repeating: 0, count: Self.pageSize)

        while true {
            var attributes = snapshotAttributes()
            let count: Int32 = page.withUnsafeMutableBytes { buffer in
                fsSnapshotList(
                    descriptor,
                    &attributes,
                    buffer.baseAddress,
                    buffer.count,
                    0
                )
            }

            guard count >= 0 else {
                throw SnapshotPrivateSizeError.listFailed(errno)
            }
            guard count > 0 else {
                break
            }

            let records = try SnapshotPrivateSizeParser.parse(
                data: Data(page),
                recordCount: Int(count)
            )
            sizes.merge(records, uniquingKeysWith: { _, latest in latest })
        }

        return sizes
    }

    private func snapshotAttributes() -> attrlist {
        var attributes = attrlist()
        attributes.bitmapcount = UInt16(ATTR_BIT_MAP_COUNT)
        attributes.commonattr =
            mask(ATTR_CMN_NAME) |
            mask(ATTR_CMN_OBJID) |
            mask(ATTR_CMN_CRTIME) |
            mask(ATTR_CMN_UUID) |
            mask(ATTR_CMN_ERROR) |
            mask(ATTR_CMN_RETURNED_ATTRS)
        attributes.fileattr = mask(ATTR_FILE_DATAALLOCSIZE)
        attributes.forkattr = mask(ATTR_CMNEXT_PRIVATESIZE)
        return attributes
    }

    private func mask<T: BinaryInteger>(_ value: T) -> UInt32 {
        UInt32(truncatingIfNeeded: value)
    }
}

enum SnapshotPrivateSizeParser {
    private static let commonName = mask(ATTR_CMN_NAME)
    private static let commonObjectID = mask(ATTR_CMN_OBJID)
    private static let commonCreationTime = mask(ATTR_CMN_CRTIME)
    private static let commonUUID = mask(ATTR_CMN_UUID)
    private static let commonError = mask(ATTR_CMN_ERROR)
    private static let fileDataAllocationSize = mask(ATTR_FILE_DATAALLOCSIZE)
    private static let forkPrivateSize = mask(ATTR_CMNEXT_PRIVATESIZE)

    static func parse(data: Data, recordCount: Int) throws -> [UUID: Int64] {
        try data.withUnsafeBytes { bytes in
            var records: [UUID: Int64] = [:]
            var offset = 0

            for _ in 0..<recordCount {
                let recordLength = try read(UInt32.self, from: bytes, at: offset)
                let length = Int(recordLength)
                let recordEnd = offset + length
                guard length >= 24, recordEnd <= bytes.count else {
                    throw SnapshotPrivateSizeError.malformedRecord
                }

                let commonAttributes = try read(UInt32.self, from: bytes, at: offset + 4)
                let fileAttributes = try read(UInt32.self, from: bytes, at: offset + 16)
                let forkAttributes = try read(UInt32.self, from: bytes, at: offset + 20)

                var cursor = offset + 24
                if commonAttributes & commonName != 0 {
                    try advance(by: 8, cursor: &cursor, recordEnd: recordEnd)
                }
                if commonAttributes & commonObjectID != 0 {
                    try advance(by: 8, cursor: &cursor, recordEnd: recordEnd)
                }
                if commonAttributes & commonCreationTime != 0 {
                    try advance(by: 16, cursor: &cursor, recordEnd: recordEnd)
                }

                let parsedUUID: UUID?
                if commonAttributes & commonUUID != 0 {
                    guard cursor + 16 <= recordEnd else {
                        throw SnapshotPrivateSizeError.malformedRecord
                    }
                    parsedUUID = readUUID(from: bytes, at: cursor)
                    cursor += 16
                } else {
                    parsedUUID = nil
                }

                if commonAttributes & commonError != 0 {
                    try advance(by: 4, cursor: &cursor, recordEnd: recordEnd)
                }
                if fileAttributes & fileDataAllocationSize != 0 {
                    try advance(by: 8, cursor: &cursor, recordEnd: recordEnd)
                }

                if
                    let parsedUUID,
                    forkAttributes & forkPrivateSize != 0
                {
                    let size = try read(UInt64.self, from: bytes, at: cursor)
                    guard size <= UInt64(Int64.max) else {
                        throw SnapshotPrivateSizeError.malformedRecord
                    }
                    records[parsedUUID] = Int64(size)
                }

                offset = recordEnd
            }

            return records
        }
    }

    private static func advance(
        by amount: Int,
        cursor: inout Int,
        recordEnd: Int
    ) throws {
        guard cursor + amount <= recordEnd else {
            throw SnapshotPrivateSizeError.malformedRecord
        }
        cursor += amount
    }

    private static func read<T>(
        _: T.Type,
        from bytes: UnsafeRawBufferPointer,
        at offset: Int
    ) throws -> T {
        guard offset >= 0, offset + MemoryLayout<T>.size <= bytes.count else {
            throw SnapshotPrivateSizeError.malformedRecord
        }
        return bytes.loadUnaligned(fromByteOffset: offset, as: T.self)
    }

    private static func readUUID(
        from bytes: UnsafeRawBufferPointer,
        at offset: Int
    ) -> UUID? {
        let values = (0..<16).map { bytes[offset + $0] }
        let text = String(
            format: "%02X%02X%02X%02X-%02X%02X-%02X%02X-%02X%02X-%02X%02X%02X%02X%02X%02X",
            values[0], values[1], values[2], values[3],
            values[4], values[5], values[6], values[7],
            values[8], values[9], values[10], values[11],
            values[12], values[13], values[14], values[15]
        )
        return UUID(uuidString: text)
    }

    private static func mask<T: BinaryInteger>(_ value: T) -> UInt32 {
        UInt32(truncatingIfNeeded: value)
    }
}

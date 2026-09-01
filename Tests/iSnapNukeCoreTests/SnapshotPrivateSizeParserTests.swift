import XCTest
@testable import iSnapNukeCore

final class SnapshotPrivateSizeParserTests: XCTestCase {
    func testParsesPrivateSizeForSnapshotUUID() throws {
        let uuid = UUID(uuidString: "0FA116AA-913B-4A65-95B0-D5769B5C8097")!
        let data = makeRecord(uuid: uuid, privateSize: 5_191_966_720)

        let values = try SnapshotPrivateSizeParser.parse(data: data, recordCount: 1)

        XCTAssertEqual(values, [uuid: 5_191_966_720])
    }

    func testRejectsTruncatedRecord() {
        XCTAssertThrowsError(
            try SnapshotPrivateSizeParser.parse(data: Data([0x80, 0, 0, 0]), recordCount: 1)
        ) { error in
            XCTAssertEqual(error as? SnapshotPrivateSizeError, .malformedRecord)
        }
    }

    private func makeRecord(uuid: UUID, privateSize: UInt64) -> Data {
        var data = Data()
        append(UInt32(96), to: &data)
        append(UInt32(0x8080_0221), to: &data)
        append(UInt32(0), to: &data)
        append(UInt32(0), to: &data)
        append(UInt32(0x400), to: &data)
        append(UInt32(0x8), to: &data)
        append(Int32(68), to: &data)
        append(UInt32(8), to: &data)
        append(UInt64(19739735), to: &data)
        append(Int64(0), to: &data)
        append(Int64(0), to: &data)
        var rawUUID = uuid.uuid
        withUnsafeBytes(of: &rawUUID) { data.append(contentsOf: $0) }
        append(UInt64(0), to: &data)
        append(privateSize, to: &data)
        data.append(contentsOf: [115, 110, 97, 112, 0, 0, 0, 0])
        return data
    }

    private func append<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
    }
}

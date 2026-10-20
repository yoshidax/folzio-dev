import Foundation

/// zip の CRC-32（多項式 0xEDB88320）。
public enum CRC32 {
    private static let table: [UInt32] = (0..<256).map { index -> UInt32 in
        var value = UInt32(index)
        for _ in 0..<8 {
            value = (value & 1) != 0 ? (0xEDB8_8320 ^ (value >> 1)) : (value >> 1)
        }
        return value
    }

    public static func checksum(_ data: Data) -> UInt32 {
        data.withUnsafeBytes { update(0, $0) }
    }

    /// 既に計算した CRC（先頭は 0）にバイト列を追記した CRC を返す。
    public static func update(_ crc: UInt32, _ bytes: UnsafeRawBufferPointer) -> UInt32 {
        var value = ~crc
        for byte in bytes {
            value = table[Int((value ^ UInt32(byte)) & 0xFF)] ^ (value >> 8)
        }
        return ~value
    }
}

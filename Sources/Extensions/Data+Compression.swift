//
//  Data+Compression.swift
//  DNWebSocket
//
//  Created by Gleb Radchenko on 2/5/18.
//

import Foundation
import CZLib

public enum DataProcessingError: LocalizedError {
    case error(status: CompressionStatus)
}

extension Data {
    private static var chunkSize: Int {
        return 0x2000 // 8192 bits
    }
    
    private static var tail: [UInt8] {
        return [0x00, 0x00, 0xFF, 0xFF]
    }
    
    public mutating func compress(windowBits: CInt) throws -> Data {
        var compressedData = Data()
        var buffer = Data(count: Data.chunkSize)
        
        guard count > 0 else { return compressedData }
        
        var stream = prepareZStream()
        try initializeDeflate(windowBits: windowBits, stream: &stream)
        defer { deflateEnd(&stream) }
        
        var result: CompressionStatus = .ok
        while stream.avail_out == 0 && result == .ok {
            if Int(stream.total_out) >= buffer.count {
                buffer.count += Data.chunkSize
            }
            
            buffer.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) in
                stream.next_out = bytes
                stream.avail_out = uInt(buffer.count)
                
                let code = deflate(&stream, Z_SYNC_FLUSH)
                result = CompressionStatus(status: code)
                
                let writtenCount = buffer.count - Int(stream.avail_out)
                compressedData.append(bytes, count: writtenCount)
            }
        }
        
        return compressedData
    }
    
    public mutating func decompress(windowBits: CInt) throws -> Data {
        var decompressedData = Data()
        var buffer = Data(count: Data.chunkSize)
        
        guard count > 0 else { return decompressedData }
        
        var stream = prepareZStream()
        try initializeInflate(windowBits: windowBits, stream: &stream)
        defer { inflateEnd(&stream) }
        
        var result: CompressionStatus = .ok
        repeat {
            if Int(stream.total_out) >= buffer.count {
                buffer.count += Data.chunkSize
            }
            
            buffer.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) in
                stream.next_out = bytes
                stream.avail_out = uInt(buffer.count)
                
                let code = inflate(&stream, Z_NO_FLUSH)
                result = CompressionStatus(status: code)
                
                let writtenCount = buffer.count - Int(stream.avail_out)
                decompressedData.append(bytes, count: writtenCount)
            }
            
        } while result == .ok
        
        return decompressedData
    }
    
    mutating public func addTail() {
        append(contentsOf: Data.tail)
    }
    
    mutating public func removeTail() {
        removeLast(4)
    }
    
    private func initializeDeflate(windowBits: CInt, stream: inout z_stream) throws {
        let code = deflateInit2_(&stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED,
                                 -windowBits, 8, Z_DEFAULT_STRATEGY,
                                 ZLIB_VERSION, z_stream.memoryLayoutSize)
        try process(code)
    }
    
    private func initializeInflate(windowBits: CInt, stream: inout z_stream) throws {
        let code = inflateInit2_(&stream, -windowBits, ZLIB_VERSION, z_stream.memoryLayoutSize)
        try process(code)
    }
    
    private mutating func prepareZStream() -> z_stream {
        var stream = z_stream()
        
        withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) in
            stream.next_in = bytes
        }
        
        stream.avail_in = uint(count)
        return stream
    }
    
    private func process(_ code: CInt) throws {
        let status = CompressionStatus(status: code)
        
        switch status {
        case .ok:
            return
        default:
            throw DataProcessingError.error(status: status)
        }
    }
}

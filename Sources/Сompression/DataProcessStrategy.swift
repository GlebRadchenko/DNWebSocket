//
//  DataProcessStrategy.swift
//  DNWebSocket
//
//  Created by Gleb Radchenko on 2/2/18.
//

import Foundation
import CZLib

protocol DataProcessingStrategy {
    init(windowBits: Int32) throws
}

public enum DataProcessingError: LocalizedError {
    case error(status: InflateDeflateStatus)
}

class BasicStrategy: DataProcessingStrategy {
    var windowBits: Int32
    var stream: z_stream
    var buffer: [UInt8]
    var prepared: Bool
    
    deinit { try? stop() }
    
    required init(windowBits: Int32) throws {
        self.windowBits = windowBits
        stream = z_stream()
        buffer = Array<UInt8>(repeating: 0, count: 0x2000)
        prepared = false
        
        try prepare()
    }
    
    func process(_ data: Data, tailed: Bool) throws -> Data {
        throw DataProcessingError.error(status: .unknown)
    }
    
    func prepare() throws {
        let status = prepareWithStatus()
        
        switch status {
        case .ok:
            prepared = true
        default:
            prepared = false
            throw DataProcessingError.error(status: status)
        }
    }
    
    func stop() throws {
        guard prepared else { return }
        let status = stopWithStatus()
        
        switch status {
        case .ok:
            prepared = false
        default:
            throw DataProcessingError.error(status: status)
        }
    }
    
    func reset() throws {
        try stop()
        try prepare()
    }
    
    func prepareWithStatus() -> InflateDeflateStatus { return .unknown }
    func stopWithStatus() -> InflateDeflateStatus { return .unknown }
}

class CompressStrategy: BasicStrategy {
    override func prepareWithStatus() -> InflateDeflateStatus {
        let code = deflateInit2_(&stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED,  -windowBits,
                                 MAX_MEM_LEVEL, Z_DEFAULT_STRATEGY, ZLIB_VERSION, z_stream.memoryLayoutSize)
        return InflateDeflateStatus(status: code)
    }
    
    override func stopWithStatus() -> InflateDeflateStatus {
        let code = deflateEnd(&stream)
        return InflateDeflateStatus(status: code)
    }
    
    override func process(_ data: Data, tailed: Bool) throws -> Data {
        var compressedData = Data()
        var result: InflateDeflateStatus = .ok
        
        data.withUnsafeBytes { (pointer: UnsafePointer<UInt8>) in
            stream.next_in = pointer.mutable()
            stream.avail_in = uInt(data.count)
            
            repeat {
                stream.next_out = UnsafeMutablePointer<UInt8>(&buffer)
                stream.avail_out = uInt(buffer.count)
                
                let code = deflate(&stream, Z_SYNC_FLUSH)
                result = InflateDeflateStatus(status: code)
                
                let compressedCount = buffer.count - Int(stream.avail_out)
                compressedData.append(buffer, count: compressedCount)
            } while result == .ok && stream.avail_out == 0
        }
        
        if (result == .ok && self.stream.avail_out > 0) || (result == .bufError && self.stream.avail_out == self.buffer.count) {
            if tailed { compressedData.removeLast(4) }
            return compressedData
        } else {
            throw DataProcessingError.error(status: result)
        }
    }
}

class DecompressStrategy: BasicStrategy {
    override func prepareWithStatus() -> InflateDeflateStatus {
        let code = inflateInit2_(&stream, -windowBits, ZLIB_VERSION, z_stream.memoryLayoutSize)
        return InflateDeflateStatus(status: code)
    }
    
    override func stopWithStatus() -> InflateDeflateStatus {
        let code = inflateEnd(&stream)
        return InflateDeflateStatus(status: code)
    }
    
    override func process(_ data: Data, tailed: Bool) throws -> Data {
        typealias Decompress = (UnsafePointer<UInt8>, Int) throws -> Data
        
        let decompressBlock: Decompress = { (bytes, count) in
            var decompressedChunk = Data()
            
            self.stream.next_in = UnsafeMutablePointer<UInt8>(mutating: bytes)
            self.stream.avail_in = uInt(count)
            var result: InflateDeflateStatus = .ok
            
            repeat {
                self.stream.next_out = UnsafeMutablePointer<UInt8>(&self.buffer)
                self.stream.avail_out = uInt(self.buffer.count)
                
                let code = inflate(&self.stream, Z_NO_FLUSH)
                result = InflateDeflateStatus(status: code)
                
                let decompressedCount = self.buffer.count - Int(self.stream.avail_out)
                decompressedChunk.append(self.buffer, count: decompressedCount)
            } while result == .ok && self.stream.avail_out == 0
            
            if (result == .ok && self.stream.avail_out > 0) || (result == .bufError && self.stream.avail_out == self.buffer.count) {
                return decompressedChunk
            } else {
                throw DataProcessingError.error(status: result)
            }
        }
        
        var decompressedData = Data()
        try data.withUnsafeBytes { (pointer: UnsafePointer<UInt8>) in
            decompressedData = try decompressBlock(pointer, data.count)
            
            if tailed {
                let tailData: [UInt8] = [0x00, 0x00, 0xFF, 0xFF]
                let decompressedTail = try decompressBlock(tailData, tailData.count)
                decompressedData.append(decompressedTail)
            }
        }
        
        return decompressedData
    }
}

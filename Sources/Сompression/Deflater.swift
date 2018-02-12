//
//  Deflater.swift
//  DNWebSocket
//
//  Created by Gleb Radchenko on 2/12/18.
//

import Foundation
import CZLib

class Deflater: CompressionObject {
    
    deinit { deflateEnd(&stream) }
    init?(windowBits: CInt) {
        super.init()
        
        let code = deflateInit2_(&stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED,
                                 -windowBits, 8, Z_DEFAULT_STRATEGY,
                                 ZLIB_VERSION, z_stream.memoryLayoutSize)
        do {
            try process(code)
        } catch {
            debugPrint(error)
            return nil
        }
    }
    
    public func compress(windowBits: CInt, data: Data) throws -> Data {
        var compressedData = Data()
        var buffer = Data(count: CompressionObject.chunkSize)
        
        guard data.count > 0 else { return compressedData }
        
        prepareZStream(for: data)
        
        var result: CompressionStatus = .ok
        while stream.avail_out == 0 && result == .ok {
            if Int(stream.total_out) >= buffer.count {
                buffer.count += CompressionObject.chunkSize
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
}

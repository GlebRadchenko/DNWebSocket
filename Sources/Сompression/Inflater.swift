//
//  Inflater.swift
//  DNWebSocket
//
//  Created by Gleb Radchenko on 2/12/18.
//

import Foundation
import CZLib

public enum DataProcessingError: LocalizedError {
    case error(status: CompressionStatus)
}

class Inflater: CompressionObject {
    
    deinit { inflateEnd(&stream) }
    
    init?(windowBits: CInt) {
        super.init()
        let code = inflateInit2_(&stream, -windowBits, ZLIB_VERSION, z_stream.memoryLayoutSize)
        do {
            try process(code)
        } catch {
            debugPrint(error.localizedDescription)
            return nil
        }
    }
    
    public func decompress(windowBits: CInt, data: Data) throws -> Data {
        var decompressedData = Data()
        var buffer = Data(count: CompressionObject.chunkSize)
        
        guard data.count > 0 else { return decompressedData }
        prepareZStream(for: data)
        
        var result: CompressionStatus = .ok
        repeat {
            if Int(stream.total_out) >= buffer.count {
                buffer.count += CompressionObject.chunkSize
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
}

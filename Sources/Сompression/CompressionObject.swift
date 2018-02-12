//
//  CompressionObject.swift
//  DNWebSocket
//
//  Created by Gleb Radchenko on 2/12/18.
//

import Foundation
import CZLib

class CompressionObject {
    static var chunkSize: Int {
        return 0x2000 // 8192 bytes
    }
    
    var stream: z_stream = z_stream()
    
    func prepareZStream(for data: Data) {
        var data = data
        data.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) in
            stream.next_in = bytes
        }
        
        stream.avail_in = uint(data.count)
    }
    
    func process(_ code: CInt) throws {
        let status = CompressionStatus(status: code)
        
        switch status {
        case .ok:
            return
        default:
            throw DataProcessingError.error(status: status)
        }
    }
    
    func reset() { }
}

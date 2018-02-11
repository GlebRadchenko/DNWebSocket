//
//  Data+Mask.swift
//  DNWebSocket
//
//  Created by Gleb Radchenko on 2/7/18.
//

import Foundation

extension Data {
    mutating func mask(with mask: Data) {
        let buffer = unsafeMutableBuffer()
        buffer.enumerated().forEach { (index, byte) in
            buffer[index] = byte ^ mask[index % 4]
        }
    }
    
    mutating func unmask(with mask: Data) {
        self.mask(with: mask)
    }
    
    static func randomMask() -> Data {
        let size = Int(UInt32.memoryLayoutSize)
        var data = Data(count: size)
        
        _ = data.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) in
            SecRandomCopyBytes(kSecRandomDefault, size, bytes)
        }
        
        return data
    }
}


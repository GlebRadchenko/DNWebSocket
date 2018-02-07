//
//  Data+Mask.swift
//  DNWebSocket
//
//  Created by Gleb Radchenko on 2/7/18.
//

import Foundation

extension Data {
    func masked(with mask: Data) -> Data {
        var data: Data = Data(count: count)
        enumerated().forEach { (index, byte) in
            data[index] = self[index] ^ mask[index % 4]
        }
        
        return data
    }
    
    func unmasked(with mask: Data) -> Data {
        return masked(with: mask)
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

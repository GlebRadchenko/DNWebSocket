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
}

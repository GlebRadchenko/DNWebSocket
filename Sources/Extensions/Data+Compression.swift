//
//  Data+Compression.swift
//  DNWebSocket
//
//  Created by Gleb Radchenko on 2/5/18.
//

import Foundation
import CZLib

extension Data {
    private static var tail: [UInt8] {
        return [0x00, 0x00, 0xFF, 0xFF]
    }
    
    mutating public func addTail() {
        append(contentsOf: Data.tail)
    }
    
    mutating public func removeTail() {
        guard count > 3 else { return }
        removeLast(4)
    }
}

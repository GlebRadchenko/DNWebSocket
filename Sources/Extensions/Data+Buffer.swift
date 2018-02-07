//
//  Data+Buffer.swift
//  DNWebSocket
//
//  Created by Gleb Radchenko on 2/5/18.
//

import Foundation

extension Data {
    static var bufferSize: Int {
        return 4096
    }
    
    static func buffer() -> Data {
        return Data(count: bufferSize)
    }
    
    func unsafeBuffer() -> UnsafeBufferPointer<UInt8> {
        return withUnsafeBytes { (pointer) in
            UnsafeBufferPointer<UInt8>(start: pointer, count: count)
        }
    }
}

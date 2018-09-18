//
//  Data+Buffer.swift
//  DNWebSocket
//
//  Created by Gleb Radchenko on 2/5/18.
//

import Foundation

extension Data {
    static var bufferSize: Int {
        return 8192
    }
    
    static func buffer() -> Data {
        return Data(count: bufferSize)
    }
    
    func unsafeBuffer() -> UnsafeBufferPointer<UInt8> {
        return withUnsafeBytes { (pointer) in
            UnsafeBufferPointer<UInt8>(start: pointer, count: count)
        }
    }
    
    mutating func unsafeMutableBuffer() -> UnsafeMutableBufferPointer<UInt8> {
        let count = self.count
        return withUnsafeMutableBytes { (pointer) in
            UnsafeMutableBufferPointer<UInt8>(start: pointer, count: count)
        }
    }
}


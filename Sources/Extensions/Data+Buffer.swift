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
}

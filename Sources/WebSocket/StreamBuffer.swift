//
//  StreamBuffer.swift
//  DNWebSocket
//
//  Created by Gleb Radchenko on 2/6/18.
//

import Foundation

class StreamBuffer {
    var buffer: Data
    
    init() {
        buffer = Data()
    }
    
    func enqueue(_ chunk: Data) {
        buffer.append(chunk)
    }
    
    func clearBuffer() {
        buffer.removeAll()
    }
}

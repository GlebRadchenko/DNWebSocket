//
//  StreamBuffer.swift
//  DNWebSocket
//
//  Created by Gleb Radchenko on 2/6/18.
//

import Foundation

class StreamBuffer {
    var queue: [Data]
    var buffer: Data
    
    var isEmpty: Bool {
        return queue.isEmpty
    }
    
    var shouldBeProcessed: Bool {
        return queue.count == 1
    }
    
    init() {
        queue = []
        buffer = Data()
    }
    
    func enqueue(_ chunk: Data) {
        queue.append(chunk)
    }
    
    func dequeueIntoBuffer() {
        buffer.append(queue.removeFirst())
    }
    
    func clearBuffer() {
        buffer.removeAll()
    }
    
    func reset() {
        queue.removeAll()
        buffer.removeAll()
    }
}

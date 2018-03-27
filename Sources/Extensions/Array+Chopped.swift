//
//  Array+Chopped.swift
//  DNWebSocket
//
//  Created by Gleb Radchenko on 3/27/18.
//

import Foundation

extension Data {
    func chopped(by chopSize: Int) -> [Data] {
        guard chopSize < count else {
            return [self]
        }
        
        var chunks: [Data] = []
        var start = 0
        
        while start < count {
            let end = Swift.min(start.advanced(by: chopSize), count)
            let chunk = Data(self[start..<end])
            chunks.append(chunk)
            start = end
        }
        
        return chunks
    }
}

extension Array {
    func chopped(by chopSize: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: chopSize).map { (start) -> [Element] in
            let end = Swift.min(start.advanced(by: chopSize), count)
            return Array(self[start..<end])
        }
    }
}

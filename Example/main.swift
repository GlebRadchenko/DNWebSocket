//
//  main.swift
//  Example
//
//  Created by Gleb Radchenko on 2/2/18.
//

import Foundation

print("123")

let initialString = "String to test"
var initialData = initialString.data(using: .utf8) ?? Data()

do {
    var compressed = try initialData.compress(windowBits: 15)
    compressed.removeTail()
    compressed.addTail()
    let decompressed = try compressed.decompress(windowBits: 15)
    print(String(data: decompressed, encoding: .utf8))
} catch {
    debugPrint(error)
}

RunLoop.main.run()

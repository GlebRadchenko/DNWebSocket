//
//  Tests_macOS.swift
//  Tests-macOS
//
//  Created by Gleb Radchenko on 2/5/18.
//

import XCTest
@testable import DNWebSocket

class Tests_macOS: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testCompressing() {
        let initialString = "String to test"
        let initialData = initialString.data(using: .utf8) ?? Data()
        
        do {
            let compress = try CompressStrategy(windowBits: 8)
            let decompress = try DecompressStrategy(windowBits: 8)
            
            
            let compressedData = try compress.process(initialData, tailed: true)
            let decompressedData = try decompress.process(compressedData, tailed: true)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}

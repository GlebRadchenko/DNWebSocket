//
//  TestCompression.swift
//  TestCompression
//
//  Created by Gleb Radchenko on 2/8/18.
//

import XCTest
@testable import DNWebSocket

class TestCompression: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func test1() {
        let inputString = "String to test compression"
        var data = inputString.data(using: .utf8)
        XCTAssertNotNil(data, "String data is empty")
        
        do {
            var compressedData = try data!.compress(windowBits: 15)
            compressedData.removeTail()
            compressedData.addTail()
            let decompressedData = try compressedData.decompress(windowBits: 15)
            let outputString = String(data: decompressedData, encoding: .utf8) ?? ""
            
            XCTAssertEqual(inputString, outputString)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func test2windowbits() {
        let inputString = "String to test compression"
        var data = inputString.data(using: .utf8)
        XCTAssertNotNil(data, "String data is empty")
        
        (10...15).forEach { (windowBits) in
            do {
                var compressedData = try data!.compress(windowBits: CInt(windowBits))
                compressedData.removeTail()
                compressedData.addTail()
                let decompressedData = try compressedData.decompress(windowBits: CInt(windowBits))
                let outputString = String(data: decompressedData, encoding: .utf8) ?? ""
                
                XCTAssertEqual(inputString, outputString)
            } catch {
                XCTFail(error.localizedDescription)
            }
        }
    }
    
    func test3LargeString() {
        var inputString = ""
        inputString += String([Character](repeating: "A", count: 1000))
        inputString += String([Character](repeating: "B", count: 1000))
        inputString += String([Character](repeating: "C", count: 1000))
        inputString += String([Character](repeating: "D", count: 1000))
        inputString += String([Character](repeating: "E", count: 1000))
        inputString += String([Character](repeating: "F", count: 1000))
        inputString += String([Character](repeating: "G", count: 1000))
        inputString += String([Character](repeating: "A", count: 1000))
        inputString += String([Character](repeating: "B", count: 1000))
        inputString += String([Character](repeating: "C", count: 1000))
        
        var data = inputString.data(using: .utf8)
        XCTAssertNotNil(data, "String data is empty")
        
        do {
            var compressedData = try data!.compress(windowBits: 15)
            compressedData.removeTail()
            compressedData.addTail()
            let decompressedData = try compressedData.decompress(windowBits: 15)
            let outputString = String(data: decompressedData, encoding: .utf8) ?? ""
            
            XCTAssertEqual(inputString, outputString)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func test4JsonData() {
        var inputJson: [String: String] = [:]
        (0...1000).forEach { (i) in
            inputJson["key-\(i)"] = "value-\(i)"
        }
        
        var data = try! JSONSerialization.data(withJSONObject: inputJson, options: .prettyPrinted)
        
        do {
            var compressedData = try data.compress(windowBits: 15)
            compressedData.removeTail()
            compressedData.addTail()
            let decompressedData = try compressedData.decompress(windowBits: 15)
            let outputJson = try JSONSerialization.jsonObject(with: decompressedData, options: .mutableLeaves) as! [String: String]
            
            XCTAssertEqual(inputJson, outputJson)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
}

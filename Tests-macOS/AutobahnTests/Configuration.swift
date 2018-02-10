//
//  Helpers.swift
//  Tests-macOS
//
//  Created by Gleb Radchenko on 2/8/18.
//

import Foundation
import DNWebSocket

class TestConfiguration {
    static var agent: String {
        return Bundle(for: self).bundleIdentifier ?? "DNWebSocket"
    }
    
    static var serverURL: URL {
        return URL(string: "ws://localhost:9001")!
    }
    
    static func isAcceptable(result: String) -> Bool {
        let suitableResults = ["OK", "NON-STRICT", "INFORMATIONAL", "UNIMPLEMENTED"]
        return suitableResults.contains(result)
    }
    
    static func testsCount() -> Int {
        var count = 0
        
        let countAction = AutobahnTestAction.testsCount(url: serverURL, agent: agent) { (countReceived) in
            count = countReceived
        }
        
        countAction.perform()
        countAction.waitUntilFinished(timeout: 60)
        
        return count
    }
    
    static func testInfo(number: Int?) -> [String: String] {
        var info: [String: String] = [:]
        
        let infoAction = AutobahnTestAction.testInfo(url: serverURL, caseNumber: number) { (received) in
            info = received
        }
        
        infoAction.perform()
        infoAction.waitUntilFinished(timeout: 60)
        
        return info
    }
    
    static func testResult(number: Int?) -> [String: String] {
        var info: [String: String] = [:]
        
        let resultAction = AutobahnTestAction.testResult(url: serverURL, caseNumber: number, agent: agent) { (received) in
            info = received
        }
        
        resultAction.perform()
        resultAction.waitUntilFinished(timeout: 60)
        
        return info
    }
}

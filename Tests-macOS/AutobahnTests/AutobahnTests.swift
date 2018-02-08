//
//  AutobahnTests.swift
//  Tests-macOS
//
//  Created by Gleb Radchenko on 2/8/18.
//

import XCTest
@testable import DNWebSocket

class AutobahnTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        updateReports()
        super.tearDown()
    }
    
    func updateReports() {
        let op = AutobahnTestOperation.updateReport(url: TestConfiguration.serverURL,
                                                    agent: TestConfiguration.agent)
        op.start()
        XCTAssert(op.waitUntilFinished(timeout: 40), "Update reports timeout")
    }
    
    func testAutoBahnCases() {
        let count = TestConfiguration.testsCount()
        (1...count).forEach { (testNumber) in
            let rawInfo = TestConfiguration.testsCaseInfo(caseNumber: testNumber)
            let info = rawInfo as? [String: String] ?? [:]
            let id = info ["id"] ?? "Unknown id"
            
            makeTest(caseNumber: testNumber, id: id)
        }
    }
    
    func makeTest(caseNumber: Int?, id: String) {
        let url = TestConfiguration.serverURL
        let agent = TestConfiguration.agent
        
        let opQueue = OperationQueue()
        opQueue.maxConcurrentOperationCount = 1
        
        let test = AutobahnTestOperation.test(url: url, caseNumber: caseNumber, agent: agent)
        
        var testInfo: [String: String] = [:]
        let result = AutobahnTestOperation.testResult(url: url, caseNumber: caseNumber, agent: agent) { (info) in
            guard let info = info as? [String: String] else {
                return
            }
            
            testInfo = info
        }
        
        result.addDependency(test)
        
        opQueue.addOperation(test)
        opQueue.addOperation(result)
        
        test.start()
        XCTAssertTrue(result.waitUntilFinished(timeout: 100), "Test case: \(caseNumber ?? -1) timeout")
        if !TestConfiguration.isValidResult(caseId: id, result: testInfo["behavior"] ?? "") {
            XCTFail("Invalid test behaviour: \(testInfo["behavior"] ?? "") for test: \(id)")
        }
    }
    
}

